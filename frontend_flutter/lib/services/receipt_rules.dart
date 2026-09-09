/// Extracting date, time and amount from OCR text, on device, with no model.
///
/// This is a port of `backend/ocr/rules_extractor.py` and the parsing half of
/// `backend/ocr/receipt_text.py`. Both are checked against the same cases in
/// `test/fixtures/receipt_cases.json`, so the two implementations cannot drift
/// apart without a test going red — regenerate that file with
/// `backend/bench/make_fixture.py`.
///
/// Why rules rather than a model: on 50 payment screenshots plus 4 physical
/// receipts, these rules got all three fields right every time, where a 0.5B
/// extraction model on the identical OCR text managed 0.76. Receipts signpost
/// their own fields, and the signals are cheap to read:
///
///   * a time is only believed when it shares a row with a date, or sits on a
///     row that labels itself as a time — which keeps the phone's status-bar
///     clock out of the results without any position-based hack
///   * a labelled row beats a bare one, so a "payment details" field of
///     "22.10.25" cannot outrank the real "25/10/2025 23:40:59" below it
///   * the amount prefers total-labelled rows and discards balance-like ones,
///     because the largest number on a receipt is often an account balance
///
/// Input is the tab-joined row text that [assembleText] produces: a value's
/// label is whatever non-numeric text precedes it on its row.
library;

/// One OCR detection, in pixels measured from the top-left of the image.
class OcrLine {
  const OcrLine({
    required this.text,
    required this.confidence,
    required this.x0,
    required this.centreY,
  });

  final String text;
  final double confidence;
  final double x0;
  final double centreY;
}

/// Fields read off a receipt. A null means "could not read", never a guess.
class ReceiptFields {
  const ReceiptFields({this.date, this.time, this.amount});

  /// `DD/MM/YYYY`.
  final String? date;

  /// `HH:MM:SS`, 24-hour.
  final String? time;

  /// A bare decimal with two places, no currency — `'186.75'`.
  final String? amount;

  bool get isComplete => date != null && time != null && amount != null;

  List<String> get missing => [
        if (date == null) 'date',
        if (time == null) 'time',
        if (amount == null) 'amount',
      ];

  @override
  String toString() => 'ReceiptFields(date: $date, time: $time, amount: $amount)';

  @override
  bool operator ==(Object other) =>
      other is ReceiptFields &&
      other.date == date &&
      other.time == time &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(date, time, amount);
}

/// Detections below this confidence are dropped before rows are assembled.
const double minOcrConfidence = 0.5;

/// Rows group detections whose vertical centres are within this fraction of the
/// image height.
const double rowTolerance = 0.01;

/// Sorts OCR detections top-to-bottom and rejoins same-row ones with a tab.
///
/// Receipts are label/value pairs laid out in columns. Feeding the detections in
/// detector order shreds that pairing apart, and nothing downstream can recover
/// it.
String assembleText(List<OcrLine> lines, double imageHeight,
    {double tolerationFraction = rowTolerance}) {
  final kept = lines
      .where((l) => l.confidence >= minOcrConfidence && l.text.trim().isNotEmpty)
      .toList()
    ..sort((a, b) => a.centreY.compareTo(b.centreY));

  final tolerance = (tolerationFraction * imageHeight).clamp(1.0, double.infinity);
  final rows = <List<OcrLine>>[];
  final centres = <double>[];

  for (final line in kept) {
    if (rows.isNotEmpty && (line.centreY - centres.last).abs() <= tolerance) {
      rows.last.add(line);
      centres[centres.length - 1] =
          rows.last.map((l) => l.centreY).reduce((a, b) => a + b) / rows.last.length;
    } else {
      rows.add([line]);
      centres.add(line.centreY);
    }
  }

  return rows.map((row) {
    row.sort((a, b) => a.x0.compareTo(b.x0));
    return row.map((l) => l.text.trim()).join('\t');
  }).join('\n');
}

// --- Field normalisation -----------------------------------------------------

const _monthNames = <String, int>{
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

// Day-first: these are Malaysian receipts, so 05-09-2026 is 5 September. Change
// this deliberately rather than guessing per receipt.
final _numericDate = RegExp(r'(\d{1,2})\s*[/.-]\s*(\d{1,2})\s*[/.-]\s*(\d{2,4})');
final _isoDate = RegExp(r'(\d{4})-(\d{2})-(\d{2})');
final _spelledDate = RegExp(r'(\d{1,2})\s+([A-Za-z]{3,9})\.?\s+(\d{4})');

/// A date far in the past or more than a day ahead is a misread, not a purchase.
const int _minYear = 2000;

String _two(int value) => value.toString().padLeft(2, '0');

/// Parses a date span into `DD/MM/YYYY`, or null if it is not a plausible one.
String? normaliseDate(String? value, {DateTime? today}) {
  if (value == null || value.trim().isEmpty) return null;
  final raw = value.trim();

  int? year, month, day;

  final spelled = _spelledDate.firstMatch(raw);
  final iso = _isoDate.firstMatch(raw);
  final numeric = _numericDate.firstMatch(raw);

  if (spelled != null) {
    final month0 = _monthNames[spelled.group(2)!.toLowerCase().substring(0, 3)];
    if (month0 == null) return null;
    day = int.parse(spelled.group(1)!);
    month = month0;
    year = int.parse(spelled.group(3)!);
  } else if (iso != null) {
    year = int.parse(iso.group(1)!);
    month = int.parse(iso.group(2)!);
    day = int.parse(iso.group(3)!);
  } else if (numeric != null) {
    day = int.parse(numeric.group(1)!);
    month = int.parse(numeric.group(2)!);
    final rawYear = numeric.group(3)!;
    year = rawYear.length == 2 ? 2000 + int.parse(rawYear) : int.parse(rawYear);
  } else {
    return null;
  }

  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final parsed = DateTime(year, month, day);
  // DateTime rolls 31 April over into May; reject rather than accept the roll.
  if (parsed.year != year || parsed.month != month || parsed.day != day) return null;

  final now = today ?? DateTime.now();
  final limit = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  if (year < _minYear || parsed.isAfter(limit)) return null;

  return '${_two(day)}/${_two(month)}/$year';
}

final _timeRe = RegExp(r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?', caseSensitive: false);

/// Parses a time span into `HH:MM:SS`, resolving 12-hour spans like `07:35 PM`.
String? normaliseTime(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final match = _timeRe.firstMatch(value.trim().toUpperCase());
  if (match == null) return null;

  var hours = int.parse(match.group(1)!);
  final minutes = int.parse(match.group(2)!);
  final seconds = int.parse(match.group(3) ?? '0');
  final meridiem = match.group(4);

  if (meridiem == 'PM' && hours != 12) {
    hours += 12;
  } else if (meridiem == 'AM' && hours == 12) {
    hours = 0;
  }

  if (hours >= 24 || minutes >= 60 || seconds >= 60) return null;
  return '${_two(hours)}:${_two(minutes)}:${_two(seconds)}';
}

/// Above this, assume a reference number caught by the money pattern.
const int _maxAmountCents = 100000 * 100;

/// Normalises a money span to a bare two-decimal string, or null.
///
/// Parsed as integer cents rather than a double: this is money, and it is stored
/// as cents by the backend anyway.
String? normaliseAmount(String? value) {
  if (value == null) return null;
  var raw = value.trim().replaceAll(RegExp(r'[^\d.,-]'), '');
  raw = raw.replaceAll('-', '');
  if (raw.isEmpty) return null;

  // Whichever separator comes last is the decimal mark; the other groups digits.
  if (raw.contains(',') && raw.contains('.')) {
    raw = raw.lastIndexOf('.') > raw.lastIndexOf(',')
        ? raw.replaceAll(',', '')
        : raw.replaceAll('.', '').replaceAll(',', '.');
  } else if (raw.contains(',')) {
    final tail = raw.split(',').last;
    raw = tail.length == 2 ? raw.replaceAll(',', '.') : raw.replaceAll(',', '');
  }

  final parts = raw.split('.');
  if (parts.length > 2) return null;
  final whole = parts[0].isEmpty ? '0' : parts[0];
  final fraction = parts.length == 2 ? parts[1] : '';
  if (!RegExp(r'^\d+$').hasMatch(whole)) return null;
  if (fraction.isNotEmpty && !RegExp(r'^\d+$').hasMatch(fraction)) return null;

  final wholeValue = int.tryParse(whole);
  if (wholeValue == null) return null;
  var cents =
      wholeValue * 100 + int.parse(fraction.padRight(2, '0').substring(0, 2));
  // Round half-up on the third decimal rather than truncating, matching the
  // Decimal quantize in receipt_text.normalise_amount — otherwise "12.999" is
  // 12.99 here and 13.00 there. 0x35 is '5'; the digits were validated above.
  if (fraction.length > 2 && fraction.codeUnitAt(2) >= 0x35) cents += 1;
  if (cents <= 0 || cents > _maxAmountCents) return null;

  return '${cents ~/ 100}.${_two(cents % 100)}';
}

// --- Amount ------------------------------------------------------------------
//
// "Largest number on the receipt" is a trap: any receipt that also prints an
// account balance, cash tendered or a credit limit has a bigger number on it
// than the amount actually paid. On synthetic layouts that rule scored 2/9 where
// the guarded one below scored 9/9.

final _currencyRe =
    RegExp(r'RM|MYR|SGD|USD|EUR|GBP|\$|€|£', caseSensitive: false);

/// Money looks like 1,234.56 or 12.50. Requiring the two decimals is what keeps
/// quantities, table numbers, years and reference codes out of the pool.
final _moneyRe = RegExp(r'-?\d{1,3}(?:,\d{3})*\.\d{2}\b|-?\d+\.\d{2}\b');

const _totalLabels = [
  'grand total', 'grandtotal', 'total accounts receivable', 'amount payable',
  'amount paid', 'payment amount', 'total amount', 'nett total', 'net total',
  'total due', 'you paid', 'total', 'amount', 'jumlah', 'amaun', 'bayaran',
];

/// Rows whose number is emphatically not what the customer paid.
const _excludeLabels = [
  'balance', 'baki', 'change', 'kembalian', 'cash', 'tunai', 'tendered',
  'available', 'credit limit', 'points', 'point', 'mata', 'saving', 'savings',
  'discount', 'diskaun', 'rebate', 'deposit', 'wallet balance', 'outstanding',
  'previous', 'opening', 'closing', 'reward', 'bonus', 'fee', 'fees', 'caj',
  'promotion', 'cashback',
];

bool _containsAny(String haystack, List<String> needles) =>
    needles.any(haystack.contains);

List<int> _moneyIn(String text) {
  final out = <int>[];
  for (final match in _moneyRe.allMatches(text)) {
    final normalised = normaliseAmount(match.group(0));
    if (normalised != null) {
      final parts = normalised.split('.');
      out.add(int.parse(parts[0]) * 100 + int.parse(parts[1]));
    }
  }
  return out;
}

/// Recovers the paid amount from assembled OCR text.
///
/// With [guarded] false this is the plain "largest money value" rule, kept so
/// the difference stays measurable.
String? amountFromText(String ocrText, {bool guarded = true}) {
  final labelled = <int>[];
  final loose = <int>[];
  final rows = ocrText.split('\n');

  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    final lowRow = row.toLowerCase();

    // A row that names a total but carries no figure is the label for the row
    // under it — "Payment Amount (MYR)" above a bare "40.00". The row that
    // supplies the figure has to clear the exclusion list too, or a
    // "Wallet Balance  RM 250.00" sitting between the label and the real total
    // is adopted as the total.
    if (_moneyIn(row).isEmpty &&
        _containsAny(lowRow, _totalLabels) &&
        !_containsAny(lowRow, _excludeLabels) &&
        index + 1 < rows.length &&
        !_containsAny(rows[index + 1].toLowerCase(), _excludeLabels)) {
      labelled.addAll(_moneyIn(rows[index + 1]));
    }

    final rowHasCurrency = _currencyRe.hasMatch(row);
    // A value's label is the non-numeric text *before* it on the row. Text after
    // is a different column: on "-RM10.60 <tab> +10 points" the points are a
    // sibling value, not a description of the amount.
    final preceding = <String>[];

    for (final cell in row.split('\t').where((c) => c.trim().isNotEmpty)) {
      final values = _moneyIn(cell);
      if (values.isEmpty) {
        preceding.add(cell);
        continue;
      }

      if (!guarded) {
        if (rowHasCurrency || _containsAny(lowRow, _totalLabels)) loose.addAll(values);
        continue;
      }

      final context = [...preceding, cell].join(' ').toLowerCase();
      final isTotal = _containsAny(context, _totalLabels);

      // A bare "186.75" in a column only counts if something names it.
      if (!rowHasCurrency && !isTotal) continue;
      // Exclusion outranks the total label: "Total Savings" says both, and it is
      // emphatically not what the customer paid.
      if (_containsAny(context, _excludeLabels)) continue;
      (isTotal ? labelled : loose).addAll(values);
    }
  }

  final pool = labelled.isNotEmpty ? labelled : loose;
  if (pool.isEmpty) return null;
  final best = pool.reduce((a, b) => a > b ? a : b);
  return '${best ~/ 100}.${_two(best % 100)}';
}

// --- Date and time -----------------------------------------------------------

/// Rows whose date or time is not the transaction's. "Printing time" on a
/// thermal receipt is seconds after the sale and sits right next to it.
const _rowExclude = [
  'printing time', 'print time', 'printed', 'expiry', 'expires', 'valid until',
  'due date', 'statement date',
];

const _dateLabels = [
  'date', 'tarikh', '日期', 'checkout time', 'invoice date', 'transaction date',
  'date/time', 'date & time', 'date and time',
];
const _timeLabels = [
  'time', 'masa', '时间', 'date/time', 'date & time', 'date and time',
  'checkout time', 'transaction date',
];

bool _hasDate(String text) =>
    _numericDate.hasMatch(text) || _isoDate.hasMatch(text) || _spelledDate.hasMatch(text);

Iterable<String> _dateSpans(String text) sync* {
  for (final m in _spelledDate.allMatches(text)) {
    yield m.group(0)!;
  }
  for (final m in _isoDate.allMatches(text)) {
    yield m.group(0)!;
  }
  for (final m in _numericDate.allMatches(text)) {
    yield m.group(0)!;
  }
}

/// The non-numeric text on a row — its label side.
String _labelOf(String row) {
  final parts = row
      .split('\t')
      .where((c) => c.trim().isNotEmpty)
      .where((c) => !_hasDate(c) && !_timeRe.hasMatch(c) && !_moneyRe.hasMatch(c));
  return parts.join(' ').toLowerCase();
}

/// Picks the transaction's date and time out of assembled OCR text.
({String? date, String? time}) extractDateTime(String ocrText, {DateTime? today}) {
  final rows =
      ocrText.split('\n').where((r) => r.trim().isNotEmpty).toList(growable: false);

  // A narrow column wraps "23/10/2025 19:46:57" onto two rows, leaving the time
  // alone with neither a date nor a label — which the guard below would
  // otherwise discard as a status-bar clock. A bare continuation row inherits
  // the date from the row above it.
  final inheritsDate = List<bool>.filled(rows.length, false);
  for (var i = 0; i < rows.length - 1; i++) {
    final next = rows[i + 1];
    if (_hasDate(rows[i]) &&
        !_timeRe.hasMatch(rows[i]) &&
        _timeRe.hasMatch(next) &&
        !_hasDate(next) &&
        _labelOf(next).trim().isEmpty) {
      inheritsDate[i + 1] = true;
    }
  }

  String? bestDate, bestTime;
  double? bestDateScore, bestTimeScore;

  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    final low = row.toLowerCase();
    if (_containsAny(low, _rowExclude)) continue;
    // A row about a balance or a reward is not about this transaction.
    if (_containsAny(low, _excludeLabels)) continue;

    final label = _labelOf(row);
    final dates = _dateSpans(row)
        .map((s) => normaliseDate(s, today: today))
        .whereType<String>()
        .toList();
    final times = _timeRe
        .allMatches(row)
        .map((m) => normaliseTime(m.group(0)))
        .whereType<String>()
        .toList();

    final hasDateLabel = _containsAny(label, _dateLabels);
    final hasTimeLabel = _containsAny(label, _timeLabels);

    for (final value in dates) {
      // A labelled row wins; a row that also carries a time is the classic
      // "20/04/2026 19:16:30" pairing and is nearly as good. Earlier rows break
      // ties, since the summary sits above the fine print.
      final score =
          (hasDateLabel ? 2 : 0) + (times.isNotEmpty ? 1 : 0) - index * 0.001;
      if (bestDateScore == null || score > bestDateScore) {
        bestDate = value;
        bestDateScore = score;
      }
    }

    final besideDate = dates.isNotEmpty || inheritsDate[index];
    for (final value in times) {
      // The decisive rule: a bare time with neither a date beside it nor a time
      // label is almost certainly the phone's status-bar clock.
      if (!besideDate && !hasTimeLabel) continue;
      final score = (hasTimeLabel ? 2 : 0) + (besideDate ? 1 : 0) - index * 0.001;
      if (bestTimeScore == null || score > bestTimeScore) {
        bestTime = value;
        bestTimeScore = score;
      }
    }
  }

  return (date: bestDate, time: bestTime);
}

/// Reads date, time and amount out of assembled OCR text using no model.
ReceiptFields extractFields(String ocrText,
    {bool guardedAmount = true, DateTime? today}) {
  final dateTime = extractDateTime(ocrText, today: today);
  return ReceiptFields(
    date: dateTime.date,
    time: dateTime.time,
    amount: amountFromText(ocrText, guarded: guardedAmount),
  );
}
