import 'package:flutter/material.dart';

import 'game/controller.dart';
import 'theme.dart';
import 'widgets/game_screen.dart';

void main() {
  runApp(const AquaponicsApp());
}

class AquaponicsApp extends StatelessWidget {
  const AquaponicsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aquaponics',
      debugShowCheckedModeBanner: false,
      theme: buildAquaTheme(AquaColors.light),
      darkTheme: buildAquaTheme(AquaColors.dark),
      themeMode: ThemeMode.system,
      builder: (BuildContext context, Widget? child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
      home: const _Loader(),
    );
  }
}

class _Loader extends StatefulWidget {
  const _Loader();

  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  late final Future<AquaController> _future;

  @override
  void initState() {
    super.initState();
    _future = AquaController.create();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AquaController>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<AquaController> snap) {
        if (!snap.hasData) {
          final AquaColors ac = context.aqua;
          return Scaffold(
            backgroundColor: ac.bg,
            body: Center(
              child: Text('🐟', style: TextStyle(fontSize: 48, color: ac.ink)),
            ),
          );
        }
        return GameScreen(ctl: snap.data!);
      },
    );
  }
}
