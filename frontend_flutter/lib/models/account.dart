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

  /// The on-disk shape, for the snapshot cache. Cents, not ringgit: a double
  /// written and read back is the same double, but cents are what the figure
  /// actually is.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'initial_balance_cents': (initialBalance * 100).round(),
        'balance_cents': (balance * 100).round(),
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? '',
        initialBalance:
            ((json['initial_balance_cents'] as num?)?.toInt() ?? 0) / 100,
        balance: ((json['balance_cents'] as num?)?.toInt() ?? 0) / 100,
      );
}
