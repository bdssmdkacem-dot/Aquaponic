import 'package:flutter/material.dart';
@immutable
class AquaColors extends ThemeExtension<AquaColors> {
 final Color bg, surface, ink, accent;
 const AquaColors({required this.bg,required this.surface,required this.ink,required this.accent});
 static const light=AquaColors(bg:Color(0xFFE9F3EE),surface:Colors.white,ink:Color(0xFF0F2D28),accent:Color(0xFF0B8A75));
 static const dark=AquaColors(bg:Color(0xFF0C1917),surface:Color(0xFF14272A),ink:Color(0xFFE3F3EE),accent:Color(0xFF2EC4A6));
 @override AquaColors copyWith({Color? bg,Color? surface,Color? ink,Color? accent})=>AquaColors(bg:bg??this.bg,surface:surface??this.surface,ink:ink??this.ink,accent:accent??this.accent);
 @override AquaColors lerp(ThemeExtension<AquaColors>? other,double t)=>this;
}
extension AquaColorsX on BuildContext {AquaColors get aqua=>Theme.of(this).extension<AquaColors>()??AquaColors.light;}
ThemeData buildAquaTheme(AquaColors c)=>ThemeData(useMaterial3:true,scaffoldBackgroundColor:c.bg,colorScheme:ColorScheme.fromSeed(seedColor:c.accent),extensions:<ThemeExtension<dynamic>>[c]);
