// The strings every row and card is built from. A wrong sign or a hyphen where
// the design has a minus shows up on every screen at once, so they are pinned
// here rather than left to the goldens, which CI does not run.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:scandy/l10n/l10n.dart';
import 'package:scandy/util/formatting.dart';

void main() {
  late L en;
  late L zh;
  setUpAll(() async {
    // The app gets this from GlobalMaterialLocalizations; a bare test does not.
    await initializeDateFormatting('en');
    await initializeDateFormatting('zh');
    en = await L.delegate.load(const Locale('en'));
    zh = await L.delegate.load(const Locale('zh'));
  });

  group('money', () {
    test('grouped, two decimals, whatever the value', () {
      expect(formatRinggit(1666.7), 'RM 1,666.70');
      expect(formatRinggit(0), 'RM 0.00');
      expect(formatBare(4850), '4,850.00');
      expect(formatBare(1234567.891), '1,234,567.89');
    });

    test('signed amounts use a true minus sign, and + for income', () {
      expect(formatSignedCents(485000), '+4,850.00');
      expect(formatSignedCents(-8640), '${minusSign}86.40');
      expect(formatSignedCents(-8640), isNot(contains('-')), reason: 'hyphen');
      expect(formatSignedCents(0), '+0.00');
      expect(formatSignedCents(-1), '${minusSign}0.01');
    });
  });

  group('greetingFor', () {
    test('switches at noon and six', () {
      expect(greetingFor(en, DateTime(2026, 9, 6, 0, 0)), en.goodMorning);
      expect(greetingFor(en, DateTime(2026, 9, 6, 11, 59)), en.goodMorning);
      expect(greetingFor(en, DateTime(2026, 9, 6, 12, 0)), en.goodAfternoon);
      expect(greetingFor(en, DateTime(2026, 9, 6, 17, 59)), en.goodAfternoon);
      expect(greetingFor(en, DateTime(2026, 9, 6, 18, 0)), en.goodEvening);
    });
  });

  group('displayCategory', () {
    test('a person\'s own names are shown as written, trimmed', () {
      expect(displayCategory(en, '  Groceries '), 'Groceries');
      expect(displayCategory(zh, 'Groceries'), 'Groceries');
    });

    test('the uncategorised sentinel is translated, in either spelling', () {
      for (final raw in ['', '   ', 'Uncategorized', 'uncategorised']) {
        expect(displayCategory(en, raw), 'Uncategorised', reason: raw);
        expect(displayCategory(zh, raw), zh.uncategorised, reason: raw);
      }
    });
  });

  group('transactionMeta', () {
    final now = DateTime(2026, 9, 6, 21, 4);
    String meta(
      DateTime? date, {
      String shortTime = '14:22',
      String category = 'Groceries',
    }) => transactionMeta(
      l: en,
      dates: ScandyDates(en, 'en'),
      category: category,
      date: date,
      shortTime: shortTime,
      now: now,
    );

    test("today's rows show the time", () {
      expect(meta(DateTime(2026, 9, 6)), 'Groceries · 14:22');
    });

    test('older rows show the day, not the time', () {
      expect(meta(DateTime(2026, 9, 5)), 'Groceries · 5 Sep');
      // Same day of a different month is not today.
      expect(meta(DateTime(2026, 8, 6)), 'Groceries · 6 Aug');
    });

    test('the day is written the way the reader writes it', () {
      final meta = transactionMeta(
        l: zh,
        dates: ScandyDates(zh, 'zh'),
        category: 'Groceries',
        date: DateTime(2026, 9, 5),
        shortTime: '14:22',
        now: now,
      );
      expect(meta, 'Groceries · 9月5日');
    });

    test('a row with no date, or no time, is just the category', () {
      expect(meta(null), 'Groceries');
      expect(meta(DateTime(2026, 9, 6), shortTime: ''), 'Groceries');
    });

    test('the category is displayed, not stored, text', () {
      expect(meta(null, category: ''), 'Uncategorised');
    });
  });
}
