/// Mirrors an entry from `GET /api/subscriptions`.
///
/// Unlike transactions, the amount here is ringgit as a JSON number, not
/// cents-in-a-string (see `subscriptions.json`).
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

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        category: json['category'] as String? ?? '',
        dayOfMonth: (json['day_of_month'] as num?)?.toInt() ?? 1,
        accountId: json['account_id'] as String?,
        lastRecordedDate:
            DateTime.tryParse(json['last_recorded_date'] as String? ?? ''),
      );

  /// True when this month's charge has not been recorded yet, i.e. it still
  /// counts toward "recurring due" in the safe-to-spend figure.
  bool isDueLaterThisMonth(DateTime now) {
    final recorded = lastRecordedDate;
    final alreadyRecordedThisMonth =
        recorded != null && recorded.year == now.year && recorded.month == now.month;
    return !alreadyRecordedThisMonth && dayOfMonth >= now.day;
  }
}
