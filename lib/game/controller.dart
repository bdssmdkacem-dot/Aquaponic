import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';
import 'models.dart';
import 'sim.dart';
import 'util.dart';

enum AquaTab { info, build, pipe, plant, store }

enum AquaTool { select, build, pipe, plant }

enum PipeMode { draw, erase }

enum SelKind { obj, pipe }

class Selection {
  final SelKind kind;
  final int id; // object id, or pipe key
  int slot;
  Selection.obj(this.id, [this.slot = -1]) : kind = SelKind.obj;
  Selection.pipe(this.id)
      : kind = SelKind.pipe,
        slot = -1;
}

class MissionStep {
  final String txt;
  final bool Function(Sim) done;
  const MissionStep(this.txt, this.done);
}

final List<MissionStep> kMission = <MissionStep>[
  MissionStep('🎯 ابنِ حوض سمك: تبويب «بناء» ← حوض سمك ← المس مكاناً في الدفيئة',
      (Sim s) => s.objs.any((GameObj o) => o is Tank)),
  MissionStep('🐟 اضغط على الحوض ثم اشترِ صغار السمك',
      (Sim s) => s.objs.any((GameObj o) => o is Tank && o.n > 0)),
  MissionStep('💨 ضع مضخة أكسجين ملاصقة للحوض',
      (Sim s) => s.objs.any((GameObj o) => o is Air && o.tank != null)),
  MissionStep('💧 ضع مضخة ماء وحوض زراعة ووصّلهما بأنابيب (تبويب «أنابيب»)',
      (Sim s) => s.objs.any((GameObj o) => o is Bed && o.net != null && o.net!.cap > 0)),
  MissionStep('🌱 ازرع بذوراً في خانات الحوض (تبويب «زراعة»)',
      (Sim s) => s.objs.any((GameObj o) => o is Bed && o.slots.any((Slot x) => x.alive))),
  MissionStep('🍽️ أطعم الأسماك بانتظام، واحصد الناضج لتربح أول نقودك',
      (Sim s) => s.statHarv + s.statFish > 0),
  MissionStep('🏆 نظامك يعمل! وسّع المزرعة وأضف مغذّياً آلياً، وراقب التنبيهات',
      (Sim s) => false),
];

class _Ptr {
  final double sx;
  final double sy;
  int lx;
  int ly;
  final bool touch;
  bool moved = false;
  _Ptr(this.sx, this.sy, this.lx, this.ly, this.touch);
}

const List<int> kSpeeds = <int>[1, 2, 4, 0];

class AquaController extends ChangeNotifier {
  Sim sim;
  final SharedPreferences? _prefs;

  AquaTab tab = AquaTab.info;
  ObjType? armed;
  Pt? pending;
  Pt? hover;
  String crop = 'lettuce';
  PipeMode pipeMode = PipeMode.draw;
  Selection? sel;
  int? delArm;

  bool introOpen = false;
  bool helpOpen = false;
  bool resetArm = false;
  int? _speedBeforeModal;

  String? toastMsg;
  String toastKind = 'info';
  Timer? _toastTimer;

  double _acc = 0;
  double _uiT = 0;
  double _saveT = 0;
  _Ptr? _ptr;

  AquaController(this.sim, this._prefs, {bool fresh = false}) {
    _wire();
    if (fresh) _openModal(intro: true);
  }

  static Future<AquaController> create() async {
    SharedPreferences? prefs;
    Sim? loaded;
    try {
      prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(kSaveKey);
      if (raw != null) {
        final dynamic j = jsonDecode(raw);
        if (j is Map<String, dynamic>) loaded = Sim.fromJson(j);
      }
    } catch (_) {
      loaded = null;
    }
    return AquaController(loaded ?? Sim(), prefs, fresh: loaded == null);
  }

  void _wire() {
    sim.onToast = showToast;
  }

  // ------------------------------------------------------------- getters

  bool get modalOpen => introOpen || helpOpen;

  AquaTool get tool {
    switch (tab) {
      case AquaTab.pipe:
        return AquaTool.pipe;
      case AquaTab.plant:
        return AquaTool.plant;
      case AquaTab.build:
        return armed != null ? AquaTool.build : AquaTool.select;
 