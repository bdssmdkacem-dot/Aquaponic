import 'package:flutter/material.dart';

import '../game/controller.dart';
import '../theme.dart';
import 'hud_bar.dart';
import 'modals.dart';
import 'panels.dart';
import 'stage.dart';
import 'tabs_bar.dart';

class GameScreen extends StatefulWidget {
  final AquaController ctl;
  const GameScreen({super.key, required this.ctl});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      widget.ctl.save();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.ctl.save();
    widget.ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AquaColors ac = context.aqua;
    return Scaffold(
      backgroundColor: ac.bg,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: LayoutBuilder(builder: (BuildContext context, BoxConstraints cts) {
                    final bool wide = cts.maxWidth >= 880;
                    final Widget hud = HudBar(ctl: widget.ctl);
                    final Widget mission = MissionBanner(ctl: widget.ctl);
                    final Widget stage = GameStage(ctl: widget.ctl);
                    final Widget side = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        TabsBar(ctl: widget.ctl),
                        const SizedBox(height: 8),
                        GamePanel(ctl: widget.ctl),
                      ],
                    );
                    if (!wide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          hud,
                          const SizedBox(height: 8),
                          mission,
                          const SizedBox(height: 8),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: stage,
                            ),
                          ),
                          const SizedBox(height: 8),
                          side,
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        hud,
                        const SizedBox(height: 8),
                        mission,
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500), child: stage),
                            const SizedBox(width: 14),
                            Expanded(child: side),
                          ],
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            GameModals(ctl: widget.ctl),
          ],
        ),
      ),
    );
  }
}
