// Proves the app actually speaks Chinese, and that switching languages changes
// what is on the screen rather than only what is in the .arb files.
//
// Deliberately not a golden: `flutter test` registers no CJK face, so every
// Chinese character would rasterise as a placeholder box. What matters here is
// the text, which the widget tree carries whether or not there is a glyph for
// it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scandy/l10n/l10n.dart';
import 'package:scandy/models/account.dart';
import 'package:scandy/models/subscription.dart';
import 'package:scandy/models/transaction.dart';
import 'package:scandy/services/scandy_repository.dart';
import 'package:scandy/state/app_state.dart';
import 'package:scandy/state/locale_controller.dart';
import 'package:scandy/theme/app_theme.dart';
import 'package:scandy/ui/home/home_screen.dart';

class _FakeRepository implements ScandyRepository {
  @override
  Future<List<Transaction>> fetchTransactions() async => [
        Transaction(
          id: 'tx-1',
          date: DateTime(2026, 9, 6),
          time: '14:22:00',
          description: 'Jaya Grocer',
          amountCents: -8640,
          category: 'Groceries',
          accountId: 'acc-1',
          type: TransactionType.expense,
        ),
        Transaction(
          id: 'tx-2',
          date: DateTime(2026, 9, 5),
          time: '08:00:00',
          description: 'Salary',
          amountCents: 485000,
          category: 'Salary',
          accountId: 'acc-1',
          type: TransactionType.income,
        ),
      ];

  @override
  Future<List<Account>> fetchAccounts() async => const [
        Account(
          id: 'acc-1',
          name: 'Maybank',
          type: 'Bank',
          initialBalance: 8412.55,
          balance: 8412.55,
        ),
      ];

  @override
  Future<List<Subscription>> fetchSubscriptions() async => const [];

  @override
  Future<Map<String, List<String>>> fetchCategories() async => const {
        'expense': ['Groceries'],
        'income': ['Salary'],
        'transfer': ['Transfer'],
      };

  @override
  Future<void> checkSubscriptions() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('read-only fixture: ${invocation.memberName}');
}

/// 6 September 2026, 21:04 — a Sunday evening, so the greeting and the weekday
/// are both pinned.
final _fixedNow = DateTime(2026, 9, 6, 21, 4);

Widget _app(Locale locale, AppState state) => ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildScandyTheme(Brightness.light),
        locale: locale,
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: LocaleController.supported,
        home: Scaffold(body: HomeScreen(clock: _fixedNow)),
      ),
    );

Future<AppState> _loaded() async {
  final state = AppState(_FakeRepository());
  await state.loadAll();
  expect(state.status, LoadStatus.ready, reason: state.error);
  return state;
}

void main() {
  testWidgets('Home is in Chinese under zh', (tester) async {
    tester.view.physicalSize = const Size(392 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const Locale('zh'), await _loaded()));
    await tester.pumpAndSettle();

    expect(find.text('晚上好'), findsOneWidget);
    expect(find.text('最近'), findsOneWidget);

    // Chinese runs largest unit to smallest and marks each one, where English
    // writes "Sunday, 6 September". Getting this wrong is the bug that leaves
    // a translated app still reading as English halfway down the screen.
    expect(find.text('9月6日 星期日'), findsOneWidget);

    // The eyebrow, uppercased by the caller -- a no-op here, which is the
    // point: '可支配余额 · 9月' must survive toUpperCase() unchanged.
    expect(find.text('可支配余额 · 9月'), findsOneWidget);

    // Plural forms: Chinese has one, and the ICU message must not leave the
    // English "days" in.
    expect(find.text('还剩 24 天'), findsOneWidget);

    // Money does not translate. Grouping and decimals are how a Malaysian bank
    // statement writes them, in either language.
    expect(find.text('+4,850.00'), findsOneWidget);
  });

  testWidgets('the same screen is in English under en', (tester) async {
    tester.view.physicalSize = const Size(392 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const Locale('en'), await _loaded()));
    await tester.pumpAndSettle();

    expect(find.text('Good evening'), findsOneWidget);
    expect(find.text('Sunday, 6 September'), findsOneWidget);
    expect(find.text('SAFE TO SPEND · SEP'), findsOneWidget);
    expect(find.text('24 days left'), findsOneWidget);
    expect(find.text('+4,850.00'), findsOneWidget);
  });

  test('every English string has a Chinese one', () async {
    // The two .arb files are generated from one table, so a missing
    // translation is a generator bug rather than a typo -- but the generated
    // Dart is what the app actually reads, and this checks that.
    final en = await L.delegate.load(const Locale('en'));
    final cn = await L.delegate.load(const Locale('zh'));

    // A handful of representative getters across the app, rather than
    // reflection, which Dart does not offer here.
    expect(cn.signIn, isNot(en.signIn));
    expect(cn.addATransaction, isNot(en.addATransaction));
    expect(cn.deleteAccountBody, isNot(en.deleteAccountBody));
    expect(cn.datePatternFull, isNot(en.datePatternFull));
    expect(cn.nTransactions(3), isNot(en.nTransactions(3)));
  });
}
