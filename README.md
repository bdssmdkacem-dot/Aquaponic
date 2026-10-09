
# Aquaponics (Flutter)

Native Android/iOS port of the Aquaponics web game: build fish tanks, oxygen pumps, water pumps, pipes and grow beds/towers; keep fish fed and oxygenated and plants watered and fertilized by fish waste, or they die. Arabic UI, RTL, light/dark theme, autosave via `shared_preferences`.

## Structure

- `lib/game/`: Dart simulation, models, controller, and canvas renderer.
- `lib/widgets/`: Flutter interface widgets.
- `lib/theme.dart`: light/dark color tokens.
- `lib/main.dart`: app entry point.
- `pubspec.yaml`: Flutter package and dependencies.

## Setup

The source has not yet been compiled or run with the Flutter SDK. After cloning, run:

```bash
flutter create . --platforms=android,ios
flutter pub get
flutter analyze
flutter run
```

If analysis reports issues, fix them before release. For a release APK, run `flutter build apk --release`; for Google Play, use `flutter build appbundle --release`.

## Known gaps

- No bundled Cairo font; Arabic uses the platform's default Arabic font.
- The dashed mission-banner border is simplified to a solid border.
