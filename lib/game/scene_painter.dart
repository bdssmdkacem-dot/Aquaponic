import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'constants.dart';
import 'controller.dart';
import 'models.dart';
import 'util.dart';

/// Paints the greenhouse scene in logical grid coordinates.
class ScenePainter {
  final AquaController ctl;
  ScenePainter(this.ctl);

  void paint(Canvas canvas, Size size, double time) {
    final SimLike sim = SimLike(ctl);
    final double cw = size.width / kCols;
    final double ch = size.height / ctl.sim.rows;
    canvas.save();
    canvas.scale(cw, ch);
    _background(canvas, ctl.sim.rows.toDouble(), time);
    _pipes(canvas, sim, time);
    _objects(canvas, sim, time);
    _effects(canvas, sim, time);
    _selection(canvas, sim);
    canvas.restore();
  }

  void _background(Canvas c, double rows, double time) {
    final Paint p = Paint();
    p.color = const Color(0xFFD9EBDD);
    c.drawRect(Rect.fromLTWH(0,0,kCols.toDouble(),rows),p);
    p.color = const Color(0xFFE8F3E8);
    for (int y=0;y<rows;y++) {
      for(int x=0;x<kCols;x++) {
        if((x+y)%2==0)c.drawRect(Rect.fromLTWH(x.toDouble(),y.toDouble(),1,1),p);
      }
    }
    p..color=const Color(0x332A755F)..strokeWidth=0.018..style=PaintingStyle.stroke;
    for(int x=0;x<=kCols;x++)c.drawLine(Offset(x.toDouble(),0),Offset(x.toDouble(),rows),p);
    for(int y=0;y<=rows;y++)c.drawLine(Offset(0,y.toDouble()),Offset(kCols.toDouble(),y.toDouble()),p);
    p..style=PaintingStyle.fill..color=const Color(0xFFB3D4B9);
    c.drawRect(Rect.fromLTWH(0,0,kCols.toDouble(),0.16),p);
    c.drawRect(Rect.fromLTWH(0,rows-0.16,kCols.toDouble(),0.16),p);
    p..color=const Color(0x18234F44)..strokeWidth=0.04..style=PaintingStyle.stroke;
    c.drawLine(Offset(0.1,0.17),Offset(kCols-0.1,0.17),p);
    c.drawLine(Offset(0.1,rows-0.17),Offset(kCols-0.1,rows-0.17),p);
  }

  void _pipes(Canvas c, SimLike s, double time) {
    final Paint p=Paint()..strokeCap=StrokeCap.round..style=PaintingStyle.stroke;
    for(final int key in ctl.sim.pipes) {
      final int x=key%kCols,y=key~/kCols;
      p..color=const Color(0xFF2B8290)..strokeWidth=0.23;
      c.drawLine(Offset(x+0.5,y+0.5),Offset(x+0.5,y+0.5),p);
      p..color=const Color(0xFF9BE0D5)..strokeWidth=0.08;
      c.drawLine(Offset(x+0.5,y+0.5),Offset(x+0.5,y+0.5),p);
      for(final List<int> d in const <List<int>>[[1,0],[0,1]]) {
        final int nx=x+d[0],ny=y+d[1];
        if(ctl.sim.inb(nx,ny)&&ctl.sim.isPipe(nx,ny)) {
          p..color=const Color(0xFF2B8290)..strokeWidth=0.23;
          c.drawLine(Offset(x+0.5,y+0.5),Offset(nx+0.5,ny+0.5),p);
          p..color=const Color(0xFF9BE0D5)..strokeWidth=0.07;
          c.drawLine(Offset(x+0.5,y+0.5),Offset(nx+0.5,ny+0.5),p);
        }
      }
    }
  }

  void _objects(Canvas c, SimLike s, double time) {
    for(final GameObj o in ctl.sim.objs) {
      final Rect r=Rect.fromLTWH(o.x+0.06,o.y+0.06,o.w-0.12,o.h-0.12);
      final RRect rr=RRect.fromRectAndRadius(r,const Radius.circular(0.12));
      final Paint p=Paint()..style=PaintingStyle.fill;
      if(o is Tank) {
        p.color=const Color(0xFF4F9EB0);c.drawRRect(rr,p);
        p.color=const Color(0xFFB9E8E8);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.x+0.13,o.y+0.17,o.w-0.26,o.h-0.34),const Radius.circular(0.1)),p);
        p..color=const Color(0xFF5CA7B7)..style=PaintingStyle.fill;
        final double wave=math.sin(time*2+o.id)*0.035;
        c.drawRect(Rect.fromLTWH(o.x+0.14,o.y+0.3+wave,o.w-0.28,o.h-0.45),p);
        if(o.n>0) {
          for(int i=0;i<math.min(o.n,8);i++) {
            final double fx=o.x+0.35+((i*37+o.id*13)%100)/100*(o.w-0.7);
            final double fy=o.y+0.45+((i*19+o.id*7)%100)/100*(o.h-0.7);
            p.color=const Color(0xFFFFB84A);
            c.drawOval(Rect.fromCenter(center:Offset(fx,fy),width:0.24,height:0.13),p);
            p..color=const Color(0xFF9D5B26)..strokeWidth=0.035..style=PaintingStyle.stroke;
            c.drawLine(Offset(fx-0.08,fy),Offset(fx+0.1,fy),p);
            p.style=PaintingStyle.fill;
          }
        }
        _label(c,o.x+o.w/2,o.y+0.12,'🐟',0.25);
        _meter(c,o.x+0.18,o.y+o.h-0.18,o.w-0.36,o.o2/100,const Color(0xFF1B9C9A));
      } else if(o is Bed) {
        p.color=const Color(0xFF8D6745);c.drawRRect(rr,p);
        p.color=const Color(0xFFB38B5D);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.x+0.12,o.y+0.12,o.w-0.24,o.h-0.24),const Radius.circular(0.07)),p);
        for(int i=0;i<o.slots.length;i++) {
          final Pt pos=slotPos(o,i);final Slot slot=o.slots[i];
          final Rect sr=Rect.fromLTWH(pos.x+0.08,pos.y+0.08,0.84,0.84);
          p.color=const Color(0xFF6E4D35);c.drawRRect(RRect.fromRectAndRadius(sr,const Radius.circular(0.08)),p);
          if(slot.alive) {
            final double scale=0.25+slot.g*0.28;
            p.color=slot.g>=1?const Color(0xFF4D9D42):const Color(0xFF62B85B);
            c.drawOval(Rect.fromCenter(center:Offset(pos.x+0.5,pos.y+0.5),width:scale*1.8,height:scale),p);
            p..color=const Color(0xFF286F39)..strokeWidth=0.045..style=PaintingStyle.stroke;
            c.drawLine(Offset(pos.x+0.5,pos.y+0.65),Offset(pos.x+0.5,pos.y+0.35),p);p.style=PaintingStyle.fill;
            if(slot.g>=1){p.color=const Color(0xFFFFD65A);c.drawCircle(Offset(pos.x+0.5,pos.y+0.28),0.09,p);}
          } else if(slot.dead) {
            p..color=const Color(0xFF795548)..strokeWidth=0.07..style=PaintingStyle.stroke;
            c.drawLine(Offset(pos.x+0.25,pos.y+0.25),Offset(pos.x+0.75,pos.y+0.75),p);
            c.drawLine(Offset(pos.x+0.75,pos.y+0.25),Offset(pos.x+0.25,pos.y+0.75),p);p.style=PaintingStyle.fill;
          }
        }
        _label(c,o.x+o.w/2,o.y+0.12,o.type==ObjType.tower?'🌿':'🌱',0.23);
      } else if(o is Pump) {
        p.color=o.broken?const Color(0xFFB85C4C):const Color(0xFF4B8797);c.drawRRect(rr,p);
        p.color=const Color(0xFFD7F1E8);c.drawCircle(Offset(o.x+o.w/2,o.y+o.h/2),math.min(o.w,o.h)*0.28,p);
        p..color=const Color(0xFF34717C)..strokeWidth=0.09..style=PaintingStyle.stroke;
        c.drawCircle(Offset(o.x+o.w/2,o.y+o.h/2),math.min(o.w,o.h)*0.19,p);p.style=PaintingStyle.fill;
        _label(c,o.x+o.w/2,o.y+0.13,o.broken?'🔧':'💧',0.22);
      } else if(o is Air) {
        p.color=const Color(0xFF5B9EB0);c.drawRRect(rr,p);
        p.color=const Color(0xFFDCF8FA);
        for(int i=0;i<3;i++)c.drawCircle(Offset(o.x+0.28+i*0.22,o.y+0.55-math.sin(time*3+i)*0.08),0.06+i*0.015,p);
        _label(c,o.x+o.w/2,o.y+0.1,'💨',0.22);
      } else if(o is Feeder) {
        p.color=const Color(0xFFD8A34D);c.drawRRect(rr,p);
        _label(c,o.x+o.w/2,o.y+o.h/2,'🍽️',0.27);
      }
      if(o.net!=null&&o.net!.ratio>0) {
        p..color=const Color(0xFF43A78E)..strokeWidth=0.035..style=PaintingStyle.stroke;
        c.drawRRect(RRect.fromRectAndRadius(r,const Radius.circular(0.12)),p);p.style=PaintingStyle.fill;
      }
    }
  }

  void _effects(Canvas c, SimLike s, double time) {
    final Paint p=Paint();
    for(final FoodPart f in ctl.sim.parts) {
      p.color=const Color(0xFFFFD16B);c.drawCircle(Offset(f.x,f.y),0.045,p);
    }
    for(final Floater f in ctl.sim.floaters) {
      final double a=(1-f.age/1.4).clamp(0.0,1.0);
      final TextPainter tp=TextPainter(text:TextSpan(text:f.txt,style:TextStyle(color:f.col.withOpacity(a),fontSize:0.25,fontWeight:FontWeight.bold)),textDirection:TextDirection.ltr)..layout();
      tp.paint(c,Offset(f.x-tp.width/2,f.y-f.age*0.3));
    }
  }

  void _selection(Canvas c, SimLike s) {
    final Paint p=Paint()..style=PaintingStyle.stroke..strokeWidth=0.06..color=const Color(0xFF146B66);
    final GameObj? o=ctl.selObj;
    if(o!=null)c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.x+0.02,o.y+0.02,o.w-0.04,o.h-0.04),const Radius.circular(0.14)),p);
    final Pt? ghost=ctl.ghostPos();
    if(ghost!=null&&ctl.armed!=null) {
      final TypeInfo info=kTypes[ctl.armed]!;
      p.color=ctl.sim.canPlace(ctl.armed!,ghost.x,ghost.y)?const Color(0xCC1B9D75):const Color(0xCCD44343);
      p.style=PaintingStyle.fill;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(ghost.x+0.04,ghost.y+0.04,info.w-0.08,info.h-0.08),const Radius.circular(0.12)),p);
      p..color=const Color(0xFF267B64)..style=PaintingStyle.stroke;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(ghost.x+0.04,ghost.y+0.04,info.w-0.08,info.h-0.08),const Radius.circular(0.12)),p);
    }
    final Pt? pending=ctl.pending;
    if(pending!=null&&ctl.armed!=null) {
      final TypeInfo info=kTypes[ctl.armed]!;
      p..color=const Color(0xFF126D56)..style=PaintingStyle.stroke;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(pending.x+0.03,pending.y+0.03,info.w-0.06,info.h-0.06),const Radius.circular(0.12)),p);
    }
  }

  void _meter(Canvas c,double x,double y,double w,double v,Color color) {
    final Paint p=Paint()..color=const Color(0x66888888);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,y,w,0.08),const Radius.circular(0.04)),p);
    p.color=color;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,y,w*v.clamp(0.0,1.0).toDouble(),0.08),const Radius.circular(0.04)),p);
  }

  void _label(Canvas c,double x,double y,String text,double size) {
    final TextPainter tp=TextPainter(text:TextSpan(text:text,style:TextStyle(fontSize:size)),textDirection:TextDirection.ltr)..layout();
    tp.paint(c,Offset(x-tp.width/2,y));
  }
}

/// Small adapter retained to keep drawing helpers explicit.
class SimLike {
  final AquaController ctl;
  SimLike(this.ctl);
}
