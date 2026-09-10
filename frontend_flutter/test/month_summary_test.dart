import 'package:flutter_test/flutter_test.dart';
import 'package:scandy/models/month_summary.dart';
import 'package:scandy/models/subscription.dart';
import 'package:scandy/models/transaction.dart';

Transaction _tx({
  required int cents,
  required TransactionType type,
  required DateTime date,
  String? transferGroupId,
}) {
  return Transaction(
    id: '${date.toIso8601String()}-$cents',
    date: date,
    time: '12:00:00',
    description: 'test',
    amountCents: type == TransactionType.income ? cents : -cents,
    category: 'Other',
    accountId: 'acc',
    type: type,
    transferGroupId: transferGroupId,
  );
}

void main() {
  // 6 September 2026, the date the design's frames are dated.
  final now = DateTime(2026, 9, 6, 21, 4);

  group('MonthSummary reproduces the handoff figures', () {
    final summary = MonthSummary.forMonth(
      now,
      transactions: [
        _tx(cents: 485000, type: TransactionType.income, date: DateTime(2026, 9, 5)),
        _tx(cents: 291440, type: TransactionType.expense, date: DateTime(2026, 9, 6)),
      ],
      subscriptions: [
        Subscription(
          id: 's1',
          name: 'Spotify Family',
          amount: 268.90,
          category: 'Subscriptions',
          dayOfMonth: 20,
          accountId: 'acc',
          lastRecordedDate: DateTime(2026, 8, 20),
        ),
      ],
      totalBalance: 8412.55,
      accountCount: 4,
    );

    test('in − spent − due = safe to spend', () {
      expect(summary.moneyInCents, 485000);
      expect(summary.spentCents, 291440);
      expect(summary.recurringDueCents, 26890);
      // RM 1,666.70 in the design.
      expect(summary.safeToSpendCents, 166670);
    });

    test('days left counts the rest of the month', () {
      // September has 30 days; on the 6th the design reads "24 days left".
      expect(summary.daysLeft, 24);
    });

    test('per-day is safe-to-spend spread over the days left', () {
      // RM 69.44 in the design.
      expect(summary.perDay, closeTo(69.4458, 0.001));
    });

    test('bar segments are fractions of money in', () {
      expect(summary.spentFraction, closeTo(0.6009, 0.001)); // 60%
      expect(summary.recurringFraction, closeTo(0.0554, 0.001)); // 6%
    });
  });

  test('transfers are excluded from both income and spending', () {
    final summary = MonthSummary.forMonth(
      now,
      transactions: [
        _tx(cents: 100000, type: TransactionType.income, date: DateTime(2026, 9, 2)),
        // Both legs of moving RM 500 between your own accounts.
        _tx(
          cents: 50000,
          type: TransactionType.expense,
          date: DateTime(2026, 9, 3),
          transferGroupId: 'leg-b',
        ),
        _tx(
          cents: 50000,
          type: TransactionType.income,
          date: DateTime(2026, 9, 3),
          transferGroupId: 'leg-a',
        ),
      ],
      subscriptions: const [],
      totalBalance: 0,
      accountCount: 0,
    );

    expect(summary.moneyInCents, 100000);
    expect(summary.spentCents, 0);
  });

  test('other months are ignored', () {
    final summary = MonthSummary.forMonth(
      now,
      transactions: [
        _tx(cents: 9999, type: TransactionType.expense, date: DateTime(2026, 8, 31)),
        _tx(cents: 1000, type: TransactionType.expense, date: DateTime(2026, 9, 1)),
      ],
      subscriptions: const [],
      totalBalance: 0,
      accountCount: 0,
    );

    expect(summary.spentCents, 1000);
  });

  test('a subscription already recorded this month is not still due', () {
    final summary = MonthSummary.forMonth(
      now,
      transactions: const [],
      subscriptions: [
        Subscription(
          id: 's1',
          name: 'iCloud',
          amount: 3.90,
          category: 'Bills & Utilities',
          dayOfMonth: 3,
          accountId: 'acc',
          lastRecordedDate: DateTime(2026, 9, 3),
        ),
      ],
      totalBalance: 0,
      accountCount: 0,
    );

    expect(summary.recurringDueCents, 0);
  });

  test('bar segments never overflow when spending exceeds income', () {
    final summary = MonthSummary.forMonth(
      now,
      transactions: [
        _tx(cents: 10000, type: TransactionType.income, date: DateTime(2026, 9, 1)),
        _tx(cents: 50000, type: TransactionType.expense, date: DateTime(2026, 9, 2)),
      ],
      subscriptions: const [],
      totalBalance: 0,
      accountCount: 0,
    );

    expect(summary.safeToSpendCents, -40000);
    expect(summary.spentFraction, 1.0);
    expect(summary.recurringFraction, 0.0);
    expect(summary.spentFraction + summary.recurringFraction, lessThanOrEqualTo(1.0));
  });

  test('an empty month does not divide by zero', () {
    final summary = MonthSummary.forMonth(
      DateTime(2026, 9, 30),
      transactions: const [],
      subscriptions: const [],
      totalBalance: 0,
      accountCount: 0,
    );

    expect(summary.daysLeft, 0);
    expect(summary.perDay, isNull);
    expect(summary.spentFraction, 0);
  });
}
