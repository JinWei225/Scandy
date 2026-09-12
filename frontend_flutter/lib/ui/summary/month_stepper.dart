import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../util/formatting.dart';
import '../common/sheets.dart';

/// ‹ September 2026 › — 40px chevrons in a 4px-padded card, forward disabled
/// on the current month.
///
/// Shared by Summary and the Account page, which walk months the same way;
/// the caller decides which months exist (see [monthNeighbours]).
class MonthStepper extends StatelessWidget {
  const MonthStepper({
    super.key,
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

/// The months either side of [month] in [months], which is newest-first.
///
/// The chevrons hop between months that actually have data rather than
/// walking the calendar, so a gap year of no transactions is one tap away
/// instead of twelve. The selected month is folded in because it can drop out
/// of that list — delete the last transaction in it and it stops being a month
/// with data, which left both chevrons disabled and no way off the page but
/// the picker.
({DateTime? older, DateTime? newer}) monthNeighbours(
  List<DateTime> months,
  DateTime month,
) {
  final all = <DateTime>{...months, DateTime(month.year, month.month)}.toList()
    ..sort((a, b) => b.compareTo(a));
  final index =
      all.indexWhere((m) => m.year == month.year && m.month == month.month);
  return (
    older: index >= 0 && index + 1 < all.length ? all[index + 1] : null,
    newer: index > 0 ? all[index - 1] : null,
  );
}

/// Opens the full list of months that have data, so a jump back across a year
/// boundary does not need repeated chevrons. Returns the pick, or null.
Future<DateTime?> showMonthPicker(
  BuildContext context, {
  required List<DateTime> months,
  required DateTime selected,
}) {
  return showScandySheet<DateTime>(
    context: context,
    title: context.l.chooseAMonth,
    child: _MonthPicker(months: months, selected: selected),
  );
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
