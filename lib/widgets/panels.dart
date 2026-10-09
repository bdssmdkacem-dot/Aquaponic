import 'package:flutter/material.dart';

import '../game/constants.dart';
import '../game/controller.dart';
import '../game/models.dart';
import '../theme.dart';

class GamePanel extends StatelessWidget {
  final AquaController ctl;
  const GamePanel({super.key, required this.ctl});

  @override
  Widget build(BuildContext context) {
    final AquaColors ac=context.aqua;
    return AnimatedBuilder(
      animation:ctl,
      builder:(BuildContext context,Widget? _) {
        final Widget body=switch(ctl.tab) {
          AquaTab.info=>_InfoPanel(ctl:ctl),
          AquaTab.build=>_BuildPanel(ctl:ctl),
          AquaTab.pipe=>_PipePanel(ctl:ctl),
          AquaTab.plant=>_PlantPanel(ctl:ctl),
          AquaTab.store=>_StorePanel(ctl:ctl),
        };
        return Container(
          padding:const EdgeInsets.all(12),
          decoration:BoxDecoration(color:ac.surface,borderRadius:BorderRadius.circular(16),border:Border.all(color:ac.line)),
          child:body,
        );
      },
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final AquaController ctl;
  const _InfoPanel({required this.ctl});
  @override
  Widget build(BuildContext context) {
    final AquaColors ac=context.aqua;
    final GameObj? o=ctl.selObj;
    if(o==null) {
      return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:<Widget>[
        Text('🌱 مزرعتك المائية',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800,color:ac.ink)),
        const SizedBox(height:6),
        Text('اختر حوضاً أو نباتاً أو جهازاً في المشهد لمعرفة حالته. ابدأ من تبويب «بناء» لوضع المعدات.',style:TextStyle(height:1.5,color:ac.muted)),
        const SizedBox(height:10),
        _StatLine(label:'عدد المعدات',value:ctl.sim.objs.length.toString(),colors:ac),
        _StatLine(label:'طول الأنابيب',value:ctl.sim.pipes.length.toString(),colors:ac),
        _StatLine(label:'الأسماك المباعة',value:ctl.sim.statFish.toString(),colors:ac),
        _StatLine(label:'المحاصيل المحصودة',value:ctl.sim.statHarv.toString(),colors:ac),
        const SizedBox(height:8),
        _ActionButton(label:'🎁 توسيع الدفيئة',onTap:ctl.expand,colors:ac),
      ]);
    }
    final List<Widget> actions=<Widget>[];
    String title=kTypes[o.type]!.name;
    String details='الموقع: ${o.x+1}, ${o.y+1}';
    if(o is Tank) {
      title=ctl.sim.tankName(o);
      final FishSpecies? sp=o.species;
      details='الأسماك: ${o.n}  •  النمو: ${(o.size*100).round()}%\nالأكسجين: ${o.o2.round()}%  •  الفضلات: ${o.waste.round()}%\nالجوع: ${o.hunger.round()}%  •  الصحة: ${o.health.round()}%';
      actions.add(_ActionButton(label:'🍽️ إطعام الأسماك',onTap:()=>ctl.feed(o),colors:ac));
      if(sp!=null&&o.n>0) actions.add(_ActionButton(label:'💰 بيع الأسماك',onTap:()=>ctl.sell(o),colors:ac));
      if(sp==null||o.n==0) for(final String key in kFish.keys) {
        final FishSpecies f=kFish[key]!;
        actions.add(_ActionButton(label:'🐟 شراء ${f.name} — ${f.price}💰/سمكة',onTap:()=>ctl.fry(o,key),colors:ac));
      }
      if(o.net!=null) details+='
المضخات العاملة في الشبكة: ${o.net!.active}';
      if(o.air==0) details+='
⚠️ لا توجد مضخة أكسجين ملاصقة.';
    } else if(o is Bed) {
      final int alive=o.slots.where((Slot s)=>s.alive).length;
      final int ready=o.slots.where((Slot s)=>s.alive&&s.g>=1).length;
      details='الخانات المزروعة: $alive / ${o.slots.length}\nالمحاصيل الناضجة: $ready\nالماء: ${o.net==null?'غير متصل':o.net!.ratio>0?'يصل إلى الحوض':'لا يوجد تدفق'}';
      actions.add(_ActionButton(label:'🌾 حصاد كل المحاصيل الناضجة',onTap:()=>ctl.harvestAll(o),colors:ac));
      actions.add(_ActionButton(label:'🧹 تنظيف النباتات الميتة',onTap:()=>ctl.cleanDead(o),colors:ac));
    } else if(o is Pump) {
      details=o.broken?'المضخة معطلة أو مسدودة.':'المضخة تعمل على تدوير الماء.';
      if(o.broken)actions.add(_ActionButton(label:'🔧 تنظيف المضخة',onTap:()=>ctl.fixPump(o),colors:ac));
    } else if(o is Air) {
      details=o.tank==null?'لا يوجد حوض سمك ملاصق.':'تزود ${ctl.sim.tankName(o.tank!)} بالأكسجين.';
    } else if(o is Feeder) {
      details=o.tank==null?'ضع المغذي بجانب حوض السمك.':'مغذٍ آلي — يعمل تلقائياً عندما تجوع الأسماك.';
    }
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:<Widget>[
      Row(children:<Widget>[Expanded(child:Text(title,style:TextStyle(fontSize:18,fontWeight:FontWeight.w800,color:ac.ink))),IconButton(onPressed:()=>ctl.setTab(AquaTab.info),icon:Icon(Icons.close,color:ac.muted))]),
      Text(details,style:TextStyle(color:ac.muted,height:1.55)),
      if(o.net!=null)...<Widget>[const SizedBox(height:8),Text(ctl.sim.netStatus(o.net).text,style:TextStyle(color:ctl.sim.netStatus(o.net).ok?ac.good:ac.danger,fontWeight:FontWeight.w700))],
      const SizedBox(height:10),
      ...actions.map((Widget w)=>Padding(padding:const EdgeInsets.only(bottom:7),child:w)),
      const SizedBox(height:3),
      _ActionButton(label:ctl.delArm==o.id?'اضغط مجدداً لتأكيد الحذف':'🗑️ إزالة العنصر',onTap:()=>ctl.deletePressed(o),colors:ac,danger:true),
    ]);
  }
}

class _BuildPanel extends StatelessWidget {
  final AquaController ctl;
  const _BuildPanel({required this.ctl});
  @override
  Widget build(BuildContext context) {
    final AquaColors ac=context.aqua;
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:<Widget>[
      Text('🧰 بناء المزرعة',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800,color:ac.ink)),
      const SizedBox(height:5),
      Text(ctl.armed==null?'اختر جهازاً ثم المس مكاناً فارغاً في المشهد.':'تم اختيار ${kTypes[ctl.armed]!.name} — المس مكاناً لوضعه.',style:TextStyle(color:ac.muted,height:1.4)),
      const SizedBox(height:10),
      Wrap(spacing:8,runSpacing:8,children:kTypes.entries.map((MapEntry<ObjType,TypeInfo> e)=>SizedBox(width:145,child:_ActionButton(label:'${e.value.ico} ${e.value.name}\n${e.value.cost} 💰',onTap:()=>ctl.arm(e.key),colors:ac,selected:ctl.armed==e.key))).toList()),
      if(ctl.pending!=null)...<Widget>[const SizedBox(height:10),_ActionButton(label:'✅ تأكيد المكان',onTap:ctl.okPlace,colors:ac),const SizedBox(height:6),_ActionButton(label:'إلغاء',onTap:ctl.cancelPlace,colors:ac)],
      const SizedBox(height:10),
      Text('الرصيد الحالي: ${ctl.sim.coins} 💰',style:TextStyle(color:ac.ink,fontWeight:FontWeight.w700)),
    ]);
  }
}

class _PipePanel extends StatelessWidget {
  final AquaController ctl;
  const _PipePanel({required this.ctl});
  @override
  Widget build(BuildContext context) {
    final AquaColors ac=context.aqua;
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:<Widget>[
      Text('💧 الأنابيب والماء',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800,color:ac.ink)),
      const SizedBox(height:6),
      Text('اسحب على الخلايا الفارغة لرسم الأنابيب وربط المضخة بحوض السمك وأحواض الزراعة.',style:TextStyle(color:ac.muted,height:1.5)),
      const SizedBox(height:10),
      SegmentedButton<PipeMode>(segments:const <ButtonSegment<PipeMode>>[ButtonSegment<PipeMode>(value:PipeMode.draw,label:Text('رسم الأنابيب'),icon:Icon(Icons.add)),ButtonSegment<PipeMode>(value:PipeMode.erase,label:Text('إزالة الأنابيب'),icon:Icon(Icons.remove))],selected:<PipeMode>{ctl.pipeMode},onSelectionChanged:(Set<PipeMode> s)=>ctl.setPipeMode(s.first)),
      const SizedBox(height:8),
      _StatLine(label:'الأنابيب الموضوعة',value:ctl.sim.pipes.length.toString(),colors:ac),
      _StatLine(label:'تكلفة الأنبوب',value:'$kPipeCost 💰',colors:ac),
      ...ctl.sim.nets.map((Net n)=>Padding(padding:const EdgeInsets.only(top:6),child:Text(ctl.sim.netStatus(n).text,style:TextStyle(color:ctl.sim.netStatus(n).ok?ac.good:ac.danger)))),
    ]);
  }
}

class _PlantPanel extends StatelessWidget {
  final AquaController ctl;
  const _PlantPanel({required this.ctl});
  @override
  Widget build(BuildContext context) {
    final AquaColors ac=context.aqua;
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:<Widget>[
      Text('🌿 الزراعة',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800,color:ac.ink)),
      const SizedBox(height:6),
      Text('اختر نوع البذور ثم المس خانات حوض الزراعة. الزراعة تستهلك نقوداً وتحتاج ماءً وفضلات أسماك.',style:TextStyle(color:ac.muted,height:1.5)),
      const SizedBox(height:10),
      Wrap(spacing:8,runSpacing:8,children:kCrops.entries.map((MapEntry<String,CropInfo> e)=>SizedBox(width:145,child:_ActionButton(label:'${e.value.ico} ${e.value.name}\nبذور: ${e.value.seed} 💰',onTap:()=>ctl.setCrop(e.key),colors:ac,selected:ctl.crop==e.key))).toList()),
      const SizedBox(height:10),
      Text('البذور المختارة: ${kCrops[ctl.crop]!.name}',style:TextStyle(color:ac.ink,fontWeight:FontWeight.w700)),
    ]);
  }
}

class _StorePanel extends StatelessWidget {
  final AquaController ctl;
  const _StorePanel({required this.ctl});
  @override
  Widget build(BuildContext context) {
    final AquaColors ac=context.aqua;
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:<Widget>[
      Text('🛒 المخزن والاقتصاد',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800,color:ac.ink)),
      const SizedBox(height:8),
      _StatLine(label:'النقود',value:'${ctl.sim.coins} 💰',colors:ac),
      _StatLine(label:'طعام السمك',value:ctl.sim.food.toString(),colors:ac),
      _StatLine(label:'المحاصيل المحصودة',value:ctl.sim.statHarv.toString(),colors:ac),
      _StatLine(label:'الأسماك المباعة',value:ctl.sim.statFish.toString(),colors:ac),
      const SizedBox(height:10),
      _ActionButton(label:'🍽️ شراء 6 حصص طعام — 15 💰',onTap:()=>ctl.buyFood(),colors:ac),
      const SizedBox(height:8),
      _ActionButton(label:'🏗️ توسيع الدفيئة — ${ctl.sim.rows} صفوف حالياً',onTap:ctl.expand,colors:ac),
      const SizedBox(height:8),
      _ActionButton(label:'💾 حفظ التقدم الآن',onTap:()=>ctl.save(),colors:ac),
    ]);
  }
}

class _StatLine extends StatelessWidget {
  final String label,value;
  final AquaColors colors;
  const _StatLine({required this.label,required this.value,required this.colors});
  @override
  Widget build(BuildContext context)=>Padding(
    padding:const EdgeInsets.symmetric(vertical:4),
    child:Row(children:<Widget>[Expanded(child:Text(label,style:TextStyle(color:colors.muted))),Text(value,style:TextStyle(color:colors.ink,fontWeight:FontWeight.w800))]),
  );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final AquaColors colors;
  final bool selected,danger;
  const _ActionButton({required this.label,required this.onTap,required this.colors,this.selected=false,this.danger=false});
  @override
  Widget build(BuildContext context)=>Material(
    color:selected?colors.accent.withOpacity(0.15):danger?colors.danger.withOpacity(0.08):colors.surface2,
    borderRadius:BorderRadius.circular(11),
    child:InkWell(
      borderRadius:BorderRadius.circular(11),onTap:onTap,
      child:Container(
        width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:11,vertical:10),
        decoration:BoxDecoration(borderRadius:BorderRadius.circular(11),border:Border.all(color:selected?colors.accent:danger?colors.danger:colors.line)),
        child:Text(label,textAlign:TextAlign.center,style:TextStyle(color:danger?colors.danger:colors.ink,fontWeight:FontWeight.w700,fontSize:13,height:1.35)),
      ),
    ),
  );
}
