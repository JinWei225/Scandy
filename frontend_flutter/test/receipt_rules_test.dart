// The Dart rules must agree with the Python ones in backend/ocr/rules_extractor.py.
//
// Both run against test/fixtures/receipt_cases.json — the same OCR text, the same
// expected fields — so a divergence between the two implementations shows up here
// rather than as a wrong transaction on someone's phone. Regenerate the fixture
// with `.venv/bin/python backend/bench/make_fixture.py`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scandy/services/receipt_rules.dart';

void main() {
  // The captured receipts are dated in the past; pinning "today" keeps the
  // future-date validation from failing the suite as the real clock moves on.
  final today = DateTime(2030, 1, 1);

  group('shared fixture', () {
    final file = File('test/fixtures/receipt_cases.json');
    final payload = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final cases = (payload['cases'] as List).cast<Map<String, dynamic>>();

    test('fixture is present and non-trivial', () {
      expect(cases.length, greaterThan(50));
    });

    for (final testCase in cases) {
      final id = testCase['id'] as String;
      final expected = (testCase['expected'] as Map).cast<String, dynamic>();

      test(id, () {
        final got = extractFields(testCase['ocr_text'] as String, today: today);
        expect(got.date, expected['date'], reason: 'date for $id');
        expect(got.time, expected['time'], reason: 'time for $id');
        expect(got.amount, expected['amount'], reason: 'amount for $id');
      });
    }
  });

  group('normaliseDate', () {
    final today = DateTime(2030, 1, 1);

    test('reads the formats receipts actually print', () {
      expect(normaliseDate('20/04/2026', today: today), '20/04/2026');
      expect(normaliseDate('05-09-2026 07:35 PM', today: today), '05/09/2026');
      expect(normaliseDate('2026-08-21', today: today), '21/08/2026');
      expect(normaliseDate('5 Sep 2026', today: today), '05/09/2026');
      expect(normaliseDate('29 Oct 2025 18:33:24', today: today), '29/10/2025');
      expect(normaliseDate('25.10.25', today: today), '25/10/2025');
    });

    test('is day-first, not month-first', () {
      expect(normaliseDate('05/09/2026', today: today), '05/09/2026');
    });

    test('rejects impossible and out-of-range dates', () {
      expect(normaliseDate('31/04/2026', today: today), isNull);
      expect(normaliseDate('20/13/2026', today: today), isNull);
      expect(normaliseDate('01/01/1970', today: today), isNull);
      expect(normaliseDate('01/01/2031', today: today), isNull, reason: 'future');
      expect(normaliseDate('', today: today), isNull);
      expect(normaliseDate(null, today: today), isNull);
    });

    test('does not mistake a time for a date', () {
      expect(normaliseDate('19:16:30', today: today), isNull);
    });
  });

  group('normaliseTime', () {
    test('resolves 12-hour spans', () {
      expect(normaliseTime('07:35 PM'), '19:35:00');
      expect(normaliseTime('12:30 AM'), '00:30:00');
      expect(normaliseTime('12:30 PM'), '12:30:00');
      expect(normaliseTime('10:28AM'), '10:28:00');
      expect(normaliseTime('19:16:30'), '19:16:30');
    });

    test('rejects nonsense', () {
      expect(normaliseTime('25:00'), isNull);
      expect(normaliseTime('10:99'), isNull);
      expect(normaliseTime('no time here'), isNull);
      expect(normaliseTime(null), isNull);
    });

    test('does not mistake a date for a time', () {
      expect(normaliseTime('20/04/2026'), isNull);
    });
  });

  group('normaliseAmount', () {
    test('strips currency and separators', () {
      expect(normaliseAmount('RM 186.75'), '186.75');
      expect(normaliseAmount('-RM10.60'), '10.60', reason: 'sign is dropped');
      expect(normaliseAmount('RM2,075.70'), '2075.70');
      expect(normaliseAmount('68.44 MYR'), '68.44');
      expect(normaliseAmount('1.234,56'), '1234.56', reason: 'comma decimal mark');
    });

    test('rejects non-amounts', () {
      expect(normaliseAmount('0.00'), isNull);
      expect(normaliseAmount(''), isNull);
      expect(normaliseAmount(null), isNull);
      expect(normaliseAmount('99999999.00'), isNull, reason: 'above the ceiling');
    });
  });

  group('amountFromText', () {
    // The layouts a "largest number" rule gets wrong. These mirror the synthetic
    // probe in backend/bench/compare_pipelines.py, which scores the naive rule
    // 2/9 and the guarded one 9/9.
    const cases = <String, (String, String)>{
      'labelled total': (
        'SUBTOTAL(MYR)\t161.00\nTAX(SST 6%)\t9.66\nGRANDTOTAL(MYR)\t186.75',
        '186.75'
      ),
      'headline only': (
        'Details\n-RM10.60\t+10 points\nMerchant\tEXAMPLE CAFE\nStatus\tSuccessful',
        '10.60'
      ),
      'wallet balance shown': (
        'RM 6.00\tPaid\nPayment Method\teWallet Balance\neWallet Balance\tRM 250.00',
        '6.00'
      ),
      'cash and change': ('TOTAL\tRM 45.60\nCASH\tRM 100.00\nCHANGE\tRM 54.40', '45.60'),
      'points and savings': (
        'Total Amount\tRM 23.90\nTotal Savings\tRM 31.20\nPoints Earned\t120.00',
        '23.90'
      ),
      'credit limit': ('AMOUNT\tRM 88.00\nCREDIT LIMIT\tRM 5,000.00\nAPPROVED', '88.00'),
      'malay labels': ('JUMLAH\tRM 73.40\nTUNAI\tRM 100.00\nBAKI\tRM 26.60', '73.40'),
      'balance, no total label': (
        'RM 9.90\nPaid to EXAMPLE WARUNG\nBaki eWallet\tRM 430.00',
        '9.90'
      ),
      'amount on the next row': ('Payment Amount (MYR)\n40.00\nReference No.\t123', '40.00'),
    };

    cases.forEach((name, data) {
      final (text, expected) = data;
      test('guarded: $name', () => expect(amountFromText(text), expected));
    });

    test('the naive rule really is worse, and that is why guarded exists', () {
      const text =
          'RM 6.00\tPaid\nPayment Method\teWallet Balance\neWallet Balance\tRM 250.00';
      expect(amountFromText(text, guarded: false), '250.00');
      expect(amountFromText(text), '6.00');
    });
  });

  group('extractDateTime', () {
    final today = DateTime(2030, 1, 1);

    test('ignores the status-bar clock', () {
      // "9:05" at the top has neither a date beside it nor a time label.
      const text = '9:05\nPayment successful\nRM 76.67\n'
          'Date & time\t5 Sep 2026, 9:05 PM';
      final got = extractDateTime(text, today: today);
      expect(got.date, '05/09/2026');
      expect(got.time, '21:05:00');
    });

    test('a labelled row beats a bare date elsewhere', () {
      const text = '款项详情\t22.10.25\n日期/时间\t25/10/2025 23:40:59';
      final got = extractDateTime(text, today: today);
      expect(got.date, '25/10/2025', reason: 'the details field must not win');
      expect(got.time, '23:40:59');
    });

    test('follows a value wrapped onto the next row', () {
      const text = 'Date & Time\t23/10/2025\n19:46:57';
      final got = extractDateTime(text, today: today);
      expect(got.date, '23/10/2025');
      expect(got.time, '19:46:57');
    });

    test('skips a printing time next to the real one', () {
      const text = 'Checkout Time:2026-08-21 13:20:44\n'
          'Printing Time:2026-08-21 13:20:45';
      final got = extractDateTime(text, today: today);
      expect(got.time, '13:20:44');
    });

    test('reports nothing rather than guessing', () {
      final got = extractDateTime('Payment successful\nRM 42.50', today: today);
      expect(got.date, isNull);
      expect(got.time, isNull);
    });
  });

  group('assembleText', () {
    test('groups a row and orders it left to right', () {
      final lines = [
        const OcrLine(text: '19:16:30', confidence: 1, x0: 300, centreY: 100),
        const OcrLine(text: 'Date/Time', confidence: 1, x0: 10, centreY: 102),
        const OcrLine(text: 'Paid', confidence: 1, x0: 10, centreY: 400),
      ];
      expect(assembleText(lines, 1000), 'Date/Time\t19:16:30\nPaid');
    });

    test('drops low-confidence and empty detections', () {
      final lines = [
        const OcrLine(text: 'kept', confidence: 0.9, x0: 0, centreY: 10),
        const OcrLine(text: 'dropped', confidence: 0.1, x0: 0, centreY: 200),
        const OcrLine(text: '   ', confidence: 1, x0: 0, centreY: 400),
      ];
      expect(assembleText(lines, 1000), 'kept');
    });
  });

  group('ReceiptFields', () {
    test('reports what is missing', () {
      const partial = ReceiptFields(amount: '42.50');
      expect(partial.isComplete, isFalse);
      expect(partial.missing, ['date', 'time']);

      const full = ReceiptFields(date: '01/01/2026', time: '00:00:00', amount: '1.00');
      expect(full.isComplete, isTrue);
      expect(full.missing, isEmpty);
    });
  });
}
