"""Original CITIES_DO review assets only. No game/catalog files are written.
blender -b --factory-startup -t 6 -P tools/build_growth_14.py [-- --only ID]
"""
import bpy,math,json,sys,argparse
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[1]; FLOOR=3.05
FLEET=[
('residential','medium-2x2-multiplex-01','필로티 다세대주택','medium',2,5,'multiplex'),
('residential','medium-2x2-corner-villa-02','코너형 원룸 빌라','medium',2,6,'corner'),
('residential','large-2x2-slim-tower-01','세로 발코니 주거타워','large',2,10,'slim'),
('residential','large-2x2-pencil-tower-02','세트백 펜슬 주거타워','large',2,12,'pencil'),
('commercial','medium-2x2-neighborhood-01','편의점·학원 근린상가','medium',2,4,'neighborhood'),
('commercial','medium-2x2-cafe-building-02','층별 식당·카페 빌딩','medium',2,5,'cafe'),
('commercial','large-2x2-slim-office-01','커튼월 슬림 오피스','large',2,8,'office'),
('commercial','large-2x2-boutique-hotel-02','명품매장 부티크 호텔','large',2,10,'hotel'),
('industrial','medium-2x2-bakery-01','소형 제빵 공장','medium',2,2,'bakery'),
('industrial','medium-2x2-electronics-02','클린룸 전자부품 공장','medium',2,3,'electronics'),
('industrial','large-2x2-grain-silo-01','곡물 사일로·컨베이어','large',2,0,'silo'),
('industrial','large-2x2-distillation-02','화학 증류탑 설비','large',2,0,'distill'),
('industrial','small-4x4-logistics-01','2베이 물류창고','small',4,1,'logistics'),
('industrial','small-4x4-metalshop-02','금속가공 작업장·야적장','small',4,1,'metalshop')]
COLORS={'cream':'e4dfce','paving':'d9dacd','stone':'bdbfb3','green':'346d58','metal':'435759','glass':'75a1ab','lightglass':'afc4c1','roof':'949d96','wood':'a58056','red':'b56f5d','leaf':'64815a','black':'34413e','ivory':'f8edcf','blue':'7093a1','ochre':'c4a473'}
M={};CACHE={}
def rgb(h):
 c=[int(h[i:i+2],16)/255 for i in [0,2,4]];return tuple(v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in c)+(1,)
def reset():
 global M,CACHE
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0;CACHE={};M={}
 for k,h in COLORS.items():
  m=bpy.data.materials.new(k);m.use_nodes=True;s=m.node_tree.nodes['Principled BSDF'];s.inputs['Base Color'].default_value=rgb(h);s.inputs['Roughness'].default_value=.65 if k!='glass' else .2;s.inputs['Metallic'].default_value=.2 if k=='metal' else 0;M[k]=m
 bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1

def box(name,loc,size,mat='cream',bevel=.015):
 key=(tuple(size),mat)
 if key not in CACHE:
  x,y,z=[v/2 for v in size];vs=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)];mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]);mesh.materials.append(M[mat]);mesh.update();CACHE[key]=mesh
 o=bpy.data.objects.new(name,CACHE[key]);bpy.context.scene.collection.objects.link(o);o.location=loc
 if bevel:
  b=o.modifiers.new('Edge highlights','BEVEL');b.width=min(bevel,min(size)*.15);b.segments=2
 return o

def tube(name,loc,r,h,mat='metal',vertices=16):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=h,location=loc);o=bpy.context.object;o.name=name;o.data.materials.append(M[mat]);b=o.modifiers.new('Edges','BEVEL');b.width=.025;b.segments=2;return o

def bar(name,a,b,r=.035,mat='metal'):
 d=Vector(b)-Vector(a);o=tube(name,(Vector(a)+Vector(b))/2,r,d.length,mat,12);o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return o

def text(body,loc,width=3.5,height=.35):
 c=bpy.data.curves.new('Sign_'+body,'FONT');c.body=body;c.align_x='CENTER';c.align_y='CENTER';c.extrude=.008
 c.font=bpy.data.fonts.load('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf');o=bpy.data.objects.new('Sign_'+body,c);bpy.context.scene.collection.objects.link(o);o.location=loc;o.data.materials.append(M['ivory']);bpy.context.view_layer.update();c.size*=min(width/max(o.dimensions.x,.001),height/max(o.dimensions.y,.001));o.rotation_euler=(math.pi/2,0,0);bpy.context.view_layer.update();return o

def door(x,y,z=.12,w=1.1,h=2.35):
 box('EntranceFrame',(x,y,z+h/2),(w+.18,.13,h+.15),'metal');box('EntranceGlass',(x,y-.08,z+h/2),(w,.045,h),'lightglass');bar('DoorHandle',(x+w*.22,y-.13,z+.85),(x+w*.22,y-.13,z+1.25),.025)

def roof(w,d,y,z,mat='cream'):
 box('RoofCap',(0,y,z),(w+.20,d+.20,.18),mat)
 for yy in [y-d/2,y+d/2]:box('RoofParapet',(0,yy,z+.23),(w,.10,.4),mat)
 for xx in [-w/2,w/2]:box('RoofParapet',(xx,y,z+.23),(.1,d,.4),mat)

def windows(w,d,cy,floor,z,mat='cream',balcony=False,continuous=False):
 h=1.68;count=max(2,int(w/1.65))
 for i in range(count):
  x=-w/2+(i+.5)*w/count
  box('FrontWindow_%02d'%floor,(x,cy-d/2-.025,z),(w/count-.28,.065,h),'glass');box('WindowSill',(x,cy-d/2-.07,z-h/2-.06),(w/count-.14,.14,.10),'ivory')
 for i in range(max(2,int(d/1.9))):
  y=cy-d/2+(i+.5)*d/max(2,int(d/1.9));box('SideWindow_%02d'%floor,(w/2+.025,y,z),(.065,d/max(2,int(d/1.9))-.3,h),'glass')
 if continuous:
  box('FrontFloorBand',(0,cy-d/2-.07,z+1.08),(w+.1,.14,.23),'metal')
 if balcony:
  bw=min(2.2,w*.4);x=-w*.24
  box('BalconySlab',(x,cy-d/2-.42,z-.95),(bw,.82,.13),'stone')
  box('BalconyFront',(x,cy-d/2-.79,z-.45),(bw,.07,.95),mat)
  for xx in [x-bw/2,x+bw/2]:box('BalconySide',(xx,cy-d/2-.4,z-.45),(.07,.8,.95),mat)

def car(x,y):
 box('ParkedCar',(x,y,.70),(1.75,4.3,.95),'blue',.12);box('CarCabin',(x,y+.12,1.30),(1.5,2.05,.6),'lightglass',.09)
 for xx in [-.80,.80]:
  for yy in [-1.35,1.35]:
   o=tube('CarWheel',(x+xx,y+yy,.42),.31,.18,'black',12);o.rotation_euler[1]=math.pi/2

def residential(style,floors):
 w,d,cy=6.05,5.55,.55;mat='red' if style=='multiplex' else 'cream'
 if style=='corner':w,d,cy=6.3,5.85,.28;mat='ochre'
 if style=='slim':w,d,cy=5.7,5.9,.45;mat='cream'
 if style=='pencil':w,d,cy=5.65,5.65,.5;mat='stone'
 base=.12
 for floor in range(floors):
  z=base+floor*FLOOR
  ww=w-(.9 if style=='pencil' and floor>=9 else 0)-(1.0 if style=='pencil' and floor>=11 else 0)
  dd=d-(.8 if style=='pencil' and floor>=9 else 0)
  if floor==0 and style=='multiplex':
   for xx in [-w/2+.18,w/2-.18]:
    for yy in [cy-d/2+.2,cy+d/2-.2]:box('PilotiColumn',(xx,yy,z+FLOOR/2),(.32,.32,FLOOR),'stone')
   box('EntranceStairCore',(1.98,cy+.35,z+FLOOR/2),(1.45,3.9,FLOOR),'cream');door(1.98,cy-1.62);car(-.85,.6)
  else:
   box('Storey_%02d'%(floor+1),(0,cy,z+FLOOR/2),(ww,dd,FLOOR),mat)
   windows(ww,dd,cy,floor+1,z+1.5,mat,style in ['multiplex','slim'] and floor>0)
   if style=='corner':
    box('CornerInsetGlass',(ww/2+.04,cy-dd*.30,z+1.55),(.08,1.6,1.9),'lightglass')
    box('CornerShade',(ww/2+.12,cy-dd*.30,z+2.75),(.3,1.8,.12),'ivory')
   if floor==0:door(0,cy-dd/2-.10)
  box('SlabEdge',(0,cy,z+FLOOR-.05),(ww+.14,dd+.14,.18),'ivory')
  if style=='pencil' and floor in [8,10]:roof(ww,dd,cy,z+FLOOR)
 top=base+floors*FLOOR;roof(ww,dd,cy,top,mat)
 box('RoofAccess',(0,cy+1.0,top+1.275),(1.65,1.8,2.45),'cream');door(0,cy+.02,z=top+.05,w=.85,h=2.15)
 if style=='slim':
  for x in [-2.15,2.15]:box('VerticalTowerFin',(x,cy-d/2-.10,top/2),(.14,.20,top),'stone')

def commercial(style,floors):
 w,d,cy=6.2,5.95,.45
 for floor in range(floors):
  z=.12+floor*FLOOR
  ww=w-(.5 if style=='office' and floor>=6 else 0)
  box('Storey_%02d'%(floor+1),(0,cy,z+FLOOR/2),(ww,d,FLOOR),'cream' if style!='cafe' else 'red')
  if style=='office':
   box('CurtainWall',(0,cy-d/2-.04,z+1.55),(ww-.15,.08,2.8),'glass')
   box('CurtainWallSide',(ww/2+.04,cy,z+1.55),(.08,d-.18,2.8),'lightglass')
   for x in [-2.3,-1.15,0,1.15,2.3]:box('CurtainMullion',(x,cy-d/2-.10,z+1.55),(.055,.07,2.85),'metal')
   box('Spandrel',(0,cy-d/2-.10,z+.15),(ww+.1,.14,.30),'metal')
  else:windows(ww,d,cy,floor+1,z+1.5,'cream',False,True)
  if style in ['neighborhood','cafe']:
   label=(['MART','ACADEMY','CLINIC','OFFICE'] if style=='neighborhood' else ['CAFE','BISTRO','NOODLES','DINING','ROOFTOP'])[floor]
   box('TenantFascia',(0,cy-d/2-.18,z+2.7),(ww-.12,.26,.55),'green' if style=='neighborhood' else 'wood');text(label,(0,cy-d/2-.325,z+2.7),ww-.5,.33)
 door(0,cy-d/2-.12,w=1.25)
 box('EntryCanopy',(0,cy-d/2-.50,2.65),(2.3,1.0,.14),'metal')
 top=.12+floors*FLOOR;roof(ww,d,cy,top,'metal' if style=='office' else 'cream')
 box('HVAC',(0,cy+1.1,top+.55),(1.8,1.6,.8),'metal')
 if style=='hotel':
  text('HOTEL',(0,cy-d/2-.12,top-1.0),4.9,.70)
  box('LuxuryFascia',(-1.6,cy-d/2-.17,2.7),(2.5,.25,.65),'black');text('JEWEL',(-1.6,cy-d/2-.31,2.7),2.15,.28)
  for x in [-1.8,0,1.8]:box('HotelPier',(x,cy-d/2-.12,1.45),(.14,.22,2.7),'stone')
 if style=='cafe':
  for x in [-2.1,2.1]:tube('CafeTable',(x,-3.30,.85),.36,.1,'wood');box('CafeTableLeg',(x,-3.30,.48),(.12,.12,.7),'metal')

def industrial(style,floors):
 if style in ['bakery','electronics']:
  w,d,cy=6.1,5.3,.75;mat='ochre' if style=='bakery' else 'ivory'
  for floor in range(floors):
   z=.12+floor*FLOOR;box('ProductionFloor_%02d'%(floor+1),(0,cy,z+FLOOR/2),(w,d,FLOOR),mat)
   windows(w,d,cy,floor+1,z+1.8,mat,False,True)
  top=.12+floors*FLOOR;roof(w,d,cy,top,'stone');door(-1.95,cy-d/2-.12)
  box('LoadingDoor',(.65,cy-d/2-.10,1.5),(2.25,.12,2.65),'metal')
  if style=='electronics':
   box('ElectronicsSignBacking',(0,cy-d/2-.16,3.50),(5.4,.16,.72),'metal')
   text('MICRO LAB',(0,cy-d/2-.255,3.50),5.0,.42)
  else:text('BAKERY',(0,cy-d/2-.20,2.83),5.2,.35)
  for i in range(2 if style=='bakery' else 3):
   x=-1.7+i*1.6;box('RooftopAirPlant',(x,cy+.6,top+.6),(1.25,1.6,.95),'metal');tube('AirFilter',(x,cy+.6,top+1.15),.4,.18,'roof')
  if style=='bakery':
   bar('OvenExhaust',(-2.65,cy+.9,2),(-2.65,cy+.9,top+2),.22);tube('OvenExhaustCap',(-2.65,cy+.9,top+2),.34,.16,'stone')
  else:
   box('CleanRoomAirlock',(1.8,-2.5,1.6),(2.0,1.15,2.9),'lightglass');box('CleanRoomDoor',(1.8,-3.09,1.4),(.95,.05,2.35),'metal')
 elif style=='silo':
  for x in [-1.6,1.6]:
   tube('GrainSilo',(x,.9,7.1),1.35,13.3,'ivory',24);tube('SiloRoof',(x,.9,13.8),1.42,.35,'metal',24)
   for z in [2,5,8,11]:tube('SiloRing',(x,.9,z),1.38,.09,'stone',24)
  box('ElevatorHead',(0,1.0,15.6),(1.1,1.3,2.8),'blue');box('TopConveyor',(0,1.0,14.2),(5.6,.7,.6),'metal')
  box('BaggingHouse',(0,-2.2,1.8),(5.9,2.3,3.35),'ochre');door(0,-3.4);text('GRAIN',(0,-3.43,2.8),4.7,.4)
  bar('FeedConveyor',(2.0,-2.7,2.9),(2.0,.5,6.1),.23)
  for z in range(1,15):bar('ElevatorRung',(-.53,-.2,z),(.53,-.2,z),.035)
 else:
  if style=='distill':
   tube('DistillationColumn',(0,.8,9.2),1.25,17.8,'stone',24)
   for z in [3.1,7.1,11.1,15.1]:
    tube('ServiceDeck',(0,.8,z),1.8,.16,'metal',24)
    for a in range(0,360,30):
     rad=math.radians(a);x,y=1.7*math.cos(rad),.8+1.7*math.sin(rad);bar('SafetyRailPost',(x,y,z),(x,y,z+.9),.027)
    tube('ColumnBand',(0,.8,z+.45),1.29,.14,'ivory',24)
   tube('Flue',(2.65,1.5,7.1),.36,13.8,'red');bar('MainPipe',(-2.8,-1.7,.6),(-2.8,-1.7,12.4),.16)
   bar('PipeElbow',(-2.8,-1.7,12.4),(0,-.5,12.4),.16);box('ControlCabin',(0,-2.6,1.4),(3.4,1.5,2.55),'ivory');door(0,-3.4);text('CHEM',(0,-3.46,2.2),2.6,.3)
  else:
   w,d,cy=13.6,8.4,2.2;top=5.1 if style=='logistics' else 4.5
   box('IndustrialHall',(0,cy,(top+.12)/2),(w,d,top-.12),'cream' if style=='logistics' else 'blue')
   box('HallRoof',(0,cy,top+.16),(w+.25,d+.25,.3),'metal')
   if style=='metalshop':
    for yy in [cy-2.4,cy+.2,cy+2.8]:
     box('SawtoothMonitor',(0,yy,top+.6),(12.8,1.4,.85),'stone');box('RoofNorthLight',(0,yy-.73,top+.65),(12.5,.06,.65),'glass')
   front=cy-d/2
   for x in [-3.5,3.5]:
    box('LoadingShutter',(x,front-.08,1.9),(3.3,.14,3.5),'metal')
    for z in [.5,1,1.5,2,2.5,3]:box('ShutterRib',(x,front-.17,z),(3.2,.05,.045),'stone')
    box('DockCanopy',(x,front-.65,3.9),(3.8,1.4,.16),'ivory')
    for xx in [x-1.8,x+1.8]:box('DockApronLine',(xx,-4.7,.135),(.07,4.3,.025),'ivory')
   door(0,front-.12)
   sign_z=4.60 if style=='logistics' else 4.23
   sign_width=7.2 if style=='logistics' else 5.6
   box('IndustrialSignBacking',(0,front-.20,sign_z),(sign_width,.15,.80 if style=='logistics' else .52),'metal')
   text('LOGISTICS' if style=='logistics' else 'METAL WORKS',(0,front-.29,sign_z),sign_width-.3,.47 if style=='logistics' else .34)
   if style=='metalshop':
    for x in [-5.3,-3.9,-2.5]:
     for z in [.45,.85,1.25]:box('StackedSteelStock',(x,-5.8,z),(1.15,2.5,.25),'stone')
    box('OutdoorWorkBench',(4.6,-5.7,.85),(3.0,2.0,1.4),'wood')
   else:
    for x in [-5.8,5.8]:
     for z in [.4,.95]:box('FreightPallet',(x,-4.9,z),(1.0,1.6,.4),'wood')

def build(row):
 zone,ident,label,density,n,floors,style=row;reset();scene=bpy.context.scene;W=n*4
 out=ROOT/f'assets/{zone}-growth'/ident;out.mkdir(parents=True,exist_ok=True)
 box('LotPlinth',(0,0,0),(W,W,.24),'paving',0)
 if zone=='residential':residential(style,floors)
 elif zone=='commercial':commercial(style,floors)
 else:industrial(style,floors)
 for i in range(floors):
  o=bpy.data.objects.new('OccupiedFloor_%02d'%(i+1),None);o['storey_index']=i+1;scene.collection.objects.link(o)
 bpy.context.view_layer.update();meshes=[o for o in scene.objects if o.type=='MESH']
 vertices=[o.matrix_world@v.co for o in meshes for v in o.data.vertices];low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
 assert low[0]>=-W/2-.0001 and high[0]<=W/2+.0001 and low[1]>=-W/2-.0001 and high[1]<=W/2+.0001,(ident,low,high)
 # Centre front door/road marker is an empty, not a rendered extra object.
 anchor=bpy.data.objects.new('RoadFront_BlenderMinusY',None);anchor.location=(0,-W/2,.12);anchor['front_gltf']='+Z';scene.collection.objects.link(anchor)
 target_z=(high[2]+low[2])*.48;distance=60
 bpy.ops.object.camera_add(location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.pi/6)));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,target_z))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=max(W*1.9,high[2]*1.15);scene.camera=cam
 scene.render.resolution_x=900;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
 # Fit every actual vertex with a fixed 5% margin, retaining the existing azimuth/elevation.
 for _ in range(12):
  bpy.context.view_layer.update();points=[world_to_camera_view(scene,cam,v) for v in vertices]
  excess=max(max(abs(p.x-.5)/.45,abs(p.y-.5)/.45) for p in points)
  if excess<=1.001:break
  cam.data.ortho_scale*=excess*1.01
 bpy.ops.object.light_add(type='AREA',location=(-12,-14,28));light=bpy.context.object;light.name='Key';light.data.energy=2800;light.data.shape='DISK';light.data.size=12;light.rotation_euler=(Vector((0,0,high[2]*.35))-light.location).to_track_quat('-Z','Y').to_euler()
 scene.world=bpy.data.worlds.new('World');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.55,.65,.75,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.55
 scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=48;scene.cycles.use_denoising=False;scene.render.threads_mode='FIXED';scene.render.threads=6;scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
 def pixel(v):
  p=world_to_camera_view(scene,cam,Vector(v));return [round(p.x*900,4),round((1-p.y)*1100,4)]
 meta={'id':ident,'name':label,'zone':zone,'category':density+'_'+zone,'density':density,'footprint_cells':[n,n],'cell_meters':4,'lot_meters':[W,W],'floors':floors,'occupied_storeys':floors,'storey_height_m':FLOOR,'footprint_status':'user-specified','front':'+Z','front_coordinate_space':'gltf/Godot','front_blender':'-Y','up_blender':'+Z','floor_reference_m':.12,'plinth_min_z_m':-.12,'vertex_bounds_m':[low,high],'measured_dimensions_m':[high[i]-low[i] for i in range(3)],'image_size':[900,1100],'anchor_px':pixel((W/2,-W/2,.12)),'lot_corners_px':[pixel(v) for v in [(-W/2,-W/2,.12),(W/2,-W/2,.12),(W/2,W/2,.12),(-W/2,W/2,.12)]],'camera_elevation_degrees':30,'camera_azimuth_degrees':-45,'orthographic_scale':cam.data.ortho_scale,'approval_status':'pending-user-review','game_registered':False,'source':'original scripted Blender geometry; system DejaVu font; no external models, textures or generation APIs','scope':'asset-only preview; 8x8 removed by user; no runtime/game catalog changes','industrial_structure_only':floors==0}
 (out/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
 for f in bpy.data.fonts:
  if f.filepath and Path(f.filepath).is_file():f.pack()
 bpy.ops.wm.save_as_mainfile(filepath=str(out/(ident+'.blend')))
 scene.render.filepath=str(out/'building.png');bpy.ops.render.render(write_still=True)
 print('ASSET_DONE',ident,meta['measured_dimensions_m'],floors,flush=True)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--only');a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
 for row in FLEET:
  if not a.only or row[1]==a.only:build(row)
