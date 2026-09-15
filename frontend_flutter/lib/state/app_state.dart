import 'dart:async';

import 'package:flutter/material.dart';

import '../models/account.dart';
import '../models/month_summary.dart';
import '../models/subscription.dart';
import '../models/transaction.dart';
import '../services/scandy_repository.dart';
import '../services/snapshot_cache.dart';

enum LoadStatus { idle, loading, ready, failed }

/// Replaces the Vue singleton composables (`useTransactions`, `useAccounts`)
/// with one notifier. They shared module-level `ref`s so every component saw
/// the same list; a single ChangeNotifier provided above the app gives the
/// same property without the implicit global.
class AppState extends ChangeNotifier {
  /// Without a [cache] every launch starts from the network, which is what
  /// tests want and what the app used to do.
  // ignore: prefer_initializing_formals
  AppState(this._repo, {SnapshotCache? cache}) : _cache = cache;

  final ScandyRepository _repo;
  final SnapshotCache? _cache;

  /// Whoever [start] was called for. Everything that lands after an await --
  /// a snapshot read, a network response -- checks it is still theirs before
  /// touching the lists, since a sign-out can happen in the meantime.
  String? _userId;

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

  /// Whether there is a ledger on screen -- possibly a stale one, if the load
  /// that followed it failed. Screens use this to keep showing what they have
  /// instead of swapping it for a spinner or an error card.
  bool get hasData => _transactions.isNotEmpty || _accounts.isNotEmpty;

  ScandyRepository get repo => _repo;

  /// Every row dated within [range], inclusive at both ends — Home's "Recent"
  /// card. The repository orders newest-first, so this keeps that order.
  ///
  /// Only the calendar date matters: the range's times are ignored, so a
  /// picker that hands back midnight-to-midnight still includes the last day.
  List<Transaction> transactionsBetween(DateTimeRange range) {
    final start = DateUtils.dateOnly(range.start);
    final end = DateUtils.dateOnly(range.end);
    return _transactions.where((t) {
      final date = t.date;
      if (date == null) return false;
      final day = DateUtils.dateOnly(date);
      return !day.isBefore(start) && !day.isAfter(end);
    }).toList(growable: false);
  }

  /// The account behind [id], or null once it has been deleted.
  Account? accountById(String id) {
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// "Bank · 32 transactions" on the Accounts screen. Both legs of a transfer
  /// are real rows against their own accounts, so they are counted here —
  /// unlike in the spending figures, where they would double-count.
  int transactionCountFor(String accountId) =>
      _transactions.where((t) => t.accountId == accountId).length;

  /// Every month that has at least one transaction, newest first, with the
  /// current month always included so Summary opens somewhere sensible on a
  /// fresh install. Drives the month picker. With [accountId] only that
  /// account's rows count, so an Account page's chevrons skip the months it
  /// sat idle.
  List<DateTime> availableMonths({DateTime? now, String? accountId}) {
    final today = now ?? DateTime.now();
    final months = <DateTime>{DateTime(today.year, today.month)};
    for (final t in _transactions) {
      if (accountId != null && t.accountId != accountId) continue;
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

  /// The first load for whoever just signed in.
  ///
  /// If the last load for this person is still on disk it goes on screen
  /// first, and the network is asked in the background; a launch then shows
  /// the ledger in the time it takes to read a file rather than the time it
  /// takes to make three round trips. Only with nothing cached -- first
  /// launch, or a different account -- does the spinner appear.
  Future<void> start(String userId) async {
    _userId = userId;

    final cached = await _cache?.read(userId);
    if (_userId != userId) return; // signed out while the disk was read
    if (cached != null) {
      _apply(cached);
      _status = LoadStatus.ready;
      notifyListeners();
    }

    await loadAll(showSpinner: cached == null);
  }

  Future<void> loadAll({bool showSpinner = true}) async {
    final user = _userId;
    if (showSpinner) {
      _status = LoadStatus.loading;
      _error = null;
      notifyListeners();
    }

    try {
      // The catch-up used to run before the reads so that anything it
      // recorded came back in the same load. That put a whole round trip in
      // front of every launch to cover a case that comes up once a month.
      // Now it runs alongside them, and only if it did record something are
      // the reads repeated.
      final catchUp = _catchUpSubscriptions();
      var snapshot = await _fetchAll();
      if (await catchUp > 0) snapshot = await _fetchAll();

      if (_userId != user) return; // somebody else's ledger by now
      _apply(snapshot);
      _status = LoadStatus.ready;
      _error = null;
      notifyListeners();

      if (user != null) await _cache?.write(user, snapshot);
      return;
    } on RepositoryException catch (e) {
      _error = e.message;
      _status = LoadStatus.failed;
    } catch (e) {
      // The raw failure, with no English preamble bolted on: the UI supplies
      // its own heading in the reader's language, and this line is whatever
      // the server or the network actually said.
      _error = '$e';
      _status = LoadStatus.failed;
    }
    if (_userId != user) return;
    notifyListeners();
  }

  /// One await for four independent GETs — on a phone the round trips
  /// dominate, so serialising them is felt.
  Future<Snapshot> _fetchAll() async {
    final results = await Future.wait([
      _repo.fetchTransactions(),
      _repo.fetchAccounts(),
      _repo.fetchSubscriptions(),
      _repo.fetchCategories(),
    ]);
    return Snapshot(
      transactions: results[0] as List<Transaction>,
      accounts: results[1] as List<Account>,
      subscriptions: results[2] as List<Subscription>,
      categories: results[3] as Map<String, List<String>>,
    );
  }

  /// How many recurring charges the backend just recorded; zero when it has
  /// already been asked this session. Failure is not fatal — offline, or no
  /// server yet — and the flag stays down so the next load tries again.
  /// Nothing is lost by skipping it: the backend works out what it owes from
  /// last_recorded_date whenever it is next asked.
  Future<int> _catchUpSubscriptions() async {
    if (_subscriptionsChecked) return 0;
    try {
      final recorded = await _repo.checkSubscriptions();
      _subscriptionsChecked = true;
      return recorded;
    } catch (_) {
      return 0;
    }
  }

  void _apply(Snapshot snapshot) {
    _transactions = snapshot.transactions;
    _accounts = snapshot.accounts;
    _subscriptions = snapshot.subscriptions;
    _categories = snapshot.categories;
  }

  /// Pull-to-refresh: keeps the current data on screen while it revalidates.
  Future<void> refresh() => loadAll(showSpinner: false);

  /// Forget everything, on sign-out -- in memory and on disk.
  ///
  /// Without this the next person to sign in on this device sees the previous
  /// user's transactions until the first load returns. Brief, but separate
  /// ledgers that leak for a second are not separate ledgers.
  ///
  /// _subscriptionsChecked is reset too: the catch-up is per session, and the
  /// next user has their own recurring charges to settle.
  void clear() {
    _userId = null;
    _transactions = const [];
    _accounts = const [];
    _subscriptions = const [];
    _categories = const {};
    _status = LoadStatus.idle;
    _error = null;
    _subscriptionsChecked = false;
    notifyListeners();
    // The snapshot on disk goes too: it is the signed-out person's ledger,
    // and a sign-out that leaves it readable on the phone is not a sign-out.
    unawaited(_cache?.clear());
  }

  Future<void> deleteTransaction(String id) async {
    final previous = _transactions;
    // Optimistic, and dropping the paired transfer leg too, which the
    // repository also removes. Matching on the shared group rather than on the
    // id means either half of a transfer can be the one deleted.
    final group = _transactions
        .where((t) => t.id == id)
        .map((t) => t.transferGroupId)
        .firstOrNull;
    _transactions = _transactions
        .where((t) =>
            t.id != id && (group == null || t.transferGroupId != group))
        .toList(growable: false);
    notifyListeners();

    try {
      await _repo.deleteTransaction(id);
    } catch (_) {
      _transactions = previous;
      notifyListeners();
      rethrow;
    }

    // Balances are computed by the server, not from _transactions, so the
    // optimistic removal above leaves every account still carrying the deleted
    // amount. Revalidate the way every other mutation does; the list is
    // already correct, so nothing visible flickers.
    await refresh();
  }
}
