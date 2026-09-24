// SupabaseRepository against a fake PostgREST.
//
// Everything else in test/ swaps the repository out for a fixture, so the one
// class that actually talks to Postgres -- the paging, the transfer legs, the
// ringgit-to-cents rounding, the error sentences -- was only ever exercised by
// hand. Here the real SupabaseClient runs with an http.MockClient underneath,
// so each test sees the exact requests the app would send.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scandy/models/transaction.dart';
import 'package:scandy/services/scandy_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '11111111-1111-1111-1111-111111111111';

/// A handler answers one request; returning null falls through to a 404 so an
/// unexpected query fails loudly rather than quietly reading as empty.
typedef _Handler = http.Response? Function(http.Request request);

class _FakeServer {
  _FakeServer(this.handler);

  final _Handler handler;
  final requests = <http.Request>[];

  late final client = MockClient((request) async {
    requests.add(request);
    final response =
        handler(request) ??
        _json({'message': 'unexpected ${request.method} ${request.url}'}, 404);
    // postgrest reads the method back off response.request, which a
    // handler-built Response does not carry.
    return http.Response.bytes(
      response.bodyBytes,
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  });

  /// Requests against the REST API, leaving out anything auth might send.
  List<http.Request> get rest =>
      requests.where((r) => r.url.path.startsWith('/rest/v1/')).toList();
}

http.Response _json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _pgError(String code, String message, [int status = 400]) =>
    _json({
      'code': code,
      'message': message,
      'details': null,
      'hint': null,
    }, status);

/// A JWT whose payload only needs an expiry far enough out that the client
/// never tries to refresh it. The signature is never checked client-side.
String _fakeJwt() {
  String part(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${part({'sub': _userId, 'exp': 4102444800, 'role': 'authenticated'})}.'
      'sig';
}

Future<SupabaseClient> _client(
  _FakeServer server, {
  bool signedIn = true,
}) async {
  final client = SupabaseClient(
    'http://scandy.test',
    'anon-key',
    httpClient: server.client,
    // Retries would re-send a failing GET with a back-off, which turns an
    // error-path test into a slow one and doubles the requests it sees.
    postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  if (signedIn) {
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': _fakeJwt(),
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'refresh',
        'user': {
          'id': _userId,
          'aud': 'authenticated',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'created_at': '2026-09-01T00:00:00Z',
        },
      }),
    );
  }
  addTearDown(client.dispose);
  return client;
}

Map<String, dynamic> _txRow(
  String id, {
  String type = 'expense',
  int cents = 1000,
  String? group,
  String account = 'bank',
  String on = '2026-09-06',
}) => {
  'id': id,
  'occurred_on': on,
  'occurred_at': '12:00:00',
  'description': '  $id  ',
  'amount_cents': cents,
  'category': 'Groceries',
  'account_id': account,
  'type': type,
  'transfer_group_id': group,
};

void main() {
  group('reads', () {
    test('transactions are paged until a short page comes back', () async {
      // The migrated ledger was 1,018 rows; PostgREST's max_rows silently cut
      // it at 1,000 before paging was added.
      final all = [for (var i = 0; i < 1018; i++) _txRow('t$i')];
      final server = _FakeServer((r) {
        if (r.url.path != '/rest/v1/transactions') return null;
        final offset = int.parse(r.url.queryParameters['offset']!);
        final limit = int.parse(r.url.queryParameters['limit']!);
        return _json(all.skip(offset).take(limit).toList());
      });
      final repo = SupabaseRepository(await _client(server));

      final got = await repo.fetchTransactions();

      expect(got, hasLength(1018));
      expect(got.first.id, 't0');
      expect(got.last.id, 't1017');
      final pages = server.rest;
      expect(pages.map((r) => r.url.queryParameters['offset']), ['0', '1000']);
      expect(pages.map((r) => r.url.queryParameters['limit']), [
        '1000',
        '1000',
      ]);
      // The id tiebreak is what keeps rows from straddling a page boundary.
      expect(
        pages.first.url.queryParameters['order'],
        'occurred_on.desc.nullslast,occurred_at.desc.nullslast,id.asc.nullslast',
      );
    });

    test(
      'an exact multiple of the page size costs one extra, empty page',
      () async {
        final all = [for (var i = 0; i < 1000; i++) _txRow('t$i')];
        final server = _FakeServer((r) {
          final offset = int.parse(r.url.queryParameters['offset']!);
          return _json(all.skip(offset).take(1000).toList());
        });
        final repo = SupabaseRepository(await _client(server));

        expect(await repo.fetchTransactions(), hasLength(1000));
        expect(server.rest, hasLength(2));
      },
    );

    test(
      'rows are signed by type and both transfer legs learn From and To',
      () async {
        final server = _FakeServer(
          (r) => _json([
            _txRow('salary', type: 'income', cents: 485000),
            _txRow('bread', cents: 720),
            _txRow('out', cents: 50000, group: 'g1', account: 'bank'),
            _txRow(
              'in',
              type: 'income',
              cents: 50000,
              group: 'g1',
              account: 'cash',
            ),
          ]),
        );
        final repo = SupabaseRepository(await _client(server));

        final byId = {for (final t in await repo.fetchTransactions()) t.id: t};

        expect(byId['salary']!.amountCents, 485000);
        expect(byId['bread']!.amountCents, -720);
        expect(byId['bread']!.description, 'bread', reason: 'trimmed');
        expect(byId['bread']!.fromAccountId, isNull);

        for (final leg in [byId['out']!, byId['in']!]) {
          expect(leg.isTransfer, isTrue);
          expect(leg.fromAccountId, 'bank', reason: leg.id);
          expect(leg.toAccountId, 'cash', reason: leg.id);
        }
        expect(byId['out']!.amountCents, -50000);
        expect(byId['in']!.amountCents, 50000);
      },
    );

    test(
      'accounts take their balance from the view, else the opening figure',
      () async {
        final server = _FakeServer(
          (r) => switch (r.url.path) {
            '/rest/v1/accounts' => _json([
              {
                'id': 'bank',
                'name': 'MAE',
                'type': 'Bank',
                'initial_balance_cents': 10000,
              },
              {
                'id': 'new',
                'name': 'TNG',
                'type': 'E-Wallet',
                'initial_balance_cents': -2550,
              },
            ]),
            '/rest/v1/account_balances' => _json([
              {'account_id': 'bank', 'balance_cents': 7329},
            ]),
            _ => null,
          },
        );
        final repo = SupabaseRepository(await _client(server));

        final accounts = await repo.fetchAccounts();

        expect(accounts.map((a) => a.id), [
          'bank',
          'new',
        ], reason: 'server order');
        expect(accounts[0].initialBalance, 100.0);
        expect(accounts[0].balance, 73.29);
        expect(accounts[1].balance, -25.5, reason: 'not silently zero');
        final accountsQuery = server.rest
            .firstWhere((r) => r.url.path == '/rest/v1/accounts')
            .url
            .queryParameters['order'];
        expect(accountsQuery, 'created_at.asc.nullslast,id.asc.nullslast');
      },
    );

    test(
      'categories keep the server order and gain the Transfer kind',
      () async {
        final server = _FakeServer(
          (r) => _json([
            {'kind': 'expense', 'name': 'Food & Drink'},
            {'kind': 'income', 'name': 'Salary'},
            {'kind': 'expense', 'name': 'another'},
          ]),
        );
        final repo = SupabaseRepository(await _client(server));

        expect(await repo.fetchCategories(), {
          'expense': ['Food & Drink', 'another'],
          'income': ['Salary'],
          'transfer': ['Transfer'],
        });
        expect(
          server.rest.single.url.queryParameters['order'],
          'sort_order.asc.nullslast',
        );
      },
    );

    test(
      'an account with no categories of a kind still gets an empty list',
      () async {
        final server = _FakeServer((r) => _json(<Object>[]));
        final repo = SupabaseRepository(await _client(server));

        final got = await repo.fetchCategories();
        expect(got['expense'], isEmpty);
        expect(got['income'], isEmpty);
      },
    );

    test(
      'checkSubscriptions reports how many rows the catch-up wrote',
      () async {
        final server = _FakeServer((r) {
          if (r.url.path != '/rest/v1/rpc/record_due_subscriptions') {
            return null;
          }
          return _json([
            {'id': 'a'},
            {'id': 'b'},
          ]);
        });
        final repo = SupabaseRepository(await _client(server));

        expect(await repo.checkSubscriptions(), 2);
      },
    );
  });

  group('writes', () {
    test('a manual transaction is translated into columns', () async {
      final server = _FakeServer((r) => _json(<Object>[], 201));
      final repo = SupabaseRepository(await _client(server));

      await repo.createManualTransaction({
        'date': '5/9/2026',
        'time': '14:22:00',
        'description': '  Jaya Grocer ',
        // 0.29 * 100 is 28.999999999999996: truncating loses a cent.
        'amount': 0.29,
        'account_id': 'bank',
        'type': 'expense',
      });

      final request = server.rest.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/transactions');
      expect(jsonDecode(request.body), {
        'user_id': _userId,
        'occurred_on': '2026-09-05',
        'occurred_at': '14:22:00',
        'description': 'Jaya Grocer',
        'amount_cents': 29,
        'category': 'Uncategorized',
        'account_id': 'bank',
        'type': 'expense',
      });
    });

    test('amounts are stored as magnitudes, from numbers or strings', () async {
      final server = _FakeServer((r) => _json(<Object>[], 201));
      final repo = SupabaseRepository(await _client(server));

      await repo.createManualTransaction({
        'date': '2026-09-05', // already ISO, passed through
        'amount': '-12.345',
        'type': 'income',
        'category': 'Refunds',
      });

      final body = jsonDecode(server.rest.single.body) as Map;
      expect(body['amount_cents'], 1235);
      expect(body['occurred_on'], '2026-09-05');
      expect(body['occurred_at'], '00:00:00');
      expect(body['type'], 'income');
      expect(body['category'], 'Refunds');
    });

    test('anything that is not income is filed as an expense', () async {
      final server = _FakeServer((r) => _json(<Object>[], 201));
      final repo = SupabaseRepository(await _client(server));

      await repo.createManualTransaction({
        'date': '1/1/2026',
        'amount': 1,
        'type': 'transfer',
      });

      expect((jsonDecode(server.rest.single.body) as Map)['type'], 'expense');
    });

    test('an opening balance keeps its sign', () async {
      final server = _FakeServer((r) => _json(<Object>[], 201));
      final repo = SupabaseRepository(await _client(server));

      await repo.createAccount({
        'name': ' Visa ',
        'type': 'Card',
        'initial_balance': -1200.5,
      });

      expect(jsonDecode(server.rest.single.body), {
        'user_id': _userId,
        'name': 'Visa',
        'type': 'Card',
        'initial_balance_cents': -120050,
      });
    });

    test(
      'a subscription only sends last_recorded_date when the form does',
      () async {
        final server = _FakeServer((r) => _json(<Object>[], 200));
        final repo = SupabaseRepository(await _client(server));

        await repo.updateSubscription('s1', {
          'name': 'Netflix',
          'amount': 54.9,
          'day_of_month': 31,
          'account_id': null,
        });
        await repo.updateSubscription('s1', {
          'name': 'Netflix',
          'amount': 54.9,
          'day_of_month': 31,
          'account_id': null,
          'last_recorded_date': null,
        });

        final first = jsonDecode(server.rest[0].body) as Map;
        final second = jsonDecode(server.rest[1].body) as Map;
        expect(first.containsKey('last_recorded_date'), isFalse);
        expect(first['amount_cents'], 5490);
        expect(first['category'], 'Bills & Utilities');
        expect(second.containsKey('last_recorded_date'), isTrue);
        expect(server.rest[0].method, 'PATCH');
        expect(server.rest[0].url.queryParameters['id'], 'eq.s1');
      },
    );

    test('a transfer goes through create_transfer in one call', () async {
      final server = _FakeServer((r) => _json(null));
      final repo = SupabaseRepository(await _client(server));

      await repo.createTransfer({
        'from_account_id': 'bank',
        'to_account_id': 'cash',
        'amount': 500,
        'date': '04/09/2026',
        'description': 'ATM',
      });

      final request = server.rest.single;
      expect(request.url.path, '/rest/v1/rpc/create_transfer');
      expect(jsonDecode(request.body), {
        'p_from_account': 'bank',
        'p_to_account': 'cash',
        'p_amount_cents': 50000,
        'p_occurred_on': '2026-09-04',
        'p_occurred_at': '00:00:00',
        'p_description': 'ATM',
      });
    });

    test('writing while signed out is refused before any request', () async {
      final server = _FakeServer((r) => _json(<Object>[], 201));
      final repo = SupabaseRepository(await _client(server, signedIn: false));

      await expectLater(
        repo.addCategory(type: 'expense', name: 'Pets'),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.message,
            'message',
            'You are signed out.',
          ),
        ),
      );
      expect(server.rest, isEmpty);
    });
  });

  group('editing and deleting', () {
    test('a plain row is updated in place', () async {
      final server = _FakeServer(
        (r) => r.method == 'GET'
            ? _json({'transfer_group_id': null})
            : _json(<Object>[]),
      );
      final repo = SupabaseRepository(await _client(server));

      await repo.updateTransaction('t1', {
        'date': '06/09/2026',
        'amount': 10,
        'type': 'expense',
      });

      expect(server.rest.map((r) => r.method), ['GET', 'PATCH']);
      expect(server.rest.last.url.queryParameters['id'], 'eq.t1');
    });

    test('a transfer leg is replaced atomically, never patched', () async {
      final server = _FakeServer(
        (r) => r.method == 'GET'
            ? _json({'transfer_group_id': 'g1'})
            : _json(null),
      );
      final repo = SupabaseRepository(await _client(server));

      await repo.updateTransaction('leg', {
        'date': '06/09/2026',
        'time': '10:00:00',
        'amount': 20,
        'type': 'expense',
        'category': 'Food',
        'account_id': 'bank',
      });

      final rpc = server.rest.last;
      expect(rpc.url.path, '/rest/v1/rpc/replace_transaction');
      final params = jsonDecode(rpc.body) as Map;
      expect(params['p_id'], 'leg');
      expect(params['p_type'], 'expense', reason: 'collapsing to a plain row');
      expect(params['p_amount_cents'], 2000);
      expect(params['p_occurred_on'], '2026-09-06');
      expect(server.rest.any((r) => r.method == 'PATCH'), isFalse);
    });

    test(
      'turning a plain row into a transfer also goes through the function',
      () async {
        final server = _FakeServer(
          (r) => r.method == 'GET'
              ? _json({'transfer_group_id': null})
              : _json(null),
        );
        final repo = SupabaseRepository(await _client(server));

        await repo.updateTransaction('t1', {
          'date': '06/09/2026',
          'amount': 20,
          'type': 'transfer',
          'account_id': 'bank',
          'to_account_id': 'cash',
        });

        final params = jsonDecode(server.rest.last.body) as Map;
        expect(params['p_type'], 'transfer');
        expect(params['p_to_account'], 'cash');
      },
    );

    test('editing a row deleted elsewhere says so', () async {
      // maybeSingle() on a GET asks for an array and reads [] as no row.
      final server = _FakeServer((r) => _json(<Object>[]));
      final repo = SupabaseRepository(await _client(server));

      await expectLater(
        repo.updateTransaction('gone', {'amount': 1}),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.message,
            'message',
            'That transaction no longer exists.',
          ),
        ),
      );
    });

    test('deleting either leg of a transfer deletes the whole group', () async {
      final server = _FakeServer(
        (r) => r.method == 'GET'
            ? _json({'transfer_group_id': 'g1'})
            : _json(<Object>[]),
      );
      final repo = SupabaseRepository(await _client(server));

      await repo.deleteTransaction('leg');

      final delete = server.rest.last;
      expect(delete.method, 'DELETE');
      expect(delete.url.queryParameters['transfer_group_id'], 'eq.g1');
      expect(delete.url.queryParameters.containsKey('id'), isFalse);
    });

    test('deleting a plain row deletes only that row', () async {
      final server = _FakeServer(
        (r) => r.method == 'GET'
            ? _json({'transfer_group_id': null})
            : _json(<Object>[]),
      );
      final repo = SupabaseRepository(await _client(server));

      await repo.deleteTransaction('t1');

      expect(server.rest.last.url.queryParameters['id'], 'eq.t1');
    });
  });

  group('errors reach the person as sentences', () {
    // Postgres error code and message in, snackbar text out.
    const cases = <String, (String, String, String)>{
      'duplicate name': (
        '23505',
        'duplicate key value violates unique constraint "categories_user_kind_name_key"',
        'That name is already used.',
      ),
      'row level security': (
        '42501',
        'new row violates row-level security policy for table "transactions"',
        'You do not have access to that.',
      ),
      'deleted account': (
        '23503',
        'insert or update on table "transactions" violates foreign key constraint',
        'That account no longer exists. Refresh and try again.',
      ),
      'expired token': (
        'PGRST301',
        'JWT expired',
        'Your session has expired. Sign in again.',
      ),
      'raised by a function': (
        'P0001',
        'Cannot delete the last expense category',
        'Cannot delete the last expense category',
      ),
      'transfer check': (
        'P0001',
        'Transfer accounts must differ',
        'Transfer accounts must differ',
      ),
      'check constraint': (
        '23514',
        'Amount must be positive',
        'Amount must be positive',
      ),
      'not found': ('P0002', 'No such transaction', 'No such transaction'),
      'unmapped': (
        'XX000',
        'relation "public.transactions" column "amount_cents" is of type bigint',
        'Something went wrong. Try again.',
      ),
    };

    cases.forEach((name, data) {
      final (code, message, shown) = data;
      test(name, () async {
        final server = _FakeServer((r) => _pgError(code, message));
        final repo = SupabaseRepository(await _client(server));

        await expectLater(
          repo.deleteAccount('a1'),
          throwsA(
            isA<RepositoryException>().having(
              (e) => e.message,
              'message',
              shown,
            ),
          ),
        );
      });
    });

    test('no connection reads as no connection', () async {
      final server = _FakeServer(
        (r) => throw const SocketException('Failed host lookup: scandy.test'),
      );
      final repo = SupabaseRepository(await _client(server));

      await expectLater(
        repo.fetchSubscriptions(),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.message,
            'message',
            'Cannot reach Scandy right now. Check your connection.',
          ),
        ),
      );
    });
  });

  test('fetched transactions round-trip through the cache shape', () async {
    // The snapshot cache stores what the repository produced; a field the
    // repository resolves but toJson drops would vanish on the next launch.
    final server = _FakeServer(
      (r) => _json([
        _txRow('out', cents: 50000, group: 'g1', account: 'bank'),
        _txRow(
          'in',
          type: 'income',
          cents: 50000,
          group: 'g1',
          account: 'cash',
        ),
      ]),
    );
    final repo = SupabaseRepository(await _client(server));

    for (final t in await repo.fetchTransactions()) {
      final back = Transaction.fromJson(t.toJson());
      expect(back.amountCents, t.amountCents);
      expect(back.fromAccountId, t.fromAccountId);
      expect(back.toAccountId, t.toAccountId);
      expect(back.date, t.date);
    }
  });
}
