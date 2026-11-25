import 'package:alias_game/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rare words are optional and toggling invalidates the old deck', () {
    final s = AppState();
    s.words['science'] = ['атом', 'квазар'];
    s.advancedWords['science'] = {'квазар'};
    s.settings.categories = {'science'};
    expect(s.countFor({'science'}), 1);
    s.newGame();
    expect(s.draw().text, 'атом');
    s.setIncludeAdvanced(true);
    expect(s.countFor({'science'}), 2);
    expect(s.draw().text, 'квазар');
    s.setIncludeAdvanced(false);
    expect(s.draw().text, 'атом');
  });

  test('category rounds are balanced despite different dictionary sizes', () {
    final s = AppState();
    s.words['animals'] = List.generate(12, (i) => 'животное$i');
    s.words['food'] = List.generate(3, (i) => 'еда$i');
    s.settings.categories = {'animals', 'food'};
    s.newGame();
    final first = List.generate(6, (_) => s.draw());
    for (var i = 0; i < 6; i += 2) {
      expect({first[i].cat, first[i + 1].cat}, {'animals', 'food'});
    }
    expect(first.map((w) => w.text).toSet().length, 6);
    expect(s.draw().cat, 'animals');
  });

  test('difficulty cannot be changed in a saved unfinished turn', () {
    final s = AppState();
    s.words['kids'] = ['мяч'];
    s.settings.categories = {'kids'};
    s.newGame();
    s.checkpoint(TurnProgress(Turn(), s.draw(), 3000, 'play'));
    s.setIncludeAdvanced(true);
    expect(s.settings.includeAdvanced, false);
  });

  test(
    'difficulty is contextual: echo is easy for kids, mythology may be hard',
    () {
      final s = AppState();
      s.words['kids'] = ['эхо'];
      s.words['fantasy'] = ['Эхо'];
      s.advancedWords['fantasy'] = {'эхо'};
      expect(s.countFor({'kids'}), 1);
      expect(s.countFor({'fantasy'}), 0);
      expect(s.countFor({'kids', 'fantasy'}), 1);
    },
  );

  test(
    'difficulty assets load, counts match cards, preference survives reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.init();
      expect(s.settings.includeAdvanced, false);
      expect(s.totalWords, greaterThan(8000));
      expect(s.advancedWords['kids'], isEmpty);
      s.settings.categories = {'science'};
      s.newGame();
      final expected = s.countFor({'science'});
      final cards = List.generate(expected, (_) => s.draw());
      expect(cards.map((w) => wordKey(w.text)).toSet().length, expected);
      expect(
        cards.any((w) => s.advancedWords['science']!.contains(wordKey(w.text))),
        false,
      );
      s.setIncludeAdvanced(true);
      await s.flush();
      final restored = AppState();
      await restored.init();
      expect(restored.settings.includeAdvanced, true);
      expect(restored.totalWords, greaterThan(s.words['science']!.length));
      expect(restored.game, isNotNull);
    },
  );
}
