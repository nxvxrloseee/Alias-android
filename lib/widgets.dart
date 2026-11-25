import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

class Pawn extends StatelessWidget {
  final Color color;
  final double size;
  const Pawn(this.color, {super.key, this.size = 16});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(
        color: Colors.black.withValues(alpha: .18),
        width: size / 6,
      ),
    ),
  );
}

enum BtnKind { primary, ghost, danger }

class BigButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final BtnKind kind;
  final bool small;
  final IconData? icon;
  const BigButton(
    this.text, {
    super.key,
    this.onTap,
    this.kind = BtnKind.primary,
    this.small = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fg = switch (kind) {
      BtnKind.primary => C.ink,
      BtnKind.ghost => C.chalk,
      BtnKind.danger => C.skip,
    };
    return Material(
      color: kind == BtnKind.primary ? C.gold : Colors.transparent,
      shape: StadiumBorder(
        side: kind == BtnKind.primary
            ? BorderSide.none
            : BorderSide(
                color: kind == BtnKind.danger ? C.skip : C.feltLine,
                width: 2,
              ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Container(
          constraints: BoxConstraints(minHeight: small ? 44 : 58),
          padding: EdgeInsets.symmetric(horizontal: small ? 16 : 22),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: fg, size: small ? 18 : 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: display(small ? 14 : 16, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? border;
  final VoidCallback? onTap;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: C.feltDeep,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: border == null
          ? BorderSide.none
          : BorderSide(color: border!, width: 2),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text.toUpperCase(), style: label()),
  );
}

/// Степпер с кнопками −/+ и быстрыми пресетами. Значения не ограничены пресетами.
class ValueStepper extends StatelessWidget {
  final int value;
  final int step;
  final int min;
  final int? max;
  final String Function(int) format;
  final List<int> presets;
  final ValueChanged<int> onChanged;
  const ValueStepper({
    super.key,
    required this.value,
    required this.step,
    required this.min,
    this.max,
    required this.format,
    required this.presets,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget round(IconData icon, int delta) => IconButton.filledTonal(
      onPressed: () {
        final raw = value + delta;
        final v = raw < min ? min : (max != null && raw > max! ? max! : raw);
        if (v != value) {
          HapticFeedback.selectionClick();
          onChanged(v);
        }
      },
      style: IconButton.styleFrom(
        backgroundColor: C.feltLine,
        foregroundColor: C.chalk,
        minimumSize: const Size(48, 48),
      ),
      icon: Icon(icon),
    );
    return Panel(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              round(Icons.remove, -step),
              Expanded(
                child: Text(
                  format(value),
                  textAlign: TextAlign.center,
                  style: display(20).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              round(Icons.add, step),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final p in presets)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _Chip(
                      text: p == 0 ? '∞' : '$p',
                      selected: p == value,
                      onTap: () => onChanged(p),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? C.chalk : Colors.transparent,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: SizedBox(
        height: 38,
        child: Center(
          child: Text(
            text,
            style: body(
              15,
              w: FontWeight.w600,
              color: selected ? C.ink : C.chalkSoft,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
      ),
    ),
  );
}

class SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const SwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Panel(
    onTap: () => onChanged(!value),
    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: body(16, w: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: body(13, color: C.chalkSoft)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: C.ok,
          activeThumbColor: C.chalk,
          inactiveTrackColor: C.feltLine,
          inactiveThumbColor: C.chalkSoft,
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ],
    ),
  );
}

/// Табло: строка команды с очками и полоской прогресса до цели.
class ScoreRow extends StatelessWidget {
  final String name;
  final Color color;
  final int score;
  final int target;
  final bool highlight;
  final String? chip;
  const ScoreRow({
    super.key,
    required this.name,
    required this.color,
    required this.score,
    required this.target,
    this.highlight = false,
    this.chip,
  });

  @override
  Widget build(BuildContext context) {
    final frac = target <= 0 ? 0.0 : (score / target).clamp(0.0, 1.0);
    return Panel(
      border: highlight ? C.gold : null,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              Pawn(color),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: body(17, w: FontWeight.w600),
                ),
              ),
              if (chip != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: C.gold,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    chip!.toUpperCase(),
                    style: body(11, w: FontWeight.w700, color: C.ink),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '$score',
                style: display(
                  26,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          if (target > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: frac),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  backgroundColor: C.feltLine,
                  color: color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String plural(int n, String one, String few, String many) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
  return many;
}

String fmtNum(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String text,
  required String yes,
  String no = 'Отмена',
  bool danger = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(no, style: body(15, w: FontWeight.w600)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            yes,
            style: body(
              15,
              w: FontWeight.w700,
              color: danger ? C.skip : C.gold,
            ),
          ),
        ),
      ],
    ),
  );
  return r ?? false;
}
