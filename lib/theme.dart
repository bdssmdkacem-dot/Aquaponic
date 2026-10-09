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
  final Color good;
  final Color danger;

  const AquaColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.good,
    required this.danger,
  });

  static const AquaColors light = AquaColors(
    bg: Color(0xFFE9F3EE),
    surface: Colors.white,
    surface2: Color(0xFFF1F7F3),
    ink: Color(0xFF0F2D28),
    muted: Color(0xFF607A72),
    line: Color(0xFFD5E5DC),
    accent: Color(0xFF0B8A75),
    onAccent: Colors.white,
    good: Color(0xFF218653),
    danger: Color(0xFFBD3C42),
  );

  static const AquaColors dark = AquaColors(
    bg: Color(0xFF0C1917),
    surface: Color(0xFF14272A),
    surface2: Color(0xFF1B3435),
    ink: Color(0xFFE3F3EE),
    muted: Color(0xFF9CB8AE),
    line: Color(0xFF31514C),
    accent: Color(0xFF2EC4A6),
    onAccent: Color(0xFF08211D),
    good: Color(0xFF67D69A),
    danger: Color(0xFFFF777C),
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
    Color? good,
    Color? danger,
  }) => AquaColors(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surface2: surface2 ?? this.surface2,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    line: line ?? this.line,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    good: good ?? this.good,
    danger: danger ?? this.danger,
  );

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
      good: Color.lerp(good, other.good, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension AquaColorsX on BuildContext {
  AquaColors get aqua =>
      Theme.of(this).extension<AquaColors>() ?? AquaColors.light;
}

ThemeData buildAquaTheme(AquaColors c) => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: c.bg,
      colorScheme: ColorScheme.fromSeed(seedColor: c.accent),
      extensions: <ThemeExtension<dynamic>>[c],
    );
