import 'package:flutter/material.dart';

import '../game/constants.dart';
import '../game/controller.dart';
import '../game/models.dart';
import '../game/sim.dart';
import '../game/util.dart';
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
    final int val = has ? (tank.n * sp.sell * tank.size).round() : 0;
    final bool armedDel = ctl.delArm == tank.id;
    final int refund = (kTypes[ObjType.tank]!.cost * 0.6).round();

    String tip;
    if (!has) {
      tip = 'اشترِ صغار السمك لبدء الإنتاج.';
    } else if (tank.o2 < sp.o2Min + 8) {
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
        _header(context, s.tankName(tank), tag: has ? '${sp.name} × ${tank.n}' : 'فارغ', tagOk: has),
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
            bad: has && tank.o2 < sp.o2Min + 8),
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
              title: '${e.key == 'tilapia' ? '🐟' : e.key == 'carp' ? '🐠' : '🐡'} ${f.name}',
              small: '4 صغار · ${cost}💰',
              desc: 'سمك للاستزراع المائي — راقب الأكسجين والجوع والنظافة.',
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
    final List<Slot> list = (one != null && one.has)
        ? <Slot>[one]
        : bed.slots.where((Slot x) => x.has).toList();
    final List<Slot> alive = list.where((Slot x) => !x.dead).toList();
    double avg(double Function(Slot) f) =>
        alive.isEmpty ? 0 : alive.map(f).reduce((double a, double b) => a + b) / alive.length;
    final int ready = bed.slots.where((Slot x) => x.alive && x.g >= 1).length;
    final int dead = bed.slots.where((Slot x) => x.dead).length;
    final bool armedDel = ctl.delArm == bed.id;
    final int refund = (kTypes[bed.type]!.cost * 0.6).round();

    String sub;
    if (one != null) {
      final String name = one.has ? (kCrops[one.crop]!.name + (one.dead ? ' (ميتة)' : '')) : 'فارغة';
      sub = 'خانة ${sel!.slot + 1}: $name';
    } else {
      sub = 'متوسط النباتات (${alive.length}/${bed.slots.length})';
    }

    final List<String> notes = <String>[];
    if (ready > 0) notes.add('✨ جاهز للحصاد: $ready');
    if (bed.thirsty) notes.add('💧 بعض النباتات عطشى — تحقق من المضخة والأنابيب.');
    if (bed.starve) notes.add('🍂 نقص مغذيات — أضف أسماكاً أو قلل النباتات.');
    final String note = notes.isEmpty
        ? 'المس النبات لمتابعته، والمس النبات الناضج (✨) لحصاده.'
        : notes.join('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _header(context, kTypes[bed.type]!.name, tag: st.text, tagOk: st.ok),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              Expanded(child: AquaBtn('🌾 حصاد الناضج',
                  kind: BtnKind.primary, onTap: ready > 0 ? () => ctl.harvestAll(bed) : null)),
              const SizedBox(width: 6),
              Expanded(child: AquaBtn('🧹 تنظيف الميت',
                  onTap: dead > 0 ? () => ctl.cleanDead(bed) : null)),
              const SizedBox(width: 6),
              Expanded(child: AquaBtn(armedDel ? '⚠️ تأكيد (+$refund)' : '🗑️ إزالة',
                  kind: BtnKind.danger, onTap: () => ctl.deletePressed(bed))),
            ],
          ),
        ),
        SubLabel(sub),
        StatBar(label: 'النمو', value: avg((Slot x) => x.g) * 100, color: const Color(0xFF4FAE4A)),
        StatBar(label: 'الماء', value: avg((Slot x) => x.water), color: const Color(0xFF3AA8E0),
            bad: alive.isNotEmpty && avg((Slot x) => x.water) < 30),
        StatBar(label: 'المغذيات', value: avg((Slot x) => x.nut), color: const Color(0xFFC08F34),
            bad: alive.isNotEmpty && avg((Slot x) => x.nut) < 15),
        StatBar(label: 'الصحة', value: alive.isEmpty ? 100 : avg((Slot x) => x.hp),
            color: const Color(0xFF3FA860), bad: alive.isNotEmpty && avg((Slot x) => x.hp) < 50),
        NoteText(note),
      ],
    );
  }
}

class _PumpPanel extends StatelessWidget {
  final AquaController ctl;
  final Pump pump;
  const _PumpPanel({required this.ctl, required this.pump});

  @override
  Widget build(BuildContext context) {
    final Net? n = pump.net;
    final bool armedDel = ctl.delArm == pump.id;
    final int refund = (kTypes[ObjType.pump]!.cost * 0.6).round();
    String tag;
    bool? ok;
    if (pump.broken) {
      tag = '🔧 معطلة (انسداد)';
      ok = false;
    } else if (n != null && n.tanks.isNotEmpty) {
      tag = '✔ تعمل';
      ok = true;
    } else {
      tag = '✖ غير متصلة بحوض سمك';
      ok = false;
    }
    final int plants =
        n == null ? 0 : n.beds.fold(0, (int a, Bed b) => a + b.slots.where((Slot x) => x.alive).length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _header(context, '💧 مضخة ماء', tag: tag, tagOk: ok),
        NoteText(
            'تدفع الماء عبر الأنابيب. سعة الشبكة: ${n?.cap ?? 0} نبات · نباتات مرتبطة: $plants\n'
            'وصّل المضخة بحوض السمك وبأحواض الزراعة عبر أنابيب.'),
        Row(
          children: <Widget>[
            Expanded(child: AquaBtn('🔧 تنظيف / إصلاح',
                kind: BtnKind.primary, onTap: pump.broken ? () => ctl.fixPump(pump) : null)),
            const SizedBox(width: 6),
            Expanded(child: AquaBtn(armedDel ? '⚠️ تأكيد (+$refund)' : '🗑️ إزالة',
                kind: BtnKind.danger, onTap: () => ctl.deletePressed(pump))),
          ],
        ),
      ],
    );
  }
}

class _AirPanel extends StatelessWidget {
  final AquaController ctl;
  final Air air;
  const _AirPanel({required this.ctl, required this.air});

  @override
  Widget build(BuildContext context) {
    final bool armedDel = ctl.delArm == air.id;
    final int refund = (kTypes[ObjType.air]!.cost * 0.6).round();
    final Tank? t = air.tank;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _header(context, '💨 مضخة أكسجين',
            tag: t != null ? '✔ متصلة بـ${ctl.sim.tankName(t)}' : '✖ غير ملاصقة لحوض', tagOk: t != null),
        const NoteText(
            'ترفع الأكسجين في الحوض الملاصق لها. حتى 3 مضخات لكل حوض — الأسماك الكبيرة والكثيفة (والسلمون) تحتاج أكثر.'),
        AquaBtn(armedDel ? '⚠️ اضغط للتأكيد (+$refund💰)' : '🗑️ إزالة',
            kind: BtnKind.danger, onTap: () => ctl.deletePressed(air)),
      ],
    );
  }
}

class _FeederPanel extends StatelessWidget {
  final AquaController ctl;
  final Feeder feeder;
  const _FeederPanel({required this.ctl, required this.feeder});

  @override
  Widget build(BuildContext context) {
    final bool armedDel = ctl.delArm == feeder.id;
    final int refund = (kTypes[ObjType.feeder]!.cost * 0.6).round();
    final Tank? t = feeder.tank;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _header(context, '🥣 مغذٍّ آلي',
            tag: t != null ? '✔ يخدم ${ctl.sim.tankName(t)}' : '✖ غير ملاصق لحوض', tagOk: t != null),
        NoteText(
            'يطعم الحوض الملاصق تلقائياً عند ارتفاع الجوع فوق 40%.\nالطعام المتاح: ${ctl.sim.food} وجبة — لا تنسَ إعادة التخزين.'),
        AquaBtn(armedDel ? '⚠️ اضغط للتأكيد (+$refund💰)' : '🗑️ إزالة',
            kind: BtnKind.danger, onTap: () => ctl.deletePressed(feeder)),
      ],
    );
  }
}

// --------------------------------------------------------------- build tab

class _BuildPanel extends StatelessWidget {
  final AquaController ctl;
  const _BuildPanel({required this.ctl});

  @override
  Widget build(BuildContext context) {
    final AquaColors ac = context.aqua;
    final Sim s = ctl.sim;
    final ObjType? armed = ctl.armed;
    final int expandIdx = (s.rows - kMinRows) ~/ 2;
    final int? expandCost = expandIdx < kExpand.length ? kExpand[expandIdx] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (armed != null) ...<Widget>[
          Builder(builder: (BuildContext context) {
            final TypeInfo tp = kTypes[armed]!;
            final Pt? pending = ctl.pending;
            if (pending != null) {
              final bool ok = s.canPlace(armed, pending.x, pending.y);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('ضع ${tp.name} في الدفيئة', style: TextStyle(color: ac.ink, fontWeight: FontWeight.w700)),
                  NoteText(ok ? 'المكان صالح — اضغط «تأكيد».' : 'المكان مشغول أو خارج الدفيئة.'),
                  Row(children: <Widget>[
                    Expanded(child: AquaBtn('تأكيد البناء', kind: BtnKind.primary, onTap: ok ? ctl.okPlace : null)),
                    const SizedBox(width: 6),
                    Expanded(child: AquaBtn('إلغاء', onTap: ctl.cancelPlace)),
                  ]),
                ],
              );
            }
            return NoteText('اختر مكاناً في الدفيئة لوضع ${tp.name}.');
          }),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('اختر عنصراً ثم المس المكان المناسب في الدفيئة:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ac.ink)),
          ),
        TwoColGrid(
          children: kTypes.entries.map((MapEntry<ObjType, TypeInfo> e) {
            final TypeInfo tp = e.value;
            return ItemCard(
              title: '${tp.ico} ${tp.name}',
              small: '${tp.cost}💰 · ${tp.w}×${tp.h}',
              desc: tp.desc,
              selected: armed == e.key,
              onTap: () => ctl.arm(e.key),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        if (expandCost != null)
          AquaBtn('↕️ توسيع الدفيئة (+2 صفوف) · $expandCost💰', onTap: ctl.expand)
        else
          const NoteText('✔ الدفيئة في أقصى حجمها.'),
      ],
    );
  }
}

// ---------------------------------------------------------------- pipe tab

class _PipePanel extends StatelessWidget {
  final AquaController ctl;
  const _PipePanel({required this.ctl});

  @override
  Widget build(BuildContext context) {
    final AquaColors ac = context.aqua;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('🔧 الأنابيب توصل المضخة بالحوض وبأحواض الزراعة. اسحب إصبعك على الدفيئة لرسمها ($kPipeCost💰 للخلية).',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ac.ink)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              Expanded(child: AquaBtn('✏️ رسم',
                  selected: ctl.pipeMode == PipeMode.draw, onTap: () => ctl.setPipeMode(PipeMode.draw))),
              const SizedBox(width: 6),
              Expanded(child: AquaBtn('🧽 إزالة',
                  selected: ctl.pipeMode == PipeMode.erase, onTap: () => ctl.setPipeMode(PipeMode.erase))),
            ],
          ),
        ),
        const NoteText('المضخة تحتاج أنابيب متصلة بحوض السمك وبأحواض الزراعة حتى يصل الماء والمغذيات.'),
      ],
    );
  }
}

class _PlantPanel extends StatelessWidget {
  final AquaController ctl;
  const _PlantPanel({required this.ctl});

  @override
  Widget build(BuildContext context) {
    final AquaColors ac = context.aqua;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('اختر المحصول ثم المس (أو اسحب على) الخانات الفارغة في أحواض الزراعة.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ac.ink)),
        ),
        TwoColGrid(
          children: kCrops.entries.map((MapEntry<String, CropInfo> e) {
            final CropInfo c = e.value;
            return ItemCard(
              title: '${c.ico} ${c.name}',
              small: 'بذرة ${c.seed}💰 · بيع ${c.sell}💰',
              desc: '${c.tower ? "أفقي + برج" : "أحواض أفقية فقط"} · نضج ~${c.growSec.round()}ث',
              selected: ctl.crop == e.key,
              onTap: () => ctl.setCrop(e.key),
            );
          }).toList(),
        ),
        const NoteText('المس النبات الناضج ✨ (في تبويب «معلومات») لحصاده.'),
      ],
    );
  }
}

// --------------------------------------------------------------- store tab

class _StorePanel extends StatelessWidget {
  final AquaController ctl;
  const _StorePanel({required this.ctl});

  @override
  Widget build(BuildContext context) {
    final AquaColors ac = context.aqua;
    final Sim s = ctl.sim;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text.rich(
          TextSpan(style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ac.ink), children: <InlineSpan>[
            const TextSpan(text: '🍽️ طعام الأسماك: '),
            TextSpan(text: '${s.food}'),
            const TextSpan(text: ' وجبة'),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AquaBtn('+6 وجبات · 15💰', kind: BtnKind.primary, onTap: s.coins >= 15 ? ctl.buyFood : null),
        ),
        const NoteText('كل 4 أسماك تحتاج وجبة عند كل إطعام. الإفراط في الإطعام يلوّث الماء.'),
        const SubLabel('📊 الإحصاءات'),
        NoteText(
            '🌾 حصاد: ${s.statHarv} · 🐟 أسماك مباعة: ${s.statFish}\n💀 أسماك نافقة: ${s.statLost} · 🥀 نباتات ميتة: ${s.statPlost}'),
        const SizedBox(height: 4),
        AquaBtn('❓ كيف تلعب', onTap: ctl.openHelp),
      ],
    );
  }
}
