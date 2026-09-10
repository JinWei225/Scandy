import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/account.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../util/formatting.dart';
import '../common/widgets.dart';
import '../shell/bottom_nav.dart';
import 'account_form_sheet.dart';
import '../transactions/search_sheet.dart';

/// "Accounts" — total balance, then one card per account.
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = context.scandy;
    final l = context.l;
    final accounts = state.accounts;
    final total = accounts.fold<double>(0, (sum, a) => sum + a.balance);

    final navHeight = ScandyBottomNav.heightFor(context);

    return FabScaffold(
      navHeight: navHeight,
      tooltip: l.addAccount,
      onPressed: () => showAccountFormSheet(context),
      child: RefreshIndicator(
      onRefresh: state.refresh,
      color: c.accent,
      backgroundColor: c.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Extra bottom room so the floating + never sits on the last card.
        padding: EdgeInsets.fromLTRB(18, 14, 18, navHeight + 88),
        children: [
          ScreenHeader(
            title: l.accounts,
            trailing: HeaderActions(onSearch: () => showSearchSheet(context)),
          ),
          const SizedBox(height: 14),
          ScandyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.totalBalance.toUpperCase(),
                    style:
                        ScandyText.cardEyebrow.copyWith(color: c.textSecondary)),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(formatRinggit(total),
                      style: ScandyText.bigBalance
                          .copyWith(color: c.textPrimary)),
                ),
                const SizedBox(height: 8),
                Text(
                  l.acrossNAccounts(accounts.length),
                  style:
                      ScandyText.greetingMeta.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (accounts.isEmpty)
            ScandyCard(
              radius: ScandyRadius.list,
              clip: true,
              child: EmptyState(
                icon: Icons.account_balance_wallet,
                title: l.noAccountsYet,
                message: l.noAccountsYetBody,
              ),
            )
          else
            for (final account in accounts) ...[
              _AccountCard(
                account: account,
                transactionCount: state.transactionCountFor(account.id),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.transactionCount});

  final Account account;
  final int transactionCount;

  /// The design tiles a bank, a wallet, cash and a card differently; anything
  /// unrecognised falls back to the wallet glyph.
  IconData get _icon => switch (account.type.toLowerCase()) {
        'bank' => Icons.account_balance,
        'e-wallet' || 'ewallet' || 'wallet' => Icons.account_balance_wallet,
        'cash' => Icons.payments,
        'card' || 'credit' => Icons.credit_card,
        _ => Icons.account_balance_wallet,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    // A negative balance — a credit card in the design — is tinted red on both
    // the tile and the figure.
    final negative = account.balance < 0;
    final tile = negative ? c.negativeSoft : c.surfaceMuted;
    final glyph = negative ? c.negative : c.textTertiary;
    final amount = negative ? c.negative : c.textPrimary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ScandyRadius.list),
      child: InkWell(
        onTap: () => showAccountFormSheet(context, account: account),
        borderRadius: BorderRadius.circular(ScandyRadius.list),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(ScandyRadius.list),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tile,
                  borderRadius: BorderRadius.circular(ScandyRadius.tileLarge),
                ),
                child: Icon(_icon, size: 22, color: glyph),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ScandyText.rowTitleLarge
                            .copyWith(color: c.textPrimary)),
                    const SizedBox(height: 3),
                    Text(
                      '${accountTypeLabel(l, account.type)} · '
                      '${l.nTransactions(transactionCount)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ScandyText.rowMetaSmall
                          .copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                // Only a negative balance carries a sign, matching the design.
                negative
                    ? '$minusSign${formatBare(account.balance.abs())}'
                    : formatBare(account.balance),
                style: ScandyText.accountAmount.copyWith(color: amount),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
