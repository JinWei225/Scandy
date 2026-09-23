import 'package:flutter_test/flutter_test.dart';
import 'package:scandy/models/subscription.dart';
import 'package:scandy/models/summary_stats.dart';

Subscription _sub(String id, String name, int day, {DateTime? recorded}) =>
    Subscription(
      id: id,
      name: name,
      amount: 10,
      category: 'Other',
      dayOfMonth: day,
      accountId: null,
      lastRecordedDate: recorded,
    );

void main() {
  final now = DateTime(2026, 9, 6);

  test('charges on the same day sort by name, whatever order they arrive in',
      () {
    final subs = [
      _sub('3', 'spotify', 15),
      _sub('1', 'Netflix', 15),
      _sub('2', 'Apple One', 15),
      _sub('4', 'Gym', 1),
    ];
    for (final input in [subs, subs.reversed.toList()]) {
      final names =
          RecurringStats.from(input, now: now).stillToCome.map((s) => s.name);
      expect(names, ['Gym', 'Apple One', 'Netflix', 'spotify']);
    }
  });

  test('already-charged ties sort by name too', () {
    final recorded = DateTime(2026, 9, 1);
    final subs = [
      _sub('2', 'b', 1, recorded: recorded),
      _sub('1', 'A', 1, recorded: recorded),
    ];
    final names = RecurringStats.from(subs, now: now)
        .alreadyCharged
        .map((s) => s.name);
    expect(names, ['A', 'b']);
  });
}
