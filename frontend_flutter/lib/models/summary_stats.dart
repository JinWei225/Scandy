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
    this.accountId,
  });

  /// First day of the month these figures cover.
  final DateTime month;

  /// When set, only that account's rows were counted — the Account page.
  /// Null on Summary, which covers every account.
  final String? accountId;

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

  /// The category a row is filed under for these figures. Rows saved with no
  /// category share one bucket rather than each becoming a category of "".
  static String categoryKey(Transaction t) =>
      t.category.isEmpty ? 'Uncategorised' : t.category;

  /// Whether [t] is one of the rows behind these figures: in [month], not a
  /// transfer, and — when [accountId] is set — against that account.
  ///
  /// One predicate for the totals, the category shares and the drill-down
  /// list, so the rows a category page shows always add up to the figure the
  /// row was tapped on.
  static bool counts(
    Transaction t, {
    required DateTime month,
    String? accountId,
  }) {
    final date = t.date;
    if (date == null) return false;
    if (date.year != month.year || date.month != month.month) return false;
    // Transfers move money between your own accounts — neither income nor
    // spending, and they would distort every category share.
    if (t.isTransfer) return false;
    if (accountId != null && t.accountId != accountId) return false;
    return true;
  }

  /// The rows behind one category row, newest first as [transactions] comes
  /// ordered. [income] picks the "Where it came from" list over "Where it
  /// went": the same category name can appear in both.
  static List<Transaction> transactionsFor(
    List<Transaction> transactions, {
    required DateTime month,
    required String category,
    required bool income,
    String? accountId,
  }) =>
      transactions
          .where((t) =>
              counts(t, month: month, accountId: accountId) &&
              t.isIncome == income &&
              categoryKey(t) == category)
          .toList(growable: false);

  factory MonthStats.forMonth(
    DateTime month, {
    required List<Transaction> transactions,
    required DateTime now,
    String? accountId,
  }) {
    var moneyIn = 0;
    var spent = 0;
    final byCategory = <String, int>{};
    final incomeByCategory = <String, int>{};

    for (final t in transactions) {
      if (!counts(t, month: month, accountId: accountId)) continue;

      final magnitude = t.amountCents.abs();
      final key = categoryKey(t);
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
      accountId: accountId,
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
