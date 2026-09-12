import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/summary_stats.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../util/formatting.dart';
import '../common/sheets.dart';
import '../common/widgets.dart';
import '../shell/bottom_nav.dart';
import '../transactions/category_transactions_page.dart';
import '../transactions/search_sheet.dart';
import 'category_list.dart';
import 'month_stats_grid.dart';
import 'month_stepper.dart';

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

    final neighbours =
        monthNeighbours(state.availableMonths(now: now), month);

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
          MonthStepper(
            month: month,
            onOlder: neighbours.older == null
                ? null
                : () => setState(() => _month = neighbours.older),
            onNewer: neighbours.newer == null
                ? null
                : () => setState(() => _month = neighbours.newer),
            onPick: () => _pickMonth(context, month, now),
          ),
          const SizedBox(height: 14),
          MonthStatGrid(stats: stats),
          const SizedBox(height: 14),
          ...categorySections(
            context,
            stats: stats,
            onOpen: (category, income) => CategoryTransactionsPage.open(
              context,
              month: stats.month,
              category: category.category,
              income: income,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMonth(
    BuildContext context,
    DateTime current,
    DateTime now,
  ) async {
    final picked = await showMonthPicker(
      context,
      months: context.read<AppState>().availableMonths(now: now),
      selected: current,
    );
    if (picked != null && mounted) setState(() => _month = picked);
  }
}

/// "Where it went" and "Where it came from" — header, top four rows, and the
/// "All N" link into the full list — for [stats]. Summary and the Account
/// page lay these out identically, so they share the block.
///
/// [onOpen] is the drill-down: a category and whether it came from the
/// income list. From the "All N" sheet the tap closes the sheet first and
/// then opens, the way Search hands a picked row back to its caller.
List<Widget> categorySections(
  BuildContext context, {
  required MonthStats stats,
  required void Function(CategorySpend category, bool income) onOpen,
}) {
  final l = context.l;
  final c = context.scandy;

  Future<void> showAll(
    List<CategorySpend> categories,
    String title,
    Color color,
    bool income,
  ) async {
    final picked = await showScandySheet<CategorySpend>(
      context: context,
      title: '$title · ${context.dates.monthYear(stats.month)}',
      child: Builder(
        builder: (sheetContext) => CategoryList(
          categories: categories,
          color: color,
          emptyIcon: Icons.bar_chart,
          emptyTitle: l.nothingHere,
          emptyMessage: l.noCategoriesForThisMonth,
          onTap: (category) => Navigator.of(sheetContext).pop(category),
        ),
      ),
    );
    if (picked != null && context.mounted) onOpen(picked, income);
  }

  return [
    SectionHeader(
      title: l.whereItWent,
      actionLabel: stats.categories.length > 4
          ? l.allN(stats.categories.length)
          : null,
      onAction: () =>
          showAll(stats.categories, l.whereItWent, c.negative, false),
    ),
    const SizedBox(height: 9),
    CategoryList(
      // The design shows four rows and links to the rest.
      categories: stats.categories.take(4).toList(),
      color: c.negative,
      emptyIcon: Icons.bar_chart,
      emptyTitle: l.nothingSpentThisMonth,
      emptyMessage: l.nothingSpentThisMonthBody,
      onTap: (category) => onOpen(category, false),
    ),
    const SizedBox(height: 15),
    SectionHeader(
      title: l.whereItCameFrom,
      actionLabel: stats.incomeCategories.length > 4
          ? l.allN(stats.incomeCategories.length)
          : null,
      onAction: () => showAll(
          stats.incomeCategories, l.whereItCameFrom, c.positive, true),
    ),
    const SizedBox(height: 9),
    CategoryList(
      categories: stats.incomeCategories.take(4).toList(),
      color: c.positive,
      emptyIcon: Icons.payments,
      emptyTitle: l.nothingCameInThisMonth,
      emptyMessage: l.nothingCameInThisMonthBody,
      onTap: (category) => onOpen(category, true),
    ),
  ];
}
