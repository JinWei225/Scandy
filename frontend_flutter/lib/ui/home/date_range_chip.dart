import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../util/formatting.dart';
import '../desktop/desktop_widgets.dart';

/// How many days "Recent" covers out of the box: today, yesterday and the day
/// before. Enough to see what was just logged without the card becoming the
/// whole ledger.
const recentRangeDays = 3;

/// The default range as of [now]: the last [recentRangeDays] calendar days,
/// ending today, with the times stripped so two defaults compare equal.
DateTimeRange defaultRecentRange(DateTime now) {
  final today = DateUtils.dateOnly(now);
  return DateTimeRange(
    start: today.subtract(const Duration(days: recentRangeDays - 1)),
    end: today,
  );
}

/// "4 – 6 Sep", tappable, with a reset beside it once the range has been
/// changed. Sits on the "Recent" title line on both compositions.
class DateRangeChip extends StatelessWidget {
  const DateRangeChip({
    super.key,
    required this.range,
    required this.now,
    required this.onChanged,
  });

  final DateTimeRange range;
  final DateTime now;
  final ValueChanged<DateTimeRange> onChanged;

  bool get _isDefault {
    final d = defaultRecentRange(now);
    return DateUtils.isSameDay(range.start, d.start) &&
        DateUtils.isSameDay(range.end, d.end);
  }

  /// A bound in this year reads "4 Sep"; anything older carries its year, so
  /// a range reaching back into last December is not mistaken for this one.
  String _bound(ScandyDates dates, DateTime date) =>
      date.year == now.year ? dates.dayMonth(date) : dates.medium(date);

  String _label(BuildContext context) {
    final dates = context.dates;
    if (DateUtils.isSameDay(range.start, range.end)) {
      return _bound(dates, range.start);
    }
    return '${_bound(dates, range.start)} – ${_bound(dates, range.end)}';
  }

  Future<void> _pick(BuildContext context) async {
    // 2000 is the floor the transaction form and the scanner already use, and
    // the ceiling matches the form's: a row can be dated up to a year ahead,
    // so the range has to be able to reach it.
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: range,
      firstDate: DateTime(2000),
      lastDate: DateUtils.dateOnly(now).add(const Duration(days: 365)),
      currentDate: now,
      helpText: context.l.chooseADateRange,
      builder: _frame,
    );
    if (picked != null) onChanged(picked);
  }

  /// The calendar range picker sizes itself to the window — it reads
  /// `MediaQuery.sizeOf` and pads by nothing — so on a desktop it swallows the
  /// whole screen. Past the sidebar breakpoint it is handed a phone-sized
  /// window instead, and Material's own dialog chrome (scrim, rounded card)
  /// does the rest. Below it the picker is left alone: full screen is right
  /// on a phone.
  static Widget _frame(BuildContext context, Widget? child) {
    final media = MediaQuery.of(context);
    if (media.size.width < desktopBreakpoint) return child!;
    const size = Size(440, 620);
    return MediaQuery(
      data: media.copyWith(size: size),
      child: Center(
        // Full-screen mode draws square corners, since it expects to meet
        // the window's edges; framed, it takes the sheet radius like every
        // other modal in the app.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ScandyRadius.sheet),
          child:
              SizedBox(width: size.width, height: size.height, child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: c.accentSoft,
          borderRadius: BorderRadius.circular(ScandyRadius.pill),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _pick(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.date_range, size: 15, color: c.onAccentSoft),
                  const SizedBox(width: 6),
                  Text(
                    _label(context),
                    style: ScandyText.countPill.copyWith(color: c.onAccentSoft),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!_isDefault) ...[
          const SizedBox(width: 4),
          Tooltip(
            message: context.l.resetDateRange,
            child: InkWell(
              onTap: () => onChanged(defaultRecentRange(now)),
              borderRadius: BorderRadius.circular(ScandyRadius.pill),
              child: SizedBox(
                width: 30,
                height: 30,
                child: Icon(Icons.restart_alt, size: 18, color: c.textTertiary),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
