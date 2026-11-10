"""Original one-asset MART concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'large-4x4-chemical-06';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# Large industrial 02 · Chemical Works\n\nBrief: chemical production facility, 4x4 cells (16x16m), two occupied floors with taller process equipment. Approval pending; do not register in game. Original Blender geometry, game-art consistency and adapted kiln local source/visual-review principles. No external model, texture, or generation API.\n\nCheckpoint: BRIEF\n')
def checkpoint(stage,text):
 with log.open('a') as f:f.write(f'\n## {stage}\n{text}\n\nCheckpoint: {stage}\n')
def rgb(h):
 v=[int(h[i:i+2],16)/255 for i in [0,2,4]];return tuple(x/12.92 if x<.04045 else ((x+.055)/1.055)**2.4 for x in v)+(1,)
def mat(name,h,metal=0,rough=.65):
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=rgb(h);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal;return m
colors={'cream':'e4dfce','paving':'d9dacd','stone':'bdbfb3','green':'346d58','darkgreen':'224f45','orange':'d6a253','ivory':'f8edcf','metal':'435759','glass':'75a1ab','lightglass':'afc4c1','roof':'949d96','wood':'a58056','shelf':'47584b','red':'c9694e','fruit':'d7a23d','leaf':'64815a','black':'34413e'}
m={key:mat('M_'+key,value,.25 if key in ['metal','glass'] else 0,.18 if key=='glass' else .65) for key,value in colors.items()}
p=m['ivory'].node_tree.nodes['Principled BSDF'];p.inputs['Emission Color'].default_value=rgb('f8edcf');p.inputs['Emission Strength'].default_value=.08
cache={}
def box(name,loc,size,material,bevel=.015):
 key=(tuple(size),material)
 if key not in cache:
  x,y,z=[v/2 for v in size];vertices=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
  mesh=bpy.data.meshes.new('SharedBox');mesh.from_pydata(vertices,[],[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]);mesh.update();mesh.materials.append(m[material]);cache[key]=mesh
 obj=bpy.data.objects.new(name,cache[key]);scene.collection.objects.link(obj);obj.location=loc
 if bevel:
  mod=obj.modifiers.new('EdgeHighlights','BEVEL');mod.width=min(bevel,min(size)*.2);mod.segments=2
 return obj

def bar(name,a,b,r=.025,material='metal'):
 delta=Vector(b)-Vector(a);bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=r,depth=delta.length,location=(Vector(a)+Vector(b))/2);o=bpy.context.object;o.name=name;o.rotation_euler=delta.to_track_quat('Z','Y').to_euler();o.data.materials.append(m[material]);return o

def text(name,body,location,rotation,width,height):
 curve=bpy.data.curves.new(name,'FONT');curve.body=body;curve.align_x='CENTER';curve.align_y='CENTER';curve.extrude=.009;curve.bevel_depth=.002
 font=Path('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf')
 if font.exists():curve.font=bpy.data.fonts.load(str(font))
 obj=bpy.data.objects.new(name,curve);scene.collection.objects.link(obj);obj.location=location;obj.rotation_euler=rotation;obj.data.materials.append(m['ivory']);bpy.context.view_layer.update()
 # Measure text in its unrotated local XY plane, so front and side signs have equal cap height.
 raw_x=max(v[0] for v in obj.bound_box)-min(v[0] for v in obj.bound_box);raw_y=max(v[1] for v in obj.bound_box)-min(v[1] for v in obj.bound_box)
 factor=min(width/max(.001,raw_x),height/max(.001,raw_y));obj.scale=(factor,factor,factor)
 return obj






box('Lot_4x4',(0,0,0),(16,16,.24),'stone',.04)
box('ConcreteYard',(0,0,.15),(15.9,15.9,.1),'paving')
# Two-storey production/control wing. Tall apparatus is unoccupied equipment.
box('ProductionWing',(-3.35,1.1,3.4),(5.3,10.3,6.4),'stone')
for x in [-5.5,-4.2,-2.9,-1.6]:box('FrontPanelRib',(x,-4.07,3.4),(.035,.045,6.3),'metal',0)
for level in range(2):
 z=1.9+level*3.1
 box('FrontControlWindow',(-3.35,-4.12,z),(4.65,.08,1.3),'glass')
 for x in [-5.5,-3.35,-1.2]:box('WindowMullion',(x,-4.19,z),(.06,.04,1.35),'metal')
 for y in [-2.7,0,2.7,5.1]:
  box('SideWindowFrame',(-.64,y,z),(.12,1.8,1.4),'metal')
  box('SideWindow',(-.56,y,z),(.035,1.6,1.2),'glass')
box('FloorBand',(-3.35,1.1,3.35),(5.5,10.5,.2),'metal')
box('StaffDoor',(-2.8,-4.23,1.5),(1.35,.1,2.6),'green')
box('StaffDoorGlass',(-2.8,-4.3,1.9),(1.05,.035,1.25),'lightglass')
bar('Handle',(-2.3,-4.36,1.1),(-2.3,-4.36,1.6),.025)
box('EntryCanopy',(-2.8,-4.7,2.95),(2.3,1.1,.14),'metal')
box('BrandBand',(-3.35,-4.22,5.95),(5.5,.24,.72),'metal')
text('ChemicalName','CHEM WORKS',(-3.35,-4.36,5.97),(math.pi/2,0,0),5,.4)
box('Roof',(-3.35,1.1,6.77),(5.7,10.7,.25),'metal')
box('RoofDeck',(-3.35,1.1,6.95),(5.3,10.3,.1),'roof')
box('RoofVent',(-3.6,4,7.4),(1.7,2, .8),'metal')
for dx in [-.6,-.3,0,.3,.6]:box('VentLouvre',(-3.6+dx,2.97,7.4),(.08,.025,.55),'stone')
def tank(name,cx,cy,radius,height,base=1.6):
 for dx in [-radius*.65,radius*.65]:
  for dy in [-radius*.65,radius*.65]:box(name+'Leg',(cx+dx,cy+dy,base/2+.2),(.15,.15,base),'metal')
 bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=radius,depth=height,location=(cx,cy,base+height/2));bpy.context.object.name=name;bpy.context.object.data.materials.append(m['roof'])
 for z in [base,base+height]:
  bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=radius,location=(cx,cy,z));o=bpy.context.object;o.name=name+'End';o.scale.z=.3;o.data.materials.append(m['roof'])
 for z in [base+.4,base+height-.4]:
  bpy.ops.mesh.primitive_torus_add(major_radius=radius+.015,minor_radius=.04,major_segments=24,minor_segments=6,location=(cx,cy,z));bpy.context.object.data.materials.append(m['metal'])
# Pair of reactor vessels and a slender processing column.
tank('Reactor',1.35,-.1,1.15,4.5)
tank('Reactor',4.55,-.1,1.15,4.5)
tank('ProcessColumn',4.55,4.25,.8,8.6,1.3)
box('ServicePlatform',(3,3,5.5),(5.8,2.3,.15),'metal')
for x in [.25,5.75]:
 for y in [1.95,4.05]:box('PlatformPost',(x,y,2.85),(.13,.13,5.3),'metal')
for z in [6.1,6.65]:
 for y in [1.92,4.08]:bar('PlatformRail',(.15,y,z),(5.85,y,z),.035,'orange')
 for x in [.15,5.85]:bar('PlatformRail',(x,1.92,z),(x,4.08,z),.035,'orange')
for x in [.15,1.6,3,4.4,5.85]:
 for y in [1.92,4.08]:bar('RailUpright',(x,y,5.6),(x,y,6.65),.03,'orange')
# Visible service ladder and pipe bridge, original stylised geometry.
for x in [5.65,6.25]:bar('LadderUpright',(x,1.8,.3),(x,1.8,6.6),.04)
for z in [i*.35+.5 for i in range(18)]:bar('LadderRung',(5.65,1.8,z),(6.25,1.8,z),.03)
for x in [1.35,4.55]:
 bar('ReactorOutlet',(x,-.1,1.55),(x,-.1,.8),.13,'green')
 bar('LowPipe',(x,-.1,.8),(x,-2.3,.8),.13,'green')
 bar('Riser',(x,1.2,1),(x,1.2,7),.12)
 bar('OverheadPipe',(x,1.2,7),(-.8,1.2,7),.12)
bar('ColumnService',(4.55,4.25,10),(4.55,5.8,10),.1)
bar('ColumnDownpipe',(4.55,5.8,10),(4.55,5.8,1),.1)
# Contained front yard and dispatch drums instead of retail props.
box('ContainmentEdge',(3.2,-2.2,.4),(6.8,.2,.35),'stone')
for x in [1,1.8,2.6]:
 bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=.3,depth=.95,location=(x,-4.9,.7));bpy.context.object.name='SealedDispatchDrum';bpy.context.object.data.materials.append(m['green'])
 for z in [.3,1.1]:
  bpy.ops.mesh.primitive_torus_add(major_radius=.302,minor_radius=.02,major_segments=20,minor_segments=6,location=(x,-4.9,z));bpy.context.object.data.materials.append(m['metal'])
box('Pallet',(1.8,-4.9,.25),(2.7,1,.15),'wood')
box('UtilityCabinet',(6.8,-1.9,1.5),(.65,1.3,2.5),'stone')
for y in [-2.35,-2.05,-1.75,-1.45]:box('CabinetVent',(7.14,y,1.5),(.025,.08,1.7),'metal')
for x in [-1,0,1]:
 o=box('ApronMark',(x,-6.5,.213),(.07,1.3,.012),'orange',0);o.rotation_euler.z=-.35
box('RearServiceDoor',(-3.35,6.3,1.55),(1.3,.1,2.6),'metal')
for i in range(2):
 o=bpy.data.objects.new('OccupiedFloor_%02d'%(i+1),None);o['storey_index']=i+1;scene.collection.objects.link(o)
bpy.context.view_layer.update()
vertices=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
assert low[0]>=-8.001 and low[1]>=-8.001 and high[0]<=8.001 and high[1]<=8.001,(low,high)
assert len([o for o in scene.objects if o.name.startswith('OccupiedFloor_')])==2
checkpoint('MODEL',f'Original 4x4 chemical production facility, two occupied storeys plus process equipment. Bounds {low} to {high}.')
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
target_z=4.5;distance=30
bpy.ops.object.camera_add(location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30))));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=32;aim(camera,(0,0,target_z));scene.camera=camera
bpy.ops.object.light_add(type='SUN',location=(-20,-30,60));light=bpy.context.object;light.data.energy=2;light.data.angle=math.radians(12);aim(light,(0,0,0))
scene.world=bpy.data.worlds.new('World');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.55,.65,.75,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.55
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=False;scene.cycles.device='CPU';scene.render.threads_mode='FIXED';scene.render.threads=6
scene.render.resolution_x=900;scene.render.resolution_y=1100;scene.render.resolution_percentage=100;scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
bpy.ops.file.pack_all()
scene.render.filepath=str(OUT/'building.png');bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'building.blend'));checkpoint('SAVED','Editable original saved; transparent front and reverse rendering next.')
bpy.ops.render.render(write_still=True)
camera.location=(-distance,distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30)));aim(camera,(0,0,target_z));scene.render.filepath=str(OUT/'reverse-review.png');bpy.ops.render.render(write_still=True)
camera.location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30)));aim(camera,(0,0,target_z));bpy.context.view_layer.update()
def pixel(p):
 v=world_to_camera_view(scene,camera,Vector(p));return [round(v.x*900,4),round((1-v.y)*1100,4)]
meta={'id':'large-4x4-chemical-06','name':'화학 생산시설','zone':'industrial','category':'large_industrial','footprint_cells':[4,4],'cell_meters':4,'lot_meters':[16,16],'occupied_storeys':2,'approval_status':'pending-user-review','game_registered':False,'image_size':[900,1100],'anchor_px':pixel((8,-8,.12)),'lot_corners_px':[pixel(v) for v in [(-8,-8,.12),(8,-8,.12),(8,8,.12),(-8,8,.12)]],'vertex_bounds_m':[low,high],'camera_elevation_degrees':30,'orthographic_scale':32,'source':'original scripted Blender geometry; system DejaVu font; no external models, textures or generation APIs','cues':['CHEM WORKS sign','two-storey production wing','reactor vessels','tall process column','service platform','pipe bridge'],'scope':'review-only concept; no game catalog or growth changes'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED','Front/reverse 900x1100 RGBA outputs complete. Await user design approval; game registration prohibited until explicit approval.')
print('PASS large industrial chemical facility, two occupied storeys, review only')
