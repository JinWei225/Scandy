/// A row of `public.transactions`.
///
/// All arithmetic goes through [amountCents]; there is no formatted amount on
/// the wire any more, because formatting belongs to the screen and a display
/// string cannot be summed without losing money.
class Transaction {
  const Transaction({
    required this.id,
    required this.date,
    required this.time,
    required this.description,
    required this.amountCents,
    required this.category,
    required this.accountId,
    required this.type,
    this.transferGroupId,
    this.fromAccountId,
    this.toAccountId,
  });

  final String id;

  /// Parsed from the API's DD/MM/YYYY display format. Null when the row's date
  /// is malformed — the transaction still renders, it just can't be bucketed
  /// into a month.
  final DateTime? date;

  /// "HH:MM:SS" as sent; only the HH:MM part is shown.
  final String time;

  final String description;

  /// Signed by [type]: expenses and outgoing transfer legs are negative.
  final int amountCents;

  final String category;
  final String? accountId;
  final TransactionType type;
  /// Shared by both legs of a transfer; null for everything else.
  final String? transferGroupId;

  /// Only set on transfer rows. Resolved by the repository from the other leg
  /// in the same group, so either half can pre-fill From/To when edited.
  final String? fromAccountId;
  final String? toAccountId;

  /// Builds one from a Supabase row.
  ///
  /// [fromAccountId] and [toAccountId] are not columns -- the repository
  /// resolves them from the other leg sharing this row's transfer group.
  factory Transaction.fromRow(
    Map<String, dynamic> row, {
    String? fromAccountId,
    String? toAccountId,
  }) {
    final type = TransactionType.parse(row['type'] as String?);
    // amount_cents is always positive in the database; direction lives in
    // `type`, and the check constraint there enforces it.
    final magnitude = (row['amount_cents'] as num?)?.toInt().abs() ?? 0;
    return Transaction(
      id: row['id'] as String? ?? '',
      date: DateTime.tryParse(row['occurred_on'] as String? ?? ''),
      time: row['occurred_at'] as String? ?? '00:00:00',
      description: (row['description'] as String? ?? '').trim(),
      amountCents: type == TransactionType.income ? magnitude : -magnitude,
      category: row['category'] as String? ?? '',
      accountId: row['account_id'] as String?,
      type: type,
      transferGroupId: row['transfer_group_id'] as String?,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
    );
  }

  /// "14:22" — the design shows hours and minutes only.
  String get shortTime => time.length >= 5 ? time.substring(0, 5) : time;

  bool get isIncome => type == TransactionType.income;
  bool get isTransfer => transferGroupId != null;
}

enum TransactionType {
  income,
  expense,
  transfer;

  static TransactionType parse(String? raw) => switch (raw) {
        'income' => TransactionType.income,
        'transfer' => TransactionType.transfer,
        _ => TransactionType.expense,
      };
}
