/// Mirrors an entry from `GET /api/accounts`.
///
/// [balance] is not stored — the route merges in `get_account_balances()`,
/// which folds every transaction into the account's `initial_balance`.
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

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? '',
        initialBalance: (json['initial_balance'] as num?)?.toDouble() ?? 0,
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
      );
}
