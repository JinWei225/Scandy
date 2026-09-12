import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/summary_stats.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../util/category_icons.dart';
import '../../util/formatting.dart';
import '../common/sheets.dart';
import '../common/widgets.dart';
import '../transactions/category_transactions_page.dart';
import '../transactions/search_sheet.dart';
import 'desktop_widgets.dart';

/// Monthly summary, desktop composition: the month stepper sits in the header,
/// the four figures run across the top, and "Where it went" and "Money in"
/// share a two-column grid instead of stacking.
class SummaryDesktop extends StatefulWidget {
  const SummaryDesktop({super.key, this.clock});

  final DateTime? clock;

  @override
  State<SummaryDesktop> createState() => _SummaryDesktopState();
}

class _SummaryDesktopState extends State<SummaryDesktop> {
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    final state = context.watch<AppState>();
    final now = widget.clock ?? DateTime.now();
    final month = _month ?? DateTime(now.year, now.month);

    final stats = MonthStats.forMonth(
      month,
      transactions: state.transactions,
      now: now,
    );

    // Counts per category, for the "14 transactions" line the frame prints
    // beside each row. MonthStats deliberately carries money only.
    final counts = <String, int>{};
    var expenseCount = 0;
    var incomeCount = 0;
    for (final t in state.transactions) {
      final date = t.date;
      if (date == null) continue;
      if (date.year != month.year || date.month != month.month) continue;
      if (t.isTransfer) continue;
      final key = t.category.isEmpty ? 'Uncategorised' : t.category;
      counts[key] = (counts[key] ?? 0) + 1;
      if (t.isIncome) {
        incomeCount++;
      } else {
        expenseCount++;
      }
    }

    // Same rule as the phone's chevrons: hop between months that have data.
    final months = state.availableMonths(now: now);
    final index = months.indexWhere(
      (m) => m.year == month.year && m.month == month.month,
    );
    final older = index >= 0 && index + 1 < months.length
        ? months[index + 1]
        : null;
    final newer = index > 0 ? months[index - 1] : null;

    final avg = stats.dailyAverage;

    return DesktopPage(
      children: [
        DesktopHeader(
          title: l.navMonthlySummary,
          subtitle: l.whereYourMoneyWentByCategory,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DesktopIconButton(
                icon: Icons.search,
                tooltip: l.searchTransactions,
                onPressed: () => showSearchSheet(context),
              ),
              const SizedBox(width: 10),
              _MonthStepper(
                month: month,
                onOlder: older == null
                    ? null
                    : () => setState(() => _month = older),
                onNewer: newer == null
                    ? null
                    : () => setState(() => _month = newer),
                onPick: () => _pickMonth(month, now),
              ),
            ],
          ),
        ),
        const SizedBox(height: desktopGap),
        DesktopCardRow(
          children: [
            DesktopStatCard(
              label: l.moneyIn,
              value: formatRinggit(stats.moneyInCents / 100),
              valueColor: c.positive,
              meta: l.nDeposits(incomeCount),
            ),
            DesktopStatCard(
              label: l.spentLabel,
              value: formatRinggit(stats.spentCents / 100),
              valueColor: c.negative,
              meta: l.nTransactions(expenseCount),
            ),
            DesktopStatCard(
              label: l.netLabel,
              value: formatRinggit(stats.netCents / 100),
              valueColor: stats.netCents < 0 ? c.negative : c.textPrimary,
              meta: stats.netCents < 0 ? l.overspentMeta : l.savedThisMonth,
            ),
            DesktopStatCard(
              label: l.dailyAverage,
              value: avg == null ? l.emDash : formatRinggit(avg),
              meta: l.overNDays(stats.daysElapsed),
            ),
          ],
        ),
        const SizedBox(height: desktopGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1.35fr / 1fr, per the frame.
            Expanded(
              flex: 135,
              child: DesktopPanel(
                title: l.whereItWent,
                trailing: stats.categories.isEmpty
                    ? null
                    : DesktopBadge(
                        label: l.nCategories(stats.categories.length),
                        color: c.negative,
                        background: c.negativeSoft,
                      ),
                child: _CategoryTable(
                  categories: stats.categories,
                  counts: counts,
                  color: c.negative,
                  emptyTitle: l.nothingSpentThisMonth,
                  emptyMessage: l.nothingSpentThisMonthBody,
                  onOpen: (category) => _open(stats.month, category, false),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 100,
              child: DesktopPanel(
                title: l.moneyIn,
                child: _IncomeList(
                  categories: stats.incomeCategories,
                  counts: counts,
                  onOpen: (category) => _open(stats.month, category, true),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The drill-down. Pushed over the sidebar as a page of its own — a list
  /// of rows with a back arrow, the same as on the phone.
  void _open(DateTime month, CategorySpend category, bool income) {
    CategoryTransactionsPage.open(
      context,
      month: month,
      category: category.category,
      income: income,
    );
  }

  Future<void> _pickMonth(DateTime current, DateTime now) async {
    final months = context.read<AppState>().availableMonths(now: now);
    final picked = await showScandySheet<DateTime>(
      context: context,
      title: context.l.chooseAMonth,
      child: _MonthGrid(months: months, selected: current),
    );
    if (picked != null && mounted) setState(() => _month = picked);
  }
}

/// ‹ September 2026 › in a 4px-padded card, as the frame draws it.
class _MonthStepper extends StatelessWidget {
  const _MonthStepper({
    required this.month,
    required this.onOlder,
    required this.onNewer,
    required this.onPick,
  });

  final DateTime month;
  final VoidCallback? onOlder;
  final VoidCallback? onNewer;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(ScandyRadius.tile),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Chevron(
            icon: Icons.chevron_left,
            onPressed: onOlder,
            tooltip: context.l.previousMonthWithData,
          ),
          InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(9),
            child: Container(
              constraints: const BoxConstraints(minWidth: 132),
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              child: Text(
                context.dates.monthYear(month),
                style: ScandyDesktopText.monthLabel.copyWith(
                  color: c.textPrimary,
                ),
              ),
            ),
          ),
          _Chevron(
            icon: Icons.chevron_right,
            onPressed: onNewer,
            tooltip: context.l.nextMonthWithData,
          ),
        ],
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 20,
            color: onPressed == null ? c.disabled : c.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// Category · amount · bar, on the frame's `1fr 92px 152px` grid.
class _CategoryTable extends StatelessWidget {
  const _CategoryTable({
    required this.categories,
    required this.counts,
    required this.color,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onOpen,
  });

  final List<CategorySpend> categories;
  final Map<String, int> counts;
  final Color color;
  final String emptyTitle;
  final String emptyMessage;
  final ValueChanged<CategorySpend> onOpen;

  static const TableColumns columns = [null, 92, 152];

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    if (categories.isEmpty) {
      return DesktopEmpty(
        icon: Icons.bar_chart,
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < categories.length; i++)
          DesktopTableRow(
            columns: columns,
            showDivider: i != categories.length - 1,
            onTap: () => onOpen(categories[i]),
            cells: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayCategory(context.l, categories[i].category),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ScandyDesktopText.cellTitle.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _countLabel(context.l, categories[i].category),
                    style: ScandyDesktopText.cellMeta.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
              DesktopAmountCell(
                text: formatBare(categories[i].cents / 100),
                color: color,
              ),
              Row(
                children: [
                  Expanded(
                    child: ProportionBar(
                      fraction: categories[i].fractionOfSpend,
                      color: color,
                      height: 8,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${(categories[i].fractionOfSpend * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: ScandyText.percentLabel.copyWith(
                        color: c.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  String _countLabel(L l, String category) {
    final n = counts[category] ?? 0;
    return l.nTransactions(n);
  }
}

/// The income panel: one row per source, then a total strip.
class _IncomeList extends StatelessWidget {
  const _IncomeList({
    required this.categories,
    required this.counts,
    required this.onOpen,
  });

  final List<CategorySpend> categories;
  final Map<String, int> counts;
  final ValueChanged<CategorySpend> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    if (categories.isEmpty) {
      return DesktopEmpty(
        icon: Icons.payments,
        title: l.nothingCameInThisMonth,
        message: l.nothingCameInThisMonthBody,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final category in categories)
          InkWell(
            onTap: () => onOpen(category),
            hoverColor: c.page.withValues(alpha: 0.6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.divider)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.positiveSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      iconForCategory(category.category),
                      size: 19,
                      color: c.positive,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayCategory(l, category.category),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ScandyDesktopText.cellTitle.copyWith(
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_count(l, category.category)} · '
                          '${(category.fractionOfSpend * 100).round()}%',
                          style: ScandyDesktopText.cellMeta.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatBare(category.cents / 100),
                    style: ScandyDesktopText.cellAmount.copyWith(
                      color: c.positive,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _count(L l, String category) {
    final n = counts[category] ?? 0;
    return l.nTransactions(n);
  }
}

/// Months that have data, three per row, newest year first.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.months, required this.selected});

  final List<DateTime> months;
  final DateTime selected;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final byYear = <int, List<DateTime>>{};
    for (final m in months) {
      byYear.putIfAbsent(m.year, () => []).add(m);
    }
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final year in years) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              '$year',
              style: ScandyText.statLabel.copyWith(color: c.textSecondary),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final month in byYear[year]!)
                _MonthChip(
                  month: month,
                  selected:
                      month.year == selected.year &&
                      month.month == selected.month,
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({required this.month, required this.selected});

  final DateTime month;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Material(
      color: selected ? c.accentSoft : c.surfaceMuted,
      borderRadius: BorderRadius.circular(ScandyRadius.tile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(month),
        child: Container(
          width: 92,
          height: 46,
          alignment: Alignment.center,
          child: Text(
            context.dates.shortMonth(month),
            style:
                (selected
                        ? ScandyText.segmentLabelActive
                        : ScandyText.segmentLabel)
                    .copyWith(
                      color: selected ? c.onAccentSoft : c.textTertiary,
                    ),
          ),
        ),
      ),
    );
  }
}
