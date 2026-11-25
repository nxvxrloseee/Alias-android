import 'package:alias_game/state.dart';
import 'package:alias_game/screens/play.dart';
import 'package:alias_game/screens/review.dart';
import 'package:alias_game/screens/categories_screen.dart';
import 'package:alias_game/screens/win.dart';
import 'package:alias_game/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestWatch extends Stopwatch {
  int ms = 0;
  @override
  int get elapsedMilliseconds => ms;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  app = AppState();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    app.game = null;
    app.settings.teams = [Team('Лисы', 0), Team('Совы', 1)];
    app.settings.categories = {'kids'};
    app.settings.seconds = 10;
    app.settings.sharedLast = true;
    app.settings.penalty = true;
    app.words.clear();
    app.words['kids'] = ['ёж', 'дом', 'мяч'];
  });

  Widget wrap(Widget screen) => MaterialApp(theme: buildTheme(), home: screen);

  Future<void> openPlay(WidgetTester t, TestWatch watch) async {
    app.newGame();
    await t.pumpWidget(
      wrap(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PlayScreen(stopwatch: watch)),
              ),
              child: const Text('Старт'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Старт'));
    await t.pumpAndSettle();
  }

  test('empty selection cannot start a game or produce a scoring card', () {
    app.settings.categories = {};
    expect(app.newGame, throwsStateError);
    app.game = Game([0, 0]);
    expect(app.draw, throwsStateError);
  });

  test('empty selection cannot draw a stale card from a previous deck', () {
    app.newGame();
    app.settings.categories = {};
    expect(app.draw, throwsStateError);
  });

  test('unique counts match deck, including е/ё and case', () {
    app.words['animals'] = ['ЕЖ', 'ёж', 'кот'];
    app.settings.categories = {'kids', 'animals'};
    expect(app.countFor(app.settings.categories), 4);
    app.newGame();
    expect({for (var i = 0; i < 4; i++) wordKey(app.draw().text)}.length, 4);
  });

  test('roster is locked while a game exists, unlocked after discarding', () {
    app.newGame();
    app.addTeam();
    app.removeTeam(0);
    expect(app.settings.teams.length, 2);
    app.endGame();
    for (var i = 0; i < 12; i++) {
      app.addTeam();
    }
    expect(app.settings.teams.length, 14);
  });

  test('pending turn and edited review survive storage reload', () async {
    final s = AppState();
    await s.init();
    s.settings.categories = {'kids'};
    s.newGame();
    final turn = Turn()
      ..words.add(TurnWord(const WordCard('ёж', 'kids'), false));
    s.checkpoint(
      TurnProgress(turn, const WordCard('дом', 'kids'), 4321, 'play'),
    );
    await s.flush();
    final restored = AppState();
    await restored.init();
    expect(restored.game!.pending!.remainingMs, 4321);
    expect(restored.game!.pending!.current!.text, 'дом');
    final edited = restored.game!.pending!.turn;
    edited.words.first.ok = true;
    edited.last = const WordCard('мяч', 'kids');
    edited.lastTeam = 1;
    restored.checkpoint(TurnProgress(edited, null, 0, 'review'));
    await restored.flush();
    final again = AppState();
    await again.init();
    expect(again.game!.pending!.phase, 'review');
    expect(again.game!.pending!.turn.words.first.ok, true);
    expect(again.game!.pending!.turn.lastTeam, 1);
    again.commit(again.game!.pending!.turn);
    await again.flush();
    final committed = AppState();
    await committed.init();
    expect(committed.game!.pending, isNull);
    expect(committed.game!.scores, [1, 1]);
    expect(committed.game!.turn, 1);
  });

  testWidgets('last selected category cannot be removed, including via back', (
    t,
  ) async {
    await t.pumpWidget(wrap(const CategoriesScreen()));
    await t.tap(find.text('Для детей'));
    await t.pump();
    expect(app.settings.categories, {'kids'});
    await t.binding.handlePopRoute();
    expect(app.settings.categories, isNotEmpty);
  });

  testWidgets('timer expiring during flyout does not deal another last word', (
    t,
  ) async {
    final watch = TestWatch();
    await openPlay(t, watch);
    watch.ms = 9990;
    await t.tap(find.text('Угадано'));
    watch.ms = 10000;
    await t.pump(const Duration(milliseconds: 60));
    await t.pumpAndSettle();
    expect(find.byType(ReviewScreen), findsOneWidget);
    expect(app.game!.pending!.turn.words.length, 1);
    expect(app.game!.pending!.turn.last, isNull);
    expect(app.game!.used.length, 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('time up on an unresolved card preserves the actual last word', (
    t,
  ) async {
    final watch = TestWatch();
    await openPlay(t, watch);
    final current = app.game!.pending!.current!.text;
    watch.ms = 10000;
    await t.pump(const Duration(milliseconds: 60));
    expect(app.game!.pending!.phase, 'last');
    expect(app.game!.pending!.current!.text, current);
    await t.pump(const Duration(milliseconds: 250));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('restored turn starts paused with the same card and time', (
    t,
  ) async {
    app.newGame();
    app.checkpoint(
      TurnProgress(Turn(), const WordCard('дом', 'kids'), 4321, 'play'),
    );
    await t.pumpWidget(wrap(const PlayScreen()));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Пауза'), findsOneWidget);
    expect(app.game!.pending!.remainingMs, 4321);
    expect(app.game!.pending!.current!.text, 'дом');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('expired saved card still becomes the last word on restore', (
    t,
  ) async {
    app.newGame();
    app.checkpoint(
      TurnProgress(Turn(), const WordCard('дом', 'kids'), 0, 'play'),
    );
    await t.pumpWidget(wrap(const PlayScreen()));
    await t.pump(const Duration(milliseconds: 300));
    expect(app.game!.pending!.phase, 'last');
    expect(app.game!.pending!.current!.text, 'дом');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('last-word team chooser scrolls with more than ten teams', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (var i = 0; i < 18; i++) {
      app.addTeam();
    }
    app.newGame();
    app.checkpoint(
      TurnProgress(Turn(), const WordCard('дом', 'kids'), 0, 'last'),
    );
    await t.pumpWidget(wrap(const PlayScreen()));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('manual finish with equal scores displays a draw', (t) async {
    app.newGame();
    await t.pumpWidget(wrap(const WinScreen()));
    await t.pumpAndSettle();
    expect(find.text('НИЧЬЯ'), findsOneWidget);
    expect(find.text('ПОБЕДА'), findsNothing);
    expect(app.leaders, [0, 1]);
    await t.pumpWidget(const SizedBox());
  });
}
