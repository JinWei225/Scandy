import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

/// Grouping and two decimals, pinned to en_US rather than the reader's locale.
///
/// Money is the one thing on the screen that does *not* change with the
/// language: "1,666.70" is how a Malaysian bank statement writes it whether it
/// is in English or Chinese, and switching to a locale that groups differently
/// would make the app disagree with the statements it is recording.
final _grouped = NumberFormat('#,##0.00', 'en_US');

/// The design writes negative amounts with a true minus sign (U+2212), not a
/// hyphen — it aligns with the tabular digits where a hyphen does not.
const minusSign = '−';

/// "RM 1,666.70" — the hero figure and anywhere else the currency is spelled.
String formatRinggit(num amount) => 'RM ${_grouped.format(amount)}';

/// "4,850.00" — the in/spent/due breakdown drops the currency, since the card
/// already establishes it.
String formatBare(num amount) => _grouped.format(amount);

/// "+4,850.00" / "−86.40" — a signed row amount. [cents] carries the sign.
String formatSignedCents(int cents) {
  final sign = cents < 0 ? minusSign : '+';
  return '$sign${_grouped.format(cents.abs() / 100)}';
}

/// Dates, written the way the reader's language writes them.
///
/// A shared pattern cannot serve both: English puts the day first and spells
/// the month ("Saturday, 6 September"), Chinese runs largest unit to smallest
/// and marks each one ("9月6日 星期六"). So the pattern itself is translated —
/// it lives in the .arb files beside the sentences — and this class is the one
/// place that turns a pattern plus a locale into text.
class ScandyDates {
  const ScandyDates(this._l, this._locale);

  factory ScandyDates.of(BuildContext context) => ScandyDates(
        L.of(context),
        Localizations.localeOf(context).toLanguageTag(),
      );

  final L _l;
  final String _locale;

  /// "Saturday, 6 September" — the greeting subtitle.
  String greeting(DateTime date) => _at(_l.datePatternGreeting, date);

  /// "Sep" — the month in the card eyebrow and the month chips.
  String shortMonth(DateTime date) => _at(_l.datePatternShortMonth, date);

  /// "September" — the desktop hero eyebrow.
  String monthOnly(DateTime date) => _at(_l.datePatternMonthOnly, date);

  /// "5 Sep" — a transaction row, or the day a charge was recorded.
  String dayMonth(DateTime date) => _at(_l.datePatternDayMonth, date);

  /// "September 2026" — the month stepper.
  String monthYear(DateTime date) => _at(_l.datePatternMonthYear, date);

  /// "10 Sep 2026" — the date tile on the transaction form.
  String medium(DateTime date) => _at(_l.datePatternMedium, date);

  /// "Thursday, 10 September 2026" — the transaction detail sheet.
  String full(DateTime date) => _at(_l.datePatternFull, date);

  String _at(String pattern, DateTime date) =>
      DateFormat(pattern, _locale).format(date);
}

extension ScandyDatesContext on BuildContext {
  ScandyDates get dates => ScandyDates.of(this);
}

/// Time of day drives the greeting, matching the design's "Good evening".
String greetingFor(L l, DateTime now) {
  final h = now.hour;
  if (h < 12) return l.goodMorning;
  if (h < 18) return l.goodAfternoon;
  return l.goodEvening;
}

/// What to print for a stored category name.
///
/// Category names are the person's own rows and are shown as they wrote them.
/// The exception is the sentinel the app writes for a row filed under nothing
/// -- "Uncategorized" was never chosen by anyone, it is what the transaction
/// form puts in when no category is picked, so it is the one name that does
/// get translated.
String displayCategory(L l, String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return l.uncategorised;
  return switch (trimmed.toLowerCase()) {
    'uncategorized' || 'uncategorised' => l.uncategorised,
    _ => trimmed,
  };
}

/// The design's transaction rows read "Groceries · 14:22" for anything from
/// today and "Salary · 5 Sep" for older rows — category first, then the most
/// useful time reference.
String transactionMeta({
  required L l,
  required ScandyDates dates,
  required String category,
  required DateTime? date,
  required String shortTime,
  required DateTime now,
}) {
  final label = displayCategory(l, category);
  if (date == null) return label;
  final isToday =
      date.year == now.year && date.month == now.month && date.day == now.day;
  final when = isToday ? shortTime : dates.dayMonth(date);
  return when.isEmpty ? label : '$label · $when';
}
