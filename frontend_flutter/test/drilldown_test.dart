// The arithmetic behind the three drill-downs: Home's date range, the rows
// behind a category figure, and the Account page's scoped month.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scandy/models/account.dart';
import 'package:scandy/models/subscription.dart';
import 'package:scandy/models/summary_stats.dart';
import 'package:scandy/models/transaction.dart';
import 'package:scandy/services/scandy_repository.dart';
import 'package:scandy/l10n/l10n.dart';
import 'package:scandy/state/app_state.dart';
import 'package:scandy/state/locale_controller.dart';
import 'package:scandy/theme/app_theme.dart';
import 'package:scandy/ui/home/date_range_chip.dart';
import 'package:scandy/ui/summary/month_stepper.dart';

Transaction _tx({
  required String id,
  required int cents,
  required DateTime date,
  TransactionType type = TransactionType.expense,
  String category = 'Groceries',
  String account = 'bank',
  String? group,
}) => Transaction(
  id: id,
  date: date,
  time: '12:00:00',
  description: id,
  amountCents: type == TransactionType.income ? cents : -cents,
  category: category,
  accountId: account,
  type: type,
  transferGroupId: group,
);

/// Newest first, as the repository orders them.
final _rows = <Transaction>[
  _tx(id: 'sep6-bank', cents: 8640, date: DateTime(2026, 9, 6)),
  _tx(
    id: 'sep6-cash',
    cents: 1150,
    date: DateTime(2026, 9, 6),
    account: 'cash',
    category: 'Food',
  ),
  _tx(
    id: 'sep5-salary',
    cents: 485000,
    date: DateTime(2026, 9, 5),
    type: TransactionType.income,
    category: 'Salary',
  ),
  _tx(id: 'sep4-uncat', cents: 2000, date: DateTime(2026, 9, 4), category: ''),
  _tx(
    id: 'sep4-out',
    cents: 50000,
    date: DateTime(2026, 9, 4),
    type: TransactionType.transfer,
    group: 'g1',
  ),
  _tx(
    id: 'sep4-in',
    cents: 50000,
    date: DateTime(2026, 9, 4),
    type: TransactionType.transfer,
    group: 'g1',
    account: 'cash',
  ),
  _tx(id: 'sep3', cents: 3000, date: DateTime(2026, 9, 3)),
  _tx(id: 'jul1-cash', cents: 700, date: DateTime(2026, 7, 1), account: 'cash'),
];

class _FakeRepository implements ScandyRepository {
  @override
  Future<List<Transaction>> fetchTransactions() async => _rows;
  @override
  Future<List<Account>> fetchAccounts() async => const [
    Account(
      id: 'bank',
      name: 'Maybank',
      type: 'Bank',
      initialBalance: 0,
      balance: 0,
    ),
    Account(
      id: 'cash',
      name: 'Wallet',
      type: 'Cash',
      initialBalance: 0,
      balance: 0,
    ),
  ];
  @override
  Future<List<Subscription>> fetchSubscriptions() async => const [];
  @override
  Future<Map<String, List<String>>> fetchCategories() async => const {};
  @override
  Future<void> checkSubscriptions() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('read-only fixture: ${invocation.memberName}');
}

void main() {
  final now = DateTime(2026, 9, 6, 21, 4);

  group('Home date range', () {
    test('defaults to today and the two days before, times stripped', () {
      final range = defaultRecentRange(now);
      expect(range.start, DateTime(2026, 9, 4));
      expect(range.end, DateTime(2026, 9, 6));
    });

    test(
      'transactionsBetween is inclusive at both ends and keeps order',
      () async {
        final state = AppState(_FakeRepository());
        await state.loadAll();
        final ids = state
            .transactionsBetween(defaultRecentRange(now))
            .map((t) => t.id)
            .toList();
        expect(ids, [
          'sep6-bank',
          'sep6-cash',
          'sep5-salary',
          'sep4-uncat',
          'sep4-out',
          'sep4-in',
        ]);
      },
    );

    test('a range whose end carries a time still includes that day', () async {
      final state = AppState(_FakeRepository());
      await state.loadAll();
      final picked = DateTimeRange(
        start: DateTime(2026, 9, 3),
        end: DateTime(2026, 9, 3, 0, 0),
      );
      expect(state.transactionsBetween(picked).map((t) => t.id), ['sep3']);
    });
  });

  group('Category drill-down', () {
    test('rows behind a category match the figure it was tapped on', () {
      final stats = MonthStats.forMonth(
        DateTime(2026, 9),
        transactions: _rows,
        now: now,
      );
      final groceries = stats.categories.firstWhere(
        (c) => c.category == 'Groceries',
      );
      final rows = MonthStats.transactionsFor(
        _rows,
        month: stats.month,
        category: 'Groceries',
        income: false,
      );
      expect(rows.map((t) => t.id), ['sep6-bank', 'sep3']);
      expect(
        rows.fold<int>(0, (s, t) => s + t.amountCents.abs()),
        groceries.cents,
      );
    });

    test('rows saved with no category are found under the shared bucket', () {
      final stats = MonthStats.forMonth(
        DateTime(2026, 9),
        transactions: _rows,
        now: now,
      );
      expect(
        stats.categories.map((c) => c.category),
        contains('Uncategorised'),
      );
      final rows = MonthStats.transactionsFor(
        _rows,
        month: stats.month,
        category: 'Uncategorised',
        income: false,
      );
      expect(rows.map((t) => t.id), ['sep4-uncat']);
    });

    test('income and spending under the same name are kept apart', () {
      final rows = MonthStats.transactionsFor(
        _rows,
        month: DateTime(2026, 9),
        category: 'Salary',
        income: false,
      );
      expect(rows, isEmpty);
    });

    test('transfers never appear behind a category', () {
      final rows = MonthStats.transactionsFor(
        _rows,
        month: DateTime(2026, 9),
        category: 'Groceries',
        income: false,
      );
      expect(rows.any((t) => t.isTransfer), isFalse);
    });
  });

  group('Account page', () {
    test('stats are scoped to the account, transfers excluded', () {
      final stats = MonthStats.forMonth(
        DateTime(2026, 9),
        transactions: _rows,
        now: now,
        accountId: 'cash',
      );
      expect(stats.spentCents, 1150);
      expect(stats.moneyInCents, 0);
      expect(stats.categories.map((c) => c.category), ['Food']);
    });

    test('a category page opened from the account shows only its rows', () {
      final rows = MonthStats.transactionsFor(
        _rows,
        month: DateTime(2026, 9),
        category: 'Groceries',
        income: false,
        accountId: 'bank',
      );
      expect(rows.map((t) => t.id), ['sep6-bank', 'sep3']);
      expect(
        MonthStats.transactionsFor(
          _rows,
          month: DateTime(2026, 9),
          category: 'Groceries',
          income: false,
          accountId: 'cash',
        ),
        isEmpty,
      );
    });

    test('months with data are per account, current month always in', () async {
      final state = AppState(_FakeRepository());
      await state.loadAll();
      expect(state.availableMonths(now: now, accountId: 'cash'), [
        DateTime(2026, 9),
        DateTime(2026, 7),
      ]);
      expect(state.availableMonths(now: now, accountId: 'bank'), [
        DateTime(2026, 9),
      ]);
      expect(state.accountById('cash')?.name, 'Wallet');
      expect(state.accountById('gone'), isNull);
    });
  });

  group('Range picker framing', pickerFramingTests);

  group('Month stepper', () {
    test('neighbours hop between months with data', () {
      final months = [DateTime(2026, 9), DateTime(2026, 7), DateTime(2025, 12)];
      final n = monthNeighbours(months, DateTime(2026, 7));
      expect(n.older, DateTime(2025, 12));
      expect(n.newer, DateTime(2026, 9));
      expect(monthNeighbours(months, DateTime(2026, 9)).newer, isNull);
      expect(monthNeighbours(months, DateTime(2025, 12)).older, isNull);
    });

    test('a selected month with no data is still stepped away from', () {
      final months = [DateTime(2026, 9), DateTime(2026, 5)];
      final n = monthNeighbours(months, DateTime(2026, 7));
      expect(n.older, DateTime(2026, 5));
      expect(n.newer, DateTime(2026, 9));
    });
  });
}

/// The range picker as the two compositions frame it.
Widget _chipApp(DateTime now) => MaterialApp(
  theme: buildScandyTheme(Brightness.light),
  locale: const Locale('en'),
  localizationsDelegates: L.localizationsDelegates,
  supportedLocales: LocaleController.supported,
  home: Scaffold(
    body: Center(
      child: DateRangeChip(
        range: defaultRecentRange(now),
        now: now,
        onChanged: (_) {},
      ),
    ),
  ),
);

void pickerFramingTests() {
  final now = DateTime(2026, 9, 6, 21, 4);

  testWidgets('the range picker fills a phone screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_chipApp(now));
    await tester.tap(find.text('4 Sep – 6 Sep'));
    await tester.pumpAndSettle();

    final dialog = tester.getSize(find.byType(Dialog));
    expect(dialog.width, 390);
    expect(dialog.height, 844);
  });

  testWidgets('the range picker is a dialog on a desktop window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_chipApp(now));
    await tester.tap(find.text('4 Sep – 6 Sep'));
    await tester.pumpAndSettle();

    // Framed, not full screen: the calendar still renders and the window
    // around it is left to the scrim.
    final dialog = tester.getSize(find.byType(Dialog));
    expect(dialog.width, 440);
    expect(dialog.height, 620);
    expect(find.text('Choose a date range'), findsOneWidget);
  });
}
