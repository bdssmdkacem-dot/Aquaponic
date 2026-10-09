# Aquaponics (Flutter)

Native Android/iOS port of the Aquaponics web game: build fish tanks, oxygen
pumps, water pumps, pipes and grow beds/towers; keep fish fed and oxygenated
and plants watered and fertilized by fish waste, or they die. Arabic UI, RTL,
light/dark theme, autosave via `shared_preferences`.

## Structure

```
lib/
  game/        pure Dart simulation (no Flutter deps except Color):
               constants.dart, util.dart, models.dart, sim.dart,
               controller.dart (ChangeNotifier gluing sim + UI state),
               scene_painter.dart (CustomPainter port of the canvas renderer)
  widgets/     Flutter UI: stage.dart (ticker + gesture input + canvas),
               hud_bar.dart, tabs_bar.dart, panels.dart, modals.dart,
               common.dart, game_screen.dart
  theme.dart   light/dark color tokens (ThemeExtension)
  main.dart    entry point
```

## Setup

This was written and syntax-checked (tree-sitter, 0 parse errors across all
15 files) in a sandbox with no access to the Flutter SDK or pub.dev, so it has
**not** been compiled or run. Carefully reviewed for API correctness, but
run `flutter analyze` first thing.

```bash
cd aquaponics_flutter
flutter create . --platforms=android,ios   # adds android/ios/ scaffolding;
                                            # safe, won't touch lib/ or pubspec.yaml
flutter pub get
flutter analyze
flutter run
```

If `flutter analyze` flags anything, it's most likely a minor type nit — the
simulation logic (`lib/game/`) is the part worth testing carefully first
(it's pure Dart, testable headless without a device):

```dart
// quick sanity check you can run in a throwaway main() or test:
final sim = Sim()..starter();
for (int i = 0; i < 1000; i++) sim.stepSim(0.2);
print('${sim.coins} coins, tank fish: ${(sim.objs.first as Tank).n}');
```

## Known gaps vs. the web version

- No bundled "Cairo" font — uses the system default (renders Arabic fine on
  Android/iOS via Noto Sans Arabic fallback, just a different look).
- Dashed mission-banner border simplified to a solid border.
- Everything else (simulation rules, balance numbers, panel layouts, build/
  pipe/plant tools, two-step delete confirm, starter system, autosave,
  day/night cycle, warnings) is a direct port.

## Building a release APK

```bash
flutter build apk --release
# or: flutter build appbundle --release
```
