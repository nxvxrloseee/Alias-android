import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'board.dart';
import 'win.dart';

class ReviewScreen extends StatefulWidget {
  final Turn turn;
  const ReviewScreen({super.key, required this.turn});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  Turn get t => widget.turn;
  bool _committed = false;
  @override
  void initState() {
    super.initState();
    _persist();
  }

  void _persist() => app.checkpoint(TurnProgress(t, null, 0, 'review'));

  void _commit() {
    if (_committed) return;
    _committed = true;
    final won = app.commit(t);
    final nav = Navigator.of(context);
    if (won) {
      nav.pushReplacement(MaterialPageRoute(builder: (_) => const WinScreen()));
    } else {
      nav.popUntil(ModalRoute.withName(BoardScreen.route));
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = app.game!;
    final s = app.settings;
    final pts = app.turnPoints(t);
    final okCount = t.words.where((w) => w.ok).length;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  children: [
                    Text(
                      'ИТОГИ ХОДА · ТАПНИ СЛОВО, ЧТОБЫ ИСПРАВИТЬ',
                      style: label(),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Pawn(C.team(s.teams[g.turn].color), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            app.teamName(g.turn),
                            overflow: TextOverflow.ellipsis,
                            style: display(26),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Угадано $okCount из ${t.words.length}',
                      style: body(14, color: C.chalkSoft),
                    ),
                    const SizedBox(height: 16),
                    if (t.words.isEmpty && t.last == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Text(
                          'За ход не было ни одного слова.',
                          textAlign: TextAlign.center,
                          style: body(15, color: C.chalkSoft),
                        ),
                      ),
                    for (final w in t.words) ...[
                      _WordRow(
                        text: w.card.text,
                        ok: w.ok,
                        badge: w.ok
                            ? '+1 угадано'
                            : (s.penalty ? '−1 пропуск' : 'пропуск'),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => w.ok = !w.ok);
                          _persist();
                        },
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (t.last != null)
                      _WordRow(
                        text: t.last!.text,
                        ok: t.lastTeam >= 0,
                        lastWord: true,
                        badgeColor: t.lastTeam >= 0
                            ? C.team(s.teams[t.lastTeam].color)
                            : null,
                        badge:
                            'последнее: ${t.lastTeam >= 0 ? app.teamName(t.lastTeam) : 'никто'}',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          // по кругу: команды → никто
                          setState(
                            () => t.lastTeam = t.lastTeam + 1 >= s.teams.length
                                ? -1
                                : t.lastTeam + 1,
                          );
                          _persist();
                        },
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            'Очки команды за ход',
                            style: body(15, color: C.chalkSoft),
                          ),
                        ),
                        Text(
                          pts > 0 ? '+$pts' : '$pts',
                          style: display(34).copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: BigButton('Записать очки', onTap: _commit),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordRow extends StatelessWidget {
  final String text;
  final bool ok;
  final String badge;
  final Color? badgeColor;
  final bool lastWord;
  final VoidCallback onTap;
  const _WordRow({
    required this.text,
    required this.ok,
    required this.badge,
    required this.onTap,
    this.badgeColor,
    this.lastWord = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = badgeColor ?? C.ok;
    return Panel(
      onTap: onTap,
      border: lastWord ? C.gold : null,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style:
                  body(
                    17,
                    w: FontWeight.w600,
                    color: ok ? C.chalk : C.chalkSoft,
                  ).copyWith(
                    decoration: ok ? null : TextDecoration.lineThrough,
                    decorationColor: C.skip,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: ok ? bg : Colors.transparent,
              borderRadius: BorderRadius.circular(99),
              border: ok ? null : Border.all(color: C.skip, width: 2),
            ),
            child: Text(
              badge,
              style: body(13, w: FontWeight.w700, color: ok ? C.ink : C.skip),
            ),
          ),
        ],
      ),
    );
  }
}
