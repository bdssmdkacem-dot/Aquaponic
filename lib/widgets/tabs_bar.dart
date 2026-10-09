import 'package:flutter/material.dart';

import '../game/controller.dart';
import '../theme.dart';

const List<(AquaTab, String, String)> _tabs = <(AquaTab, String, String)>[
  (AquaTab.info, '👆', 'معلومات'),
  (AquaTab.build, '🏗️', 'بناء'),
  (AquaTab.pipe, '🔧', 'أنابيب'),
  (AquaTab.plant, '🌱', 'زراعة'),
  (AquaTab.store, '🛒', 'المخزن'),
];

class TabsBar extends StatelessWidget {
  final AquaController ctl;
  const TabsBar({super.key, required this.ctl});

  @override
  Widget build(BuildContext context) {
    final AquaColors ac = context.aqua;
    return AnimatedBuilder(
      animation: ctl,
      builder: (BuildContext context, Widget? _) {
        return Row(
          children: _tabs.map((t) {
            final bool on = ctl.tab == t.$1;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: on ? ac.accent : ac.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => ctl.setTab(t.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: on ? ac.accent : ac.line),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(t.$2, style: const TextStyle(fontSize: 17)),
                          const SizedBox(height: 1),
                          Text(t.$3,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: on ? ac.onAccent : ac.ink)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
