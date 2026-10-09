import 'package:flutter/material.dart';

import '../game/util.dart';
import '../theme.dart';

class Tag extends StatelessWidget {
  final String text;
  final bool? ok; // null = neutral
  const Tag({super.key, required this.text, this.ok});

  @override
  Widget build(BuildContext context) {
    final AquaColors ac = context.aqua;
    final Color bg = ok == true
        ? ac.good.withOpacity(.16)
        : ok == false
            ? ac.danger.withOpacity(.15)
            : ac.surface2;
    final Color fg = ok == true ? ac.good : (ok == false ? ac.danger : ac.ink);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class StatBar extends StatelessWidget {
  final String label;
  final double value; // 0..100
  final Color color;
  final bool bad;
  const StatBar({super.key, required this.label, required this.value, required this.color, this.bad = false});

  @override
  Widget build(BuildContext context) {
    final AquaColors ac = context.aqua;
    final double v = clampD(value, 0, 100);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          SizedBox(width: 104, child: Text(label, style: TextStyle(fontSize: 12, color: ac.ink))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LayoutBuilder(builder: (BuildContext context, BoxConstraints c) {
                return Stack(
                  children: <Widget>[
                    Container(height: 9, color: ac.surface2),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 9,
                      width: c.maxWidth * v / 100,
                      color: bad ? ac.danger : color,
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text('${v.round()}%',
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: bad ? ac.danger : ac.ink)),
          ),
        ],
      ),
    );
  }
}

enum BtnKind { normal, primary, danger }

class AquaBtn extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final BtnKind kind;
  final bool selected;
  const AquaBtn(this.text, {super.key, this.onTap, this.kind = BtnKind.normal, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final AquaColors ac = context.aqua;
    final bool disabled = onTap == null;
    Color bg;
    Color fg;
    Color border;
    switch (kind) {
      case BtnKind.primary:
        bg = ac.accent;
        fg = ac.onAccent;
        border = ac.accent;
        break;
      case BtnKind.danger:
        bg = ac.surface2;
        fg = ac.danger;
        border = ac.line;
        break;
      case BtnKind.normal:
        bg = ac.surface2;
        fg = ac.ink;
        border = ac.line;
        break;
    }
    return Opacity(
      opacity: disabled ? .42 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? ac.accent : border, width: selected ? 2 : 1),
            ),
            child: Text(text,
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
          ),
        ),
      ),
    );
  }
}

class ItemCard extends StatelessWidget {
  final String title;
  final String small;
  final String desc;
  final bool selected;
  final VoidCallback? onTap;
  const ItemCard(
      {super.key,
      required this.title,
      required this.small,
      required this.desc,
      this.selected = false,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final AquaColors ac = context.aqua;
    final bool disabled = onTap == null;
    return Opacity(
      opacity: disabled ? .5 : 1,
      child: Material(
        color: ac.surface2,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? ac.accent : ac.line, width: selected ? 2 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title, style: TextStyle(fontSize: 13.5, color: ac.ink)),
                const SizedBox(height: 1),
                Text(small,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: ac.muted)),
                Text(desc, style: TextStyle(fontSize: 11.5, color: ac.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A 2-column responsive grid (avoids GridView aspect-ratio issues with
/// variable-height cards).
class TwoColGrid extends StatelessWidget {
  final List<Widget> children;
  const TwoColGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints c) {
      final double gap = 6;
      final double colW = (c.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: children.map((Widget w) => SizedBox(width: colW, child: w)).toList(),
      );
    });
  }
}

class NoteText extends StatelessWidget {
  final String text;
  const NoteText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final AquaColors ac = context.aqua;
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text, style: TextStyle(fontSize: 12.5, color: ac.muted, height: 1.5)),
    );
  }
}

class SubLabel extends StatelessWidget {
  final String text;
  const SubLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final AquaColors ac = context.aqua;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ac.ink)),
    );
  }
}
