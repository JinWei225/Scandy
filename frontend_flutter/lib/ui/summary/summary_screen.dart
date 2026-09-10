import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/summary_stats.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../util/formatting.dart';
import '../common/sheets.dart';
import '../common/widgets.dart';
import '../shell/bottom_nav.dart';
import '../transactions/search_sheet.dart';

/// "Monthly summary — Where your money went".
///
/// Month is local state: the design's stepper walks backwards through history
/// and disables "next" on the current month, so there is nothing to persist.
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key, this.clock});

  final DateTime? clock;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final state = context.watch<AppState>();
    final now = widget.clock ?? DateTime.now();
    final month = _month ?? DateTime(now.year, now.month);

    final stats = MonthStats.forMonth(
      month,
      transactions: state.transactions,
      now: now,
    );

    // The chevrons hop between months that actually have data rather than
    // walking the calendar, so a gap year of no transactions is one tap away
    // instead of twelve. availableMonths is newest-first.
    //
    // The selected month is folded in because it can drop out of that list —
    // delete the last transaction in it and it stops being a month with data,
    // which left both chevrons disabled and no way off the page but the picker.
    final months = <DateTime>{...state.availableMonths(now: now), month}.toList()
      ..sort((a, b) => b.compareTo(a));
    final index = months.indexWhere(
        (m) => m.year == month.year && m.month == month.month);
    final older = index >= 0 && index + 1 < months.length
        ? months[index + 1]
        : null;
    final newer = index > 0 ? months[index - 1] : null;

    return RefreshIndicator(
      onRefresh: state.refresh,
      color: context.scandy.accent,
      backgroundColor: context.scandy.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            18, 14, 18, ScandyBottomNav.heightFor(context) + 16),
        children: [
          ScreenHeader(
            title: l.navMonthlySummary,
            subtitle: l.whereYourMoneyWent,
            trailing:
                HeaderActions(onSearch: () => showSearchSheet(context)),
          ),
          const SizedBox(height: 14),
          _MonthStepper(
            month: month,
            onOlder: older == null ? null : () => setState(() => _month = older),
            onNewer: newer == null ? null : () => setState(() => _month = newer),
            onPick: () => _pickMonth(context, month, now),
          ),
          const SizedBox(height: 14),
          _StatGrid(stats: stats),
          const SizedBox(height: 14),
          SectionHeader(
            title: l.whereItWent,
            actionLabel: stats.categories.length > 4
                ? l.allN(stats.categories.length)
                : null,
            onAction: () => _showAllCategories(
              context,
              stats.month,
              stats.categories,
              l.whereItWent,
              context.scandy.negative,
            ),
          ),
          const SizedBox(height: 9),
          _CategoryList(
            // The design shows four rows and links to the rest.
            categories: stats.categories.take(4).toList(),
            totalCount: stats.categories.length,
            color: context.scandy.negative,
            emptyIcon: Icons.bar_chart,
            emptyTitle: l.nothingSpentThisMonth,
            emptyMessage: l.nothingSpentThisMonthBody,
          ),
          const SizedBox(height: 15),
          SectionHeader(
            title: l.whereItCameFrom,
            actionLabel: stats.incomeCategories.length > 4
                ? l.allN(stats.incomeCategories.length)
                : null,
            onAction: () => _showAllCategories(
              context,
              stats.month,
              stats.incomeCategories,
              l.whereItCameFrom,
              context.scandy.positive,
            ),
          ),
          const SizedBox(height: 9),
          _CategoryList(
            categories: stats.incomeCategories.take(4).toList(),
            totalCount: stats.incomeCategories.length,
            color: context.scandy.positive,
            emptyIcon: Icons.payments,
            emptyTitle: l.nothingCameInThisMonth,
            emptyMessage: l.nothingCameInThisMonthBody,
          ),
        ],
      ),
    );
  }

  /// Tapping the month label opens the full list of months that have data,
  /// so a jump back across a year boundary does not need repeated chevrons.
  Future<void> _pickMonth(
    BuildContext context,
    DateTime current,
    DateTime now,
  ) async {
    final months = context.read<AppState>().availableMonths(now: now);
    final picked = await showScandySheet<DateTime>(
      context: context,
      title: context.l.chooseAMonth,
      child: _MonthPicker(months: months, selected: current),
    );
    if (picked != null && mounted) setState(() => _month = picked);
  }

  void _showAllCategories(
    BuildContext context,
    DateTime month,
    List<CategorySpend> categories,
    String title,
    Color color,
  ) {
    showScandySheet<void>(
      context: context,
      title: '$title · ${context.dates.monthYear(month)}',
      child: _CategoryList(
        categories: categories,
        totalCount: categories.length,
        color: color,
        emptyIcon: Icons.bar_chart,
        emptyTitle: context.l.nothingHere,
        emptyMessage: context.l.noCategoriesForThisMonth,
      ),
    );
  }
}

/// ‹ September 2026 › — 40px chevrons in a 4px-padded card, forward disabled
/// on the current month.
class _MonthStepper extends StatelessWidget {
  const _MonthStepper({
    required this.month,
    required this.onOlder,
    required this.onNewer,
    required this.onPick,
  });

  final DateTime month;

  /// Null when there is no older/newer month with data — the chevron greys out.
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
        borderRadius: BorderRadius.circular(ScandyRadius.tileLarge),
      ),
      child: Row(
        children: [
          _Chevron(
            icon: Icons.chevron_left,
            onPressed: onOlder,
            tooltip: context.l.previousMonthWithData,
          ),
          Expanded(
            child: InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(11),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  context.dates.monthYear(month),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: ScandyText.monthLabel.copyWith(color: c.textPrimary),
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
  const _Chevron({required this.icon, required this.onPressed, this.tooltip});

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(11),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon,
              size: 21, color: enabled ? c.textTertiary : c.disabled),
        ),
      ),
    );
  }
}

/// Money in / Spent / Net / Daily avg, two per row.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final MonthStats stats;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    final avg = stats.dailyAverage;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _Stat(
                    label: l.moneyIn,
                    value: formatBare(stats.moneyInCents / 100),
                    color: c.positive)),
            const SizedBox(width: 10),
            Expanded(
                child: _Stat(
                    label: l.spentLabel,
                    value: formatBare(stats.spentCents / 100),
                    color: c.negative)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _Stat(
                    label: l.netLabel,
                    value: formatBare(stats.netCents / 100),
                    // A negative month should read as a loss, not as neutral.
                    color: stats.netCents < 0 ? c.negative : c.textPrimary)),
            const SizedBox(width: 10),
            Expanded(
                child: _Stat(
                    label: l.dailyAvg,
                    value: avg == null ? l.emDash : formatBare(avg),
                    color: c.textPrimary)),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return ScandyCard(
      radius: ScandyRadius.row,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(),
              style: ScandyText.statLabel.copyWith(color: c.textSecondary)),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child:
                Text(value, style: ScandyText.statValue.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.categories,
    required this.totalCount,
    required this.color,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.emptyIcon,
  });

  final List<CategorySpend> categories;
  final int totalCount;

  /// Bar and figure colour — spending reads red, income green.
  final Color color;

  final String emptyTitle;
  final String emptyMessage;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return ScandyCard(
      radius: ScandyRadius.list,
      clip: true,
      child: categories.isEmpty
          ? EmptyState(
              icon: emptyIcon,
              title: emptyTitle,
              message: emptyMessage,
            )
          : Column(
              children: [
                for (var i = 0; i < categories.length; i++)
                  Container(
                    constraints: const BoxConstraints(minHeight: 62),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 11),
                    decoration: i == categories.length - 1
                        ? null
                        : BoxDecoration(
                            border:
                                Border(bottom: BorderSide(color: c.divider)),
                          ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                        displayCategory(
                                            context.l, categories[i].category),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: ScandyText.rowTitle
                                            .copyWith(color: c.textPrimary)),
                                  ),
                                  const SizedBox(width: 8),
                                  // Beside the name rather than after the bar,
                                  // so the bar can run the full column width.
                                  Text(
                                    '${(categories[i].fractionOfSpend * 100).round()}%',
                                    style: ScandyText.percentLabel
                                        .copyWith(color: c.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ProportionBar(
                                fraction: categories[i].fractionOfSpend,
                                color: color,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Fixed width, so the bar column is identical on every
                        // row regardless of how many digits the figure has —
                        // otherwise a 4-figure amount visibly shortens its bar.
                        // Wide enough for "12,345.67"; anything longer scales.
                        SizedBox(
                          width: 96,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              formatBare(categories[i].cents / 100),
                              style:
                                  ScandyText.rowAmount.copyWith(color: color),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}


/// Months that have data, grouped by year, newest first. Three per row keeps
/// a full year visible without scrolling.
class _MonthPicker extends StatelessWidget {
  const _MonthPicker({required this.months, required this.selected});

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
            child: Text('$year',
                style: ScandyText.statLabel.copyWith(color: c.textSecondary)),
          ),
          for (final row in _rows(byYear[year]!))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: i < row.length
                          ? _MonthChip(
                              month: row[i],
                              selected: row[i].year == selected.year &&
                                  row[i].month == selected.month,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  static List<List<DateTime>> _rows(List<DateTime> items) {
    final rows = <List<DateTime>>[];
    for (var i = 0; i < items.length; i += 3) {
      rows.add(items.sublist(i, i + 3 > items.length ? items.length : i + 3));
    }
    return rows;
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
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: 46),
          child: Text(
            context.dates.shortMonth(month),
            style: (selected
                    ? ScandyText.segmentLabelActive
                    : ScandyText.segmentLabel)
                .copyWith(
                    color: selected ? c.onAccentSoft : c.textTertiary),
          ),
        ),
      ),
    );
  }
}
