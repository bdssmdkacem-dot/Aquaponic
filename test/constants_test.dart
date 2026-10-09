import 'package:flutter_test/flutter_test.dart';

import '../lib/game/constants.dart';

void main() {
  group('Aquaponics game configuration', () {
    test('grid and simulation timing have valid dimensions', () {
      expect(kCols, 9);
      expect(kMinRows, greaterThan(0));
      expect(kDaySec, greaterThan(0));
      expect(kStep, greaterThan(0));
    });

    test('every fish species has valid economy and growth values', () {
      expect(kFish, isNotEmpty);
      for (final FishSpecies fish in kFish.values) {
        expect(fish.key, isNotEmpty);
        expect(fish.price, greaterThan(0));
        expect(fish.sell, greaterThan(fish.price));
        expect(fish.growSec, greaterThan(0));
        expect(fish.o2Min, greaterThan(0));
      }
    });

    test('crop tower restrictions are defined consistently', () {
      expect(kCrops['lettuce']!.tower, isTrue);
      expect(kCrops['mint']!.tower, isTrue);
      expect(kCrops['tomato']!.tower, isFalse);
      expect(kCrops['strawberry']!.tower, isFalse);
      for (final CropInfo crop in kCrops.values) {
        expect(crop.seed, greaterThan(0));
        expect(crop.sell, greaterThan(0));
        expect(crop.growSec, greaterThan(0));
      }
    });

    test('all buildable object types have positive size and cost', () {
      expect(kTypes.length, ObjType.values.length);
      for (final MapEntry<ObjType, TypeInfo> entry in kTypes.entries) {
        expect(entry.value.w, greaterThan(0), reason: entry.key.name);
        expect(entry.value.h, greaterThan(0), reason: entry.key.name);
        expect(entry.value.cost, greaterThan(0), reason: entry.key.name);
      }
    });
  });
}
