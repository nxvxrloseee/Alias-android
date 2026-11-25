import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Короткие звуки игры. Любая ошибка аудио молча игнорируется — игра важнее звука.
class Sfx {
  static bool enabled = true;
  static final _players = <String, AudioPlayer>{};

  static Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .build(),
      );
      for (final name in ['ok', 'skip', 'tick', 'end', 'win', 'start']) {
        final p = AudioPlayer();
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(AssetSource('sounds/$name.wav'));
        _players[name] = p;
      }
    } catch (_) {}
  }

  static Future<void> _play(String name) async {
    if (!enabled) return;
    final p = _players[name];
    if (p == null) return;
    try {
      await p.stop();
      await p.resume();
    } catch (_) {}
  }

  static void ok() {
    _play('ok');
    HapticFeedback.lightImpact();
  }

  static void skip() {
    _play('skip');
    HapticFeedback.mediumImpact();
  }

  static void tick() => _play('tick');

  static void start() {
    _play('start');
    HapticFeedback.mediumImpact();
  }

  static void end() {
    _play('end');
    HapticFeedback.heavyImpact();
    Future.delayed(
      const Duration(milliseconds: 180),
      HapticFeedback.heavyImpact,
    );
  }

  static void win() {
    _play('win');
    HapticFeedback.heavyImpact();
  }
}
