"""Original one-asset AUTO concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'small-2x2-auto-02';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# Small commercial 01 · AUTO\n\nBrief: one neighbourhood car showroom, 2x2 cells (8x8m), one occupied floor. Approval pending; do not register in game. Original Blender geometry, game-art consistency and adapted kiln local source/visual-review principles. No external model, texture, or generation API.\n\nCheckpoint: BRIEF\n')
def checkpoint(stage,text):
 with log.open('a') as f:f.write(f'\n## {stage}\n{text}\n\nCheckpoint: {stage}\n')
def rgb(h):
 v=[int(h[i:i+2],16)/255 for i in [0,2,4]];return tuple(x/12.92 if x<.04045 else ((x+.055)/1.055)**2.4 for x in v)+(1,)
def mat(name,h,metal=0,rough=.65):
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=rgb(h);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal;return m
colors={'cream':'e4dfce','paving':'d9dacd','stone':'bdbfb3','green':'344f65','darkgreen':'26394b','orange':'d58546','ivory':'f8edcf','metal':'435759','glass':'75a1ab','lightglass':'afc4c1','roof':'949d96','wood':'a58056','shelf':'47584b','red':'c9694e','fruit':'d7a23d','leaf':'64815a','black':'34413e'}
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

box('Lot_2x2',(0,0,0),(8,8,.24),'stone',.04)
box('Paving',(0,0,.15),(7.9,7.9,.1),'paving')
box('Showroom',(0,.6,1.95),(6.5,5.3,3.5),'cream')
box('FrontGlass',(0,-2.09,1.8),(6.15,.08,2.65),'glass')
for x in [-3,-1.7,.7,2.9]:box('FrontMullion',(x,-2.16,1.8),(.065,.06,2.7),'metal')
box('SideGlass',(3.29,.6,1.8),(.08,4.8,2.65),'glass')
for y in [-1.7,0,1.8,2.9]:box('SideMullion',(3.36,y,1.8),(.06,.065,2.7),'metal')
box('Door',(2,-2.21,1.5),(1.25,.05,2.2),'lightglass')
bar('DoorHandle',(2.35,-2.28,1.2),(2.35,-2.28,1.7),.025)
box('FrontFascia',(0,-2.2,3.48),(6.75,.25,.8),'green')
box('SideFascia',(3.36,.6,3.48),(.25,5.8,.8),'green')
box('FrontAccent',(0,-2.34,3.08),(6.75,.05,.09),'orange')
box('SideAccent',(3.5,.6,3.08),(.05,5.8,.09),'orange')
text('AUTO_Front','AUTO',(.55,-2.35,3.5),(math.pi/2,0,0),3.8,.54)
text('AUTO_Side','AUTO',(3.5,.7,3.5),(math.pi/2,0,math.pi/2),3.6,.54)
# Car silhouette on the front fascia.
y=-2.37
outline=[(-2.9,3.35),(-2.9,3.5),(-2.65,3.53),(-2.45,3.72),(-2.1,3.72),(-1.9,3.53),(-1.65,3.48),(-1.65,3.35)]
for a,b in zip(outline,outline[1:]):bar('CarLogo',(a[0],y,a[1]),(b[0],y,b[1]),.025,'ivory')
for x in [-2.65,-1.95]:
 bpy.ops.mesh.primitive_torus_add(major_radius=.09,minor_radius=.024,major_segments=16,minor_segments=6,location=(x,y,3.34),rotation=(math.pi/2,0,0));bpy.context.object.data.materials.append(m['ivory'])
box('Roof',(0,.6,3.97),(6.85,5.8,.2),'cream')
box('RoofDeck',(0,.6,4.1),(6.55,5.5,.08),'roof')
for yy in [-2.2,3.4]:box('Parapet',(0,yy,4.2),(6.8,.12,.25),'cream')
for xx in [-3.35,3.35]:box('Parapet',(xx,.6,4.2),(.12,5.6,.25),'cream')
# Actual display vehicle in the forecourt, rather than apartment-like entrance props.
cx,cy=-.6,-3.05
box('DisplayPlinth',(cx,cy,.26),(3.8,1.65,.12),'darkgreen')
box('CarBody',(cx,cy,.73),(3.15,1.32,.48),'red',.12)
box('CarCabin',(cx+.1,cy,1.13),(1.65,1.13,.56),'red',.1)
box('NearSideWindows',(cx+.1,cy-.58,1.17),(1.38,.025,.36),'glass',.04)
box('WindowPillar',(cx+.13,cy-.603,1.17),(.07,.03,.38),'metal')
box('Windshield',(cx-.75,cy,1.18),(.04,1.02,.37),'glass',.02)
box('FrontBumper',(cx-1.6,cy,.58),(.06,1.2,.13),'metal')
for yy in [cy-.45,cy+.45]:box('Headlamp',(cx-1.62,yy,.81),(.035,.23,.14),'ivory')
for xx in [cx-1.03,cx+1.03]:
 for yy in [cy-.65,cy+.65]:
  bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=.29,depth=.16,location=(xx,yy,.54),rotation=(math.pi/2,0,0));bpy.context.object.name='CarWheel';bpy.context.object.data.materials.append(m['black'])
  bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.16,depth=.17,location=(xx,yy,.54),rotation=(math.pi/2,0,0));bpy.context.object.data.materials.append(m['stone'])
box('SalesBoard',(2.7,-3.1,.86),(.75,.13,1.3),'green')
text('SalesText','CAR',(2.7,-3.18,1.05),(math.pi/2,0,0),.6,.23)
box('BoardStripe',(2.7,-3.19,.69),(.52,.02,.06),'orange')
box('RearDoor',(-1.7,3.3,1.45),(1.2,.1,2.3),'metal')
marker=bpy.data.objects.new('OccupiedFloor_01',None);scene.collection.objects.link(marker)
bpy.context.view_layer.update()
vertices=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
assert low[0]>=-4.001 and low[1]>=-4.001 and high[0]<=4.001 and high[1]<=4.001
checkpoint('MODEL',f'Original compact auto showroom with car silhouette and display vehicle. Bounds {low} to {high}.')
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
target_z=2.0;distance=30
bpy.ops.object.camera_add(location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30))));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=15;aim(camera,(0,0,target_z));scene.camera=camera
bpy.ops.object.light_add(type='SUN',location=(-20,-30,60));light=bpy.context.object;light.data.energy=2;light.data.angle=math.radians(12);aim(light,(0,0,0))
scene.world=bpy.data.worlds.new('World');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.55,.65,.75,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.55
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=False;scene.cycles.device='CPU';scene.render.threads_mode='FIXED';scene.render.threads=6
scene.render.resolution_x=900;scene.render.resolution_y=1100;scene.render.resolution_percentage=100;scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
bpy.ops.file.pack_all()
scene.render.filepath=str(OUT/'auto.png');bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'auto.blend'));checkpoint('SAVED','Editable original saved; transparent front and reverse rendering next.')
bpy.ops.render.render(write_still=True)
camera.location=(-distance,distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30)));aim(camera,(0,0,target_z));scene.render.filepath=str(OUT/'reverse-review.png');bpy.ops.render.render(write_still=True)
camera.location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30)));aim(camera,(0,0,target_z));bpy.context.view_layer.update()
def pixel(p):
 v=world_to_camera_view(scene,camera,Vector(p));return [round(v.x*900,4),round((1-v.y)*1100,4)]
meta={'id':'small-2x2-auto-02','name':'자동차 전시장 AUTO','zone':'commercial','category':'small_commercial','footprint_cells':[2,2],'cell_meters':4,'lot_meters':[8,8],'occupied_storeys':1,'approval_status':'pending-user-review','game_registered':False,'image_size':[900,1100],'anchor_px':pixel((4,-4,.12)),'lot_corners_px':[pixel(v) for v in [(-4,-4,.12),(4,-4,.12),(4,4,.12),(-4,4,.12)]],'vertex_bounds_m':[low,high],'camera_elevation_degrees':30,'orthographic_scale':15,'source':'original scripted Blender geometry; system DejaVu font; no external models, textures or generation APIs','cues':['AUTO lettering','car silhouette','display vehicle','glass showroom'],'scope':'review-only concept; no game catalog or growth changes'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED','Front/reverse 900x1100 RGBA outputs complete. Await user design approval; game registration prohibited until explicit approval.')
print('PASS AUTO concept, 2x2, one floor, two literal AUTO signs, no game registration')
