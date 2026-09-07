import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/month_summary.dart';
import '../../models/transaction.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../util/category_icons.dart';
import '../../util/formatting.dart';
import '../transactions/add_transaction_sheet.dart';
import '../transactions/search_sheet.dart';
import '../transactions/transaction_detail_sheet.dart';
import 'desktop_actions.dart';
import 'desktop_widgets.dart';

/// Home, desktop composition: greeting header, a hero card beside the two
/// add-a-transaction actions, then the recent transactions as a table.
///
/// The phone puts those two actions behind the nav's ADD button because there
/// is no room for them; the desktop frame has the width to show both outright,
/// so there is no sheet here at all.
class HomeDesktop extends StatelessWidget {
  const HomeDesktop({
    super.key,
    required this.onScanReceipt,
    this.clock,
  });

  final VoidCallback onScanReceipt;
  final DateTime? clock;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = clock ?? DateTime.now();
    final summary = state.summaryFor(now);

    return DesktopPage(
      children: [
        DesktopHeader(
          title: greetingFor(now),
          subtitle: formatGreetingDate(now),
          // Search only: the frame also puts a "Scan receipt" button here, but
          // the card below it does the same job with room to explain itself,
          // so the header keeps one action rather than two of the same.
          trailing: DesktopIconButton(
            icon: Icons.search,
            tooltip: 'Search transactions',
            onPressed: () => showSearchSheet(context),
          ),
        ),
        const SizedBox(height: 22),
        if (state.status == LoadStatus.failed)
          _ErrorPanel(message: state.error ?? 'Something went wrong')
        else if (state.status == LoadStatus.loading)
          const _LoadingPanel()
        else ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1.55fr / 1fr, as the frame's grid template specifies.
                Expanded(
                  flex: 155,
                  child: _HeroCard(summary: summary, now: now),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.photo_camera,
                          title: 'Scan a receipt',
                          subtitle: "Snap it and we'll fill in the details",
                          filled: true,
                          onTap: onScanReceipt,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.edit_note,
                          title: 'Log it by hand',
                          subtitle:
                              'Cash, transfers, anything without a receipt',
                          filled: false,
                          onTap: () => showAddTransactionSheet(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _RecentPanel(now: now),
        ],
      ],
    );
  }
}

/// Safe to spend, at desktop scale: 58px figure, a three-part bar with a
/// legend, and the in/spent/due breakdown as a hairline-separated strip.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.summary, required this.now});

  final MonthSummary summary;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final perDay = summary.perDay;
    final negative = summary.safeToSpendCents < 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Safe to spend · ${DateFormat('MMMM').format(now)}'
                      .toUpperCase(),
                  style: ScandyDesktopText.eyebrow
                      .copyWith(color: c.textSecondary),
                ),
              ),
              const SizedBox(width: 12),
              DesktopBadge(
                label: summary.daysLeft == 1
                    ? '1 day left'
                    : '${summary.daysLeft} days left',
                color: c.onAccentSoft,
                background: c.accentSoft,
              ),
            ],
          ),
          const SizedBox(height: 20),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatRinggit(summary.safeToSpendCents / 100),
              style: ScandyDesktopText.hero
                  .copyWith(color: negative ? c.negative : c.accent),
            ),
          ),
          const SizedBox(height: 10),
          if (perDay != null)
            Text.rich(
              TextSpan(
                style: ScandyDesktopText.heroCaption
                    .copyWith(color: c.textSecondary),
                children: [
                  const TextSpan(text: "That's "),
                  TextSpan(
                    text: formatRinggit(perDay),
                    style: ScandyDesktopText.heroCaptionStrong
                        .copyWith(color: c.textPrimary),
                  ),
                  const TextSpan(text: ' a day for the rest of the month.'),
                ],
              ),
            )
          else
            Text('The month is done — this is what it came to.',
                style: ScandyDesktopText.heroCaption
                    .copyWith(color: c.textSecondary)),
          const SizedBox(height: 20),
          _HeroBar(summary: summary),
          const SizedBox(height: 20),
          _Breakdown(summary: summary),
        ],
      ),
    );
  }
}

class _HeroBar extends StatelessWidget {
  const _HeroBar({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final spent = summary.spentFraction;
    final due = summary.recurringFraction;
    final left = (1 - spent - due).clamp(0.0, 1.0);

    int pct(double f) => (f * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(ScandyRadius.pill),
          // Same trap as the mobile card: the segments are childless boxes, so
          // the row must stretch and the box must have a width, or both
          // collapse to nothing.
          child: SizedBox(
            width: double.infinity,
            height: 9,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                    flex: (spent * 10000).round(),
                    child: ColoredBox(color: c.negative)),
                Expanded(
                    flex: (due * 10000).round(),
                    child: ColoredBox(color: c.trackRecurring)),
                Expanded(
                    flex: (left * 10000).round(),
                    child: ColoredBox(color: c.track)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 18,
          runSpacing: 6,
          children: [
            _LegendItem(color: c.negative, label: 'Spent ${pct(spent)}%'),
            _LegendItem(
                color: c.trackRecurring, label: 'Recurring due ${pct(due)}%'),
            _LegendItem(color: c.track, label: 'Left ${pct(left)}%'),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 7),
        Text(label,
            style: ScandyDesktopText.legend.copyWith(color: c.textTertiary)),
      ],
    );
  }
}

/// Money in / Spent / Recurring due, three cells divided by hairlines.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final cells = [
      ('Money in', formatRinggit(summary.moneyInCents / 100), c.positive),
      ('Spent', formatRinggit(summary.spentCents / 100), c.negative),
      (
        'Recurring due',
        formatRinggit(summary.recurringDueCents / 100),
        c.textPrimary
      ),
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0) Container(width: 1, color: c.border),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cells[i].$1.toUpperCase(),
                          style: ScandyDesktopText.tableHeader
                              .copyWith(color: c.textSecondary)),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(cells[i].$2,
                            style: ScandyDesktopText.cellAmountLarge
                                .copyWith(color: cells[i].$3)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The dark "Scan a receipt" tile and its outlined sibling.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// The scan card is filled with the ink colour; the manual one is outlined.
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // The frame's dark tile is the light theme's ink. In dark mode that is the
    // page itself, so the muted surface stands in — otherwise the card would
    // vanish into the background.
    final fill = filled
        ? (isDark ? c.surfaceMuted : const Color(0xFF24201C))
        : c.surface;
    final titleColor = filled ? (isDark ? c.textPrimary : c.page) : c.textPrimary;
    final subtitleColor = filled
        ? (isDark ? c.textSecondary : const Color(0xFFB5ADA5))
        : c.textSecondary;

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: filled
              ? null
              : BoxDecoration(
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(16),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: filled ? c.accent : c.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    size: 22, color: filled ? c.onAccent : c.textTertiary),
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: ScandyDesktopText.actionTitle
                      .copyWith(color: titleColor)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: ScandyDesktopText.actionSubtitle
                      .copyWith(color: subtitleColor)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Description / Category / Amount / Actions.
class _RecentPanel extends StatelessWidget {
  const _RecentPanel({required this.now});

  final DateTime now;

  /// The frame's `1fr 168px 132px 84px` grid.
  static const TableColumns columns = [null, 168, 132, 84];

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final recent = context.watch<AppState>().recentTransactions;

    return DesktopPanel(
      title: 'Recent transactions',
      child: recent.isEmpty
          ? const DesktopEmpty(
              icon: Icons.receipt_long,
              title: 'Nothing logged yet',
              message: 'Scan a receipt or log one by hand to get started.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DesktopTableHeader(
                  columns: columns,
                  labels: ['Description', 'Category', 'Amount', 'Actions'],
                  alignRight: {2, 3},
                ),
                for (var i = 0; i < recent.length; i++)
                  _row(context, c, recent[i], i == recent.length - 1),
              ],
            ),
    );
  }

  Widget _row(
    BuildContext context,
    ScandyColors c,
    Transaction t,
    bool last,
  ) {
    final income = t.isIncome;
    return DesktopTableRow(
      columns: columns,
      showDivider: !last,
      onTap: () => showTransactionDetailSheet(context, t),
      cells: [
        DesktopRowIdentity(
          icon: iconForCategory(t.category, isTransfer: t.isTransfer),
          title: t.description.isEmpty ? 'Untitled' : t.description,
          meta: _meta(t),
          tileColor: income ? c.positiveSoft : c.surfaceMuted,
          glyphColor: income ? c.positive : c.textTertiary,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: DesktopChip(
            label: t.category.isEmpty ? 'Uncategorised' : t.category,
            income: income,
          ),
        ),
        DesktopAmountCell(
          text: formatSignedCents(t.amountCents),
          color: income ? c.positive : c.negative,
        ),
        RowActions(
          onEdit: () => showAddTransactionSheet(context, transaction: t),
          onDelete: () => deleteTransactionFromRow(context, t),
        ),
      ],
    );
  }

  /// "6 Sep · 14:22" — the desktop row has room for both, where the phone
  /// shows whichever is more useful.
  static String _meta(Transaction t) {
    final parts = <String>[];
    final date = t.date;
    if (date != null) parts.add(DateFormat('d MMM').format(date));
    if (t.shortTime.isNotEmpty) parts.add(t.shortTime);
    if (t.isTransfer) parts.add('transfer');
    return parts.join(' · ');
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Container(
      height: 260,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: CircularProgressIndicator(color: c.accent, strokeWidth: 2.5),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off, size: 28, color: c.negative),
          const SizedBox(height: 12),
          Text("Can't load your data",
              style:
                  ScandyDesktopText.cardTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 6),
          Text(message,
              style: ScandyDesktopText.pageSubtitle
                  .copyWith(color: c.textSecondary)),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: DesktopAccentButton(
              icon: Icons.refresh,
              label: 'Try again',
              onPressed: () => context.read<AppState>().loadAll(),
            ),
          ),
        ],
      ),
    );
  }
}
