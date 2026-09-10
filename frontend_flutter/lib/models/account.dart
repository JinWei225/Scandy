/// A row of `public.accounts`.
///
/// [balance] is not stored on the row: it comes from the `account_balances`
/// view, which folds every transaction into the opening balance. A view cannot
/// drift from the rows the way a cached column would.
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.initialBalance,
    required this.balance,
  });

  final String id;
  final String name;

  /// "Bank" / "E-Wallet" / "Card".
  final String type;

  final double initialBalance;

  /// Ringgit, already net of all transactions.
  final double balance;

  /// [balanceCents] comes from the joined view; without it the balance falls
  /// back to the opening figure rather than silently reading zero.
  factory Account.fromRow(Map<String, dynamic> row, {int? balanceCents}) {
    final initialCents = (row['initial_balance_cents'] as num?)?.toInt() ?? 0;
    return Account(
      id: row['id'] as String? ?? '',
      name: row['name'] as String? ?? '',
      type: row['type'] as String? ?? '',
      initialBalance: initialCents / 100,
      balance: (balanceCents ?? initialCents) / 100,
    );
  }
}
