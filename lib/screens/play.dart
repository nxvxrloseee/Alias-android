import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../categories.dart';
import '../sfx.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'review.dart';

enum _Phase { play, anim, last, done }

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, this.stopwatch});
  final Stopwatch? stopwatch;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _threshold = 80.0;

  late final Turn _turn;
  late final Stopwatch _sw;
  late int _budgetMs;
  int _lastSavedSecond = -1;
  Timer? _ticker;
  late WordCard _current;
  _Phase _phase = _Phase.play;
  bool _paused = false;
  int _lastTick = -1;

  late final AnimationController _drag = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  int get _totalMs => app.settings.seconds * 1000;
  int get _leftMs => max(0, _budgetMs - _sw.elapsedMilliseconds);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final pending = app.game!.pending;
    _sw = widget.stopwatch ?? Stopwatch();
    _turn = pending?.turn ?? Turn();
    _budgetMs = pending?.remainingMs ?? _totalMs;
    app.prepareDeck();
    _current =
        pending?.current ??
        (_budgetMs > 0 ? app.draw() : const WordCard('', 'kids'));
    _phase =
        pending?.phase == 'last' ||
            (_budgetMs == 0 &&
                pending?.current != null &&
                app.settings.sharedLast)
        ? _Phase.last
        : _Phase.play;
    _paused = pending != null && _phase == _Phase.play;
    _enter.forward();
    if (!_paused && _phase == _Phase.play) _sw.start();
    _checkpoint();
    if (_budgetMs == 0 && _phase != _Phase.last) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (pending?.current != null) app.putBack(_current);
        _finish();
      });
    }
    _ticker = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _onTick(),
    );
    Sfx.start();
    WakelockPlus.enable().catchError((_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _drag.dispose();
    _enter.dispose();
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      if (!_paused && (_phase == _Phase.play || _phase == _Phase.anim)) {
        _setPaused(true);
      }
      _checkpoint();
    }
  }

  void _onTick() {
    if (!mounted || _paused || _phase == _Phase.last || _phase == _Phase.done) {
      return;
    }
    final left = _leftMs;
    final s = (left / 1000).ceil();
    if (s != _lastSavedSecond) {
      _lastSavedSecond = s;
      _checkpoint();
    }
    if (s <= 5 && s > 0 && s != _lastTick) {
      _lastTick = s;
      Sfx.tick();
    }
    if (left <= 0) {
      _timeUp();
    } else {
      setState(() {});
    }
  }

  void _setPaused(bool p) {
    if (_phase == _Phase.last || _phase == _Phase.done) return;
    setState(() {
      _paused = p;
      p ? _sw.stop() : _sw.start();
    });
    _checkpoint();
  }

  void _nextCard() {
    _current = app.draw();
    _drag.value = 0;
    _enter.forward(from: 0);
    _checkpoint();
  }

  void _resolve(bool ok) {
    if (_phase != _Phase.play || _paused) return;
    if (_leftMs == 0) {
      _timeUp();
      return;
    }
    _turn.words.add(TurnWord(_current, ok));
    ok ? Sfx.ok() : Sfx.skip();
    _flyOut(ok, () {
      if (_phase == _Phase.anim) {
        if (_leftMs == 0) {
          _timeUp();
          return;
        }
        _phase = _Phase.play;
        _nextCard();
      }
    });
  }

  void _flyOut(bool up, VoidCallback done) {
    setState(() => _phase = _Phase.anim);
    _checkpoint();
    final h = MediaQuery.sizeOf(context).height;
    _drag
        .animateTo(
          up ? -h : h,
          duration: const Duration(milliseconds: 230),
          curve: Curves.easeIn,
        )
        .then((_) {
          if (!mounted) return;
          done();
          setState(() {});
        });
  }

  void _timeUp() {
    _ticker?.cancel();
    _sw.stop();
    Sfx.end();
    if (_phase == _Phase.anim) {
      // Ответ уже засчитан, следующую карточку ещё не показывали.
      _drag.stop();
      _finish();
      return;
    }
    if (app.settings.sharedLast) {
      setState(() => _phase = _Phase.last);
      _checkpoint();
    } else {
      // слово на экране не досказали — возвращаем его в колоду
      app.putBack(_current);
      _finish();
    }
  }

  void _finishLast(int team) {
    if (_phase == _Phase.done) return;
    _turn.last = _current;
    _turn.lastTeam = team;
    if (team >= 0) Sfx.ok();
    _finish();
  }

  void _finish() {
    if (_phase == _Phase.done) return;
    _phase = _Phase.done;
    app.checkpoint(TurnProgress(_turn, null, 0, 'review'));
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ReviewScreen(turn: _turn)),
    );
  }

  Future<void> _askQuit() async {
    final wasPaused = _paused;
    if (!wasPaused) _setPaused(true);
    final ok = await confirmDialog(
      context,
      title: 'Прервать ход?',
      text: 'Очки за этот ход не запишутся, ход перейдёт заново к этой же команде.',
      yes: 'Прервать',
      no: 'Играть дальше',
      danger: true,
    );
    if (!mounted) return;
    if (ok) {
      _phase = _Phase.done;
      app.abandonTurn();
      Navigator.pop(context);
    } else if (!wasPaused) {
      _setPaused(false);
    }
  }

  void _checkpoint() {
    if (_phase == _Phase.done) return;
    // Во время вылета ответ уже записан: не сохраняем ту же карточку второй раз.
    final resolved =
        _phase == _Phase.anim &&
        _turn.words.isNotEmpty &&
        identical(_turn.words.last.card, _current);
    app.checkpoint(
      TurnProgress(
        _turn,
        resolved ? null : _current,
        _leftMs,
        _phase == _Phase.last ? 'last' : 'play',
      ),
    );
  }

  // ---------- Жесты ----------
  void _onDragUpdate(DragUpdateDetails d) {
    if (_phase != _Phase.play && _phase != _Phase.last) return;
    if (_paused) return;
    _drag.value += d.delta.dy;
  }

  void _onDragEnd(DragEndDetails d) {
    if (_phase != _Phase.play && _phase != _Phase.last) return;
    final dy = _drag.value;
    final v = d.primaryVelocity ?? 0;
    final up = dy < -_threshold || (v < -900 && dy < -20);
    final down = dy > _threshold || (v > 900 && dy > 20);
    if (_phase == _Phase.last) {
      if (up) return _finishLast(app.game!.turn);
      if (down) return _finishLast(-1);
    } else {
      if (up) return _resolve(true);
      if (down) return _resolve(false);
    }
    _drag.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = app.game!;
    final s = app.settings;
    final teamColor = C.team(s.teams[g.turn].color);
    final pts = app.turnPoints(_turn);
    final isLast = _phase == _Phase.last;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _phase != _Phase.done) _askQuit();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Pawn(teamColor),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              app.teamName(g.turn),
                              overflow: TextOverflow.ellipsis,
                              style: body(16, w: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _TimerRing(
                      leftMs: _leftMs,
                      totalMs: _totalMs,
                      last: isLast,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            pts > 0 ? '+$pts' : '$pts',
                            style: display(26).copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Text('за ход', style: body(12, color: C.chalkSoft)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(child: _buildTable(isLast)),
                const SizedBox(height: 12),
                isLast ? _buildLastBar() : _buildControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTable(bool isLast) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _paused ? () => _setPaused(false) : null,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      onVerticalDragCancel: () =>
          _drag.animateTo(0, duration: const Duration(milliseconds: 150)),
      child: AnimatedBuilder(
        animation: Listenable.merge([_drag, _enter]),
        builder: (context, _) {
          final dy = _drag.value;
          final e = Curves.easeOutCubic.transform(_enter.value);
          final up = (-dy / _threshold).clamp(0.0, 1.0);
          final down = (dy / _threshold).clamp(0.0, 1.0);
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 0,
                child: Transform.scale(
                  scale: 1 + up * .3,
                  child: Text(
                    isLast ? '↑ УГАДАЛИ МЫ' : '↑ УГАДАНО',
                    style: body(
                      13,
                      w: FontWeight.w700,
                      color: C.ok.withValues(alpha: .5 + up * .5),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: Transform.scale(
                  scale: 1 + down * .3,
                  child: Text(
                    isLast ? 'НИКТО ↓' : 'ПРОПУСК ↓',
                    style: body(
                      13,
                      w: FontWeight.w700,
                      color: C.skip.withValues(alpha: .5 + down * .5),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Transform.translate(
                  offset: Offset(0, dy + (1 - e) * 40),
                  child: Transform.rotate(
                    angle: dy / -900,
                    child: Opacity(
                      opacity: e,
                      child: _WordCardView(
                        card: _current,
                        paused: _paused,
                        last: isLast,
                        up: up,
                        down: down,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        Expanded(
          child: _CtlButton(
            text: 'Пропуск',
            color: C.skip,
            filled: false,
            onTap: () => _resolve(false),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 58,
          height: 58,
          child: IconButton(
            onPressed: () => _setPaused(!_paused),
            style: IconButton.styleFrom(
              side: const BorderSide(color: C.feltLine, width: 2),
            ),
            icon: Icon(
              _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: C.chalk,
              size: 28,
            ),
            tooltip: _paused ? 'Продолжить' : 'Пауза',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CtlButton(
            text: 'Угадано',
            color: C.ok,
            filled: true,
            onTap: () => _resolve(true),
          ),
        ),
      ],
    );
  }

  Widget _buildLastBar() {
    final s = app.settings;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Время вышло! Последнее слово — кто угадал?',
          textAlign: TextAlign.center,
          style: body(15, w: FontWeight.w600, color: C.gold),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .3,
          ),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < s.teams.length; i++)
                  _LastChip(
                    label: app.teamName(i),
                    color: C.team(s.teams[i].color),
                    onTap: () => _finishLast(i),
                  ),
                _LastChip(
                  label: 'Никто',
                  color: null,
                  onTap: () => _finishLast(-1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WordCardView extends StatelessWidget {
  final WordCard card;
  final bool paused;
  final bool last;
  final double up;
  final double down;
  const _WordCardView({
    required this.card,
    required this.paused,
    required this.last,
    required this.up,
    required this.down,
  });

  @override
  Widget build(BuildContext context) {
    final cat = categoryById(card.cat);
    final tint = up > 0 ? C.ok : (down > 0 ? C.skip : null);
    final t = max(up, down);
    return AspectRatio(
      aspectRatio: 3 / 4.3,
      child: Container(
        decoration: BoxDecoration(
          color: Color.lerp(C.card, tint ?? C.card, t * .18),
          borderRadius: BorderRadius.circular(28),
          border: last ? Border.all(color: C.gold, width: 4) : null,
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), offset: Offset(0, 2)),
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 30,
              offset: Offset(0, 14),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cat.icon, size: 16, color: C.inkSoft),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      cat.title.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: body(
                        11,
                        w: FontWeight.w600,
                        color: C.inkSoft,
                      ).copyWith(letterSpacing: 1.6),
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: paused
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.pause_circle_filled,
                          size: 56,
                          color: C.inkSoft,
                        ),
                        const SizedBox(height: 10),
                        Text('Пауза', style: display(24, color: C.ink)),
                        const SizedBox(height: 4),
                        Text(
                          'Нажми, чтобы продолжить',
                          style: body(14, color: C.inkSoft),
                        ),
                      ],
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Text(
                          card.text,
                          textAlign: TextAlign.center,
                          style: display(
                            card.text.length > 14 ? 30 : 38,
                            color: C.ink,
                            height: 1.12,
                          ),
                        ),
                      ),
                    ),
            ),
            if (last)
              Align(
                alignment: Alignment.bottomCenter,
                child: Text(
                  'ПОСЛЕДНЕЕ СЛОВО',
                  style: body(
                    12,
                    w: FontWeight.w700,
                    color: C.gold,
                  ).copyWith(letterSpacing: 1.6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimerRing extends StatelessWidget {
  final int leftMs;
  final int totalMs;
  final bool last;
  const _TimerRing({
    required this.leftMs,
    required this.totalMs,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final low = leftMs <= 10000;
    final secs = (leftMs / 1000).ceil();
    final text = secs >= 100
        ? '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}'
        : '$secs';
    return SizedBox(
      width: 78,
      height: 78,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: totalMs == 0 ? 0 : leftMs / totalMs,
            strokeWidth: 7,
            strokeCap: StrokeCap.round,
            backgroundColor: C.feltLine,
            color: low ? C.skip : C.gold,
          ),
          Center(
            child: Text(
              last ? '0' : text,
              style: display(text.length > 3 ? 17 : 22)
                  .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }
}

class _CtlButton extends StatelessWidget {
  final String text;
  final Color color;
  final bool filled;
  final VoidCallback onTap;
  const _CtlButton({
    required this.text,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: filled ? color : color.withValues(alpha: .16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: filled ? BorderSide.none : BorderSide(color: color, width: 2),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 66,
        child: Center(
          child: Text(text, style: display(15, color: filled ? C.ink : color)),
        ),
      ),
    ),
  );
}

class _LastChip extends StatelessWidget {
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _LastChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: C.feltDeep,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50, minWidth: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (color != null) ...[Pawn(color!), const SizedBox(width: 8)],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: body(
                  15,
                  w: FontWeight.w600,
                  color: color == null ? C.chalkSoft : C.chalk,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
