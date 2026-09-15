// What a launch shows before the network answers, and what it does once the
// network has: the snapshot cache and the load path around it.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scandy/models/account.dart';
import 'package:scandy/models/subscription.dart';
import 'package:scandy/models/transaction.dart';
import 'package:scandy/services/scandy_repository.dart';
import 'package:scandy/services/snapshot_cache.dart';
import 'package:scandy/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bank = Account(
  id: 'bank',
  name: 'Maybank',
  type: 'Bank',
  initialBalance: 12.5,
  balance: -3.29,
);

const _netflix = Subscription(
  id: 'sub1',
  name: 'Netflix',
  amount: 54.9,
  category: 'Entertainment',
  dayOfMonth: 31,
  accountId: 'bank',
  lastRecordedDate: null,
);

Transaction _tx(String id, {String? group}) => Transaction(
  id: id,
  date: DateTime(2026, 9, 6),
  time: '12:00:00',
  description: 'Row $id',
  amountCents: -2900,
  category: 'Groceries',
  accountId: 'bank',
  type: group == null ? TransactionType.expense : TransactionType.transfer,
  transferGroupId: group,
  fromAccountId: group == null ? null : 'bank',
  toAccountId: group == null ? null : 'cash',
);

/// A repository whose answers can be swapped mid-test and whose reads can be
/// held open, so a test can look at the screen between the disk and the
/// network answering.
class _Repo implements ScandyRepository {
  List<Transaction> transactions = [_tx('net')];
  int recordedByCatchUp = 0;
  Object? failure;

  /// Completed by the test to let the reads through.
  Completer<void>? gate;

  int fetchCount = 0;
  int catchUpCount = 0;

  Future<T> _read<T>(T value) async {
    await gate?.future;
    fetchCount++;
    if (failure != null) throw failure!;
    return value;
  }

  @override
  Future<List<Transaction>> fetchTransactions() => _read(transactions);
  @override
  Future<List<Account>> fetchAccounts() => _read(const [_bank]);
  @override
  Future<List<Subscription>> fetchSubscriptions() => _read(const [_netflix]);
  @override
  Future<Map<String, List<String>>> fetchCategories() => _read(const {
    'expense': ['Groceries'],
    'income': ['Salary'],
    'transfer': ['Transfer'],
  });
  @override
  Future<int> checkSubscriptions() async {
    catchUpCount++;
    return recordedByCatchUp;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('read-only fixture: ${invocation.memberName}');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SnapshotCache', () {
    test('round-trips every field', () async {
      final cache = SnapshotCache();
      await cache.write(
        'u1',
        Snapshot(
          transactions: [_tx('a'), _tx('b', group: 'g1')],
          accounts: const [_bank],
          subscriptions: const [_netflix],
          categories: const {
            'expense': ['Groceries'],
            'transfer': ['Transfer'],
          },
        ),
      );

      final back = (await cache.read('u1'))!;
      expect(back.transactions.map((t) => t.id), ['a', 'b']);
      final transfer = back.transactions[1];
      expect(transfer.type, TransactionType.transfer);
      expect(transfer.transferGroupId, 'g1');
      expect(transfer.fromAccountId, 'bank');
      expect(transfer.toAccountId, 'cash');
      expect(transfer.date, DateTime(2026, 9, 6));
      expect(transfer.amountCents, -2900);

      final bank = back.accounts.single;
      expect(bank.initialBalance, 12.5);
      expect(bank.balance, -3.29);

      final sub = back.subscriptions.single;
      expect(sub.amount, 54.9);
      expect(sub.dayOfMonth, 31);
      expect(sub.lastRecordedDate, isNull);

      expect(back.categories, {
        'expense': ['Groceries'],
        'transfer': ['Transfer'],
      });
    });

    test('is not handed to a different user', () async {
      final cache = SnapshotCache();
      await cache.write(
        'u1',
        const Snapshot(
          transactions: [],
          accounts: [_bank],
          subscriptions: [],
          categories: {},
        ),
      );
      expect(await cache.read('u2'), isNull);
      expect(await cache.read('u1'), isNotNull);
    });

    test('a blob it cannot parse reads as no cache', () async {
      SharedPreferences.setMockInitialValues({'scandy.snapshot': '{nope'});
      expect(await SnapshotCache().read('u1'), isNull);
    });
  });

  group('AppState.start', () {
    test('shows the snapshot before the network answers, then refreshes',
        () async {
      final cache = SnapshotCache();
      await cache.write(
        'u1',
        Snapshot(
          transactions: [_tx('disk')],
          accounts: const [_bank],
          subscriptions: const [],
          categories: const {},
        ),
      );
      final repo = _Repo()..gate = Completer();
      final state = AppState(repo, cache: cache);

      final statuses = <LoadStatus>[];
      state.addListener(() => statuses.add(state.status));

      final started = state.start('u1');
      await Future<void>.delayed(Duration.zero);

      // The disk has answered, the network has not: a ledger, no spinner.
      expect(state.status, LoadStatus.ready);
      expect(state.transactions.map((t) => t.id), ['disk']);
      expect(statuses, isNot(contains(LoadStatus.loading)));

      repo.gate!.complete();
      await started;

      expect(state.transactions.map((t) => t.id), ['net']);
      expect(statuses, isNot(contains(LoadStatus.loading)));
      expect((await cache.read('u1'))!.transactions.single.id, 'net');
    });

    test('with nothing cached it spins, then caches what it got', () async {
      final cache = SnapshotCache();
      final state = AppState(_Repo(), cache: cache);
      final statuses = <LoadStatus>[];
      state.addListener(() => statuses.add(state.status));

      await state.start('u1');

      expect(statuses, [LoadStatus.loading, LoadStatus.ready]);
      expect((await cache.read('u1'))!.transactions.single.id, 'net');
    });

    test('a failed refresh keeps the snapshot on screen', () async {
      final cache = SnapshotCache();
      await cache.write(
        'u1',
        Snapshot(
          transactions: [_tx('disk')],
          accounts: const [_bank],
          subscriptions: const [],
          categories: const {},
        ),
      );
      final state = AppState(
        _Repo()..failure = RepositoryException('Cannot reach Scandy right now.'),
        cache: cache,
      );

      await state.start('u1');

      expect(state.status, LoadStatus.failed);
      expect(state.error, 'Cannot reach Scandy right now.');
      expect(state.hasData, isTrue);
      expect(state.transactions.map((t) => t.id), ['disk']);
    });

    test('signing out wipes the disk, not just memory', () async {
      final cache = SnapshotCache();
      final state = AppState(_Repo(), cache: cache);
      await state.start('u1');
      expect(await cache.read('u1'), isNotNull);

      state.clear();
      await Future<void>.delayed(Duration.zero);

      expect(state.hasData, isFalse);
      expect(await cache.read('u1'), isNull);
    });

    test('a load that lands after sign-out is dropped', () async {
      final repo = _Repo()..gate = Completer();
      final state = AppState(repo, cache: SnapshotCache());

      final started = state.start('u1');
      await Future<void>.delayed(Duration.zero);
      state.clear();
      repo.gate!.complete();
      await started;

      expect(state.hasData, isFalse);
      expect(state.status, LoadStatus.idle);
      expect(await SnapshotCache().read('u1'), isNull);
    });
  });

  group('AppState.loadAll', () {
    test('runs the catch-up alongside the reads and only rereads if it wrote',
        () async {
      final repo = _Repo();
      final state = AppState(repo);

      await state.loadAll();
      expect(repo.catchUpCount, 1);
      expect(repo.fetchCount, 4);

      await state.refresh();
      expect(repo.catchUpCount, 1, reason: 'once per session');
      expect(repo.fetchCount, 8);
    });

    test('rereads when the catch-up recorded a charge', () async {
      final repo = _Repo()..recordedByCatchUp = 1;
      final state = AppState(repo);

      await state.loadAll();
      expect(repo.fetchCount, 8);
      expect(state.status, LoadStatus.ready);
    });
  });
}
