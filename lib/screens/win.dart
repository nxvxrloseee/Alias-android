import 'dart:math';

import 'package:flutter/material.dart';

import '../sfx.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class WinScreen extends StatefulWidget {
  const WinScreen({super.key});

  @override
  State<WinScreen> createState() => _WinScreenState();
}

class _WinScreenState extends State<WinScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );
  late final List<int> _scores = List.of(app.game!.scores);
  late final int _winner = app.leader;
  late final List<int> _leaders = app.leaders;
  late final int _rounds = app.game!.round;
  late final List<_Bit> _bits;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    final colors = [C.team(app.settings.teams[_winner].color), C.card, C.gold];
    _bits = List.generate(
      150,
      (_) => _Bit(
        vx: (rng.nextDouble() - .5) * 900,
        vy: -rng.nextDouble() * 900 - 300,
        spin: (rng.nextDouble() - .5) * 14,
        size: 6 + rng.nextDouble() * 7,
        color: colors[rng.nextInt(colors.length)],
      ),
    );
    Sfx.win();
    if (!MediaQueryData.fromView(
      WidgetsBinding.instance.platformDispatcher.views.first,
    ).disableAnimations) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _rematch() {
    app.newGame();
    Navigator.of(context).popUntil((r) => r.isFirst);
    Navigator.of(context).pushNamed('/board');
  }

  void _menu() {
    app.endGame();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final s = app.settings;
    final order = List.generate(_scores.length, (i) => i)
      ..sort((a, b) => _scores[b].compareTo(_scores[a]));
    final top = _scores[_winner];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _menu();
      },
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                      children: [
                        Center(
                          child: Text(
                            _leaders.length > 1 ? 'НИЧЬЯ' : 'ПОБЕДА',
                            style: display(15, color: C.gold, spacing: 3),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: Pawn(C.team(s.teams[_winner].color), size: 80),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _leaders.map(app.teamName).join(' · '),
                          textAlign: TextAlign.center,
                          style: display(40, w: FontWeight.w900, height: 1.05),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '$top ${plural(top, 'очко', 'очка', 'очков')} за $_rounds ${plural(_rounds, 'раунд', 'раунда', 'раундов')}',
                          textAlign: TextAlign.center,
                          style: body(16, color: C.chalkSoft),
                        ),
                        const SizedBox(height: 28),
                        for (final i in order) ...[
                          ScoreRow(
                            name: app.teamName(i),
                            color: C.team(s.teams[i].color),
                            score: _scores[i],
                            target: s.target == 0 ? top : s.target,
                            highlight: _leaders.contains(i),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: BigButton(
                            'В меню',
                            kind: BtnKind.ghost,
                            onTap: _menu,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: BigButton('Ещё раз', onTap: _rematch)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, _) => CustomPaint(
                  size: Size.infinite,
                  painter: _Confetti(_bits, _c.value * 3.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bit {
  final double vx, vy, spin, size;
  final Color color;
  _Bit({
    required this.vx,
    required this.vy,
    required this.spin,
    required this.size,
    required this.color,
  });
}

class _Confetti extends CustomPainter {
  final List<_Bit> bits;
  final double t; // секунды
  _Confetti(this.bits, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 3.6) return;
    final origin = Offset(size.width / 2, size.height * .3);
    final paint = Paint();
    for (final b in bits) {
      final x = origin.dx + b.vx * t * .9;
      final y = origin.dy + b.vy * t + 900 * t * t;
      if (y > size.height + 20) continue;
      paint.color = b.color.withValues(alpha: (1 - t / 3.6).clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.spin * t);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size / 2),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Confetti old) => old.t != t;
}
