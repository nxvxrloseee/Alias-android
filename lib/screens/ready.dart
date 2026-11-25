import 'package:flutter/material.dart';

import '../categories.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'play.dart';

class ReadyScreen extends StatelessWidget {
  const ReadyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = app.game!;
    final s = app.settings;
    final color = C.team(s.teams[g.turn].color);
    final cats = s.categories.length == categories.length
        ? 'все категории'
        : categories
              .where((c) => s.categories.contains(c.id))
              .map((c) => c.title.toLowerCase())
              .join(', ');
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Pawn(color, size: 76),
                        const SizedBox(height: 22),
                        Text('СЕЙЧАС ОБЪЯСНЯЕТ КОМАНДА', style: label()),
                        const SizedBox(height: 10),
                        Text(
                          app.teamName(g.turn),
                          textAlign: TextAlign.center,
                          style: display(40, w: FontWeight.w900, height: 1.05),
                        ),
                        const SizedBox(height: 18),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text(
                            'Передайте телефон объясняющему. На ход ${s.seconds} ${plural(s.seconds, 'секунда', 'секунды', 'секунд')}. '
                            'Вверх — угадано, вниз — пропуск.',
                            textAlign: TextAlign.center,
                            style: body(16, color: C.chalkSoft, height: 1.45),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text(
                            'Слова: $cats. ${s.includeAdvanced ? 'Включая сложные' : 'Обычный набор'}',
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: body(13, color: C.chalkSoft),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  BigButton(
                    'Назад',
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BigButton(
                      'Поехали!',
                      onTap: !app.canPlay
                          ? null
                          : () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const PlayScreen(),
                                ),
                              );
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
