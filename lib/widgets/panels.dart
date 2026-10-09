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

class _PipeInfo extends StatelessWidget {
  final AquaController ctl;
  final int pipeKey;
  const _PipeInfo({required this.ctl, required this.pipeKey});

  @override
  Widget build(BuildContext context) {
    final AquaColors ac = context.aqua;
    final Net? n = ctl.sim.pipeNet[pipeKey];
    if (n == null) return _Welcome(ctl: ctl);
    final NetStatus st = ctl.sim.netStatus(n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
                child: Text('🔧 شبكة أنابيب',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ac.ink))),
            Tag(text: st.text, ok: st.ok),
          ],
        ),
        NoteText(
            'أحواض سمك: ${n.tanks.length} · مضخات تعمل: ${n.active}/${n.pumps.length} · أحواض زراعة: ${n.beds.length}\n'
            'سعة الري: ${n.cap} نبات · أنابيب: ${n.pipes}'),
      ],
    );
  }
}

Widget _header(BuildContext context, String title, {String? tag, bool? tagOk}) {
  final AquaColors ac = context.aqua;
  return Row(
    children: <Widget>[
      Expanded(
          child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ac.ink))),
      if (tag != null) Tag(text: tag, ok: tagOk),
    ],
  );
}

class _TankPanel extends StatelessWidget {
  final AquaController ctl;
  final Tank tank;
  const _TankPanel({required this.ctl, required this.tank});

  @override
  Widget build(BuildContext context) {
    final Sim s = ctl.sim;
    final FishSpecies? sp = tank.species;
    final bool has = tank.n > 0 && sp != null;
    final int need = tank.n > 0 ? (tank.n / 4).ceil() : 0;
    final int val = has ? (tank.n * sp!.sell * tank.size).round() : 0;
    final bool armedDel = ctl.delArm == tank.id;
    final int refund = (kTypes[ObjType.tank]!.cost * 0.6).round();

    String tip;
    if (!has) {
      tip = 'اشترِ صغار السمك لبدء الإنتاج.';
    } else if (tank.o2 < sp!.o2Min + 8) {
      tip = '⚠ الأكسجين منخفض — ضع مضخة أكسجين ملاصقة للحوض.';
    } else if (tank.waste > 50) {
      tip = '⚠ الفضلات عالية — وصّل الحوض بأحواض زراعة (مضخة + أنابيب).';
    } else if (tank.hunger > 60) {
      tip = '⚠ الأسماك جائعة — اضغط «أطعم».';
    } else {
      tip = '✔ الحوض بحالة جيدة.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _header(context, s.tankName(tank), tag: has ? '${sp!.name} × ${tank.n}' : 'فارغ', tagOk: has),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              Expanded(
                  child: AquaBtn(has ? '🍽️ أطعم ($need)' : '🍽️ أطعم',
                      kind: BtnKind.primary, onTap: has ? () => ctl.feed(tank) : null)),
              const SizedBox(width: 6),
              Expanded(
                  child: AquaBtn('💰 بيع ($val)',
                      onTap: (has && tank.size >= 0.6) ? () => ctl.sell(tank) : null)),
              const SizedBox(width: 6),
              Expanded(
                  child: AquaBtn(armedDel ? '⚠️ تأكيد (+$refund)' : '🗑️ إزالة',
                      kind: BtnKind.danger, onTap: () => ctl.deletePressed(tank))),
            ],
          ),
        ),
        StatBar(
            label: 'الأكسجين',
            value: tank.o2,
            color: const Color(0xFF3AA8E0),
            bad: has && tank.o2 < sp!.o2Min + 8),
        StatBar(
            label: 'الفضلات (أمونيا)',
            value: tank.waste,
            color: const Color(0xFFC08F34),
            bad: has && tank.waste > 50),
        StatBar(label: 'الجوع', value: tank.hunger, color: const Color(0xFFE8952A), bad: has && tank.hunger > 60),
        StatBar(
            label: 'صحة الأسماك',
            value: has ? tank.health : 100,
            color: const Color(0xFF3FA860),
            bad: has && tank.health < 40),
        StatBar(label: 'النمو (بيع من 60%)', value: has ? tank.size * 100 : 0, color: const Color(0xFF7A6BE0)),
        NoteText('مضخات الأكسجين: ${tank.air} · مغذّيات آلية: ${tank.feeders.length}\n$tip'),
        const SubLabel('➕ أضف 4 صغار سمك'),
        TwoColGrid(
          children: kFish.entries.map((MapEntry<String, FishSpecies> e) {
            final FishSpecies f = e.value;
            final bool allowed = !has || tank.sp == e.key;
            final int cost = f.price * 4;
            return ItemCard(
              title: '${f.ico} ${f.name}',
              small: '4 صغار · ${cost}💰',
              desc: f.desc,
              onTap: allowed && s.coins >= cost ? () => ctl.fry(tank, e.key) : null,
            );
          }).toList(),
        ),
      ],
    );
  }
}


// Bed panel restoration continues in the following source chunks.

class _BedPanel extends StatelessWidget {
  final AquaController ctl;
  final Bed bed;
  const _BedPanel({required this.ctl, required this.bed});

  @override
  Widget build(BuildContext context) {
    final Sim s = ctl.sim;
    final NetStatus st = s.netStatus(bed.net);
    final Selection? sel = ctl.sel;
    final Slot? one = (sel != null && sel.slot >= 0 && sel.slot < bed.slots.length)
        ? bed.slots[sel.slot]
        : null;
