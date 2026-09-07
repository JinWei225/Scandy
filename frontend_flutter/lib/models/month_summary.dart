import 'subscription.dart';
import 'transaction.dart';

/// The figures behind the "Safe to spend" card.
///
/// The redesign introduces this concept; the backend has no budget endpoint,
/// so everything is derived client-side from transactions + subscriptions.
/// The design's own numbers pin the formulas down exactly:
///
///   in 4850.00 − spent 2914.40 − due 268.90 = safe 1666.70   ✓
///   1666.70 / 24 days left                  = 69.44 per day  ✓
///   spent 2914.40 / in 4850.00              = 60% of the bar ✓
///   due    268.90 / in 4850.00              =  6% of the bar ✓
///
/// All money is integer cents until the very last step, so the three bar
/// segments can never drift against the figures printed beside them.
class MonthSummary {
  const MonthSummary({
    required this.moneyInCents,
    required this.spentCents,
    required this.recurringDueCents,
    required this.daysLeft,
    required this.totalBalance,
    required this.accountCount,
  });

  final int moneyInCents;
  final int spentCents;
  final int recurringDueCents;

  /// Calendar days remaining after today, matching the design: on 6 September
  /// (30 days) it reads "24 days left".
  final int daysLeft;

  /// Ringgit across every account, for the desktop sidebar.
  final double totalBalance;
  final int accountCount;

  static const empty = MonthSummary(
    moneyInCents: 0,
    spentCents: 0,
    recurringDueCents: 0,
    daysLeft: 0,
    totalBalance: 0,
    accountCount: 0,
  );

  int get safeToSpendCents => moneyInCents - spentCents - recurringDueCents;

  /// Null when the month is over — the design has nothing to divide by then,
  /// and the caller drops the "a day for the rest of the month" line.
  double? get perDay {
    if (daysLeft <= 0) return null;
    return safeToSpendCents / 100 / daysLeft;
  }

  double _fraction(int part) {
    if (moneyInCents <= 0) return 0;
    return (part / moneyInCents).clamp(0.0, 1.0);
  }

  /// Width of the red segment, 0–1.
  double get spentFraction => _fraction(spentCents);

  /// Width of the peach segment, 0–1. Clamped so the two together never
  /// overflow the track when spending has already exceeded income.
  double get recurringFraction {
    final remaining = (1.0 - spentFraction).clamp(0.0, 1.0);
    return _fraction(recurringDueCents).clamp(0.0, remaining);
  }

  factory MonthSummary.forMonth(
    DateTime now, {
    required List<Transaction> transactions,
    required List<Subscription> subscriptions,
    required double totalBalance,
    required int accountCount,
  }) {
    var moneyIn = 0;
    var spent = 0;

    for (final t in transactions) {
      final date = t.date;
      if (date == null) continue;
      if (date.year != now.year || date.month != now.month) continue;
      // Both legs of a transfer are stored as real rows, one income and one
      // expense. Counting them would inflate income and spending alike, so
      // they are skipped — money moving between your own accounts is neither.
      if (t.isTransfer) continue;

      if (t.isIncome) {
        moneyIn += t.amountCents.abs();
      } else {
        spent += t.amountCents.abs();
      }
    }

    var due = 0;
    for (final s in subscriptions) {
      if (s.isDueLaterThisMonth(now)) {
        due += (s.amount * 100).round();
      }
    }

    return MonthSummary(
      moneyInCents: moneyIn,
      spentCents: spent,
      recurringDueCents: due,
      daysLeft: _daysInMonth(now.year, now.month) - now.day,
      totalBalance: totalBalance,
      accountCount: accountCount,
    );
  }

  /// Day 0 of the next month rolls back to the last day of this one.
  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;
}
