/// Mirrors a row from `GET /api/transactions`.
///
/// Two amount fields come back and they are not interchangeable: the backend
/// stores cents in a TEXT column and serialises both `amount_cents` (int, for
/// arithmetic) and `amount` (a pre-formatted "RM 12.34" string, for display).
/// Summing the display string would be lossy, so all maths here goes through
/// [amountCents].
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
    this.transferRelatedId,
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
  final String? transferRelatedId;

  /// Only set on transfer rows. The backend resolves the counterpart leg's
  /// account so either half can pre-fill From/To when edited.
  final String? fromAccountId;
  final String? toAccountId;

  static DateTime? _parseDisplayDate(Object? raw) {
    if (raw is! String) return null;
    // The API serves DD/MM/YYYY (see `_to_display_date` in backend/main.py).
    final parts = raw.split('/');
    if (parts.length != 3) return DateTime.tryParse(raw);
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final type = TransactionType.parse(json['type'] as String?);
    // `amount_cents` is always positive on the wire; direction lives in `type`.
    final magnitude = (json['amount_cents'] as num?)?.toInt().abs() ?? 0;
    return Transaction(
      id: json['id'] as String? ?? '',
      date: _parseDisplayDate(json['date']),
      time: json['time'] as String? ?? '',
      description: (json['description'] as String? ?? '').trim(),
      amountCents: type == TransactionType.income ? magnitude : -magnitude,
      category: json['category'] as String? ?? '',
      accountId: json['account_id'] as String?,
      type: type,
      transferRelatedId: json['transfer_related_id'] as String?,
      fromAccountId: json['from_account_id'] as String?,
      toAccountId: json['to_account_id'] as String?,
    );
  }

  /// "14:22" — the design shows hours and minutes only.
  String get shortTime => time.length >= 5 ? time.substring(0, 5) : time;

  bool get isIncome => type == TransactionType.income;
  bool get isTransfer => transferRelatedId != null;
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
