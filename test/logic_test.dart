import 'package:alias_game/state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('очки хода, штраф и общее последнее слово', () {
    final s = AppState();
    s.words['kids'] = ['мяч', 'кот', 'дом'];
    s.settings.categories = {'kids'};
    s.newGame();
    final t = Turn()
      ..words.addAll([
        TurnWord(const WordCard('мяч', 'kids'), true),
        TurnWord(const WordCard('кот', 'kids'), false),
      ])
      ..last = const WordCard('дом', 'kids')
      ..lastTeam = 1;
    expect(s.turnPoints(t), 0); // +1 −1, последнее слово угадала чужая команда
    expect(s.commit(t), false);
    expect(s.game!.scores, [0, 1]);
    expect(s.game!.turn, 1);
  });

  test('победа только после полного круга и без ничьей', () {
    final s = AppState();
    s.words['kids'] = List.generate(50, (i) => 'слово$i');
    s.settings.categories = {'kids'};
    s.settings.target = 2;
    s.newGame();
    Turn won(int n) => Turn()
      ..words.addAll(
        List.generate(n, (i) => TurnWord(WordCard('w$i', 'kids'), true)),
      );
    expect(
      s.commit(won(3)),
      false,
    ); // первая команда набрала, но круг не закончен
    expect(s.commit(won(3)), false); // ничья 3:3 — играем дальше
    expect(s.game!.round, 2);
    expect(s.commit(won(1)), false);
    expect(s.commit(won(0)), true); // 4:3
    expect(s.leader, 0);
  });

  test('колода не повторяет слова и перезапускается, когда кончились', () {
    final s = AppState();
    s.words['kids'] = ['а1', 'б2', 'в3'];
    s.settings.categories = {'kids'};
    s.newGame();
    final got = {for (var i = 0; i < 3; i++) s.draw().text};
    expect(got.length, 3);
    expect(['а1', 'б2', 'в3'], contains(s.draw().text));
  });
}
