import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:scandy/services/api_client.dart';
import 'package:scandy/state/app_state.dart';
import 'package:scandy/theme/app_theme.dart';
import 'package:scandy/ui/home/home_screen.dart';
import 'package:scandy/ui/home/safe_to_spend_card.dart';
import 'package:scandy/ui/shell/bottom_nav.dart';

/// Canned responses reproducing the exact figures printed in the handoff, so
/// the rendered screen can be compared against the mockup directly.
///
/// The five rows below are the ones the design shows. `_filler` makes the
/// month's spending add up to the design's RM 2,914.40 without appearing in
/// the "Recent" card — the API returns newest-first and the card takes the
/// first five, so it sits last.
String _transactionsJson() {
  Map<String, dynamic> tx({
    required String desc,
    required int cents,
    required String category,
    required String date,
    required String time,
    required String type,
  }) =>
      {
        'id': '$date-$time-$desc',
        'date': date,
        'time': time,
        'description': desc,
        'amount': 'RM ${(cents / 100).toStringAsFixed(2)}',
        'amount_cents': cents,
        'category': category,
        'account_id': 'acc-1',
        'type': type,
        'transfer_related_id': null,
      };

  return jsonEncode([
    tx(desc: 'Jaya Grocer', cents: 8640, category: 'Groceries', date: '06/09/2026', time: '14:22:00', type: 'expense'),
    tx(desc: 'Grab ride', cents: 1420, category: 'Transport', date: '06/09/2026', time: '09:05:00', type: 'expense'),
    tx(desc: 'Salary — September', cents: 485000, category: 'Salary', date: '05/09/2026', time: '08:00:00', type: 'income'),
    tx(desc: 'Spotify Family', cents: 2690, category: 'Subscriptions', date: '04/09/2026', time: '00:12:00', type: 'expense'),
    tx(desc: 'Kopi Kenangan', cents: 1150, category: 'Food & Drink', date: '03/09/2026', time: '16:40:00', type: 'expense'),
    // 86.40 + 14.20 + 26.90 + 11.50 = 139.00; + 2775.40 = 2914.40.
    tx(desc: 'Earlier spending', cents: 277540, category: 'Shopping', date: '02/09/2026', time: '10:00:00', type: 'expense'),
  ]);
}

/// Flask's `jsonify` sends UTF-8. `package:http` falls back to latin1 when a
/// response carries no charset, which would mangle the em-dash in
/// "Salary — September" before the client ever sees it — so the fixture states
/// the charset explicitly, exactly as the real backend does.
http.Response _json(String body) => http.Response(
      body,
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Client _mockClient() => MockClient((request) async {
      final path = request.url.path;
      return switch (path) {
        '/api/transactions' => _json(_transactionsJson()),
        '/api/accounts' => _json(jsonEncode([
            {'id': 'acc-1', 'name': 'Maybank', 'type': 'Bank', 'initial_balance': 8412.55, 'balance': 8412.55},
          ])),
        '/api/subscriptions' => _json(jsonEncode([
            {
              'id': 'sub-1',
              'name': 'Recurring due',
              'amount': 268.90,
              'category': 'Subscriptions',
              'day_of_month': 20,
              'account_id': 'acc-1',
              'last_recorded_date': '2026-08-20',
            },
          ])),
        '/api/categories' => _json(jsonEncode(
            {'expense': ['Groceries'], 'income': ['Salary'], 'transfer': ['Transfer']})),
        _ => _json('[]'),
      };
    });

/// Pinned to the date the design's frames carry (6 September 2026, 21:04), so
/// the greeting, the date line and "24 days left" never drift.
final _fixedNow = DateTime(2026, 9, 6, 21, 4);

Widget _app(Brightness brightness, AppState state) {
  return ChangeNotifierProvider.value(
    value: state,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildScandyTheme(brightness),
      home: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              Expanded(child: HomeScreen(clock: _fixedNow)),
              ScandyBottomNav(
                current: NavTab.home,
                onSelect: (_) {},
                onAdd: () {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Home renders — ${brightness.name}', (tester) async {
      // The design's mobile frame is 392 x 844.
      tester.view.physicalSize = const Size(392 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final api = ApiClient(client: _mockClient());
      final state = AppState(api);
      await state.loadAll();
      expect(state.status, LoadStatus.ready, reason: state.error);

      await tester.pumpWidget(_app(brightness, state));
      await tester.pumpAndSettle();

      // The figures the design prints, proving the screen is wired to the
      // same arithmetic and not just laid out to look right. These hold for
      // any run date because the clock is pinned above.
      expect(find.text('RM 1,666.70'), findsOneWidget);
      expect(find.text('24 days left'), findsOneWidget);
      expect(find.text('Jaya Grocer'), findsOneWidget);
      expect(find.text('−86.40'), findsOneWidget);
      expect(find.text('+4,850.00'), findsOneWidget);
      // The filler row must not reach the five-row Recent card.
      expect(find.text('Earlier spending'), findsNothing);

      // Regression, twice over. The bar collapsed to zero width because its
      // SizedBox declared no width under the Column's loose constraints; then
      // its *segments* collapsed to zero height because a childless ColoredBox
      // takes the smallest height a centred Row will give it. Both times the
      // card looked fine except for a missing progress track, so the segment
      // is measured here, not just the box around it.
      final bar = tester.getSize(find.byKey(SafeToSpendCard.barKey));
      expect(bar.height, 9);
      expect(bar.width, greaterThan(300));

      final spentSegment =
          tester.getSize(find.byKey(SafeToSpendCard.barSpentSegmentKey));
      expect(spentSegment.height, 9, reason: 'segment must fill the track');
      // ~60% of the bar, per the design.
      expect(spentSegment.width, closeTo(bar.width * 0.60, 4));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_${brightness.name}.png'),
      );
    });
  }
}
