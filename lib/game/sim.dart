import 'dart:math' as math;
import 'dart:ui' show Color;
import 'constants.dart';
import 'models.dart';
import 'util.dart';

typedef ToastFn = void Function(String msg, String kind);

class Floater {
  final double x, y;
  final String txt;
  final Color col;
  double age = 0;
  Floater(this.x, this.y, this.txt, this.col);
}

class FoodPart {
  double x, y;
  final double vy, ph, bot;
  FoodPart(this.x, this.y, this.vy, this.ph, this.bot);
}

class Sim {
  double t = 0;
  int coins = 600, food = 10, rows = kMinRows, missionStep = 0, speed = 1;
  int statHarv = 0, statFish = 0, statLost = 0, statPlost = 0, nid = 1;
  final List<GameObj> objs = <GameObj>[];
  Set<int> pipes = <int>{};
  List<List<GameObj?>> grid = <List<GameObj?>>[];
  List<Net> nets = <Net>[];
  Map<int, Net> pipeNet = <int, Net>{};
  double poor = 0;
  ToastFn? onToast;
  final math.Random rng = math.Random();
  final Map<String, double> _warnAt = <String, double>{};
  final List<Floater> floaters = <Floater>[];
  final List<FoodPart> parts = <FoodPart>[];

  Sim() { rebuild(); }
  int pk(int x, int y) => y * kCols + x;
  bool inb(int x, int y) => x >= 0 && y >= 0 && x < kCols && y < rows;
  GameObj? at(int x, int y) => inb(x, y) ? grid[y][x] : null;
  bool isPipe(int x, int y) => pipes.contains(pk(x, y));
  bool conductAt(int x, int y) => inb(x,y) && (grid[y][x] != null || isPipe(x,y));

  GameObj addObj(ObjType type, int x, int y) {
    final int id = nid++;
    final GameObj o = switch (type) {
      ObjType.tank => Tank(id,x,y),
      ObjType.bed => Bed(id,ObjType.bed,x,y),
      ObjType.tower => Bed(id,ObjType.tower,x,y),
      ObjType.pump => Pump(id,x,y),
      ObjType.air => Air(id,x,y),
      ObjType.feeder => Feeder(id,x,y),
    };
    objs.add(o); rebuild(); return o;
  }

  String tankName(Tank o) {
    int n=0;
    for (final GameObj x in objs) { if (x is Tank) { n++; if (identical(x,o)) return 'حوض ' + n.toString(); } }
    return 'حوض';
  }

  void rebuild() {
    grid = List<List<GameObj?>>.generate(rows, (_) => List<GameObj?>.filled(kCols,null));
    for (final GameObj o in objs) {
      for (int j=0;j<o.h;j++) { for (int i=0;i<o.w;i++) {
        final int x=o.x+i, y=o.y+j; if (inb(x,y)) grid[y][x]=o;
      }}
    }
    pipes.removeWhere((int k) { final int x=k%kCols, y=k~/kCols; return !inb(x,y)||grid[y][x]!=null; });
    nets=<Net>[]; pipeNet=<int,Net>{};
    final Set<int> visited=<int>{};
    final Map<int,Net> objNets=<int,Net>{};
    bool waterObj(GameObj? o) => o is Tank || o is Bed || o is Pump;
    for (final GameObj o in objs) { o.net=null; if (waterObj(o)) objNets[o.id]=Net(); }
    final Map<int,List<int>> adj=<int,List<int>>{};
    int node(int x,int y) { final GameObj? o=at(x,y); if (waterObj(o)) return 100000+o!.id; return isPipe(x,y)?pk(x,y):-1; }
    for (int y=0;y<rows;y++) { for (int x=0;x<kCols;x++) {
      final int a=node(x,y); if (a<0) continue;
      for (final List<int> d in const <List<int>>[[1,0],[0,1]]) {
        final int nx=x+d[0], ny=y+d[1]; if(!inb(nx,ny)) continue;
        final int b=node(nx,ny); if(b<0||a==b) continue;
        final GameObj? oa=at(x,y), ob=at(nx,ny);
        if (isPipe(x,y)||isPipe(nx,ny)||oa is Pump||ob is Pump) {
          (adj[a]??=<int>[]).add(b); (adj[b]??=<int>[]).add(a);
        }
      }
    }}
    for (final int start in adj.keys) {
      if (visited.contains(start)) continue;
      final List<int> stack=<int>[start], component=<int>[];
      visited.add(start);
      while(stack.isNotEmpty) { final int a=stack.removeLast(); component.add(a); for(final int b in adj[a]??<int>[]) { if(visited.add(b)) stack.add(b); } }
      final Net n=Net(); nets.add(n);
      for(final int a in component) {
        if(a>=100000) {
          final int id=a-100000;
          GameObj? o; for (final GameObj e in objs) { if (e.id == id) { o = e; break; } }
          if(o is Tank) n.tanks.add(o);
          if(o is Pump) n.pumps.add(o);
          if(o is Bed) n.beds.add(o);
          if(o!=null) o.net=n;
        } else { n.pipes++; pipeNet[a]=n; }
      }
    }
    for(final GameObj o in objs) { if(waterObj(o) && o.net==null) { final Net n=Net(); if(o is Tank)n.tanks.add(o); if(o is Pump)n.pumps.add(o); if(o is Bed)n.beds.add(o); o.net=n; nets.add(n); } }
    for(final GameObj o in objs) { if(o is Tank) { o.air=0; o.feeders=<Feeder>[]; } }
    for(final GameObj o in objs) { if(o is Air||o is Feeder) {
      Tank? found;
      for(final List<int> d in kDirs) { final GameObj? c=at(o.x+d[0],o.y+d[1]); if(c is Tank){found=c;break;} }
      if(o is Air){o.tank=found;if(found!=null)found.air++;}
      if(o is Feeder){o.tank=found;if(found!=null)found.feeders.add(o);}
    }}
    refreshNets();
  }

  void refreshNets() { for(final Net n in nets){n.active=n.pumps.where((Pump p)=>!p.broken).length;n.cap=n.tanks.isNotEmpty?n.active*kPumpCap:0;} }
  NetStatus netStatus(Net? n) {
    if(n==null||n.tanks.isEmpty)return const NetStatus(false,'✖ غير متصل بحوض سمك');
    if(n.pumps.isEmpty)return const NetStatus(false,'✖ لا توجد مضخة ماء');
    if(n.active==0)return const NetStatus(false,'🔧 كل المضخات معطلة');
    if(n.ratio<0.7)return const NetStatus(true,'⚠ تدفق ضعيف — أضف مضخة');
    return const NetStatus(true,'✔ الماء يصل');
  }
  void toast(String msg,[String kind='info']) { onToast?.call(msg,kind); }
  void warnT(String key,String msg,String kind,[double gap=45]) { final double now=DateTime.now().millisecondsSinceEpoch/1000; if(now-(_warnAt[key]??-1e9)>gap){_warnAt[key]=now;toast(msg,kind);} }
  void addFloater(double x,double y,String txt,Color col)=>floaters.add(Floater(x,y,txt,col));
  void spawnFood(Tank o) { for(int i=0;i<10;i++){parts.add(FoodPart(o.x+0.4+rng.nextDouble()*(o.w-0.8),o.y+0.3+rng.nextDouble()*0.3,0.5+rng.nextDouble()*0.6,rng.nextDouble()*6,o.y+o.h-0.4));} }
  void updateFx(double dt) { for(final FoodPart p in parts){p.y+=p.vy*dt;p.x+=math.sin(p.y*9+p.ph)*0.15*dt;} parts.removeWhere((FoodPart p)=>p.y>=p.bot);for(final Floater f in floaters){f.age+=dt;}floaters.removeWhere((Floater f)=>f.age>=1.4); }

  void stepSim(double dt) {
    t+=dt; refreshNets();
    for(final GameObj o in objs){if(o is Tank)stepTank(o,dt);else if(o is Pump)stepPump(o,dt);else if(o is Feeder)stepFeeder(o,dt);}
    for(final Net n in nets)stepNet(n,dt);
    final bool alive=objs.any((GameObj o)=>(o is Tank&&o.n>0)||(o is Bed&&o.slots.any((Slot s)=>s.alive)));
    if((coins<15&&!alive)||(coins<12&&food<=0)){poor+=dt;if(poor>20){coins+=80;poor=0;toast('🎁 منحة دعم للمزارعين: +80💰','good');}}else{poor=0;}
  }
  void stepTank(Tank o,double dt) {
    final FishSpecies? sp=o.species;final int n=o.n;final int air=math.min(o.air,3);
    final double d=(n>0&&sp!=null)?n*(0.025+0.03*o.size)*sp.o2:0;
    o.o2=clampD(o.o2+((0.5+air*1.6)*(1-o.o2/100)-d)*dt,0,100);
    if(n<=0||sp==null){o.waste=math.max(2.0,o.waste-0.02*dt);o.bad=null;return;}
    o.hunger=math.min(100.0,o.hunger+sp.hunger*dt);
    o.waste=clampD(o.waste+n*(0.015+0.02*o.size)*sp.waste*dt,2,100);
    double dmg=0;if(o.o2<sp.o2Min)dmg+=(sp.o2Min-o.o2)*0.05;if(o.waste>55)dmg+=(o.waste-55)*0.04;if(o.hunger>70)dmg+=(o.hunger-70)*0.04;
    if(dmg>0){o.health-=dmg*dt;}else{o.health=math.min(100.0,o.health+0.4*dt);}
    if(o.health<=0){final int k=math.max(1,(o.n*0.25).ceil());o.n=math.max(0,o.n-k);statLost+=k;o.health=o.n>0?40:100;if(o.n==0)o.size=0;toast('💀 نفقت '+k.toString()+' من الأسماك في '+tankName(o),'bad');}
    if(o.n>0&&o.health>40)o.size=math.min(1.0,o.size+dt/sp.growSec*(1-o.hunger/100)*(o.o2>25?1.0:0.3));
    o.bad=o.n>0?TankBad(o.o2<sp.o2Min+8,o.waste>50,o.hunger>60):null;
    final TankBad? b=o.bad;if(b!=null){if(b.o2)warnT('o2'+o.id,'💨 الأكسجين منخفض في '+tankName(o)+' — ضع مضخة أكسجين ملاصقة','warn');if(b.waste)warnT('w'+o.id,'☠️ الفضلات مرتفعة في '+tankName(o)+' — أضف نباتات ووصّلها بمضخة وأنابيب','warn');if(b.hunger)warnT('h'+o.id,'🍽️ أسماك '+tankName(o)+' جائعة — أطعمها','warn');}
  }
  void stepPump(Pump o,double dt){final Net? n=o.net;if(!o.broken&&t>150&&n!=null&&n.tanks.isNotEmpty&&rng.nextDouble()<dt/500){o.broken=true;toast('🔧 انسدت مضخة الماء — اضغط عليها لتنظيفها','bad');}}
  void stepFeeder(Feeder o,double dt){o.timer-=dt;if(o.timer>0)return;o.timer=8;final Tank? tk=o.tank;if(tk!=null&&tk.n>0&&tk.hunger>40)feedTank(tk,auto:true);}
  void stepNet(Net n,double dt) {
    final List<Slot> slots=<Slot>[];for(final Bed b in n.beds){for(final Slot s in b.slots){if(s.alive)slots.add(s);}}
    final double ratio=n.cap>0?math.min(1.0,n.cap/math.max(1,slots.length)):0.0;double demand=0;
    for(final Slot s in slots){demand+=kCrops[s.crop]!.nut*(s.g>=1?0.5:1.0)*dt;}
    double avail=0;for(final Tank tk in n.tanks){avail+=math.max(0.0,tk.waste-4);}
    double sup=0;if(ratio>0&&demand>0){final double req=demand*ratio;final double taken=math.min(req,avail);sup=taken/req;if(avail>0){for(final Tank tk in n.tanks){tk.waste-=taken*math.max(0.0,tk.waste-4)/avail;}}}
    n.ratio=ratio;
    for(final Bed b in n.beds){bool thirsty=false,starve=false;for(final Slot s in b.slots){if(!s.alive)continue;updateSlot(s,ratio,sup,dt);if(s.dead)continue;if(s.water<30)thirsty=true;if(s.nut<15)starve=true;}b.thirsty=thirsty;b.starve=starve;if(thirsty)warnT('t'+b.id,'💧 نباتات عطشى في '+kTypes[b.type]!.name+' — تحقق من الأنابيب والمضخة','warn');else if(starve)warnT('s'+b.id,'🍂 نباتات جائعة — تحتاج فضلات أسماك أكثر','warn');}
  }
  void updateSlot(Slot s,double ratio,double sup,double dt) {
    final CropInfo c=kCrops[s.crop]!;s.water=clampD(s.water+(ratio*3-1)*dt,0,100);s.nut+=(100*sup*(0.4+0.6*ratio)-s.nut)*math.min(1.0,0.1*dt);
    double dmg=0;if(s.water<12)dmg+=(12-s.water)*0.09;if(s.nut<8)dmg+=(8-s.nut)*0.03;if(dmg>0){s.hp-=dmg*dt;}else{s.hp=math.min(100.0,s.hp+0.5*dt);}
    if(s.hp<=0){s.dead=true;statPlost++;toast('🥀 مات نبات '+c.name,'bad');return;}
    if(s.g<1&&s.hp>25&&s.water>15)s.g=math.min(1.0,s.g+dt/c.growSec*(0.25+0.75*s.nut/100));
    if(s.g>=1&&!s.rdy){s.rdy=true;toast('🌾 محصول جاهز للحصاد: '+c.name,'good');}
  }
  bool feedTank(Tank o,{bool auto=false}) {
    if(o.sp==null||o.n<=0){if(!auto)toast('الحوض فارغ من الأسماك','warn');return false;}
    if(food<=0){if(auto)warnT('nofood','🍽️ نفد طعام الأسماك! اشترِ من «المخزن»','bad',30);else toast('🍽️ لا يوجد طعام — اشترِ من «المخزن»','warn');return false;}
    final int need=math.max(1,(o.n/4).ceil()),use=math.min(need,food);final bool over=o.hunger<15;
    o.hunger=math.max(0.0,o.hunger-42.0*use/need);o.waste=math.min(100.0,o.waste+(over?5.0:0.8)*use);food-=use;spawnFood(o);
    if(over&&!auto)toast('⚠️ الأسماك شبعانة — الطعام الزائد يلوّث الماء','warn');return true;
  }
  bool buyFry(Tank o,String k) {
    final FishSpecies? f=kFish[k];if(f==null)return false;if(o.n>0&&o.sp!=k){toast('لا يمكن خلط أنواع السمك في حوض واحد','warn');return false;}
    final int room=kFishCap-o.n;if(room<=0){toast('الحوض ممتلئ','warn');return false;}final int q=math.min(4,room),cost=q*f.price;
    if(coins<cost){toast('💰 النقود لا تكفي','warn');return false;}coins-=cost;
    if(o.n==0){o.sp=k;o.size=0.05;o.health=100;o.hunger=30;}else{o.size=(o.size*o.n+0.05*q)/(o.n+q);o.hunger=(o.hunger*o.n+30.0*q)/(o.n+q);}
    o.n+=q;toast('🐟 أُضيف '+q.toString()+' من '+f.name,'good');return true;
  }
  bool sellFish(Tank o) {
    final FishSpecies? sp=o.species;if(sp==null||o.n<=0)return false;if(o.size<0.6){toast('الأسماك لم تكبر بعد — تُباع عند 60% نمو','warn');return false;}
    final int v=(o.n*sp.sell*o.size).round();coins+=v;statFish+=o.n;addFloater(o.x+o.w/2,o.y+0.8,'+'+v.toString(),const Color(0xFFFFE27A));o.n=0;o.size=0;o.health=100;toast('💰 بعت الأسماك مقابل '+v.toString(),'good');return true;
  }
  int slotAt(Bed b,int gx,int gy){for(int i=0;i<b.slots.length;i++){final Pt p=slotPos(b,i);if(p.x==gx&&p.y==gy)return i;}return -1;}
  void harvestSlot(Bed b,int i){final Slot s=b.slots[i];final CropInfo c=kCrops[s.crop]!;final Pt p=slotPos(b,i);coins+=c.sell;statHarv++;addFloater(p.x+0.5,p.y+0.3,'+'+c.sell.toString(),const Color(0xFFFFE27A));s.clear();}
  bool canPlace(ObjType k,int x,int y){final TypeInfo tp=kTypes[k]!;if(x<0||y<0||x+tp.w>kCols||y+tp.h>rows)return false;for(int j=0;j<tp.h;j++){for(int i=0;i<tp.w;i++){if(grid[y+j][x+i]!=null||isPipe(x+i,y+j))return false;}}return true;}
  GameObj? placeObj(ObjType k,int x,int y){if(!canPlace(k,x,y)){toast('❌ المكان غير صالح — الخلايا مشغولة','warn');return null;}final int cost=kTypes[k]!.cost;if(coins<cost){toast('💰 النقود لا تكفي','warn');return null;}coins-=cost;return addObj(k,x,y);}
  void paintPipe(int gx,int gy,bool erase){if(!inb(gx,gy))return;final int k=pk(gx,gy);if(erase){if(pipes.remove(k)){coins++;rebuild();}return;}if(pipes.contains(k)||grid[gy][gx]!=null)return;if(coins<kPipeCost){warnT('nocoin','💰 النقود لا تكفي','warn',3);return;}pipes.add(k);coins-=kPipeCost;rebuild();}
  void plantAt(int gx,int gy,String crop){final GameObj? o=at(gx,gy);if(o is! Bed)return;final int i=slotAt(o,gx,gy);if(i<0)return;final Slot s=o.slots[i];final CropInfo? c=kCrops[crop];if(c==null||s.alive)return;if(o.type==ObjType.tower&&!c.tower){warnT('towercrop','🌿 '+c.name+' يحتاج حوضاً أفقياً وليس برجاً','warn',3);return;}if(coins<c.seed){warnT('nocoin','💰 النقود لا تكفي','warn',3);return;}coins-=c.seed;s.plant(crop);}
  void removeObj(GameObj o){final int refund=(kTypes[o.type]!.cost*0.6).round();coins+=refund;objs.remove(o);rebuild();toast('🗑️ تمت الإزالة (+'+refund.toString()+'💰)','info');}
  bool expand(){final int i=(rows-kMinRows)~/2;if(i>=kExpand.length)return false;if(coins<kExpand[i]){toast('💰 النقود لا تكفي','warn');return false;}coins-=kExpand[i];rows+=2;for(final GameObj o in objs){o.y+=2;}final Set<int> np=<int>{};for(final int k in pipes){np.add((k~/kCols+2)*kCols+(k%kCols));}pipes=np;rebuild();toast('🏗️ تم توسيع الدفيئة','good');return true;}
  bool buyFood(){if(coins<15){toast('💰 النقود لا تكفي','warn');return false;}coins-=15;food+=6;return true;}
  void starter(){final Tank tank=addObj(ObjType.tank,0,7) as Tank;tank.sp='tilapia';tank.n=4;tank.size=0.05;addObj(ObjType.air,4,9);addObj(ObjType.pump,4,8);pipes.addAll(<int>[pk(4,7),pk(4,6),pk(4,5)]);final Bed bed=addObj(ObjType.bed,0,4) as Bed;for(int i=0;i<4;i++){bed.slots[i].plant('lettuce');}coins-=319;rebuild();}
  Map<String,dynamic> toJson()=> <String,dynamic>{'v':1,'t':t,'coins':coins,'food':food,'rows':rows,'nid':nid,'step':missionStep,'speed':speed,'stats':<int>[statHarv,statFish,statLost,statPlost],'pipes':pipes.toList(),'objs':objs.map((GameObj o)=>o.toJson()).toList()};
  static Sim? fromJson(Map<String,dynamic> j){
    if(j['v']!=1||j['objs'] is! List)return null;final Sim s=Sim();s.t=(j['t'] as num?)?.toDouble()??0;s.coins=(j['coins'] as num?)?.toInt()??600;s.food=(j['food'] as num?)?.toInt()??0;s.rows=clampI((j['rows'] as num?)?.toInt()??kMinRows,kMinRows,kMinRows+6);s.missionStep=(j['step'] as num?)?.toInt()??0;
    final int speed=(j['speed'] as num?)?.toInt()??1;s.speed=<int>[0,1,2,4].contains(speed)?speed:1;final dynamic st=j['stats'];if(st is List&&st.length>=4){s.statHarv=(st[0] as num).toInt();s.statFish=(st[1] as num).toInt();s.statLost=(st[2] as num).toInt();s.statPlost=(st[3] as num).toInt();}
    int maxId=0;for(final dynamic e in j['objs'] as List){if(e is Map<String,dynamic>){final GameObj? o=objFromJson(e);if(o!=null){s.objs.add(o);maxId=math.max(maxId,o.id);}}}s.nid=math.max((j['nid'] as num?)?.toInt()??1,maxId+1);
    final dynamic pp=j['pipes'];if(pp is List){for(final dynamic k in pp){if(k is num)s.pipes.add(k.toInt());}}s.rebuild();return s;
  }
}
