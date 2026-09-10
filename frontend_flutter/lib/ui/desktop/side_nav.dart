import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/month_summary.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../util/formatting.dart';

/// Destinations in the desktop sidebar.
///
/// One more than the phone's bottom bar: the design gives Settings a real
/// destination here, where the mobile frames have no slot for it and push it
/// from the header instead.
enum DesktopTab {
  home(Icons.cottage),
  summary(Icons.bar_chart),
  accounts(Icons.account_balance_wallet),
  recurring(Icons.event_repeat),
  settings(Icons.settings);

  const DesktopTab(this.icon);
  final IconData icon;

  /// See [NavTab.label] — the same reason it is a method and not a field.
  String label(L l) => switch (this) {
        DesktopTab.home => l.navHome,
        DesktopTab.summary => l.navMonthlySummary,
        DesktopTab.accounts => l.navAccounts,
        DesktopTab.recurring => l.navRecurring,
        DesktopTab.settings => l.settings,
      };
}

/// The 236px sidebar: brand, destinations, and the total-balance card pinned
/// to the bottom.
class ScandySideNav extends StatelessWidget {
  const ScandySideNav({
    super.key,
    required this.current,
    required this.onSelect,
    required this.summary,
  });

  final DesktopTab current;
  final ValueChanged<DesktopTab> onSelect;

  /// Only [MonthSummary.totalBalance] and [MonthSummary.accountCount] are read
  /// — the sidebar card is the one place the design shows them together.
  final MonthSummary summary;

  static const width = 236.0;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Brand(),
          const SizedBox(height: 28),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final tab in DesktopTab.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _NavItem(
                        tab: tab,
                        selected: tab == current,
                        onTap: () => onSelect(tab),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          _BalanceCard(summary: summary),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_long, size: 19, color: c.onAccent),
          ),
          const SizedBox(width: 10),
          Text('Scandy',
              style: ScandyDesktopText.brand.copyWith(color: c.textPrimary)),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final DesktopTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final fg = selected ? c.onAccentSoft : c.textTertiary;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: selected ? null : c.surfaceMuted,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(tab.icon, size: 21, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tab.label(context.l),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (selected
                            ? ScandyDesktopText.navItemActive
                            : ScandyDesktopText.navItem)
                        .copyWith(color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final count = summary.accountCount;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.page,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l.totalBalance.toUpperCase(),
              style: ScandyDesktopText.tableHeader
                  .copyWith(color: c.textSecondary)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(formatRinggit(summary.totalBalance),
                style: ScandyDesktopText.sidebarBalance
                    .copyWith(color: c.textPrimary)),
          ),
          const SizedBox(height: 6),
          Text(
            context.l.acrossNAccounts(count),
            style: ScandyDesktopText.statMeta.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
