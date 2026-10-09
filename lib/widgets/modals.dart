import 'package:flutter/material.dart';

import '../game/controller.dart';
import '../theme.dart';
import 'common.dart';

class GameModals extends StatelessWidget {
  final AquaController ctl;
  const GameModals({super.key, required this.ctl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctl,
      builder: (BuildContext context, Widget? _) {
        if (!ctl.modalOpen) return const SizedBox.shrink();
        return Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Container(
              color: const Color(0x9E041412),
              alignment: Alignment.center,
              padding: EdgeInsets.fromLTRB(
                16,
                16 + MediaQuery.of(context).padding.top,
                16,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  child: _ModalCard(ctl: ctl),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ModalCard extends StatelessWidget {
  final AquaController ctl;
  const _ModalCard({required this.ctl});

  @override
  Widget build(BuildContext context) {
    final AquaColors ac = context.aqua;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ac.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ac.line),
      ),
      child: ctl.introOpen ? _IntroContent(ctl: ctl) : _HelpContent(ctl: ctl),
    );
  }
}

class _IntroContent extends StatelessWidget {
  final AquaController ctl;
  const _IntroContent({required this.ctl});

  @override
  Widget build(BuildContext context) {
    final AquaColors ac = context.aqua;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('🐟 Aquaponics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ac.ink)),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 14, color: ac.ink, height: 1.6),
            children: const <InlineSpan>[
              TextSpan(text: 'ابنِ نظام أكوابونيك متكاملاً: '),
              TextSpan(text: 'الأسماك', style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: ' تنتج فضلات ← '),
              TextSpan(text: 'المضخة والأنابيب', style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: ' تنقلها ← '),
              TextSpan(text: 'النباتات', style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: ' تتغذى وتنظّف الماء.'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '⚠️ الإهمال يقتل: نقص الأكسجين أو الجوع أو الفضلات العالية يقتل الأسماك، وانقطاع الماء أو التغذية يقتل النباتات.',
          style: TextStyle(fontSize: 14, color: ac.ink, height: 1.6),
        ),
        const SizedBox(height: 14),
        AquaBtn('🌱 ابدأ من الصفر (مع إرشادات)',
            kind: BtnKind.primary, onTap: () => ctl.newGame(withStarter: false)),
        const SizedBox(height: 6),
        AquaBtn('⚡ ابدأ بنظام جاهز', onTap: () => ctl.newGame(withStarter: true)),
      ],
    );
  }
}

class _HelpContent extends StatelessWidget {
  final AquaController ctl;
  const _HelpContent({required this.ctl});

  static const List<String> _steps = <String>[
    'ابنِ حوض سمك، ثم اضغط عليه واشترِ صغار السمك.',
    'ضع مضخة أكسجين ملاصقة للحوض.',
    'ضع مضخة ماء وحوض زراعة (أفقي أو برج) ووصّلها بأنابيب: اسحب إصبعك في تبويب «أنابيب».',
    'ازرع من تبويب «زراعة»، وأطعم الأسماك بانتظام.',
    'احصد المحصول وبِع الأسماك الناضجة لتوسّع المزرعة.',
  ];

  @override
  Widget build(BuildContext context) {
    final AquaColors ac = context.aqua;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('❓ كيف تلعب', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ac.ink)),
        const SizedBox(height: 10),
        ...List<Widget>.generate(_steps.length, (int i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('${i + 1}. ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ac.ink)),
                Expanded(child: Text(_steps[i], style: TextStyle(fontSize: 14, color: ac.ink, height: 1.5))),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        Text(
          '💡 المس أي أنبوب لتعرف إن كانت الشبكة تعمل. كلما زادت الأسماك احتجت نباتات أكثر لتنظيف الماء.',
          style: TextStyle(fontSize: 13, color: ac.muted, height: 1.5),
        ),
        const SizedBox(height: 14),
        AquaBtn('متابعة اللعب', kind: BtnKind.primary, onTap: ctl.closeModal),
        const SizedBox(height: 6),
        AquaBtn(ctl.resetArm ? '⚠️ اضغط للتأكيد — سيُحذف كل التقدم' : '🔄 لعبة جديدة',
            kind: BtnKind.danger, onTap: ctl.resetPressed),
      ],
    );
  }
}
