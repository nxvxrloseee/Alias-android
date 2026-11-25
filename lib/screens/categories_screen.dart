import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../categories.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.felt,
        surfaceTintColor: Colors.transparent,
        title: Text('Категории', style: display(20)),
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final sel = app.settings.categories;
          final all = sel.length == categories.length;
          final count = app.countFor(sel);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Panel(
                  border: all ? C.gold : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    app.settings.categories = {...categoryIds};
                    app.save();
                  },
                  child: Row(
                    children: [
                      Icon(
                        all ? Icons.check_box : Icons.check_box_outline_blank,
                        color: all ? C.gold : C.chalkSoft,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Все категории',
                          style: body(17, w: FontWeight.w600),
                        ),
                      ),
                      Text(
                        fmtNum(app.totalWords),
                        style: body(14, color: C.chalkSoft),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    mainAxisExtent: 112,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (_, i) {
                    final c = categories[i];
                    final on = sel.contains(c.id);
                    return _CatCard(
                      cat: c,
                      on: on,
                      count: app.countFor([c.id]),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              sel.isEmpty
                                  ? 'Ничего не выбрано'
                                  : 'Выбрано: ${sel.length} из ${categories.length}',
                              style: body(14, color: C.chalkSoft),
                            ),
                            Text(
                              '${fmtNum(count)} ${plural(count, 'слово', 'слова', 'слов')}',
                              style: display(
                                18,
                                color: sel.isEmpty ? C.skip : C.chalk,
                              ),
                            ),
                          ],
                        ),
                      ),
                      BigButton(
                        'Готово',
                        onTap: sel.isEmpty
                            ? null
                            : () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CatCard extends StatelessWidget {
  final Category cat;
  final bool on;
  final int count;
  const _CatCard({required this.cat, required this.on, required this.count});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: on ? C.chalk : C.feltDeep,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          final s = app.settings.categories;
          if (on && s.length == 1) return;
          on ? s.remove(cat.id) : s.add(cat.id);
          app.save();
        },
        onLongPress: () {
          // долгое нажатие — играть только этой категорией
          HapticFeedback.mediumImpact();
          app.settings.categories = {cat.id};
          app.save();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(cat.icon, color: on ? C.ink : C.chalkSoft, size: 26),
                  const Spacer(),
                  Icon(
                    on ? Icons.check_circle : Icons.circle_outlined,
                    color: on ? C.felt : C.feltLine,
                    size: 22,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                cat.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: body(
                  15,
                  w: FontWeight.w600,
                  color: on ? C.ink : C.chalk,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${fmtNum(count)} ${plural(count, 'слово', 'слова', 'слов')}',
                style: body(12, color: on ? C.inkSoft : C.chalkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
