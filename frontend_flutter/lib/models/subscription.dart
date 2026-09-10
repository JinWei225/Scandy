/// A row of `public.subscriptions`.
///
/// Stored in cents like everything else and converted once, here, so the rest
/// of the app keeps working in ringgit.
class Subscription {
  const Subscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.dayOfMonth,
    required this.accountId,
    required this.lastRecordedDate,
  });

  final String id;
  final String name;

  /// Ringgit.
  final double amount;

  final String category;

  /// 1–31; the day the charge lands each month.
  final int dayOfMonth;

  final String? accountId;

  /// ISO date of the last month this was auto-recorded, or null if never.
  final DateTime? lastRecordedDate;

  factory Subscription.fromRow(Map<String, dynamic> row) => Subscription(
        id: row['id'] as String? ?? '',
        name: row['name'] as String? ?? '',
        amount: ((row['amount_cents'] as num?)?.toInt() ?? 0) / 100,
        category: row['category'] as String? ?? '',
        dayOfMonth: (row['day_of_month'] as num?)?.toInt() ?? 1,
        accountId: row['account_id'] as String?,
        lastRecordedDate:
            DateTime.tryParse(row['last_recorded_date'] as String? ?? ''),
      );

  /// The day the charge lands in [month], clamped to that month's length.
  ///
  /// record_due_subscriptions() clamps the same way, so a day-31 charge lands
  /// on the 30th in a 30-day month instead of never coming due at all.
  int dueDayIn(DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    if (dayOfMonth < 1) return 1;
    return dayOfMonth > lastDay ? lastDay : dayOfMonth;
  }

  /// True when this month's charge has not been recorded yet, so it still
  /// counts toward "recurring due" in the safe-to-spend figure.
  ///
  /// Deliberately independent of whether the day has passed. A charge whose day
  /// has gone by without being recorded is still owed, not settled — and since
  /// the real renewal day drifts with when the bill actually gets paid, "the
  /// 15th has been and gone" says nothing about whether it was paid.
  bool isDueThisMonth(DateTime now) {
    final recorded = lastRecordedDate;
    return !(recorded != null &&
        recorded.year == now.year &&
        recorded.month == now.month);
  }

  /// Still unrecorded, and its expected day has already passed. Prompts you to
  /// log what you actually paid rather than asserting anything went wrong.
  bool isOverdue(DateTime now) =>
      isDueThisMonth(now) && now.day > dueDayIn(now);
}
