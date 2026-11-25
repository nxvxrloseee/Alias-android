import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'categories.dart';
import 'sfx.dart';

const defaultTeamNames = [
  'Лисы',
  'Совы',
  'Еноты',
  'Бобры',
  'Ежи',
  'Кроты',
  'Барсуки',
  'Выдры',
  'Рыси',
  'Сурки',
];
String wordKey(String text) => text.trim().toLowerCase().replaceAll('ё', 'е');

class Team {
  String name;
  int color;
  Team(this.name, this.color);

  Map<String, dynamic> toJson() => {'name': name, 'color': color};
  factory Team.fromJson(Map<String, dynamic> j) =>
      Team(j['name'] as String, j['color'] as int);
}

class Settings {
  List<Team> teams = [Team('Лисы', 0), Team('Совы', 1)];
  int seconds = 60;
  int target = 50; // 0 — без лимита, игра до ручного завершения
  Set<String> categories = {...categoryIds};
  bool penalty = true;
  bool sharedLast = true;
  bool sound = true;
  bool includeAdvanced = false;

  Map<String, dynamic> toJson() => {
    'teams': teams.map((t) => t.toJson()).toList(),
    'seconds': seconds,
    'target': target,
    'categories': categories.toList(),
    'penalty': penalty,
    'sharedLast': sharedLast,
    'sound': sound,
    'includeAdvanced': includeAdvanced,
  };

  void loadJson(Map<String, dynamic> j) {
    final t = (j['teams'] as List?)
        ?.map((e) => Team.fromJson(e as Map<String, dynamic>))
        .toList();
    if (t != null && t.length >= 2) teams = t;
    seconds = max(10, j['seconds'] as int? ?? seconds);
    target = max(0, j['target'] as int? ?? target);
    final cats = (j['categories'] as List?)
        ?.cast<String>()
        .where((id) => categoryIds.contains(id))
        .toSet();
    if (cats != null && cats.isNotEmpty) categories = cats;
    penalty = j['penalty'] as bool? ?? penalty;
    sharedLast = j['sharedLast'] as bool? ?? sharedLast;
    sound = j['sound'] as bool? ?? sound;
    includeAdvanced = j['includeAdvanced'] as bool? ?? false;
  }
}

final categoryIds = {for (final c in categories) c.id};

class WordCard {
  final String text;
  final String cat;
  const WordCard(this.text, this.cat);
  Map<String, dynamic> toJson() => {'text': text, 'cat': cat};
  factory WordCard.fromJson(Map<String, dynamic> j) =>
      WordCard(j['text'] as String, j['cat'] as String);
}

class TurnWord {
  final WordCard card;
  bool ok;
  TurnWord(this.card, this.ok);
}

class Turn {
  final words = <TurnWord>[];
  WordCard? last;
  int lastTeam = -1; // -1 — никто не угадал последнее слово
  Map<String, dynamic> toJson() => {
    'words': words.map((w) => {'card': w.card.toJson(), 'ok': w.ok}).toList(),
    'last': last?.toJson(),
    'lastTeam': lastTeam,
  };
  factory Turn.fromJson(Map<String, dynamic> j) => Turn()
    ..words.addAll(
      (j['words'] as List).map(
        (w) => TurnWord(
          WordCard.fromJson(w['card'] as Map<String, dynamic>),
          w['ok'] as bool,
        ),
      ),
    )
    ..last = j['last'] == null
        ? null
        : WordCard.fromJson(j['last'] as Map<String, dynamic>)
    ..lastTeam = j['lastTeam'] as int;
  Turn();
}

/// Снимок хода: после перезапуска игра всегда открывается на паузе.
class TurnProgress {
  final Turn turn;
  final WordCard? current;
  final int remainingMs;
  final String phase; // play, last, review
  TurnProgress(this.turn, this.current, this.remainingMs, this.phase);
  Map<String, dynamic> toJson() => {
    'turn': turn.toJson(),
    'current': current?.toJson(),
    'remainingMs': remainingMs,
    'phase': phase,
  };
  factory TurnProgress.fromJson(Map<String, dynamic> j) => TurnProgress(
    Turn.fromJson(j['turn'] as Map<String, dynamic>),
    j['current'] == null
        ? null
        : WordCard.fromJson(j['current'] as Map<String, dynamic>),
    j['remainingMs'] as int,
    j['phase'] as String,
  );
}

class Game {
  List<int> scores;
  int turn = 0;
  int round = 1;
  List<String> used = [];
  TurnProgress? pending;
  bool finished = false;

  Game(this.scores);

  Map<String, dynamic> toJson() => {
    'scores': scores,
    'turn': turn,
    'round': round,
    'used': used,
    'pending': pending?.toJson(),
    'finished': finished,
  };
  factory Game.fromJson(Map<String, dynamic> j) =>
      Game((j['scores'] as List).cast<int>())
        ..turn = j['turn'] as int
        ..round = j['round'] as int
        ..used = (j['used'] as List).cast<String>().map(wordKey).toList()
        ..pending = j['pending'] == null
            ? null
            : TurnProgress.fromJson(j['pending'] as Map<String, dynamic>)
        ..finished = j['finished'] as bool? ?? false;
}

class AppState extends ChangeNotifier {
  static const _key = 'alias-state-v1';
  final settings = Settings();
  Game? game;
  final Map<String, List<String>> words = {};
  final Map<String, Set<String>> advancedWords = {};

  Iterable<String> availableWords(String cat) =>
      (words[cat] ?? const <String>[]).where(
        (w) =>
            settings.includeAdvanced ||
            !(advancedWords[cat]?.contains(wordKey(w)) ?? false),
      );

  void setIncludeAdvanced(bool value) {
    if (game?.pending != null) return;
    settings.includeAdvanced = value;
    _deck.clear();
    save();
  }

  final _rng = Random();
  List<WordCard> _deck = [];
  SharedPreferences? _prefs;

  int countFor(Iterable<String> ids) => {
    for (final id in ids)
      for (final w in availableWords(id)) wordKey(w),
  }.length;
  bool get canPlay =>
      settings.teams.length >= 2 && countFor(settings.categories) > 0;
  Future<void> _saveQueue = Future.value();
  Future<void> flush() => _saveQueue;
  int get totalWords => countFor(categoryIds);

  Future<void> init() async {
    await Future.wait(
      categories.map((c) async {
        try {
          final raw = await rootBundle.loadString('assets/words/${c.id}.txt');
          words[c.id] = _parse(raw);
        } catch (_) {
          words[c.id] = [];
        }
      }),
    );
    final levels = jsonDecode(
      await rootBundle.loadString('assets/words/advanced.json'),
    ) as Map<String, dynamic>;
    advancedWords.addAll(
      levels.map(
        (cat, values) =>
            MapEntry(cat, (values as List).cast<String>().map(wordKey).toSet()),
      ),
    );
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_key);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        settings.loadJson(j['settings'] as Map<String, dynamic>);
        if (j['game'] != null) {
          final g = Game.fromJson(j['game'] as Map<String, dynamic>);
          if (g.scores.length == settings.teams.length &&
              g.turn >= 0 &&
              g.turn < g.scores.length &&
              g.round > 0) {
            game = g;
            // Older saves used the complete dictionary. Preserve an ongoing game.
            if (!(j['settings'] as Map).containsKey('includeAdvanced')) {
              settings.includeAdvanced = true;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('state load failed: $e');
    }
    Sfx.enabled = settings.sound;
  }

  static List<String> _parse(String raw) {
    final seen = <String>{};
    final out = <String>[];
    for (var line in const LineSplitter().convert(raw)) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (seen.add(wordKey(line))) out.add(line);
    }
    return out;
  }

  void save({bool notify = true}) {
    if (notify) notifyListeners();
    final data = jsonEncode({
      'settings': settings.toJson(),
      'game': game?.toJson(),
    });
    _saveQueue = _saveQueue
        .then((_) async {
          await _prefs?.setString(_key, data);
        })
        .catchError((Object e) {
          debugPrint('state save failed: $e');
        });
  }

  void checkpoint(TurnProgress progress) {
    game!.pending = progress;
    save(notify: false);
  }

  void abandonTurn() {
    game!.pending = null;
    save();
  }

  String teamName(int i) {
    final n = settings.teams[i].name.trim();
    return n.isEmpty ? defaultTeamNames[i % defaultTeamNames.length] : n;
  }

  // ---------- Команды ----------
  void addTeam() {
    if (game != null) return;
    final usedColors = settings.teams.map((t) => t.color).toSet();
    final color = List.generate(10, (i) => i).firstWhere(
      (c) => !usedColors.contains(c),
      orElse: () => settings.teams.length % 10,
    );
    final name = defaultTeamNames.firstWhere(
      (n) => !settings.teams.any((t) => t.name == n),
      orElse: () => 'Команда ${settings.teams.length + 1}',
    );
    settings.teams.add(Team(name, color));
    save();
  }

  void removeTeam(int i) {
    if (game != null || settings.teams.length <= 2) return;
    settings.teams.removeAt(i);
    save();
  }

  // ---------- Колода ----------
  void _buildDeck() {
    final g = game!;
    final used = g.used.toSet();
    final seen = <String>{};
    var deck = <WordCard>[];
    final selected = settings.categories.toList()..shuffle(_rng);
    for (final cat in selected) {
      for (final w in availableWords(cat)) {
        final key = wordKey(w);
        if (seen.add(key) && !used.contains(key)) deck.add(WordCard(w, cat));
      }
    }
    if (deck.isEmpty && used.isNotEmpty) {
      // все слова выбранных категорий сыграны — начинаем их заново
      g.used.removeWhere((k) => seen.contains(k));
      deck = [
        for (final cat in selected)
          for (final w in availableWords(cat)) WordCard(w, cat),
      ];
      final s2 = <String>{};
      deck.retainWhere((c) => s2.add(wordKey(c.text)));
    }
    // One card from each available category per shuffled round: large
    // dictionaries do not drown out smaller selected themes.
    final buckets = <String, List<WordCard>>{};
    for (final card in deck) {
      (buckets[card.cat] ??= []).add(card);
    }
    for (final bucket in buckets.values) {
      bucket.shuffle(_rng);
    }
    final balanced = <WordCard>[];
    while (buckets.isNotEmpty) {
      final order = buckets.keys.toList()..shuffle(_rng);
      for (final cat in order) {
        final bucket = buckets[cat]!;
        balanced.add(bucket.removeLast());
        if (bucket.isEmpty) buckets.remove(cat);
      }
    }
    _deck = balanced.reversed.toList();
  }

  /// Вызывается при старте хода: колода собирается из текущих категорий.
  void prepareDeck() {
    if (!canPlay) throw StateError('Выберите категорию с доступными словами');
    _buildDeck();
  }

  WordCard draw() {
    if (!canPlay) throw StateError('Выберите категорию с доступными словами');
    if (_deck.isEmpty) _buildDeck();
    if (_deck.isEmpty) {
      throw StateError('Выберите категорию с доступными словами');
    }
    final c = _deck.removeLast();
    game!.used.add(wordKey(c.text));
    return c;
  }

  void putBack(WordCard c) {
    game!.used.remove(wordKey(c.text));
    _deck.insert(_rng.nextInt(_deck.length + 1), c);
  }

  // ---------- Партия ----------
  void newGame() {
    if (!canPlay) throw StateError('Выберите категорию с доступными словами');
    final keepUsed = game?.used ?? <String>[];
    game = Game(List.filled(settings.teams.length, 0, growable: true))
      ..used = keepUsed;
    _buildDeck();
    save();
  }

  void endGame() {
    game = null;
    save();
  }

  int turnPoints(Turn t) {
    final g = game!;
    var p = 0;
    for (final w in t.words) {
      p += w.ok ? 1 : (settings.penalty ? -1 : 0);
    }
    if (t.last != null && t.lastTeam == g.turn) p += 1;
    return p;
  }

  /// Записывает итоги хода. Возвращает true, если партия завершилась победой.
  bool commit(Turn t) {
    final g = game!;
    g.scores[g.turn] += turnPoints(t);
    if (t.last != null && t.lastTeam >= 0 && t.lastTeam != g.turn) {
      g.scores[t.lastTeam] += 1;
    }
    g.pending = null;
    g.turn++;
    var won = false;
    if (g.turn >= settings.teams.length) {
      g.turn = 0;
      final top = g.scores.reduce(max);
      final leaders = g.scores.where((s) => s == top).length;
      if (settings.target > 0 && top >= settings.target && leaders == 1) {
        won = true;
      } else {
        g.round++;
      }
    }
    g.finished = won;
    save();
    return won;
  }

  List<int> get leaders {
    final scores = game!.scores;
    final top = scores.reduce(max);
    return [
      for (var i = 0; i < scores.length; i++)
        if (scores[i] == top) i,
    ];
  }

  int get leader {
    final g = game!;
    final top = g.scores.reduce(max);
    return g.scores.indexOf(top);
  }
}

late final AppState app;
