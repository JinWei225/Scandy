import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account.dart';
import '../models/subscription.dart';
import '../models/transaction.dart';

/// Thrown for anything the user should see. Carries a message safe for a
/// snackbar -- Postgres error text is not.
class RepositoryException implements Exception {
  RepositoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Everything the app needs from storage.
///
/// An interface rather than a single class so tests can supply their own data
/// without a network, a container or a fixture server. [SupabaseRepository] is
/// the only implementation that ships.
///
/// The map-shaped arguments are deliberate. The forms already build these, in
/// the app's own units -- ringgit, DD/MM/YYYY -- and translating to database
/// columns in one place keeps every screen out of the business of knowing what
/// the schema looks like.
abstract class ScandyRepository {
  Future<List<Transaction>> fetchTransactions();
  Future<List<Account>> fetchAccounts();
  Future<List<Subscription>> fetchSubscriptions();
  Future<Map<String, List<String>>> fetchCategories();

  /// Records any recurring charges that have come due. Idempotent.
  Future<void> checkSubscriptions();

  Future<void> createManualTransaction(Map<String, dynamic> body);
  Future<void> updateTransaction(String id, Map<String, dynamic> body);
  Future<void> deleteTransaction(String id);
  Future<void> createTransfer(Map<String, dynamic> body);

  Future<void> createAccount(Map<String, dynamic> body);
  Future<void> updateAccount(String id, Map<String, dynamic> body);
  Future<void> deleteAccount(String id);

  Future<void> createSubscription(Map<String, dynamic> body);
  Future<void> updateSubscription(String id, Map<String, dynamic> body);
  Future<void> deleteSubscription(String id);

  Future<void> addCategory({required String type, required String name});
  Future<void> renameCategory({
    required String type,
    required String oldName,
    required String newName,
  });
  Future<void> deleteCategory({required String type, required String name});
}

/// Talks to Postgres through Supabase, with row level security doing the
/// filtering. Note that nothing here passes a user id: the policies derive it
/// from the caller's token, so a query cannot be pointed at somebody else's
/// rows even by mistake.
class SupabaseRepository implements ScandyRepository {
  SupabaseRepository([SupabaseClient? client])
      : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  // --- Reads ---------------------------------------------------------------

  @override
  Future<List<Transaction>> fetchTransactions() => _guard(() async {
        final rows = await _db
            .from('transactions')
            .select()
            .order('occurred_on', ascending: false)
            .order('occurred_at', ascending: false);

        // Resolve each transfer's two legs into From/To, which the edit form
        // needs and which no single row carries. Done here rather than in the
        // model because it is a fact about the pair, not about a row.
        final outgoing = <String, String?>{};
        final incoming = <String, String?>{};
        for (final row in rows) {
          final group = row['transfer_group_id'] as String?;
          if (group == null) continue;
          if (row['type'] == 'expense') {
            outgoing[group] = row['account_id'] as String?;
          } else {
            incoming[group] = row['account_id'] as String?;
          }
        }

        return rows.map((row) {
          final group = row['transfer_group_id'] as String?;
          return Transaction.fromRow(
            row,
            fromAccountId: group == null ? null : outgoing[group],
            toAccountId: group == null ? null : incoming[group],
          );
        }).toList(growable: false);
      });

  @override
  Future<List<Account>> fetchAccounts() => _guard(() async {
        // Two queries rather than an embedded join: account_balances is a view
        // keyed by account_id, and PostgREST will not embed a view that has no
        // declared foreign key back to the table.
        final rows = await _db.from('accounts').select().order('created_at');
        final balances =
            await _db.from('account_balances').select('account_id, balance_cents');

        final byId = <String, int>{
          for (final b in balances)
            b['account_id'] as String: (b['balance_cents'] as num).toInt(),
        };

        return rows
            .map((row) => Account.fromRow(row,
                balanceCents: byId[row['id'] as String]))
            .toList(growable: false);
      });

  @override
  Future<List<Subscription>> fetchSubscriptions() => _guard(() async {
        final rows = await _db.from('subscriptions').select().order('name');
        return rows.map(Subscription.fromRow).toList(growable: false);
      });

  @override
  Future<Map<String, List<String>>> fetchCategories() => _guard(() async {
        final rows =
            await _db.from('categories').select('kind, name').order('name');
        final result = <String, List<String>>{'expense': [], 'income': []};
        for (final row in rows) {
          (result[row['kind'] as String] ??= []).add(row['name'] as String);
        }
        // Not a stored category: 'Transfer' is written by create_transfer and
        // the schema forbids anyone creating one by that name.
        result['transfer'] = const ['Transfer'];
        return result;
      });

  @override
  Future<void> checkSubscriptions() =>
      _guard(() => _db.rpc('record_due_subscriptions'));

  // --- Transactions --------------------------------------------------------

  @override
  Future<void> createManualTransaction(Map<String, dynamic> body) =>
      _guard(() => _db.from('transactions').insert({
            'user_id': _userId,
            ..._transactionColumns(body),
          }));

  @override
  Future<void> updateTransaction(String id, Map<String, dynamic> body) =>
      _guard(() async {
        final existing = await _db
            .from('transactions')
            .select('transfer_group_id')
            .eq('id', id)
            .maybeSingle();
        if (existing == null) {
          throw RepositoryException('That transaction no longer exists.');
        }
        final group = existing['transfer_group_id'] as String?;
        final becomesTransfer = body['type'] == 'transfer';

        // A transfer is two rows, so "edit" cannot be an UPDATE: changing
        // either side's account or amount has to move both legs together. The
        // Flask version rebuilt the pair for the same reason.
        if (becomesTransfer || group != null) {
          if (group != null) {
            await _db.from('transactions').delete().eq('transfer_group_id', group);
          } else {
            await _db.from('transactions').delete().eq('id', id);
          }
          if (becomesTransfer) {
            await _createTransfer({
              ...body,
              'from_account_id': body['account_id'],
            });
          } else {
            await _db.from('transactions').insert({
              'user_id': _userId,
              ..._transactionColumns(body),
            });
          }
          return;
        }

        await _db.from('transactions').update(_transactionColumns(body)).eq('id', id);
      });

  @override
  Future<void> deleteTransaction(String id) => _guard(() async {
        final row = await _db
            .from('transactions')
            .select('transfer_group_id')
            .eq('id', id)
            .maybeSingle();
        final group = row?['transfer_group_id'] as String?;
        // Deleting one leg of a transfer would leave the other stranded,
        // silently changing both accounts' balances.
        if (group != null) {
          await _db.from('transactions').delete().eq('transfer_group_id', group);
        } else {
          await _db.from('transactions').delete().eq('id', id);
        }
      });

  @override
  Future<void> createTransfer(Map<String, dynamic> body) =>
      _guard(() => _createTransfer(body));

  Future<void> _createTransfer(Map<String, dynamic> body) => _db.rpc(
        'create_transfer',
        params: {
          'p_from_account': body['from_account_id'],
          'p_to_account': body['to_account_id'],
          'p_amount_cents': _cents(body['amount']),
          'p_occurred_on': _isoDate(body['date']),
          'p_occurred_at': body['time'] ?? '00:00:00',
          'p_description': body['description'],
        },
      );

  // --- Accounts ------------------------------------------------------------

  @override
  Future<void> createAccount(Map<String, dynamic> body) =>
      _guard(() => _db.from('accounts').insert({
            'user_id': _userId,
            ..._accountColumns(body),
          }));

  @override
  Future<void> updateAccount(String id, Map<String, dynamic> body) => _guard(
      () => _db.from('accounts').update(_accountColumns(body)).eq('id', id));

  @override
  Future<void> deleteAccount(String id) =>
      _guard(() => _db.from('accounts').delete().eq('id', id));

  // --- Subscriptions -------------------------------------------------------

  @override
  Future<void> createSubscription(Map<String, dynamic> body) =>
      _guard(() => _db.from('subscriptions').insert({
            'user_id': _userId,
            ..._subscriptionColumns(body),
          }));

  @override
  Future<void> updateSubscription(String id, Map<String, dynamic> body) =>
      _guard(() => _db
          .from('subscriptions')
          .update(_subscriptionColumns(body))
          .eq('id', id));

  @override
  Future<void> deleteSubscription(String id) =>
      _guard(() => _db.from('subscriptions').delete().eq('id', id));

  // --- Categories ----------------------------------------------------------

  @override
  Future<void> addCategory({required String type, required String name}) =>
      _guard(() => _db.from('categories').insert({
            'user_id': _userId,
            'kind': type,
            'name': name.trim(),
          }));

  @override
  Future<void> renameCategory({
    required String type,
    required String oldName,
    required String newName,
  }) =>
      _guard(() => _db.rpc('rename_category', params: {
            'p_kind': type,
            'p_old_name': oldName,
            'p_new_name': newName.trim(),
          }));

  @override
  Future<void> deleteCategory({required String type, required String name}) =>
      _guard(() => _db
          .from('categories')
          .delete()
          .eq('kind', type)
          .eq('name', name));

  // --- Translation ---------------------------------------------------------

  String get _userId {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw RepositoryException('You are signed out.');
    return id;
  }

  Map<String, dynamic> _transactionColumns(Map<String, dynamic> body) => {
        'occurred_on': _isoDate(body['date']),
        'occurred_at': body['time'] ?? '00:00:00',
        'description': (body['description'] as String? ?? '').trim(),
        'amount_cents': _cents(body['amount']),
        'category': body['category'] ?? 'Uncategorized',
        'account_id': body['account_id'],
        'type': body['type'] == 'income' ? 'income' : 'expense',
      };

  Map<String, dynamic> _accountColumns(Map<String, dynamic> body) => {
        'name': (body['name'] as String? ?? '').trim(),
        'type': body['type'],
        'initial_balance_cents': _cents(body['initial_balance']),
      };

  Map<String, dynamic> _subscriptionColumns(Map<String, dynamic> body) => {
        'name': (body['name'] as String? ?? '').trim(),
        'amount_cents': _cents(body['amount']),
        'category': body['category'] ?? 'Bills & Utilities',
        'day_of_month': body['day_of_month'],
        'account_id': body['account_id'],
        if (body.containsKey('last_recorded_date'))
          'last_recorded_date': body['last_recorded_date'],
      };

  /// Ringgit to cents, rounded rather than truncated.
  ///
  /// The rounding is load-bearing: RM 0.29 is 28.999999999999996 hundredths in
  /// binary, so truncating loses a cent on 573 of the 10,000 amounts between
  /// RM 0.01 and RM 100.00.
  static int _cents(Object? amount) {
    final value = amount is num ? amount.toDouble() : double.tryParse('$amount');
    return ((value ?? 0) * 100).round().abs();
  }

  /// The forms speak DD/MM/YYYY; Postgres wants ISO.
  static String _isoDate(Object? raw) {
    final text = '${raw ?? ''}'.trim();
    final parts = text.split('/');
    if (parts.length == 3) {
      final d = parts[0].padLeft(2, '0');
      final m = parts[1].padLeft(2, '0');
      return '${parts[2]}-$m-$d';
    }
    return text; // already ISO
  }

  /// One place to turn database failures into sentences.
  ///
  /// Postgres speaks in constraint names and error codes. Letting those reach a
  /// snackbar means showing somebody 'new row violates row-level security
  /// policy for table "transactions"' when what happened is that their session
  /// expired.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      throw RepositoryException(_readable(e));
    } on AuthException {
      throw RepositoryException('Your session has expired. Sign in again.');
    } on RepositoryException {
      rethrow;
    } catch (e) {
      final text = '$e';
      if (text.contains('SocketException') ||
          text.contains('ClientException') ||
          text.contains('Failed host lookup') ||
          text.contains('TimeoutException')) {
        throw RepositoryException(
            'Cannot reach Scandy right now. Check your connection.');
      }
      throw RepositoryException('Something went wrong. Try again.');
    }
  }

  static String _readable(PostgrestException e) {
    final message = e.message;
    // Raised by name from the functions and triggers, so it is already written
    // for a person: "Cannot delete the last expense category".
    if (e.code == '23514' || message.startsWith('Cannot ') ||
        message.startsWith('Transfer ') || message.startsWith('Category ')) {
      return message;
    }
    if (e.code == '23505') {
      return 'That name is already used.';
    }
    if (e.code == '42501') {
      return 'You do not have access to that.';
    }
    return message;
  }
}
