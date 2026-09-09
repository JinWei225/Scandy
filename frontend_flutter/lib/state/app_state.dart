import 'package:flutter/foundation.dart';

import '../models/account.dart';
import '../models/month_summary.dart';
import '../models/subscription.dart';
import '../models/transaction.dart';
import '../services/api_client.dart';

enum LoadStatus { idle, loading, ready, failed }

/// Replaces the Vue singleton composables (`useTransactions`, `useAccounts`)
/// with one notifier. They shared module-level `ref`s so every component saw
/// the same list; a single ChangeNotifier provided above the app gives the
/// same property without the implicit global.
class AppState extends ChangeNotifier {
  AppState(this._api);

  final ApiClient _api;

  List<Transaction> _transactions = const [];
  List<Account> _accounts = const [];
  List<Subscription> _subscriptions = const [];
  Map<String, List<String>> _categories = const {};

  LoadStatus _status = LoadStatus.idle;
  String? _error;

  /// Recurring charges are caught up once per session, not on every refresh:
  /// the backend's own month arithmetic is idempotent, so repeating it just
  /// costs a round trip.
  bool _subscriptionsChecked = false;

  List<Transaction> get transactions => _transactions;
  List<Account> get accounts => _accounts;
  List<Subscription> get subscriptions => _subscriptions;
  Map<String, List<String>> get categories => _categories;
  LoadStatus get status => _status;
  String? get error => _error;

  ApiClient get api => _api;

  /// The five most recent rows, as the design's "Recent" card shows. The API
  /// already orders newest-first, so this is a plain prefix.
  List<Transaction> get recentTransactions =>
      _transactions.take(5).toList(growable: false);

  /// "Bank · 32 transactions" on the Accounts screen. Both legs of a transfer
  /// are real rows against their own accounts, so they are counted here —
  /// unlike in the spending figures, where they would double-count.
  int transactionCountFor(String accountId) =>
      _transactions.where((t) => t.accountId == accountId).length;

  /// Every month that has at least one transaction, newest first, with the
  /// current month always included so Summary opens somewhere sensible on a
  /// fresh install. Drives the month picker.
  List<DateTime> availableMonths({DateTime? now}) {
    final today = now ?? DateTime.now();
    final months = <DateTime>{DateTime(today.year, today.month)};
    for (final t in _transactions) {
      final date = t.date;
      if (date != null) months.add(DateTime(date.year, date.month));
    }
    final sorted = months.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  MonthSummary get summary => summaryFor(DateTime.now());

  /// [now] is a parameter rather than being read inside, so widget tests and
  /// goldens can pin a date instead of drifting every time the clock rolls
  /// past midnight (which silently changed "24 days left" to "23").
  MonthSummary summaryFor(DateTime now) => MonthSummary.forMonth(
        now,
        transactions: _transactions,
        subscriptions: _subscriptions,
        totalBalance:
            _accounts.fold<double>(0, (sum, a) => sum + a.balance),
        accountCount: _accounts.length,
      );

  Future<void> loadAll({bool showSpinner = true}) async {
    if (showSpinner) {
      _status = LoadStatus.loading;
      _error = null;
      notifyListeners();
    }

    // Before the reads, so anything it records shows up in this same load.
    // Failure is not fatal — offline, or no server address yet — and the flag
    // stays down so the next load tries again.
    if (!_subscriptionsChecked) {
      try {
        await _api.checkSubscriptions();
        _subscriptionsChecked = true;
      } catch (_) {
        // Nothing is lost by skipping it: the backend works out what it owes
        // from last_recorded_date whenever it is next asked.
      }
    }

    try {
      // One await for four independent GETs — on a phone talking to a LAN
      // server the round trips dominate, so serialising them is felt.
      final results = await Future.wait([
        _api.fetchTransactions(),
        _api.fetchAccounts(),
        _api.fetchSubscriptions(),
        _api.fetchCategories(),
      ]);

      _transactions = results[0] as List<Transaction>;
      _accounts = results[1] as List<Account>;
      _subscriptions = results[2] as List<Subscription>;
      _categories = results[3] as Map<String, List<String>>;
      _status = LoadStatus.ready;
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
      _status = LoadStatus.failed;
    } catch (e) {
      _error = 'Something went wrong: $e';
      _status = LoadStatus.failed;
    }
    notifyListeners();
  }

  /// Pull-to-refresh: keeps the current data on screen while it revalidates.
  Future<void> refresh() => loadAll(showSpinner: false);

  Future<void> deleteTransaction(String id) async {
    final previous = _transactions;
    // Optimistic, mirroring the Vue composable — and dropping the paired
    // transfer leg too, which the backend also removes.
    _transactions = _transactions
        .where((t) => t.id != id && t.transferRelatedId != id)
        .toList(growable: false);
    notifyListeners();

    try {
      await _api.deleteTransaction(id);
    } catch (_) {
      _transactions = previous;
      notifyListeners();
      rethrow;
    }
  }
}
