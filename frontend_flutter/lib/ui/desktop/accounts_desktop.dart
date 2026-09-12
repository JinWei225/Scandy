import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/account.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../util/formatting.dart';
import '../accounts/account_form_sheet.dart';
import '../accounts/account_page.dart';
import '../transactions/search_sheet.dart';
import 'desktop_actions.dart';
import 'desktop_widgets.dart';

/// Accounts, desktop composition: the total leads the header, "Add account"
/// is a labelled button rather than a floating +, and the cards become one
/// table with a Type column.
class AccountsDesktop extends StatelessWidget {
  const AccountsDesktop({super.key});

  /// The frame's `1fr 148px 168px 84px` grid.
  static const TableColumns columns = [null, 148, 168, 84];

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    final state = context.watch<AppState>();
    final accounts = state.accounts;
    final total = accounts.fold<double>(0, (sum, a) => sum + a.balance);

    return DesktopPage(
      children: [
        DesktopFigureHeader(
          title: l.accounts,
          label: l.totalBalance,
          figure: formatRinggit(total),
          figureColor: total < 0 ? c.negative : null,
          titleTrailing: DesktopIconButton(
            icon: Icons.search,
            tooltip: l.searchTransactions,
            onPressed: () => showSearchSheet(context),
          ),
          trailing: DesktopAccentButton(
            icon: Icons.add,
            label: l.addAccount,
            height: 44,
            onPressed: () => showAccountFormSheet(context),
          ),
        ),
        const SizedBox(height: desktopGap),
        DesktopPanel(
          child: accounts.isEmpty
              ? DesktopEmpty(
                  icon: Icons.account_balance_wallet,
                  title: l.noAccountsYet,
                  message: l.noAccountsYetBody,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DesktopTableHeader(
                      columns: columns,
                      labels: [
                        l.tableAccount,
                        l.fieldType,
                        l.tableBalance,
                        l.tableActions,
                      ],
                      alignRight: const {2, 3},
                    ),
                    for (var i = 0; i < accounts.length; i++)
                      _row(
                        context,
                        c,
                        accounts[i],
                        state.transactionCountFor(accounts[i].id),
                        i == accounts.length - 1,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Text(
          l.deletingAnAccountNote,
          style: ScandyDesktopText.actionSubtitle
              .copyWith(color: c.textSecondary),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    ScandyColors c,
    Account account,
    int count,
    bool last,
  ) {
    // A credit card in the design carries a red tile and a red figure; the
    // same rule applies to anything overdrawn.
    final negative = account.balance < 0;
    final l = context.l;
    return DesktopTableRow(
      columns: columns,
      showDivider: !last,
      verticalPadding: 15,
      onTap: () => AccountPage.open(context, account),
      cells: [
        DesktopRowIdentity(
          icon: accountIcon(account.type),
          large: true,
          size: 40,
          title: account.name,
          meta: l.nTransactions(count),
          tileColor: negative ? c.negativeSoft : c.surfaceMuted,
          glyphColor: negative ? c.negative : c.textTertiary,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: DesktopChip(label: accountTypeLabel(l, account.type)),
        ),
        DesktopAmountCell(
          large: true,
          text: negative
              ? '$minusSign${formatRinggit(account.balance.abs())}'
              : formatRinggit(account.balance),
          color: negative ? c.negative : c.textPrimary,
        ),
        RowActions(
          onEdit: () => showAccountFormSheet(context, account: account),
          onDelete: () => deleteAccountFromRow(context, account),
        ),
      ],
    );
  }

}
