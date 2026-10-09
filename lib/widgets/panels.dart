import 'package:flutter/material.dart';

import '../game/constants.dart';
import '../game/controller.dart';
import '../game/models.dart';
import '../game/sim.dart';
import '../theme.dart';
import 'common.dart';

class GamePanel extends StatelessWidget {
  final AquaController ctl;
  const GamePanel({super.key, required this.ctl});

  @override
  Widget build(BuildContext context) {
    final AquaColors ac = context.aqua;
    return AnimatedBuilder(
      animation: ctl,
      builder: (BuildContext context, Widget? _) {
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ac.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ac.line),
          ),
          child: _body(context),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    switch (ctl.tab) {
      case AquaTab.info:
        return _InfoPanel(ctl: ctl);
      case AquaTab.build:
        return _BuildPanel(ctl: ctl);
      case AquaTab.pipe:
        return _PipePanel(ctl: ctl);
      case AquaTab.plant:
        return _PlantPanel(ctl: ctl);
      case AquaTab.store:
        return _StorePanel(ctl: ctl);
    }
  }
}

// ---------------------------------------------------------------- info tab

class _InfoPanel extends StatelessWidget {
  final AquaController ctl;
  const _InfoPanel({required this.ctl});

  @override
  Widget build(BuildContext context) {
    final Selection? sel = ctl.sel;
    if (sel == null) return _Welcome(ctl: ctl);
    if (sel.kind == SelKind.pipe) return _PipeInfo(ctl: ctl, pipeKey: sel.id);
    final GameObj? o = ctl.selObj;
    if (o == null) return _Welcome(ctl: ctl);
    if (o is Tank) return _TankPanel(ctl: ctl, tank: o);
    if (o is Bed) return _BedPanel(ctl: ctl, bed: o);
    if (o is Pump) return _PumpPanel(ctl: ctl, pump: o);
    if (o is Air) return _AirPanel(ctl: ctl, air: o);
    if (o is Feeder) return _FeederPanel(ctl: ctl, feeder: o);
    return _Welcome(ctl: ctl);
  }
}

class _Welcome extends StatelessWidget {
  final AquaController ctl;
  const _Welcome({required this.ctl});

  @override
  Widget build(BuildContext context) {
    final AquaColors ac = context.aqua;
    final Sim s = ctl.sim;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'اضغط على أي عنصر في الدفيئة لمتابعة حالته والتحكم فيه.\n'
          '🐟 الأسماك تحتاج أكسجيناً وطعاماً وماءً نظيفاً.\n'
          '🌱 النباتات تحتاج ماءً جارياً، وتتغذى على فضلات الأسماك.\n'
          '🔧 المضخات قد تنسد — اضغط عليها لتنظيفها.',
          style: TextStyle(fontSize: 12.5, color: ac.muted, height: 1.5),
        ),
        const SizedBox(height: 10),
        Text(
          '🌾 حصاد: ${s.statHarv} · 🐟 أسماك مباعة: ${s.statFish} · 💀 أسماك نافقة: ${s.statLost} · 🥀 نباتات ميتة: ${s.statPlost}',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ac.ink),
        ),
      ],
    );
  }
}
