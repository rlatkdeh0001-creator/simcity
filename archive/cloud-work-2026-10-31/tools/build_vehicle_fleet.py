"""CITIES_DO original city fleet. Run with blender -b --factory-startup -P this_file.
Uses reviewed zstack vehicle helpers and its metric/wheel-pivot export contract.
"""
from pathlib import Path
import bpy, bmesh, math, json, sys, argparse
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
SKILL=ROOT/'.agents/skills/vehicle'
sys.path.insert(0,str(SKILL/'blender'))
import common as C
OUT=ROOT/'assets/vehicle-fleet'; GAME=ROOT/'cities_do/assets/vehicles'
OUT.mkdir(parents=True,exist_ok=True);GAME.mkdir(parents=True,exist_ok=True)
SPECS=[
 ('bus-city-01','시내버스','bus','bus',12.0,2.5,3.2,'447f96'),
 ('taxi-sedan-01','택시','taxi','sedan',4.65,1.82,1.62,'e4b343'),
 ('car-hatch-01','소형 해치백','citizen','hatch',3.6,1.65,1.5,'84b6a0'),
 ('car-compact-02','준중형 세단','citizen','sedan',4.35,1.76,1.43,'b6bdc3'),
 ('car-sedan-03','중형 세단','citizen','sedan',4.8,1.86,1.48,'4e657e'),
 ('car-wagon-04','스테이션 왜건','citizen','wagon',4.65,1.82,1.53,'73876a'),
 ('car-crossover-05','크로스오버','citizen','crossover',4.35,1.83,1.65,'ce8760'),
 ('car-suv-06','대형 SUV','citizen','suv',4.95,1.98,1.86,'965d64'),
 ('car-coupe-07','스포츠 쿠페','citizen','coupe',4.42,1.88,1.25,'bb5e50'),
 ('car-minivan-08','패밀리 미니밴','citizen','minivan',5.1,1.92,1.83,'d7d0b3'),
 ('car-electric-09','전기 세단','citizen','electric',4.62,1.86,1.52,'8e82a8'),
 ('car-pickup-10','레저 픽업','citizen','pickup',5.35,1.98,1.8,'548d90'),
 ('truck-box-01','소형 탑차','industrial','box',6.2,2.25,3.15,'e0dfcf'),
 ('truck-flatbed-02','평판 트럭','industrial','flatbed',7.45,2.45,2.85,'4f7c9d'),
 ('truck-fridge-03','냉동 트럭','industrial','fridge',8.15,2.48,3.45,'71a9a1'),
 ('truck-mixer-04','콘크리트 믹서','industrial','mixer',8.4,2.5,3.5,'ce9162'),
 ('trailer-container-05','컨테이너 트레일러','industrial','container',16.2,2.5,3.85,'aa6555'),
 ('trailer-tanker-06','탱크 트레일러','industrial','tanker',15.4,2.5,3.6,'567b68'),
 ('truck-dump-07','중형 덤프트럭','industrial','dump',7.8,2.5,3.15,'d4ac4e'),
 ('truck-heavy-dump-08','대형 덤프트럭','industrial','heavy_dump',9.6,2.6,3.55,'b47b4e'),
]
M={};root=None;body=None

def linear(h):
 v=[int(h[i:i+2],16)/255 for i in (0,2,4)]
 return tuple(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in v)+(1,)
def material(name,color,metal=0,rough=.58):
 m=bpy.data.materials.new(name);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=linear(color);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 m.diffuse_color=linear(color)
 return m
def attach(o,parent=None,mat='Paint'):
 if mat:o.data.materials.append(M[mat])
 parent=body if parent is None else parent
 if parent is not None:C.parent_keep(o,parent)
 return o
def box(name,p,size,mat='Paint',bevel=.035,parent=None):
 o=C.rounded_box(name,size,p,bevel=bevel,segs=2)
 # Flat normals on the broad faces keep small game silhouettes crisp.
 for face in o.data.polygons:face.use_smooth=False
 return attach(o,parent,mat)
def mesh(name,vertices,faces,mat='Paint',parent=None):
 data=bpy.data.meshes.new(name);data.from_pydata(vertices,[],faces);data.update()
 bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
 o=bpy.data.objects.new(name,data);bpy.context.scene.collection.objects.link(o)
 return attach(o,parent,mat)
def pane(name,verts,mat='Glass',parent=None):
 return mesh(name,verts,[(0,1,2,3)],mat,parent)
def empty(name,p=(0,0,0),parent=None):
 o=C.empty(name,p);C.parent_keep(o,body if parent is None else parent);return o
def cyl(name,p,r,depth,mat='Metal',axis='X',parent=None,segments=16):
 o=C.revolve(name,[(r,-depth/2),(r,depth/2)],segments=segments,axis=axis,cap=True)
 o.location=p;return attach(o,parent,mat)
def text(name,words,p,size=.18,parent=None,mat='Ivory',rotation=(math.pi/2,0,0)):
 c=bpy.data.curves.new(name,'FONT');c.body=words;c.align_x='CENTER';c.align_y='CENTER';c.size=size;c.extrude=.002
 o=bpy.data.objects.new(name,c);bpy.context.scene.collection.objects.link(o);o.location=p;o.rotation_euler=rotation
 o.data.materials.append(M[mat]);C.parent_keep(o,body if parent is None else parent)
 bpy.context.view_layer.objects.active=o;o.select_set(True)
 for x in bpy.context.selected_objects:
  if x!=o:x.select_set(False)
 bpy.ops.object.convert(target='MESH');o.select_set(False);return o

def arch_cut(target,y,r,W):
 bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=r*1.12,depth=W+1,location=(0,y,r),rotation=(0,math.pi/2,0))
 cutter=bpy.context.object;mod=target.modifiers.new('WheelWell','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
 bpy.context.view_layer.objects.active=target
 try:bpy.ops.object.modifier_apply(modifier=mod.name)
 except RuntimeError:target.modifiers.remove(mod)
 bpy.data.objects.remove(cutter,do_unlink=True)
def wheel(name,x,y,r,w,parent=None,steer=False):
 p=(x,y,r)
 pivot=empty('Wheel_'+name,p,parent);pivot['steerAxis']=[0.,0.,1.];pivot['steerAxisGltf']=[0.,1.,0.];pivot['steerable']=steer
 spin=empty('Wheel_'+name+'_Spin',p,pivot);spin['spinAxis']=[1.,0.,0.];spin['spinAxisGltf']=[1.,0.,0.];spin['radius_m']=r
 profile=[(r*.65,-w/2),(r*.9,-w/2),(r,-w*.32),(r,w*.32),(r*.9,w/2),(r*.65,w/2)]
 tyre=C.revolve('Tyre_'+name,profile,segments=16,axis='X');tyre.location=p;attach(tyre,spin,'Tyre')
 outer=1 if x>0 else -1
 cyl('Rim_'+name,(x+outer*w*.3,y,r),r*.66,w*.35,'Rim',parent=spin,segments=12)
 cyl('Hub_'+name,(x+outer*w*.5,y,r),r*.25,w*.12,'Metal',parent=spin,segments=12)
 for a in range(5):
  angle=a*math.tau/5
  # Small bolt recesses, kept separate from the wheel pivot.
  cyl('Lug_'+name,(x+outer*w*.57,y+math.cos(angle)*r*.19,r+math.sin(angle)*r*.19),r*.035,.025,'Dark',parent=spin,segments=6)
 return pivot

def chassis(L,W,z=.65):
 box('Frame',(0,0,z),(W*.76,L*.94,.22),'Dark')
 box('Underbody',(0,0,z-.1),(W*.66,L*.84,.12),'Metal')
def lights(L,W,z,front_y=None):
 fy=-L/2-.015 if front_y is None else front_y
 for s in [-1,1]:
  box('Headlamp',(s*W*.32,fy,z),(W*.2,.035,.13),'Head',.02)
  box('TailLamp',(s*W*.33,L/2+.012,z),(W*.18,.03,.13),'Tail',.02)
  box('FrontIndicator',(s*W*.43,fy,z-.13),(.09,.04,.055),'Amber',.01)
 box('RearPlate',(0,L/2+.028,z-.18),(.32,.022,.10),'Ivory',.01)
 box('FrontPlate',(0,fy-.014,z-.18),(.32,.023,.1),'Ivory',.01)
def anchors(W,front_y,z):
 e=empty('Seat_FL',(W*.24,front_y,z));e['role']='driver';e['handedness']='left_hand_drive'
 empty('Seat_FR',(-W*.24,front_y,z))
 empty('SteeringWheel',(W*.24,front_y-.3,z+.2))
def mirror_pair(W,y,z):
 for s in [-1,1]:
  box('MirrorArm',(s*(W/2+.045),y,z),(.13,.07,.05),'Dark',.01)
  box('MirrorHousing',(s*(W/2+.105),y,z+.025),(.14,.22,.13),'Paint',.035)
  box('MirrorGlass',(s*(W/2+.105),y+.116,z+.025),(.11,.015,.095),'Glass',.01)

def car(spec):
 id,label,cat,kind,L,W,H,color=spec
 if cat=='taxi':roofH=1.44
 else:roofH=H-.035
 r=.30 if L<4 else (.36 if kind in ['suv','pickup'] else .325)
 front=-L*.30;rear=L*.29
 base=.31 if kind not in ['suv','pickup','crossover'] else .44
 belt=.86 if kind not in ['suv','pickup','minivan','crossover'] else 1.03
 # A sparse feature-line body loft, four-sided rings with deliberate nose/tail taper.
 stations=[(-L/2,.84,belt*.88),(-L*.43,.98,belt),(-L*.26,1,belt),(L*.30,1,belt),(L*.45,.97,belt*.95),(L/2,.85,belt*.87)]
 vertices=[]
 for y,w,z in stations:vertices += [(-W*w/2,y,base),(W*w/2,y,base),(W*w/2,y,z),(-W*w/2,y,z)]
 faces=[]
 for i in range(len(stations)-1):
  for k in range(4):faces.append((i*4+k,i*4+(k+1)%4,(i+1)*4+(k+1)%4,(i+1)*4+k))
 faces +=[(3,2,1,0),tuple(range((len(stations)-1)*4,len(stations)*4))]
 shell=mesh('BodyShell',vertices,faces)
 for y in [front,rear]:arch_cut(shell,y,r,W)
 if kind=='pickup':lf,lr,rf,rr=-L*.25,L*.08,-L*.12,L*.015
 elif kind=='minivan':lf,lr,rf,rr=-L*.40,L*.44,-L*.26,L*.34
 elif kind=='suv':lf,lr,rf,rr=-L*.30,L*.43,-L*.19,L*.33
 elif kind in ['wagon','hatch']:lf,lr,rf,rr=-L*.27,L*.40,-L*.09,L*.31
 elif kind=='electric':lf,lr,rf,rr=-L*.28,L*.43,-L*.13,L*.16
 elif kind=='coupe':lf,lr,rf,rr=-L*.22,L*.31,-L*.02,L*.15
 else:lf,lr,rf,rr=-L*.24,L*.34,-L*.07,L*.20
 wb=W*.47;wt=W*(.34 if kind=='coupe' else .385)
 vertices=[(-wb,lf,belt), (wb,lf,belt),(wb,lr,belt),(-wb,lr,belt),(-wt,rf,roofH),(wt,rf,roofH),(wt,rr,roofH),(-wt,rr,roofH)]
 mesh('CabinShell',vertices,[(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)])
 for s in [-1,1]:
  # Divided side glass leaves solid A/B/C pillars rather than a painted black box.
  split=(rf+rr)/2
  pane('WindowFront',[(s*(wb+.008),lf+.08,belt+.07),(s*(wb+.008),split-.04,belt+.07),(s*(wt+.008),split-.04,roofH-.08),(s*(wt+.008),rf+.06,roofH-.08)])
  pane('WindowRear',[(s*(wb+.008),split+.04,belt+.07),(s*(wb+.008),lr-.09,belt+.07),(s*(wt+.008),rr-.06,roofH-.08),(s*(wt+.008),split+.04,roofH-.08)])
  for y in [split-.05,lr-.16]:box('DoorHandle',(s*(W*.485),y,belt-.06),(.025,.19,.045),'Metal',.008)
  box('Rocker',(s*(W*.476),.01,base+.08),(.045,L*.60,.07),'Dark',.01)
 pane('Windscreen',[(-wb*.94,lf-.012,belt+.065),(wb*.94,lf-.012,belt+.065),(wt*.94,rf-.012,roofH-.075),(-wt*.94,rf-.012,roofH-.075)])
 pane('RearGlass',[(-wt*.94,rr+.012,roofH-.08),(wt*.94,rr+.012,roofH-.08),(wb*.94,lr+.012,belt+.065),(-wb*.94,lr+.012,belt+.065)])
 chassis(L,W,base-.03)
 lights(L,W,belt-.13)
 if kind!='electric':box('Grille',(0,-L/2-.02,belt-.22),(W*.46,.045,.18),'Dark',.02)
 else:
  box('EVLightBar',(0,-L/2-.032,belt-.12),(W*.72,.025,.055),'Head',.01)
  box('EVClosedNose',(0,-L/2-.02,belt-.26),(W*.55,.025,.12),'Paint',.015)
 if kind in ['wagon','suv','crossover']:
  for s in [-1,1]:box('RoofRail',(s*W*.30,(rf+rr)/2,roofH+.035),(.045,rr-rf,.055),'Metal',.015)
 if kind=='coupe':box('RearSpoiler',(0,L*.42,belt+.13),(W*.83,.18,.075),'Paint',.025)
 if kind=='pickup':
  bedfront=L*.11;bedback=L/2-.10;by=(bedfront+bedback)/2
  box('BedFloor',(0,by,belt+.016),(W*.80,bedback-bedfront,.1),'Dark',.015)
  for s in [-1,1]:box('BedRail',(s*W*.44,by,belt+.05),(.14,bedback-bedfront,.24),'Paint',.02)
  box('Tailgate',(0,bedback,belt),(W*.86,.12,.35),'Paint',.02)
 if cat=='taxi':
  box('TaxiRoofSign',(0,(rf+rr)/2,roofH+.12),(.66,.28,.20),'Ivory',.045)
  text('TaxiText','TAXI',(0,(rf+rr)/2-.15,roofH+.12),.14,mat='Dark')
  for s in [-1,1]:box('TaxiDoorStripe',(s*W*.494,.03,belt-.12),(.025,L*.42,.09),'Dark',.003)
 mirror_pair(W,lf+.13,belt+.13)
 anchors(W,rf+.18,belt+.06)
 for name,x,y in [('FL',W/2-.10,front),('FR',-W/2+.10,front),('RL',W/2-.10,rear),('RR',-W/2+.10,rear)]:wheel(name,x,y,r,.22,steer=name.startswith('F'))
 return 4

def bus(spec):
 _,_,_,_,L,W,H,_=spec;r=.51
 chassis(L,W,.65)
 box('BusBody',(0,0,1.62),(W,L,2.30),'Paint',.18)
 box('CreamLower',(0,0,.90),(W+.012,L-.06,.45),'Ivory',.07)
 box('BusRoof',(0,0,H-.22),(W*.98,L*.98,.24),'Ivory',.11)
 for side in [-1,1]:
  for i in range(9):
   y=-L/2+1.35+i*(L-2.0)/9
   box('PassengerWindow',(side*(W/2+.008),y,2.22),(.025,.87,.83),'Glass',.035)
 # Passenger doors only on the vehicle's RIGHT (-X), matching right-hand traffic.
 for y in [-L/2+.95,L*.10]:
  for offset in [-.24,.24]:box('Door_Right',( -W/2-.022,y+offset,1.55),(.045,.44,1.90),'Glass',.025)
  box('DoorStep',(-W/2-.028,y,.55),(.05,.98,.11),'Dark',.015)
  box('DoorRail',(-W/2-.052,y,1.45),(.025,.045,1.6),'Ivory',.008)
 box('BusWindscreen',(0,-L/2-.02,2.13),(W*.86,.04,1.02),'Glass',.08)
 box('Destination',(0,-L/2-.025,2.82),(W*.78,.045,.30),'Dark',.035)
 text('BusRoute','21 CITY',(0,-L/2-.052,2.82),.19)
 box('RearWindow',(0,L/2+.016,2.25),(W*.78,.03,.85),'Glass',.06)
 box('RoofAC',(0,.15,H-.035),(W*.70,2.0,.25),'Metal',.08)
 lights(L,W,1.02);mirror_pair(W,-L/2+.38,2.18)
 anchors(W,-L*.36,1.25)
 for axle,y in [('F',-L*.30),('R',L*.28)]:
  for side,x in [('L',W/2-.16),('R',-W/2+.16)]:wheel(axle+side,x,y,r,.29,steer=axle=='F')
 root['passenger_door_side']='right';return 4

def truck(spec):
 _,_,_,kind,L,W,H,_=spec;r=.59 if kind=='heavy_dump' else .47
 chassis(L,W,.77)
 cy=-L/2+1.12;cabtop=2.45 if kind in ['flatbed','dump'] else 2.67
 cab=box('TruckCab',(0,cy,(.80+cabtop)/2),(W*.94,2.2,cabtop-.80),'Paint',.14)
 pane('TruckWindscreen',[(-W*.41,-L/2-.008,1.63),(W*.41,-L/2-.008,1.63),(W*.38,-L/2-.028,cabtop-.22),(-W*.38,-L/2-.028,cabtop-.22)])
 for s in [-1,1]:
  box('CabSideGlass',(s*(W*.472),cy,2.04),(.026,1.21,.74),'Glass',.065)
  box('CabStep',(s*W*.47,cy+.40,.63),(.16,.70,.12),'Metal',.02)
 box('CabGrille',(0,-L/2-.05,1.29),(W*.57,.06,.34),'Dark',.035)
 for z in [1.22,1.34,1.46]:box('GrilleSlat',(0,-L/2-.086,z),(W*.52,.025,.028),'Metal',.003)
 lights(L,W,1.10);mirror_pair(W,cy-.48,2.17);anchors(W,cy-.17,1.33)
 front=-L/2+1.19
 arch_cut(cab,front,r,W)
 cf=-L/2+2.35;cb=L/2-.06
 trailer=None
 if kind in ['container','tanker']:
  cf=-L/2+3.8
  trailer=empty('Trailer_Pivot',(0,cf+.60,1.05));trailer['hingeAxis']=[0.,0.,1.];trailer['hingeAxisGltf']=[0.,1.,0.];trailer['role']='articulation'
  box('TractorSleeper',(0,cy+.95,2.15),(W*.85,.55,1.8),'Paint',.10)
  box('TrailerFrame',(0,(cf+cb)/2,.96),(W*.90,cb-cf,.19),'Metal',.025,parent=trailer)
 cargo_parent=trailer or body;cl=cb-cf;cm=(cf+cb)/2
 if kind in ['box','fridge','container']:
  cargo_material='Container' if kind=='container' else 'Ivory'
  height=H-1.02
  box('CargoBox',(0,cm,1.02+height/2),(W*.98,cl,height),cargo_material,.055,parent=cargo_parent)
  for s in [-1,1]:
   for i in range(int(cl/.45)):
    y=cf+.18+i*.45
    box('CargoRib',(s*(W*.494),y,1.02+height/2),(.026,.042,height-.16),'Metal' if kind!='container' else 'Container',.004,parent=cargo_parent)
  box('CargoRearDoors',(0,cb+.035,1.04+height/2),(W*.91,.04,height-.11),'Ivory' if kind!='container' else 'Container',.015,parent=cargo_parent)
  for s in [-1,1]:box('DoorLatch',(s*W*.25,cb+.061,1.07+height/2),(.035,.025,height*.8),'Metal',.004,parent=cargo_parent)
  if kind=='fridge':
   box('RefrigeratorUnit',(0,cf-.12,H-.58),(W*.65,.40,.85),'Metal',.065)
   for x in [-.33,.33]:cyl('CoolingFan',(x,cf-.34,H-.55),.20,.045,'Dark',axis='Y',segments=12)
   for s in [-1,1]:box('ColdStripe',(s*W*.498,cm,1.6),(.022,cl-.05,.17),'Paint',.004)
 elif kind=='flatbed':
  box('FlatDeck',(0,cm,1.02),(W,cl,.18),'Wood',.025)
  for s in [-1,1]:
   box('SideRail',(s*W*.47,cm,1.40),(.08,cl,.11),'Paint',.015)
   for i in range(5):box('Stake',(s*W*.47,cf+.25+i*(cl-.5)/4,1.29),(.08,.08,.55),'Paint',.012)
  for y in [cm-.8,cm+.8]:
   box('Pallet',(0,y,1.18),(W*.72,1.2,.17),'Wood',.015)
   for x in [-.47,0,.47]:box('SteelLoad',(x,y,1.48),(.24,1.08,.47),'Metal',.025)
 elif kind=='mixer':
  drum=empty('Mixer_Drum_Pivot',(0,cm,2.05));drum['spinAxis']=[0.,1.,0.];drum['spinAxisGltf']=[0.,0.,-1.]
  o=C.revolve('MixingDrum',[(.36,-cl*.46),(.92,-cl*.26),(.99,cl*.12),(.70,cl*.35),(.34,cl*.46)],segments=20,axis='Y',cap=True);o.location=(0,cm,2.08);attach(o,drum,'Ivory')
  for y in [-.60,.60]:
   o=C.revolve('DrumBand',[(1.002,y-.14),(1.002,y+.14)],segments=20,axis='Y');o.location=(0,cm,2.08);attach(o,drum,'Paint')
  box('RearHopper',(0,cb-.18,2.48),(.90,.58,.80),'Metal',.09)
  box('DischargeChute',(0,cb-.04,1.47),(.48,.65,.15),'Metal',.035)
 elif kind=='tanker':
  radius=min(1.13,(H-1.1)/2)
  o=C.revolve('Tank',[(.15,-cl/2),(.78,-cl/2+.18),(radius,-cl/2+.55),(radius,cl/2-.55),(.78,cl/2-.18),(.15,cl/2)],segments=24,axis='Y',cap=True);o.location=(0,cm,1.05+radius);attach(o,cargo_parent,'Ivory')
  for y in [cf+.75,cm,cb-.75]:
   o=C.revolve('TankBand',[(radius+.015,-.09),(radius+.015,.09)],segments=24,axis='Y');o.location=(0,y,1.05+radius);attach(o,cargo_parent,'Paint')
  for y in [cf+1.1,cb-1.1]:cyl('TankHatch',(0,y,1.08+radius*2),.22,.12,'Metal',axis='Z',parent=cargo_parent)
 elif kind in ['dump','heavy_dump']:
  bed=empty('Dump_Bed_Pivot',(0,cb-.15,1.05));bed['hingeAxis']=[1.,0.,0.];bed['hingeAxisGltf']=[1.,0.,0.];bed['openLimit']=.75
  wall=1.50 if kind=='heavy_dump' else 1.17
  box('DumpFloor',(0,cm,1.04),(W*.87,cl,.17),'Dark',.025,parent=bed)
  for s in [-1,1]:
   vertices=[(s*W*.43,cf,1.08),(s*W*.43,cb,1.08),(s*W*.50,cb,1.08+wall),(s*W*.50,cf,1.08+wall)]
   side=pane('DumpSide',vertices,'Paint',bed);mod=side.modifiers.new('MetalWall','SOLIDIFY');mod.thickness=.08
   for i in range(6):box('DumpRib',(s*W*.503,cf+.2+i*(cl-.4)/5,1.08+wall*.6),(.075,.10,wall*.78),'Metal',.01,parent=bed)
  for y in [cf,cb]:box('DumpEndWall',(0,y,1.08+wall/2),(W*.91,.10,wall),'Paint',.025,parent=bed)
  box('BedRim',(0,cf,1.08+wall),(W*1.01,.14,.10),'Metal',.015,parent=bed)
 if kind in ['container','tanker']:axles=[front,-L/2+3.05,-L/2+4.1,L/2-2.2,L/2-1.0]
 elif kind=='heavy_dump':axles=[front,front+1.5,L/2-2.3,L/2-.95]
 elif kind in ['fridge','mixer','dump']:axles=[front,L/2-2.0,L/2-.80]
 else:axles=[front,L/2-.95]
 for i,y in enumerate(axles):
  label='F' if i==0 else ('R' if i==len(axles)-1 else 'A'+str(i+1))
  axle_parent=trailer if trailer and i>=3 else body
  for side,x in [('L',W/2-.12),('R',-W/2+.12)]:wheel(label+side,x,y,r,.28,parent=axle_parent,steer=i==0 or(kind=='heavy_dump' and i==1))
 return len(axles)*2

def build(spec):
 global M,root,body
 id,label,cat,kind,L,W,H,color=spec
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
 scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
 M={key:material(key,h,metal,rough) for key,h,metal,rough in [('Paint',color,.12,.48),('Ivory','e4e2d4',.03,.65),('Dark','303b3e',.05,.75),('Metal','7b8c8d',.30,.52),('Rim','b7c0c0',.45,.38),('Tyre','293031',0,.90),('Glass','426777',.20,.20),('Head','f1e6ba',.05,.28),('Tail','b8544a',.03,.34),('Amber','dca252',.03,.4),('Wood','aa9572',0,.8),('Container','688b91',.12,.6)]}
 root=C.empty('VehicleRoot');root['vehicle_id']=id;root['category']=cat;root['forward_axis_gltf']='+Z';root['traffic_side']='right';root['nominal_length_m']=L
 body=C.empty('Body');body.parent=root
 count=bus(spec) if kind=='bus' else(truck(spec) if cat=='industrial' else car(spec))
 # Ensure double-sided panels remain readable after export without adding a pavement plinth.
 for o in list(scene.objects):
  if o.type=='MESH':
   for mod in list(o.modifiers):
    scene.view_layers[0].objects.active=o
    try:bpy.ops.object.modifier_apply(modifier=mod.name)
    except RuntimeError:pass
   for p in o.data.polygons:
    if len(p.vertices)<3:raise RuntimeError('degenerate face')
 bpy.context.view_layer.update()
 meshes=[o for o in scene.objects if o.type=='MESH']
 vertices=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
 low=[min(v[k] for v in vertices) for k in range(3)];high=[max(v[k] for v in vertices) for k in range(3)]
 if any(not math.isfinite(v[k]) for v in vertices for k in range(3)):raise RuntimeError('nonfinite vertices')
 if low[2]<-.025:raise RuntimeError('wheel/geometry below ground '+str(low))
 data={'id':id,'label':label,'category':cat,'body_type':kind,'length_m':L,'width_m':W,'height_m':H,'color':'#'+color,'wheel_count':count,'triangles':C.tri_count(meshes),'bounds_blender':{'min':low,'max':high},'forward_axis_gltf':'+Z','traffic_side':'right','steering':'left_hand_drive','source_skill':'zstack/vehicle','model':'res://assets/vehicles/'+id+'.glb','preview':'res://assets/vehicles/'+id+'.png','rig_scope':'wheel steer/spin; trailer or dump pivots where applicable; no door/crash simulation','nominal_dimensions':'original design values in metres, not a certified replica'}
 directory=OUT/id;directory.mkdir(exist_ok=True)
 (directory/'spec.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 # Retain a source camera for convenient inspection; exclude it from game export.
 bpy.ops.object.camera_add(location=(-L*.95,-L*1.15,H+L*.65));cam=bpy.context.object;cam.name='SourceCamera';cam.data.type='ORTHO';cam.data.ortho_scale=L*1.25;cam.rotation_euler=(Vector((0,0,H*.45))-cam.location).to_track_quat('-Z','Y').to_euler();scene.camera=cam
 bpy.ops.wm.save_as_mainfile(filepath=str(directory/'vehicle.blend'))
 for o in scene.objects:o.select_set(o.type in ['MESH','EMPTY'])
 bpy.ops.export_scene.gltf(filepath=str(GAME/(id+'.glb')),export_format='GLB',use_selection=True,export_extras=True,export_cameras=False,export_lights=False,export_yup=True,export_apply=True,export_animations=False)
 print('VEHICLE_DONE',id,'triangles',data['triangles'],'wheels',count,flush=True)
 return data

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--only');args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
 entries=[]
 for spec in SPECS:
  if args.only and spec[0]!=args.only:
   p=OUT/spec[0]/'spec.json'
   if p.exists():entries.append(json.loads(p.read_text()))
   continue
  entries.append(build(spec))
 catalog={'schema_version':1,'units':'metres','count':len(entries),'skill':'https://github.com/duolahypercho/zstack/tree/74f7786e9931b9ced858a0e2df880f23e4c2430e/skills/vehicle','entries':entries}
 (GAME/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
 (OUT/'production_log.md').write_text('# Vehicle production\n\n20 original low-poly city vehicles. Applied the vehicle skill metric frame, component separation, reviewed common.py helpers, wheel pivots, glTF extras and export checks.\n\nNot performed: real-vehicle reference/IoU calibration, opening-door sweeps or crash deformation. These are not certified replicas or a traffic simulator.\n')
 print('FLEET_COMPLETE',len(entries),flush=True)
