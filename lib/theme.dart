import 'package:flutter/material.dart';

@immutable
class AquaColors extends ThemeExtension<AquaColors> {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color ink;
  final Color muted;
  final Color line;
  final Color accent;
  final Color onAccent;
  final Color danger;
  final Color warn;
  final Color good;

  const AquaColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.warn,
    required this.good,
  });

  static const AquaColors light = AquaColors(
    bg: Color(0xFFE9F3EE),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFE2EEE8),
    ink: Color(0xFF0F2D28),
    muted: Color(0xFF557068),
    line: Color(0xFFC9DDD3),
    accent: Color(0xFF0B8A75),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFD63A41),
    warn: Color(0xFFC98100),
    good: Color(0xFF278F4A),
  );

  static const AquaColors dark = AquaColors(
    bg: Color(0xFF0C1917),
    surface: Color(0xFF14272A),
    surface2: Color(0xFF1C3538),
    ink: Color(0xFFE3F3EE),
    muted: Color(0xFF93B5AB),
    line: Color(0xFF2A4B49),
    accent: Color(0xFF2EC4A6),
    onAccent: Color(0xFF04221C),
    danger: Color(0xFFFF6F74),
    warn: Color(0xFFF2B23C),
    good: Color(0xFF5DD688),
  );

  @override
  AquaColors copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? ink,
    Color? muted,
    Color? line,
    Color? accent,
    Color? onAccent,
    Color? danger,
    Color? warn,
    Color? good,
  }) {
    return AquaColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      danger: danger ?? this.danger,
      warn: warn ?? this.warn,
      good: good ?? this.good,
    );
  }

  @override
  AquaColors lerp(ThemeExtension<AquaColors>? other, double t) {
    if (other is! AquaColors) return this;
    return AquaColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      good: Color.lerp(good, other.good, t)!,
    );
  }
}

extension AquaColorsX on BuildContext {
  AquaColors get aqua => Theme.of(this).extension<AquaColors>() ?? AquaColors.light;
}

ThemeData buildAquaTheme(AquaColors c) {
  return ThemeData(
    useMaterial3: true,
    brightness: c == AquaColors.dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: c == AquaColors.dark ? Brightness.dark : Brightness.light,
      primary: c.accent,
      surface: c.surface,
    ),
    extensions: <ThemeExtension<dynamic>>[c],
  );
}
