// Row parsing and the per-model arithmetic the screens lean on.
import 'package:flutter_test/flutter_test.dart';
import 'package:scandy/models/account.dart';
import 'package:scandy/models/subscription.dart';
import 'package:scandy/models/summary_stats.dart';
import 'package:scandy/models/transaction.dart';

Subscription _sub({
  int day = 15,
  double amount = 10,
  DateTime? recorded,
  String name = 'Sub',
}) => Subscription(
  id: name,
  name: name,
  amount: amount,
  category: 'Other',
  dayOfMonth: day,
  accountId: null,
  lastRecordedDate: recorded,
);

void main() {
  group('Transaction.fromRow', () {
    test(
      'direction comes from type, whatever sign the amount arrives with',
      () {
        Transaction row(String? type, int cents) => Transaction.fromRow({
          'id': 'x',
          'amount_cents': cents,
          'type': type,
        });
        expect(row('income', 500).amountCents, 500);
        expect(row('income', -500).amountCents, 500);
        expect(row('expense', 500).amountCents, -500);
        expect(row('transfer', 500).amountCents, -500);
        expect(row(null, 500).type, TransactionType.expense);
        expect(row('garbage', 500).type, TransactionType.expense);
      },
    );

    test('a sparse row still renders instead of throwing', () {
      final t = Transaction.fromRow(const {});
      expect(t.id, '');
      expect(t.date, isNull);
      expect(t.time, '00:00:00');
      expect(t.amountCents, 0);
      expect(t.category, '');
      expect(t.isTransfer, isFalse);
    });

    test('a malformed date is null, not today', () {
      final t = Transaction.fromRow(const {'occurred_on': '31/02/2026'});
      expect(t.date, isNull);
    });

    test('shortTime keeps hours and minutes only', () {
      Transaction at(String time) => Transaction.fromRow({'occurred_at': time});
      expect(at('14:22:07').shortTime, '14:22');
      expect(at('9:05').shortTime, '9:05');
      expect(at('').shortTime, '');
    });
  });

  group('Account', () {
    test(
      'without a balance from the view, it falls back to the opening one',
      () {
        final a = Account.fromRow(const {
          'id': 'a',
          'initial_balance_cents': -12050,
        });
        expect(a.initialBalance, -120.5);
        expect(a.balance, -120.5);
      },
    );

    test('the cache round-trip is exact in cents', () {
      // 0.1 + 0.2 style drift must not reach the stored figure.
      const a = Account(
        id: 'a',
        name: 'n',
        type: 't',
        initialBalance: 0.29,
        balance: 1234567.89,
      );
      final back = Account.fromJson(a.toJson());
      expect(back.initialBalance, 0.29);
      expect(back.balance, 1234567.89);
      expect(a.toJson()['initial_balance_cents'], 29);
    });
  });

  group('Subscription', () {
    test('fromRow converts cents and reads the recorded date', () {
      final s = Subscription.fromRow(const {
        'id': 's',
        'name': 'Netflix',
        'amount_cents': 5490,
        'day_of_month': 31,
        'last_recorded_date': '2026-08-31',
      });
      expect(s.amount, 54.9);
      expect(s.dayOfMonth, 31);
      expect(s.lastRecordedDate, DateTime(2026, 8, 31));
      expect(
        Subscription.fromRow(s.toJson()).lastRecordedDate,
        DateTime(2026, 8, 31),
      );
    });

    test('the due day clamps to the length of the month', () {
      final s = _sub(day: 31);
      expect(s.dueDayIn(DateTime(2026, 2)), 28);
      expect(s.dueDayIn(DateTime(2028, 2)), 29, reason: 'leap year');
      expect(s.dueDayIn(DateTime(2026, 9)), 30);
      expect(s.dueDayIn(DateTime(2026, 10)), 31);
      expect(_sub(day: 0).dueDayIn(DateTime(2026, 9)), 1);
    });

    test('due until recorded in this calendar month', () {
      final now = DateTime(2026, 9, 6);
      expect(_sub().isDueThisMonth(now), isTrue, reason: 'never recorded');
      expect(_sub(recorded: DateTime(2026, 8, 15)).isDueThisMonth(now), isTrue);
      expect(
        _sub(recorded: DateTime(2025, 9, 15)).isDueThisMonth(now),
        isTrue,
        reason: 'same month, a year ago',
      );
      expect(_sub(recorded: DateTime(2026, 9, 1)).isDueThisMonth(now), isFalse);
    });

    test('overdue only once its day has passed', () {
      final s = _sub(day: 15);
      expect(s.isOverdue(DateTime(2026, 9, 15)), isFalse, reason: 'due today');
      expect(s.isOverdue(DateTime(2026, 9, 16)), isTrue);
      expect(
        _sub(
          day: 15,
          recorded: DateTime(2026, 9, 15),
        ).isOverdue(DateTime(2026, 9, 20)),
        isFalse,
      );
      // A day-31 charge in September is due on the 30th, so never overdue
      // until October.
      expect(_sub(day: 31).isOverdue(DateTime(2026, 9, 30)), isFalse);
    });
  });

  group('RecurringStats', () {
    test('totals are summed in cents, not in floating ringgit', () {
      final now = DateTime(2026, 9, 6);
      final stats = RecurringStats.from([
        _sub(name: 'a', amount: 0.1),
        _sub(name: 'b', amount: 0.2),
        _sub(name: 'c', amount: 54.9, recorded: DateTime(2026, 9, 1)),
      ], now: now);
      expect(stats.toComeCents, 30);
      expect(stats.chargedCents, 5490);
      expect(stats.monthlyTotalCents, 5520);
    });

    test('an unrecorded charge whose day has passed is still to come', () {
      final stats = RecurringStats.from([
        _sub(day: 1),
      ], now: DateTime(2026, 9, 6));
      expect(stats.stillToCome, hasLength(1));
      expect(stats.alreadyCharged, isEmpty);
    });
  });

  group('MonthStats', () {
    Transaction tx(
      int cents,
      DateTime date, {
      TransactionType type = TransactionType.expense,
      String category = 'Food',
    }) => Transaction(
      id: '$date$cents',
      date: date,
      time: '12:00:00',
      description: '',
      amountCents: type == TransactionType.income ? cents : -cents,
      category: category,
      accountId: 'a',
      type: type,
    );

    test('a past month averages over all of its days', () {
      final stats = MonthStats.forMonth(
        DateTime(2026, 2),
        transactions: [tx(2800, DateTime(2026, 2, 10))],
        now: DateTime(2026, 9, 6),
      );
      expect(stats.daysElapsed, 28);
      expect(stats.dailyAverage, 1.0);
    });

    test('the current month averages over the days so far', () {
      final stats = MonthStats.forMonth(
        DateTime(2026, 9, 20), // any day of the month selects it
        transactions: [tx(600, DateTime(2026, 9, 2))],
        now: DateTime(2026, 9, 6),
      );
      expect(stats.month, DateTime(2026, 9));
      expect(stats.daysElapsed, 6);
      expect(stats.dailyAverage, 1.0);
    });

    test('categories rank largest first with shares that sum to one', () {
      final stats = MonthStats.forMonth(
        DateTime(2026, 9),
        transactions: [
          tx(100, DateTime(2026, 9, 1), category: 'Small'),
          tx(300, DateTime(2026, 9, 1), category: 'Big'),
          tx(150, DateTime(2026, 9, 2), category: 'Small'),
          tx(
            1000,
            DateTime(2026, 9, 3),
            type: TransactionType.income,
            category: 'Salary',
          ),
        ],
        now: DateTime(2026, 9, 6),
      );
      expect(stats.categories.map((c) => c.category), ['Big', 'Small']);
      expect(stats.categories.map((c) => c.cents), [300, 250]);
      expect(
        stats.categories.fold<double>(0, (s, c) => s + c.fractionOfSpend),
        closeTo(1, 1e-9),
      );
      expect(stats.incomeCategories.single.category, 'Salary');
      expect(stats.incomeCategories.single.fractionOfSpend, 1.0);
      expect(stats.netCents, 450);
    });

    test('a row with no date counts nowhere', () {
      final undated = Transaction.fromRow(const {
        'amount_cents': 999,
        'type': 'expense',
      });
      final stats = MonthStats.forMonth(
        DateTime(2026, 9),
        transactions: [undated],
        now: DateTime(2026, 9, 6),
      );
      expect(stats.spentCents, 0);
    });
  });
}
