import 'package:flutter/material.dart';

import '../game/constants.dart';
import '../game/controller.dart';
import '../theme.dart';

String _pad2(int n) => n.toString().padLeft(2, '0');

const Map<int, String> _speedLabel = <int, String>{
  0: '⏸ متوقف',
  1: '▶ 1×',
  2: '⏩ 2×',
  4: '⏩ 4×',
};

class HudBar extends StatelessWidget {
  final AquaController ctl;
  const HudBar({super.key, required this.ctl});

  @override
  Widget build(BuildContext context) {
    final AquaColors ac = context.aqua;
    return AnimatedBuilder(
      animation: ctl,
      builder: (BuildContext context, Widget? _) {
        final double total = 7 + ctl.sim.t / kDaySec * 24;
        final int hh = total.floor() % 24;
        final int mm = ((total % 1) * 60).floor();
        final int day = (total ~/ 24) + 1;
        final bool isDay = hh >= 6 && hh < 18;
        final bool lowFood = ctl.sim.food <= 2;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _IconPill(
              child: const Text('❓', style: TextStyle(fontSize: 15)),
              onTap: ctl.openHelp,
              colors: ac,
            ),
            const SizedBox(width: 5),
            _IconPill(
              child: Text(_speedLabel[ctl.sim.speed] ?? '▶ 1×',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: ac.ink)),
              onTap: ctl.cycleSpeed,
              colors: ac,
              background: ac.surface2,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: _Pill(
                colors: ac,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(isDay ? '☀️' : '🌙', style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text('يوم $day · ${_pad2(hh)}:${_pad2(mm)}',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: ac.ink)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            _IconPill(
              onTap: () => ctl.setTab(AquaTab.store),
              colors: ac,
              borderColor: lowFood ? ac.danger : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('🍽️', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 3),
                  Text('${ctl.sim.food}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: lowFood ? ac.danger : ac.ink)),
                ],
              ),
            ),
            const SizedBox(width: 5),
            _Pill(
              colors: ac,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('💰', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 3),
                  Text('${ctl.sim.coins}',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: ac.ink)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final Widget child;
  final AquaColors colors;
  final Color? background;
  final Color? borderColor;
  const _Pill({required this.child, required this.colors, this.background, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background ?? colors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor ?? colors.line, width: borderColor != null ? 1.4 : 1),
      ),
      child: child,
    );
  }
}

class _IconPill extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final AquaColors colors;
  final Color? background;
  final Color? borderColor;
  const _IconPill(
      {required this.child, required this.onTap, required this.colors, this.background, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: _Pill(colors: colors, background: background, borderColor: borderColor, child: child),
    );
  }
}

class MissionBanner extends StatelessWidget {
  final AquaController ctl;
  const MissionBanner({super.key, required this.ctl});

  @override
  Widget build(BuildContext context) {
    final AquaColors ac = context.aqua;
    return AnimatedBuilder(
      animation: ctl,
      builder: (BuildContext context, Widget? _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: ac.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ac.accent, width: 1),
          ),
          child: Text(
            ctl.missionText,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: ac.ink, height: 1.4),
          ),
        );
      },
    );
  }
}
