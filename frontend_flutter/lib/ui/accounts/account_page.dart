import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/account.dart';
import '../../models/summary_stats.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../util/formatting.dart';
import '../common/widgets.dart';
import '../summary/month_stats_grid.dart';
import '../summary/month_stepper.dart';
import '../summary/summary_screen.dart';
import '../transactions/category_transactions_page.dart';
import 'account_form_sheet.dart';

/// One account: its balance, then the Summary month view scoped to it — the
/// stepper, Money in / Spent / Net, and both category lists with their
/// drill-down. Editing is behind the pencil in the header; deleting stays in
/// the edit sheet, where the confirmation already lives.
///
/// Holds the id rather than the [Account]: the page looks it up on every
/// build, so a rename shows the moment the sheet saves, and if the account is
/// deleted while this page is open there is nothing left to show and it pops.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.accountId, this.clock});

  final String accountId;
  final DateTime? clock;

  static Future<void> open(BuildContext context, Account account) {
    return Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AccountPage(accountId: account.id),
    ));
  }

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  DateTime? _month;
  bool _leaving = false;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    final state = context.watch<AppState>();
    final now = widget.clock ?? DateTime.now();
    final account = state.accountById(widget.accountId);

    if (account == null) {
      // Deleted from the edit sheet, or gone on refresh. Pop once the frame
      // that noticed it has finished building — a route cannot be removed
      // from inside its own build.
      if (!_leaving) {
        _leaving = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).maybePop();
        });
      }
      return Scaffold(backgroundColor: c.page);
    }

    final month = _month ?? DateTime(now.year, now.month);
    final stats = MonthStats.forMonth(
      month,
      transactions: state.transactions,
      now: now,
      accountId: account.id,
    );
    final neighbours = monthNeighbours(
      state.availableMonths(now: now, accountId: account.id),
      month,
    );

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
                maxWidth: CategoryTransactionsPage.maxWidth),
            child: RefreshIndicator(
              onRefresh: state.refresh,
              color: c.accent,
              backgroundColor: c.surface,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                children: [
                  PageBackHeader(
                    title: account.name,
                    subtitle: accountTypeLabel(l, account.type),
                    trailing: AccentIconButton(
                      icon: Icons.edit,
                      tooltip: l.editAccount,
                      onPressed: () =>
                          showAccountFormSheet(context, account: account),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _BalanceCard(
                    account: account,
                    transactionCount: state.transactionCountFor(account.id),
                  ),
                  const SizedBox(height: 14),
                  MonthStepper(
                    month: month,
                    onOlder: neighbours.older == null
                        ? null
                        : () => setState(() => _month = neighbours.older),
                    onNewer: neighbours.newer == null
                        ? null
                        : () => setState(() => _month = neighbours.newer),
                    onPick: () => _pickMonth(month, now, account.id),
                  ),
                  const SizedBox(height: 14),
                  MonthStatGrid(stats: stats, compact: true),
                  const SizedBox(height: 14),
                  ...categorySections(
                    context,
                    stats: stats,
                    onOpen: (category, income) =>
                        CategoryTransactionsPage.open(
                      context,
                      month: stats.month,
                      category: category.category,
                      income: income,
                      accountId: account.id,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickMonth(
    DateTime current,
    DateTime now,
    String accountId,
  ) async {
    final picked = await showMonthPicker(
      context,
      months: context
          .read<AppState>()
          .availableMonths(now: now, accountId: accountId),
      selected: current,
    );
    if (picked != null && mounted) setState(() => _month = picked);
  }
}

/// The balance, at the size the Accounts screen gives the total, with the
/// account's tile beside it.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.account, required this.transactionCount});

  final Account account;
  final int transactionCount;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    // Overdrawn reads red on the tile and the figure, as the list card does.
    final negative = account.balance < 0;

    return ScandyCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.tableBalance.toUpperCase(),
                    style:
                        ScandyText.cardEyebrow.copyWith(color: c.textSecondary)),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    negative
                        ? '$minusSign${formatRinggit(account.balance.abs())}'
                        : formatRinggit(account.balance),
                    style: ScandyText.bigBalance.copyWith(
                        color: negative ? c.negative : c.textPrimary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.nTransactions(transactionCount),
                  style:
                      ScandyText.greetingMeta.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: negative ? c.negativeSoft : c.surfaceMuted,
              borderRadius: BorderRadius.circular(ScandyRadius.tileLarge),
            ),
            child: Icon(accountIcon(account.type),
                size: 24, color: negative ? c.negative : c.textTertiary),
          ),
        ],
      ),
    );
  }
}
