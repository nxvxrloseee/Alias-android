import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'ready.dart';
import 'play.dart';
import 'review.dart';
import 'win.dart';

class BoardScreen extends StatelessWidget {
  static const route = '/board';
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: app,
          builder: (context, _) {
            final g = app.game;
            if (g == null) return const SizedBox.shrink();
            final s = app.settings;
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    children: [
                      Text('РАУНД ${g.round}', style: label()),
                      const SizedBox(height: 4),
                      Text('Счёт', style: display(30)),
                      const SizedBox(height: 18),
                      for (var i = 0; i < s.teams.length; i++) ...[
                        ScoreRow(
                          name: app.teamName(i),
                          color: C.team(s.teams[i].color),
                          score: g.scores[i],
                          target: s.target,
                          highlight: i == g.turn,
                          chip: i == g.turn ? 'ходит' : null,
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.target == 0
                                  ? 'Игра без лимита очков'
                                  : 'Играем до ${s.target}',
                              style: body(14, color: C.chalkSoft),
                            ),
                          ),
                          Text(
                            'Сыграно слов: ${g.used.length}',
                            style: body(14, color: C.chalkSoft),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _finish(context),
                          icon: const Icon(
                            Icons.flag_outlined,
                            color: C.chalkSoft,
                          ),
                          label: Text(
                            'Завершить партию',
                            style: body(
                              15,
                              w: FontWeight.w600,
                              color: C.chalkSoft,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      BigButton(
                        'Меню',
                        kind: BtnKind.ghost,
                        small: true,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: BigButton(
                          g.finished
                              ? 'Результаты'
                              : g.pending != null
                              ? 'Продолжить ход'
                              : 'Ход: ${app.teamName(g.turn)}',
                          onTap: !app.canPlay
                              ? null
                              : () {
                                  final pending = g.pending;
                                  final Widget screen = g.finished
                                      ? const WinScreen()
                                      : pending?.phase == 'review'
                                      ? ReviewScreen(turn: pending!.turn)
                                      : pending != null
                                      ? const PlayScreen()
                                      : const ReadyScreen();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => screen),
                                  );
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _finish(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Завершить партию?',
      text: 'Покажем итоговый счёт. При равных очках будет ничья.',
      yes: 'Завершить',
    );
    if (!ok || !context.mounted) return;
    app.game!
      ..pending = null
      ..finished = true;
    app.save();
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const WinScreen()));
  }
}
