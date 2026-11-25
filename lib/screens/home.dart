import 'package:flutter/material.dart';

import '../categories.dart';
import '../sfx.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'board.dart';
import 'categories_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: app,
          builder: (context, _) {
            final s = app.settings;
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Элиас',
                              style: display(44, w: FontWeight.w900, height: 1),
                            ),
                            TextSpan(
                              text: '.',
                              style: display(
                                44,
                                w: FontWeight.w900,
                                color: C.gold,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Объясняй слова, не называя их. Один телефон на всех.',
                        style: body(15, color: C.chalkSoft),
                      ),
                      const SizedBox(height: 28),
                      const SectionLabel('Команды'),
                      if (app.game != null)
                        TextButton(
                          onPressed: () async {
                            final ok = await confirmDialog(
                              context,
                              title: 'Сбросить партию?',
                              text: 'Счёт и незавершённый ход будут удалены. После этого можно изменить команды.',
                              yes: 'Сбросить',
                              danger: true,
                            );
                            if (ok) app.endGame();
                          },
                          child: const Text(
                            'Сбросить партию и изменить команды',
                          ),
                        ),
                      for (var i = 0; i < s.teams.length; i++) ...[
                        _TeamRow(key: ObjectKey(s.teams[i]), index: i),
                        const SizedBox(height: 8),
                      ],
                      if (app.game == null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: app.addTeam,
                            icon: const Icon(Icons.add, color: C.gold),
                            label: Text(
                              'Добавить команду',
                              style: body(
                                15,
                                w: FontWeight.w600,
                                color: C.gold,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      SwitchRow(
                        title: 'Сложные слова',
                        subtitle: app.game?.pending != null
                            ? 'Можно изменить после завершения сохранённого хода'
                            : 'Редкие термины и имена. По умолчанию выключены',
                        value: s.includeAdvanced,
                        onChanged: app.setIncludeAdvanced,
                      ),
                      const SizedBox(height: 20),
                      const SectionLabel('Категории слов'),
                      _CategoriesTile(),
                      const SizedBox(height: 24),
                      if (app.game?.pending != null)
                        Text(
                          'Есть сохранённый ход. Время, категории и правила можно изменить после его завершения.',
                          style: body(13, color: C.gold),
                        ),
                      const SectionLabel('Время хода'),
                      ValueStepper(
                        value: s.seconds,
                        step: 10,
                        min: 10,

                        presets: const [30, 60, 90, 120],
                        format: (v) =>
                            v < 60 || v % 60 != 0 ? '$v сек' : '${v ~/ 60} мин',
                        onChanged: (v) {
                          if (app.game?.pending != null) return;
                          s.seconds = v;
                          app.save();
                        },
                      ),
                      const SizedBox(height: 24),
                      const SectionLabel('Играем до'),
                      ValueStepper(
                        value: s.target,
                        step: 5,
                        min: 0,

                        presets: const [30, 50, 100, 0],
                        format: (v) => v == 0
                            ? 'Без лимита'
                            : '$v ${plural(v, 'очка', 'очков', 'очков')}',
                        onChanged: (v) {
                          s.target = v;
                          app.save();
                        },
                      ),
                      if (s.target == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Играете сколько хотите и завершаете партию кнопкой на табло.',
                            style: body(13, color: C.chalkSoft),
                          ),
                        ),
                      const SizedBox(height: 24),
                      const SectionLabel('Правила'),
                      SwitchRow(
                        title: 'Штраф за пропуск',
                        subtitle: 'Каждое пропущенное слово — минус очко',
                        value: s.penalty,
                        onChanged: (v) {
                          if (app.game?.pending != null) return;
                          s.penalty = v;
                          app.save();
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchRow(
                        title: 'Общее последнее слово',
                        subtitle: 'Когда время вышло, слово может угадать любая команда',
                        value: s.sharedLast,
                        onChanged: (v) {
                          if (app.game?.pending != null) return;
                          s.sharedLast = v;
                          app.save();
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchRow(
                        title: 'Звуки',
                        subtitle: 'Сигналы таймера и отгаданных слов',
                        value: s.sound,
                        onChanged: (v) {
                          s.sound = v;
                          Sfx.enabled = v;
                          app.save();
                        },
                      ),
                      const SizedBox(height: 24),
                      const _Rules(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: app.game == null
                      ? SizedBox(
                          width: double.infinity,
                          child: BigButton(
                            'Начать игру',
                            onTap: () => _start(context),
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: BigButton(
                                'Новая игра',
                                kind: BtnKind.ghost,
                                onTap: () => _restart(context),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: BigButton(
                                'Продолжить',
                                onTap: app.canPlay
                                    ? () => openBoard(context)
                                    : null,
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

  void _start(BuildContext context) {
    if (app.countFor(app.settings.categories) == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы одну категорию')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    app.newGame();
    openBoard(context);
  }

  Future<void> _restart(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Начать заново?',
      text: 'Счёт текущей партии обнулится.',
      yes: 'Начать заново',
      danger: true,
    );
    if (ok && context.mounted) _start(context);
  }
}

void openBoard(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: BoardScreen.route),
      builder: (_) => const BoardScreen(),
    ),
  );
}

class _TeamRow extends StatefulWidget {
  final int index;
  const _TeamRow({super.key, required this.index});

  @override
  State<_TeamRow> createState() => _TeamRowState();
}

class _TeamRowState extends State<_TeamRow> {
  late final TextEditingController _c = TextEditingController(
    text: app.settings.teams[widget.index].name,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final team = app.settings.teams[widget.index];
    final canRemove = app.game == null && app.settings.teams.length > 2;
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 2, 4, 2),
      child: Row(
        children: [
          Pawn(C.team(team.color)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _c,
              maxLength: 20,
              textCapitalization: TextCapitalization.sentences,
              style: body(17, w: FontWeight.w600),
              decoration: InputDecoration(
                border: InputBorder.none,
                counterText: '',
                hintText:
                    defaultTeamNames[widget.index % defaultTeamNames.length],
                hintStyle: body(17, color: C.chalkSoft),
              ),
              onChanged: (v) {
                team.name = v;
                app.save();
              },
            ),
          ),
          IconButton(
            onPressed: canRemove ? () => app.removeTeam(widget.index) : null,
            icon: Icon(
              Icons.close,
              color: canRemove ? C.chalkSoft : C.feltLine,
            ),
            tooltip: 'Удалить команду',
          ),
        ],
      ),
    );
  }
}

class _CategoriesTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sel = app.settings.categories;
    final all = sel.length == categories.length;
    final names = categories
        .where((c) => sel.contains(c.id))
        .map((c) => c.title)
        .toList();
    final title = all
        ? 'Все категории'
        : sel.length == 1
        ? names.first
        : '${sel.length} ${plural(sel.length, 'категория', 'категории', 'категорий')}';
    final subtitle = all ? 'Любые слова вперемешку' : names.join(', ');
    return Panel(
      onTap: app.game?.pending != null
          ? null
          : () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CategoriesScreen())),
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: body(17, w: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: body(13, color: C.chalkSoft),
                ),
                const SizedBox(height: 6),
                Text(
                  '${fmtNum(app.countFor(sel))} ${plural(app.countFor(sel), 'слово', 'слова', 'слов')}',
                  style: body(13, w: FontWeight.w600, color: C.gold),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: C.chalkSoft),
        ],
      ),
    );
  }
}

class _Rules extends StatelessWidget {
  const _Rules();

  @override
  Widget build(BuildContext context) {
    const rules = [
      'Команды ходят по очереди. Один игрок объясняет, его команда угадывает.',
      'Нельзя называть само слово, однокоренные слова и переводить на другой язык. Жесты и «звучит как» — можно.',
      'Отгадали — смахни карточку вверх или жми «Угадано». Не выходит — вниз или «Пропуск».',
      'После хода можно исправить ошибки: тапни по слову в списке.',
      'Побеждает команда, первой набравшая нужные очки. Круг доигрывается до конца, чтобы у всех было поровну ходов.',
    ];
    return Panel(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text('Как играть', style: body(16, w: FontWeight.w600)),
          iconColor: C.chalkSoft,
          collapsedIconColor: C.chalkSoft,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            for (var i = 0; i < rules.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        '${i + 1}.',
                        style: body(15, w: FontWeight.w600, color: C.gold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rules[i],
                        style: body(15, color: C.chalkSoft, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
