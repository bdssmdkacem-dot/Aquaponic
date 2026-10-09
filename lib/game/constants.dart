import 'dart:ui';

const int kCols = 9;
const int kMinRows = 10;
const double kDaySec = 60;
const double kStep = 0.2;
const int kPipeCost = 2;
const int kPumpCap = 8;
const int kFishCap = 16;
const List<int> kExpand = [250, 400, 600];
const String kSaveKey = 'aquaponics-save-v1';

const List<List<int>> kDirs = [
  [1, 0], [-1, 0], [0, 1], [0, -1],
];

enum ObjType { tank, bed, tower, pump, air, feeder }

class TypeInfo {
  final String name;
  final int w;
  final int h;
  final int cost;
  final String ico;
  final String desc;
  const TypeInfo(this.name, this.w, this.h, this.cost, this.ico, this.desc);
}

const Map<ObjType, TypeInfo> kTypes = {
  ObjType.tank: TypeInfo('حوض سمك', 4, 3, 120, '🐟', 'يتسع لـ16 سمكة'),
  ObjType.bed: TypeInfo('حوض زراعة أفقي', 4, 2, 70, '🌱', '4 خانات لكل المحاصيل'),
  ObjType.tower: TypeInfo('برج عمودي', 2, 4, 100, '🌿', '6 خانات للخس والنعناع'),
  ObjType.pump: TypeInfo('مضخة ماء', 1, 1, 45, '💧', 'تكفي 8 نباتات'),
  ObjType.air: TypeInfo('مضخة أكسجين', 1, 1, 30, '💨', 'ضعها ملاصقة للحوض'),
  ObjType.feeder: TypeInfo('مغذٍّ آلي', 1, 1, 80, '🥣', 'يطعم الحوض الملاصق'),
};

class FishSpecies {
  final String key; final String name; final int price; final int sell;
  final double growSec; final double o2; final double waste; final double o2Min;
  final double hunger; final Color body; final Color tail;
  const FishSpecies({required this.key, required this.name, required this.price,
    required this.sell, required this.growSec, required this.o2, required this.waste,
    required this.o2Min, required this.hunger, required this.body, required this.tail});
}

const Map<String, FishSpecies> kFish = {
  'tilapia': FishSpecies(key:'tilapia', name:'بلطي', price:8, sell:24, growSec:200, o2:1.0, waste:1.0, o2Min:28, hunger:0.30, body:Color(0xFFF0895E), tail:Color(0xFFD4573A)),
  'carp': FishSpecies(key:'carp', name:'شبوط', price:6, sell:18, growSec:170, o2:0.85, waste:1.25, o2Min:22, hunger:0.28, body:Color(0xFFE6B64A), tail:Color(0xFFC98A1E)),
  'trout': FishSpecies(key:'trout', name:'سلمون مرقط', price:20, sell:66, growSec:300, o2:1.5, waste:1.1, o2Min:50, hunger:0.36, body:Color(0xFF8EA9CF), tail:Color(0xFF5F7FAE)),
};

class CropInfo {
  final String key; final String name; final String ico; final int seed; final int sell;
  final double growSec; final double nut; final bool tower; final Color color;
  const CropInfo({required this.key, required this.name, required this.ico, required this.seed,
    required this.sell, required this.growSec, required this.nut, required this.tower, required this.color});
}

const Map<String, CropInfo> kCrops = {
  'lettuce': CropInfo(key:'lettuce', name:'خس', ico:'🥬', seed:4, sell:14, growSec:100, nut:0.025, tower:true, color:Color(0xFF5CBF4A)),
  'mint': CropInfo(key:'mint', name:'نعناع', ico:'🌿', seed:3, sell:10, growSec:80, nut:0.02, tower:true, color:Color(0xFF38A865)),
  'tomato': CropInfo(key:'tomato', name:'طماطم', ico:'🍅', seed:8, sell:34, growSec:200, nut:0.045, tower:false, color:Color(0xFF4F9D3C)),
  'strawberry': CropInfo(key:'strawberry', name:'فراولة', ico:'🍓', seed:10, sell:42, growSec:240, nut:0.04, tower:false, color:Color(0xFF48A04A)),
};
