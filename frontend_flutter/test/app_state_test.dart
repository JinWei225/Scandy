// AppState's mutations and the preference controllers. The load path has its
// own file (snapshot_cache_test.dart); this is what happens after it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scandy/models/account.dart';
import 'package:scandy/models/subscription.dart';
import 'package:scandy/models/transaction.dart';
import 'package:scandy/services/scandy_repository.dart';
import 'package:scandy/state/app_state.dart';
import 'package:scandy/state/locale_controller.dart';
import 'package:scandy/state/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Transaction _tx(String id, {String account = 'bank', String? group}) =>
    Transaction(
      id: id,
      date: DateTime(2026, 9, 6),
      time: '12:00:00',
      description: id,
      amountCents: -100,
      category: 'Food',
      accountId: account,
      type: group == null ? TransactionType.expense : TransactionType.transfer,
      transferGroupId: group,
    );

class _Repo implements ScandyRepository {
  List<Transaction> rows = [
    _tx('bread'),
    _tx('out', group: 'g1'),
    _tx('in', account: 'cash', group: 'g1'),
    _tx('milk', account: 'cash'),
  ];
  Object? deleteFailure;
  Object? readFailure;
  final deleted = <String>[];

  @override
  Future<List<Transaction>> fetchTransactions() async {
    if (readFailure != null) throw readFailure!;
    return rows;
  }

  @override
  Future<List<Account>> fetchAccounts() async => const [];
  @override
  Future<List<Subscription>> fetchSubscriptions() async => const [];
  @override
  Future<Map<String, List<String>>> fetchCategories() async => const {};
  @override
  Future<int> checkSubscriptions() async => 0;

  @override
  Future<void> deleteTransaction(String id) async {
    if (deleteFailure != null) throw deleteFailure!;
    deleted.add(id);
    final group = rows.firstWhere((t) => t.id == id).transferGroupId;
    rows = rows
        .where(
          (t) => t.id != id && (group == null || t.transferGroupId != group),
        )
        .toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('not used here: ${invocation.memberName}');
}

void main() {
  group('deleteTransaction', () {
    test('removes both legs of a transfer at once, then revalidates', () async {
      final repo = _Repo();
      final state = AppState(repo);
      await state.loadAll();

      // Watch what the screen sees the moment the delete starts, before the
      // server has answered.
      final seen = <List<String>>[];
      state.addListener(
        () => seen.add(state.transactions.map((t) => t.id).toList()),
      );

      await state.deleteTransaction('in');

      expect(seen.first, ['bread', 'milk'], reason: 'optimistic');
      expect(repo.deleted, ['in']);
      expect(state.transactions.map((t) => t.id), ['bread', 'milk']);
      expect(state.status, LoadStatus.ready);
    });

    test('a plain row takes nothing else with it', () async {
      final state = AppState(_Repo());
      await state.loadAll();

      await state.deleteTransaction('bread');

      expect(state.transactions.map((t) => t.id), ['out', 'in', 'milk']);
    });

    test('a refused delete puts the rows back and rethrows', () async {
      final repo = _Repo()
        ..deleteFailure = RepositoryException(
          'You do not have access to that.',
        );
      final state = AppState(repo);
      await state.loadAll();

      await expectLater(
        state.deleteTransaction('out'),
        throwsA(isA<RepositoryException>()),
      );

      expect(state.transactions.map((t) => t.id), [
        'bread',
        'out',
        'in',
        'milk',
      ]);
    });
  });

  group('loadAll', () {
    test(
      'an unexpected failure is reported as it is, without a preamble',
      () async {
        final state = AppState(_Repo()..readFailure = StateError('bad row'));

        await state.loadAll();

        expect(state.status, LoadStatus.failed);
        expect(state.error, 'Bad state: bad row');
      },
    );

    test('a successful reload clears the previous error', () async {
      final repo = _Repo()..readFailure = RepositoryException('offline');
      final state = AppState(repo);
      await state.loadAll();
      expect(state.error, 'offline');

      repo.readFailure = null;
      await state.refresh();

      expect(state.status, LoadStatus.ready);
      expect(state.error, isNull);
    });
  });

  test(
    'transactionCountFor counts both legs, each against its own account',
    () async {
      final state = AppState(_Repo());
      await state.loadAll();
      expect(state.transactionCountFor('bank'), 2);
      expect(state.transactionCountFor('cash'), 2);
      expect(state.transactionCountFor('none'), 0);
    },
  );

  group('ThemeController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'follows the system until a mode is picked, and remembers it',
      () async {
        final first = ThemeController();
        await first.load();
        expect(first.mode, ThemeMode.system);

        await first.set(ThemeMode.dark);

        final next = ThemeController();
        await next.load();
        expect(next.mode, ThemeMode.dark);
      },
    );

    test('an unknown stored value falls back to the system', () async {
      SharedPreferences.setMockInitialValues({'scandy.themeMode': 'sepia'});
      final c = ThemeController();
      await c.load();
      expect(c.mode, ThemeMode.system);
    });
  });

  group('LocaleController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a picked language survives a restart', () async {
      final first = LocaleController();
      await first.load();
      expect(first.locale, isNull, reason: 'follows the phone');

      await first.set(const Locale('zh'));

      final next = LocaleController();
      await next.load();
      expect(next.locale, const Locale('zh'));
    });

    test('going back to the phone language forgets the pin', () async {
      SharedPreferences.setMockInitialValues({'scandy.locale': 'zh'});
      final c = LocaleController();
      await c.load();
      await c.set(null);

      final next = LocaleController();
      await next.load();
      expect(next.locale, isNull);
    });
  });
}
