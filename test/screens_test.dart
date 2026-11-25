import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:alias_game/screens/categories_screen.dart';
import 'package:alias_game/screens/home.dart';
import 'package:alias_game/screens/play.dart';
import 'package:alias_game/screens/review.dart';
import 'package:alias_game/state.dart';
import 'package:alias_game/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Рендер экранов в PNG для визуальной проверки: flutter test --update-goldens test/screens_test.dart
class FrozenWatch extends Stopwatch {
  @override
  int get elapsedMilliseconds => 0;
}

Future<void> _fonts() async {
  for (final (family, file) in [
    ('Unbounded', 'Unbounded.ttf'),
    ('Golos', 'GolosText.ttf'),
  ]) {
    final bytes = File('assets/fonts/$file').readAsBytesSync();
    await (FontLoader(
      family,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
  final icons = File(
    '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
        .load();
  }
}

Widget _wrap(Widget w) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildTheme(),
  home: w,
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _fonts();
    SharedPreferences.setMockInitialValues({});
    app = AppState();
    await app.init();
    app.settings.teams.add(Team('Еноты', 2));
    app.settings.categories = {'animals', 'food', 'movies'};
  });

  Future<void> shot(WidgetTester t, Widget w, String name) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    await t.pumpWidget(_wrap(w));
    await t.pump(const Duration(milliseconds: 800));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/$name.png'),
    );
  }

  testWidgets('home', (t) => shot(t, const HomeScreen(), 'home'));
  testWidgets(
    'categories',
    (t) => shot(t, const CategoriesScreen(), 'categories'),
  );
  testWidgets('play', (t) async {
    app.settings.categories = {'animals'};
    app.words['animals'] = ['бегемот'];
    app.newGame();
    await shot(t, PlayScreen(stopwatch: FrozenWatch()), 'play');
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
  testWidgets('review', (t) async {
    final turn = Turn()
      ..words.addAll([
        TurnWord(const WordCard('бегемот', 'animals'), true),
        TurnWord(
          const WordCard('Иван Васильевич меняет профессию', 'movies'),
          true,
        ),
        TurnWord(const WordCard('шаурма', 'food'), false),
      ])
      ..last = const WordCard('кенгуру', 'animals')
      ..lastTeam = 1;
    await shot(t, ReviewScreen(turn: turn), 'review');
  });
}
