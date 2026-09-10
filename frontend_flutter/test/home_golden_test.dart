// Tagged so CI can run this separately from everything else.
//
// matchesGoldenFile compares actual pixels, and text rasterises differently on
// macOS and Linux -- sub-pixel differences in the same font, at the same size.
// A golden recorded on one will never match the other, which is why Flutter's
// own repository pins its goldens to a single platform. These were recorded on
// macOS, so they are checked on macOS.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scandy/models/account.dart';
import 'package:scandy/models/subscription.dart';
import 'package:scandy/models/transaction.dart';
import 'package:scandy/services/scandy_repository.dart';
import 'package:scandy/state/app_state.dart';
import 'package:scandy/theme/app_theme.dart';
import 'package:scandy/ui/home/home_screen.dart';
import 'package:scandy/ui/home/safe_to_spend_card.dart';
import 'package:scandy/ui/shell/bottom_nav.dart';

/// The figures printed in the handoff, as models rather than as JSON.
///
/// This used to be canned HTTP responses for a mocked http.Client. There is no
/// HTTP left to mock -- the app talks to Postgres -- so the fixture is now the
/// data itself, which is both shorter and one fewer layer that can be wrong
/// without the screen being wrong.
///
/// The five rows below are the ones the design shows. The last makes the
/// month's spending add up to RM 2,914.40 without appearing in the "Recent"
/// card -- that card takes the first five of a newest-first list, so it sits
/// last.
List<Transaction> _transactions() {
  Transaction tx({
    required String desc,
    required int cents,
    required String category,
    required DateTime date,
    required String time,
    required TransactionType type,
  }) =>
      Transaction(
        id: '${date.toIso8601String()}-$desc',
        date: date,
        time: time,
        description: desc,
        // Positive in the database, signed here, exactly as fromRow does it.
        amountCents: type == TransactionType.income ? cents : -cents,
        category: category,
        accountId: 'acc-1',
        type: type,
      );

  return [
    tx(desc: 'Jaya Grocer', cents: 8640, category: 'Groceries', date: DateTime(2026, 9, 6), time: '14:22:00', type: TransactionType.expense),
    tx(desc: 'Grab ride', cents: 1420, category: 'Transport', date: DateTime(2026, 9, 6), time: '09:05:00', type: TransactionType.expense),
    tx(desc: 'Salary — September', cents: 485000, category: 'Salary', date: DateTime(2026, 9, 5), time: '08:00:00', type: TransactionType.income),
    tx(desc: 'Spotify Family', cents: 2690, category: 'Subscriptions', date: DateTime(2026, 9, 4), time: '00:12:00', type: TransactionType.expense),
    tx(desc: 'Kopi Kenangan', cents: 1150, category: 'Food & Drink', date: DateTime(2026, 9, 3), time: '16:40:00', type: TransactionType.expense),
    // 86.40 + 14.20 + 26.90 + 11.50 = 139.00; + 2775.40 = 2914.40.
    tx(desc: 'Earlier spending', cents: 277540, category: 'Shopping', date: DateTime(2026, 9, 2), time: '10:00:00', type: TransactionType.expense),
  ];
}

/// Serves the fixtures and refuses everything else, so a screen that starts
/// writing during a render fails the test instead of passing quietly.
class _FakeRepository implements ScandyRepository {
  @override
  Future<List<Transaction>> fetchTransactions() async => _transactions();

  @override
  Future<List<Account>> fetchAccounts() async => const [
        Account(
          id: 'acc-1',
          name: 'Maybank',
          type: 'Bank',
          initialBalance: 8412.55,
          balance: 8412.55,
        ),
      ];

  @override
  Future<List<Subscription>> fetchSubscriptions() async => [
        Subscription(
          id: 'sub-1',
          name: 'Recurring due',
          amount: 268.90,
          category: 'Subscriptions',
          dayOfMonth: 20,
          accountId: 'acc-1',
          lastRecordedDate: DateTime(2026, 8, 20),
        ),
      ];

  @override
  Future<Map<String, List<String>>> fetchCategories() async => const {
        'expense': ['Groceries'],
        'income': ['Salary'],
        'transfer': ['Transfer'],
      };

  @override
  Future<void> checkSubscriptions() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
      'The Home golden test does not write: ${invocation.memberName}');
}

/// Pinned to the date the design's frames carry (6 September 2026, 21:04), so
/// the greeting, the date line and "24 days left" never drift.
final _fixedNow = DateTime(2026, 9, 6, 21, 4);

Widget _app(Brightness brightness, AppState state) {
  return ChangeNotifierProvider.value(
    value: state,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildScandyTheme(brightness),
      home: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              Expanded(child: HomeScreen(clock: _fixedNow)),
              ScandyBottomNav(
                current: NavTab.home,
                onSelect: (_) {},
                onAdd: () {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Home renders — ${brightness.name}', (tester) async {
      // The design's mobile frame is 392 x 844.
      tester.view.physicalSize = const Size(392 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final state = AppState(_FakeRepository());
      await state.loadAll();
      expect(state.status, LoadStatus.ready, reason: state.error);

      await tester.pumpWidget(_app(brightness, state));
      await tester.pumpAndSettle();

      // The figures the design prints, proving the screen is wired to the
      // same arithmetic and not just laid out to look right. These hold for
      // any run date because the clock is pinned above.
      expect(find.text('RM 1,666.70'), findsOneWidget);
      expect(find.text('24 days left'), findsOneWidget);
      expect(find.text('Jaya Grocer'), findsOneWidget);
      expect(find.text('−86.40'), findsOneWidget);
      expect(find.text('+4,850.00'), findsOneWidget);
      // The filler row must not reach the five-row Recent card.
      expect(find.text('Earlier spending'), findsNothing);

      // Regression, twice over. The bar collapsed to zero width because its
      // SizedBox declared no width under the Column's loose constraints; then
      // its *segments* collapsed to zero height because a childless ColoredBox
      // takes the smallest height a centred Row will give it. Both times the
      // card looked fine except for a missing progress track, so the segment
      // is measured here, not just the box around it.
      final bar = tester.getSize(find.byKey(SafeToSpendCard.barKey));
      expect(bar.height, 9);
      expect(bar.width, greaterThan(300));

      final spentSegment =
          tester.getSize(find.byKey(SafeToSpendCard.barSpentSegmentKey));
      expect(spentSegment.height, 9, reason: 'segment must fill the track');
      // ~60% of the bar, per the design.
      expect(spentSegment.width, closeTo(bar.width * 0.60, 4));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_${brightness.name}.png'),
      );
    });
  }
}
