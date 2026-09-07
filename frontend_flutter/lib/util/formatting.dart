import 'package:intl/intl.dart';

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

/// "Saturday, 6 September" — the greeting subtitle.
String formatGreetingDate(DateTime date) =>
    DateFormat('EEEE, d MMMM').format(date);

/// "Sep" — the month in the card eyebrow.
String formatShortMonth(DateTime date) => DateFormat('MMM').format(date);

/// Time of day drives the greeting, matching the design's "Good evening".
String greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

/// The design's transaction rows read "Groceries · 14:22" for anything from
/// today and "Salary · 5 Sep" for older rows — category first, then the most
/// useful time reference.
String transactionMeta({
  required String category,
  required DateTime? date,
  required String shortTime,
  required DateTime now,
}) {
  final label = category.isEmpty ? 'Uncategorised' : category;
  if (date == null) return label;
  final isToday =
      date.year == now.year && date.month == now.month && date.day == now.day;
  final when = isToday ? shortTime : DateFormat('d MMM').format(date);
  return when.isEmpty ? label : '$label · $when';
}
