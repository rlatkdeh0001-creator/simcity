"""Eight remaining original primary main assets; source/PNG only, no game writes."""
from pathlib import Path
import bpy,sys,math,json,argparse,importlib.util
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1]
sp=importlib.util.spec_from_file_location('work_helpers',ROOT/'tools/build_primary_work_tiles.py');W=importlib.util.module_from_spec(sp);sp.loader.exec_module(W);P=W.P;G=W.G
ROWS=[('primary-farm-vegetable-01','채소·과수 농장','farm_vegetable','vegetable'),('primary-farm-livestock-01','축산 농장','farm_livestock','livestock'),('primary-forestry-01','벌목장','forestry','forestry'),('primary-mine-iron-01','철광산','mine_iron','iron'),('primary-mine-coal-01','석탄 광산','mine_coal','coal'),('primary-oil-01','유정 본부','oil','oil'),('primary-mine-uranium-01','우라늄 광산','mine_uranium','uranium'),('primary-fishing-01','어항','fishing','fishing')]

def box(n,p,s,m='cream'):return G.box(n,p,s,m,.015)
def cyl(n,p,r,h,m='metal',verts=16):return W.cylinder(n,p,r,h,m,verts)
def bar(n,a,b,w=.10,m='metal'):return W.bar(n,a,b,w,m)
def base(mat='paving'):
 box('LotPlinth',(0,0,0),(16,16,.24),mat)
 box('FrontServiceApron',(0,-6,.132),(14.6,3.8,.024),'stone')
def hall(name,x,y,w,d,floors=1,wall='cream',roof='green',freight=False):
 h=floors*3.05;box(name,(x,y,.12+h/2),(w,d,h),wall);P.gable(name+'Roof',x,y,w+.24,d+.24,.12+h,.12+h+1.10,roof)
 front=y-d/2-.07
 if freight:
  box('FreightDoorFrame',(x,front,1.57),(min(3.4,w-.8),.14,2.90),'metal')
  box('FreightDoor',(x,front-.08,1.55),(min(3.1,w-1.0),.035,2.68),'roof')
  for z in [.60,1.15,1.70,2.25]:box('ShutterSlat',(x,front-.11,z),(min(3.05,w-1.05),.025,.025),'stone')
 else:G.door(x,front,z=.12,w=1.10)
 for floor in range(floors):
  for xx in [x-w*.31,x+w*.31]:box('FacadeWindow',(xx,front-.04,.12+floor*3.05+1.7),(.85,.045,1.15),'glass')
 anchor=bpy.data.objects.new('Access_'+name,None);bpy.context.scene.collection.objects.link(anchor);anchor.location=(x,front,.12);anchor['outward_blender']=[0,-1,0]
 return .12+h+1.10

def greenhouse(x,y):
 width,length=4.6,5.5;stations=[-length/2,length/2];section=[(-width/2,.12),(-width/2,1.42)]+[(-width/2*math.cos(j*math.pi/8),1.42+1.6*math.sin(j*math.pi/8)) for j in range(1,9)]+[(width/2,.12)]
 n=len(section);vs=[(x+xx,y+yy,z) for yy in stations for xx,z in section];faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
 W.mesh('GreenhouseShell',vs,faces,'lightglass')
 for yy in [y-length/2,y,y+length/2]:
  pts=[(x-width/2,yy,.14),(x-width/2,yy,1.42)]+[(x-width/2*math.cos(j*math.pi/8),yy,1.42+1.6*math.sin(j*math.pi/8)) for j in range(1,9)]+[(x+width/2,yy,.14)]
  for a,b in zip(pts,pts[1:]):bar('GreenhouseRib',a,b,.055,'ivory')
 box('GreenhouseDoor',(x,y-length/2-.025,1.1),(1.15,.06,1.96),'ivory');box('GreenhouseDoorGlass',(x,y-length/2-.062,1.18),(.96,.018,1.64),'glass')

def vegetable():
 base();hall('Farmhouse',-4.5,-3.6,4.4,4.1,2);hall('SortingHouse',3.1,-3.6,5.5,4.1,1,'ochre','roof',True)
 greenhouse(-3.1,3.1);greenhouse(3.1,3.1)
 for x in [2.0,3.0,4.0]:box('ProduceCrate',(x,-6.27,.42),(.75,.8,.60),'wood');box('CrateProduce',(x,-6.27,.75),(.60,.65,.08),'leaf')

def fence(x0,x1,y0,y1,mat='wood',wire=False):
 for x in [x0,x1]:
  for i in range(5):box('FencePost',(x,y0+(y1-y0)*i/4,1.0),(.10,.10,1.76),mat)
  for z in [.65,1.35]:box('FenceRail',(x,(y0+y1)/2,z),(.06,y1-y0,.06),mat)
 for x in [x0+(x1-x0)*i/6 for i in range(7)]:box('FencePost',(x,y1,1.0),(.10,.10,1.76),mat)
 for z in [.65,1.35]:box('FenceRail',((x0+x1)/2,y1,z),(x1-x0,.06,.06),mat)
 if wire:
  for x in [x0,x1]:
   for i in range(int((y1-y0)/.45)+1):bar('FenceMesh',(x,y0+i*.45,.3),(x,y0+i*.45,1.8),.012,mat)
  for i in range(int((x1-x0)/.45)+1):bar('FenceMesh',(x0+i*.45,y1,.3),(x0+i*.45,y1,1.8),.012,mat)

def livestock():
 base('grass');hall('CattleBarn',-1.8,1.0,8.2,8.3,1,'red','roof',True)
 cyl('FeedSilo',(-6.1,5.8,2.92),.94,5.60,'cream');P.cone('FeedSiloCap',-6.1,5.8,5.72,1.03,.80,'metal')
 box('CattleYard',(5.3,.6,.13),(3.8,11,.02),'soil');fence(3.5,7.3,-4.8,6.6)
 for y in [-2,1.0,4.0]:box('FeedTrough',(4.0,y,.41),(.65,1.45,.55),'wood')
 box('FrontBarnCanopy',(-1.8,-4.0,2.9),(4.5,1.55,.14),'roof')

def forestry():
 base();hall('Sawmill',-3.2,1.7,7.8,7.6,1,'red','green',True)
 for layer in range(2):
  for x in [3.1,3.8,4.5,5.2]:
   log=cyl('LogStock',(x+layer*.15,3.1,.45+layer*.63),.30,4.8,'wood',12);log.rotation_euler[0]=math.pi/2
   end=cyl('LogCutFace',(x+layer*.15,.69,.45+layer*.63),.26,.025,'ochre',12);end.rotation_euler[0]=math.pi/2
 box('CraneFoot',(4.6,-2.7,.30),(1.25,1.25,.36),'metal');bar('CraneMast',(4.6,-2.7,.48),(4.6,-2.7,5.2),.26,'metal')
 bar('CraneBoom',(4.6,-2.7,5.2),(4.6,2.7,4.7),.24,'ochre');bar('CraneCable',(4.6,2.7,4.7),(4.6,2.7,2.4),.028,'black')
 for x in [4.35,4.85]:bar('LogGrab',(4.6,2.7,2.4),(x,2.7,2.0),.07,'metal')

def portal(x,y):
 W.rock('MineRockMass',x,y+1.2,.12,2.7,3.7,'stone')
 for xx in [x-1.25,x+1.25]:box('PortalPier',(xx,y,1.55),(.46,.65,2.86),'metal')
 box('PortalLintel',(x,y,3.0),(2.98,.65,.45),'metal');box('MinePortalOpening',(x,y-.34,1.43),(2.02,.05,2.50),'black')
 for xx in [x-.45,x+.45]:box('MineTrack',(xx,y-1.2,.15),(.07,2.3,.05),'metal')

def headframe(x,y):
 for xx in [x-1.1,x+1.1]:
  for yy in [y-.9,y+.9]:bar('HeadframeLeg',(xx,yy,.12),(x+(xx-x)*.65,y+(yy-y)*.65,7.9),.20,'metal')
 for z in [2.0,4.5,7.0]:
  for yy in [y-.85,y+.85]:bar('HeadframeBrace',(x-1,yy,z-1.3),(x+1,yy,z),.09,'metal')
 box('HeadframePlatform',(x,y,7.8),(2.9,2.6,.18),'ochre')
 wheel=cyl('HoistWheel',(x,y,8.45),.70,.30,'metal',20);wheel.rotation_euler[0]=math.pi/2
 for xx in [x-.23,x+.23]:bar('HoistCable',(xx,y-.20,.50),(xx,y-.20,8.35),.025,'black')
 box('HeadframeCap',(x,y,9.2),(3.1,2.8,.16),'roof')

def mine(kind):
 base();portal(-3.8,2.1);headframe(2.6,3.3);hall('MineOffice',-4.2,-4.8,4.8,3.3,1,'cream','roof')
 if kind=='iron':
  # A broad red equipment hall dominates the iron mine instead of another pile-only yard.
  box('CrusherBuilding',(2.5,-1.55,3.17),(7.3,5.7,6.10),'red')
  P.gable('CrusherRoof',2.5,-1.55,7.55,5.95,6.22,7.20,'metal')
  box('CrusherDoorFrame',(1.0,-4.48,1.60),(2.9,.16,2.94),'metal')
  box('CrusherDoor',(1.0,-4.58,1.57),(2.6,.035,2.74),'roof')
  for z in [.55,1.15,1.75,2.35]:box('CrusherShutterSlat',(1.0,-4.615,z),(2.55,.02,.035),'stone')
  # External angular feed hopper and dust filter make the processing function readable.
  vs=[(4.0,-4.5,3.0),(5.0,-4.5,3.0),(5.0,-3.6,3.0),(4.0,-3.6,3.0),
      (3.4,-4.9,5.15),(5.6,-4.9,5.15),(5.6,-3.3,5.15),(3.4,-3.3,5.15)]
  W.mesh('CrusherFeedHopper',vs,[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'metal')
  box('CrusherHopperRim',(4.5,-4.08,5.17),(2.34,1.74,.12),'red')
  box('CrusherHopperOpening',(4.5,-4.08,5.239),(2.07,1.46,.025),'black')
  cyl('CrusherDustFilter',(6.86,.3,2.50),.50,4.72,'roof',12)
  bar('CrusherDustDuct',(6.86,.3,4.85),(5.80,.3,4.85),.32,'metal')
  box('CrusherFascia',(1.2,-4.48,4.85),(3.25,.16,.65),'metal');G.text('CRUSHER',(1.2,-4.575,4.85),2.85,.39)
  marker=bpy.data.objects.new('Access_CrusherBuilding',None);bpy.context.scene.collection.objects.link(marker);marker.location=(1.0,-4.65,.12);marker['outward_blender']=[0,-1,0]
  for x,y,r,h in [(5.80,-6.0,1.22,2.10),(2.35,-6.65,.92,1.35),(-.1,-6.35,.78,1.0)]:W.rock('OreStock',x,y,.18,r,h,'ironrock')
 else:
  # Coal reads as a large low black stockyard with a high, wide open conveyor.
  box('CoalStockApron',(3.35,-3.75,.16),(7.1,7.3,.08),'soil')
  for x,y,r,h in [(3.35,-2.9,2.20,3.70),(5.15,-4.7,1.65,2.65),(1.25,-5.9,1.35,1.95)]:W.rock('OreStock',x,y,.20,r,h,'coalrock')
  a=Vector((4.1,-3.0,3.45));b=Vector((2.3,2.5,6.15));d=b-a
  belt=box('ConveyorBelt',(a+b)/2,(1.85,.18,d.length),'black');belt.rotation_euler=d.to_track_quat('Z','Y').to_euler()
  for dx in [-1.0,1.0]:
   bar('ConveyorRail',a+Vector((dx,0,.08)),b+Vector((dx,0,.08)),.14,'ochre')
   bar('ConveyorLowerChord',a+Vector((dx,0,-.50)),b+Vector((dx,0,-.50)),.13,'metal')
  for t in [.10,.25,.40,.55,.70,.85,.96]:
   q=a+d*t;bar('ConveyorRoller',q+Vector((-1,0,-.05)),q+Vector((1,0,-.05)),.09,'metal')
  for t in [.2,.55,.88]:
   q=a+d*t
   for dx in [-.8,.8]:bar('ConveyorSupport',(q.x+dx,q.y,.15),(q.x+dx,q.y,q.z-.4),.16,'metal')

def oil():
 base();hall('OilOffice',-4.6,-3.5,4.8,4.4,2,'cream','metal')
 for x in [-3.3,3.3]:
  cyl('OilStorageTank',(x,4.2,2.32),1.72,4.40,'cream',24);P.cone('OilTankCap',x,4.2,4.52,1.75,.38,'metal')
  for z in [.55,2.45,4.38]:
   bpy.ops.mesh.primitive_torus_add(major_radius=1.72,minor_radius=.035,major_segments=24,minor_segments=4,location=(x,4.2,z));o=bpy.context.object;o.name='TankBand';o.data.materials.append(G.M['metal'])
 before=set(bpy.context.scene.objects);W.oil();new=set(bpy.context.scene.objects)-before
 for ob in list(new):
  if ob.name.startswith('TileGround'):bpy.data.objects.remove(ob,do_unlink=True);new.remove(ob)
 bpy.context.view_layer.update()
 t=Matrix.Translation(Vector((3.3,-2.6,.12)))@Matrix.Scale(2.2,4)
 for ob in new:ob.matrix_world=t@ob.matrix_world
 for x in [-3.3,3.3]:bar('OilHeader',(x,4.2,.65),(x,.90,.65),.16,'metal')
 bar('OilHeader',(-3.3,.9,.65),(3.3,.9,.65),.16,'metal')

def uranium():
 base();portal(-3.9,3.4);hall('SealedUraniumStore',3.1,3.5,5.5,5.4,1,'stone','metal',True);hall('ControlOffice',-3.7,-3.7,5.1,4.2,1,'cream','green')
 fence(-7.5,7.5,-.4,7.3,'metal',True)
 for x,y in [(-6.5,-.4),(6.5,-.4)]:
  before=set(bpy.context.scene.objects);W.radiation(0,0,0)
  bpy.context.view_layer.update()
  t=Matrix.Translation(Vector((x,y,1.75)))@Matrix.Scale(2.2,4)
  for ob in set(bpy.context.scene.objects)-before:ob.matrix_world=t@ob.matrix_world
 box('ControlledGateLeft',(-1.8,-.55,1.15),(.16,.18,2.1),'ochre');box('ControlledGateRight',(1.8,-.55,1.15),(.16,.18,2.1),'ochre')


def boat(x,y):
 # Two editable fictional boats; bow faces +Y into the water side.
 vs=[(x-.58,y-2.1,-.08),(x+.58,y-2.1,-.08),(x+.60,y+1.25,-.08),(x,y+2.25,-.08),(x-.60,y+1.25,-.08),
     (x-.78,y-2.1,.55),(x+.78,y-2.1,.55),(x+.78,y+1.25,.55),(x,y+2.25,.55),(x-.78,y+1.25,.55)]
 faces=[tuple(reversed(range(5))),tuple(range(5,10))]+[(j,(j+1)%5,(j+1)%5+5,j+5) for j in range(5)]
 W.mesh('FishingBoatHull',vs,faces,'blue');box('BoatDeck',(x,y-.20,.59),(1.30,2.5,.08),'wood');box('BoatCabin',(x,y-.8,1.10),(1.1,1.35,.94),'cream')
 box('BoatWindscreen',(x,y-.10,1.25),(.88,.03,.45),'glass');box('BoatCabinRoof',(x,y-.8,1.62),(1.25,1.48,.12),'ivory')
 bar('BoatMast',(x,y+.20,.62),(x,y+.20,2.30),.06,'metal')

def fishing():
 box('LandPlinth',(0,-3,0),(16,10,.24),'paving');box('FrontServiceApron',(0,-6,.133),(14.6,3.8,.026),'stone')
 hall('FishProcessing',-2.8,-3.15,8.3,6.25,1,'cream','blue',True);hall('ColdStorage',4.8,-3.2,4.0,4.6,1,'stone','roof',True)
 # No opaque water plane. Shoreline is y=+2; all piers and boats remain inside +/-8.
 box('PierSpine',(0,5,.20),(1.8,6,.16),'wood')
 for x in [-6.35,6.35]:box('SidePier',(x,4.65,.20),(.90,5.30,.16),'wood')
 box('CrossPier',(0,2.5,.20),(13.6,1.0,.16),'wood')
 for x in [-6.35,0,6.35]:
  for y in [2.5,6.7]:cyl('PierSupport',(x,y,.04),.13,.24,'metal',8)
 boat(-4.65,5.10);boat(4.65,5.10)
 for x in [-2.1,1.8]:box('FishCrate',(x,.70,.40),(1.05,.70,.56),'wood')

BUILDERS={'vegetable':vegetable,'livestock':livestock,'forestry':forestry,'iron':lambda:mine('iron'),'coal':lambda:mine('coal'),'oil':oil,'uranium':uranium,'fishing':fishing}

def build(row):
 ident,name,industry,style=row;G.COLORS.update(W.COLORS);G.reset();BUILDERS[style]();pts,bb,tri=P.bounds()
 assert all(bb[0][i]>=-8-.0001 and bb[1][i]<=8+.0001 for i in [0,1]),(ident,bb)
 marker=bpy.data.objects.new('RoadFront_BlenderMinusY',None);bpy.context.scene.collection.objects.link(marker);marker.location=(0,-8,.12)
 cam=P.studio(pts,(900,1100));scene=bpy.context.scene;out=P.OUT/ident;out.mkdir(parents=True,exist_ok=True)
 meta=dict(id=ident,name=name,kind='primary_main',industry=industry,footprint_cells=[4,4],cell_meters=4,lot_meters=[16,16],floors=2 if style in ['vegetable','oil'] else 1,main_storey_height_m=3.05,footprint_status='user-specified',front='-Y (Blender) / +Z (Godot)',front_blender='-Y',front_godot='+Z',vertex_bounds_m=bb,measured_dimensions_m=[bb[1][i]-bb[0][i] for i in range(3)],triangles=tri,camera_elevation_degrees=30,game_registered=False,approval_status='pending-user-review',source=('original scripted Blender geometry; packed system DejaVu font; no external models, textures or generation APIs' if style=='iron' else 'original scripted Blender geometry; system font supported but no font used; no external models, textures or generation APIs'))
 if style=='fishing':meta.update(waterfront_blender='+Y',shoreline_y_m=2,water_surface_included=False,boat_count=2,pier_within_lot=True)
 for font in bpy.data.fonts:
  if font.filepath and Path(font.filepath).is_file():font.pack()
 (out/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n');bpy.ops.wm.save_as_mainfile(filepath=str(out/(ident+'.blend')))
 scene.render.filepath=str(out/'building.png');bpy.ops.render.render(write_still=True)
 if style=='fishing':
  target=Vector(cam['target_m']);delta=cam.location-target;cam.location=target+Vector((delta.x,-delta.y,delta.z));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/'rear-review.png');bpy.ops.render.render(write_still=True)
 print('PRIMARY_MAIN_DONE',ident,meta['measured_dimensions_m'],tri,flush=True)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--only',choices=[r[0] for r in ROWS]);a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
 for row in ROWS:
  if not a.only or a.only==row[0]:build(row)
