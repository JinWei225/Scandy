import 'subscription.dart';
import 'transaction.dart';

/// One row of Summary's "Where it went" list.
class CategorySpend {
  const CategorySpend({
    required this.category,
    required this.cents,
    required this.fractionOfSpend,
  });

  final String category;
  final int cents;

  /// Share of the month's total spending, 0–1. The design labels this "30%"
  /// for 862.10 of 2,914.40.
  final double fractionOfSpend;
}

/// The figures behind the Summary screen, for one calendar month.
///
/// Verified against the design's own numbers:
///   in 4850.00 − spent 2914.40      = net 1935.60  ✓
///   spent 2914.40 / 6 days elapsed  = 485.73/day   ✓
///   groceries 862.10 / spent        = 30%          ✓
class MonthStats {
  const MonthStats({
    required this.month,
    required this.moneyInCents,
    required this.spentCents,
    required this.categories,
    required this.incomeCategories,
    required this.daysElapsed,
  });

  /// First day of the month these figures cover.
  final DateTime month;

  final int moneyInCents;
  final int spentCents;

  /// Spending per category, largest first.
  final List<CategorySpend> categories;

  /// Income per category, largest first — the mirror of [categories].
  final List<CategorySpend> incomeCategories;

  /// Days counted for the daily average — the elapsed part of the current
  /// month, or the whole of a past one.
  final int daysElapsed;

  int get netCents => moneyInCents - spentCents;

  /// Average spend per day so far. Null when no days have elapsed.
  double? get dailyAverage {
    if (daysElapsed <= 0) return null;
    return spentCents / 100 / daysElapsed;
  }

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  factory MonthStats.forMonth(
    DateTime month, {
    required List<Transaction> transactions,
    required DateTime now,
  }) {
    var moneyIn = 0;
    var spent = 0;
    final byCategory = <String, int>{};
    final incomeByCategory = <String, int>{};

    for (final t in transactions) {
      final date = t.date;
      if (date == null) continue;
      if (date.year != month.year || date.month != month.month) continue;
      // Transfers move money between your own accounts — neither income nor
      // spending, and they would distort every category share.
      if (t.isTransfer) continue;

      final magnitude = t.amountCents.abs();
      final key = t.category.isEmpty ? 'Uncategorised' : t.category;
      if (t.isIncome) {
        moneyIn += magnitude;
        incomeByCategory[key] = (incomeByCategory[key] ?? 0) + magnitude;
      } else {
        spent += magnitude;
        byCategory[key] = (byCategory[key] ?? 0) + magnitude;
      }
    }

    List<CategorySpend> ranked(Map<String, int> source, int total) =>
        source.entries
            .map((e) => CategorySpend(
                  category: e.key,
                  cents: e.value,
                  fractionOfSpend: total <= 0 ? 0 : e.value / total,
                ))
            .toList()
          ..sort((a, b) => b.cents.compareTo(a.cents));

    final categories = ranked(byCategory, spent);
    final incomeCategories = ranked(incomeByCategory, moneyIn);

    // The current month averages over the days that have actually happened;
    // a past month averages over all of its days.
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    final daysElapsed = isCurrentMonth
        ? now.day
        : _daysInMonth(month.year, month.month);

    return MonthStats(
      month: DateTime(month.year, month.month),
      moneyInCents: moneyIn,
      spentCents: spent,
      categories: categories,
      incomeCategories: incomeCategories,
      daysElapsed: daysElapsed,
    );
  }
}

/// Recurring charges split by whether this month's instance has been recorded.
class RecurringStats {
  const RecurringStats({
    required this.stillToCome,
    required this.alreadyCharged,
  });

  final List<Subscription> stillToCome;
  final List<Subscription> alreadyCharged;

  static int _cents(List<Subscription> l) =>
      l.fold(0, (sum, s) => sum + (s.amount * 100).round());

  int get toComeCents => _cents(stillToCome);
  int get chargedCents => _cents(alreadyCharged);

  /// "Every month" — the full monthly commitment, charged or not.
  int get monthlyTotalCents => toComeCents + chargedCents;

  factory RecurringStats.from(
    List<Subscription> subscriptions, {
    required DateTime now,
  }) {
    final toCome = <Subscription>[];
    final charged = <Subscription>[];

    for (final s in subscriptions) {
      // Split on whether the charge was actually recorded this month, not on
      // whether its day has passed. Anything unrecorded is still owed and
      // belongs under "still to come", late or not — filing it as "already
      // charged" because the 15th went by was simply untrue, and hid exactly
      // the charges worth chasing.
      (s.isDueThisMonth(now) ? toCome : charged).add(s);
    }

    toCome.sort((a, b) => a.dueDayIn(now).compareTo(b.dueDayIn(now)));
    charged.sort((a, b) => b.dueDayIn(now).compareTo(a.dueDayIn(now)));

    return RecurringStats(stillToCome: toCome, alreadyCharged: charged);
  }
}
