"""Original asset-only primary-industry pilot. No runtime, GLB or catalogs written.
blender -b --factory-startup -t 4 -P tools/build_primary_industry.py
"""
from pathlib import Path
import bpy,sys,math,json,importlib.util
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('growth_helpers',ROOT/'tools/build_growth_14.py')
G=importlib.util.module_from_spec(spec);spec.loader.exec_module(G)
OUT=ROOT/'assets/primary-industry'

def mesh(name,vs,faces,mat):
 data=bpy.data.meshes.new(name);data.from_pydata(vs,[],faces);data.materials.append(G.M[mat]);data.update()
 ob=bpy.data.objects.new(name,data);bpy.context.scene.collection.objects.link(ob);return ob

def gable(name,x,y,w,d,eave,ridge,mat='red'):
 vs=[(x-w/2,y-d/2,eave),(x+w/2,y-d/2,eave),(x,y-d/2,ridge),(x-w/2,y+d/2,eave),(x+w/2,y+d/2,eave),(x,y+d/2,ridge)]
 return mesh(name,vs,[(0,2,1),(3,4,5),(0,3,5,2),(2,5,4,1),(0,1,4,3)],mat)

def cone(name,x,y,z,r,h,mat='roof'):
 bpy.ops.mesh.primitive_cone_add(vertices=20,radius1=r,radius2=0,depth=h,location=(x,y,z+h/2));o=bpy.context.object;o.name=name;o.data.materials.append(G.M[mat]);return o

def farmhouse():
 G.box('LotPlinth',(0,0,0),(16,16,.24),'paving',0)
 G.box('Yard',(0,1,.125),(14.9,12.9,.01),'soil',0)
 G.box('Driveway',(3.4,-5.94,.137),(4.5,4.12,.025),'stone',0)
 G.box('Farmhouse',(-3.5,-3.3,3.17),(5.6,4.6,6.10),'cream')
 gable('FarmhouseRoof',-3.5,-3.3,6.0,5.05,6.22,7.56,'green')
 G.door(-3.5,-5.68,z=.12,w=1.05)
 for z in [1.70,4.75]:
  for x in [-5.18,-1.82]:
   G.box('FarmhouseWindow',(x,-5.63,z),(1.02,.05,1.3),'glass')
   G.box('WindowSill',(x,-5.72,z-.69),(1.18,.20,.10),'ivory')
   G.box('WindowMullion',(x,-5.675,z),(.055,.02,1.3),'cream',0)
 for y in [-4.4,-2.3]:G.box('SideWindow',(-.68,y,4.75),(.04,1.0,1.3),'glass')
 G.box('PorchCanopy',(-3.5,-6.12,2.75),(2.35,1.1,.15),'green')
 for x in [-4.5,-2.5]:G.box('PorchPost',(x,-6.50,1.46),(.12,.12,2.68),'wood')
 # Separate 1-storey machinery shed, with open front bay to the -Y driveway.
 for x in [.65,6.15]:G.box('GarageSideWall',(x,-1.8,1.82),(.22,6.0,3.4),'red')
 G.box('GarageRearWall',(3.4,1.15,1.82),(5.5,.22,3.4),'red')
 G.box('GarageLintel',(3.4,-4.8,3.18),(5.5,.22,.68),'red')
 G.box('GarageSlab',(3.4,-1.8,.20),(5.7,6.1,.16),'stone')
 gable('GarageRoof',3.4,-1.8,5.95,6.4,3.52,4.50,'roof')
 G.box('GarageFascia',(3.4,-5.025,3.39),(3.1,.12,.43),'green')
 G.text('GRAIN',(3.4,-5.10,3.39),2.7,.27)
 # A small original tractor establishes metre scale; no external vehicle model.
 G.box('TractorHood',(3.25,-3.42,1.02),(1.2,1.6,.78),'green',.06)
 G.box('TractorSeat',(3.25,-2.2,1.22),(.68,.55,.48),'black')
 G.box('TractorRoof',(3.25,-2.3,2.10),(1.6,1.5,.12),'cream')
 for x in [2.58,3.92]:G.bar('TractorRoofPost',(x,-1.8,.9),(x,-1.8,2.07),.035,'metal')
 for y,r in [(-3.75,.37),(-2.02,.56)]:
  for x in [2.50,4.0]:
   o=G.tube('TractorTyre',(x,y,.20+r),r,.25,'black',12);o.rotation_euler[1]=math.pi/2
   o=G.tube('TractorHub',(x+(.14 if x>3 else -.14),y,.20+r),r*.5,.04,'ochre',12);o.rotation_euler[1]=math.pi/2
 # Two independent grain silos, each entirely within the 16m yard.
 for x in [-5.4,-2.25]:
  G.tube('GrainSilo',(x,3.48,3.22),1.22,6.20,'roof',20)
  cone('SiloConicalCap',x,3.48,6.32,1.28,1.05,'metal')
  for z in [.70,2.15,3.60,5.05,6.20]:
   # A ring with no solid cap avoids z fighting on the cylinder top.
   bpy.ops.mesh.primitive_torus_add(major_radius=1.225,minor_radius=.025,major_segments=20,minor_segments=4,location=(x,3.48,z));o=bpy.context.object;o.name='SiloBand';o.data.materials.append(G.M['metal'])
  for xx in [x-.20,x+.20]:G.bar('SiloLadderRail',(xx,2.22,.30),(xx,2.22,6.20),.024,'metal')
  for j in range(15):G.bar('SiloLadderRung',(x-.20,2.22,.55+j*.36),(x+.20,2.22,.55+j*.36),.02,'metal')
 G.box('GrainLoadingApron',(3.45,4.30,.15),(5.0,4.1,.06),'stone',0)
 for x,y in [(2.4,3.9),(4.2,4.7)]:
  G.box('Pallet',(x,y,.28),(1.25,1.2,.20),'wood')
  for a in [-.27,.27]:G.box('GrainSack',(x+a,y,.68),(.48,1.02,.58),'ochre',.10)
 # Front entrance is deliberately open. No perimeter curb is placed on work tiles.
 for x in [-7.3,7.3]:
  for y in [-5.9,-1.9,2.1,6.1]:G.box('FencePost',(x,y,.73),(.12,.12,1.22),'wood')
  for z in [.65,1.15]:G.box('SideFence',(x,.1,z),(.07,12,.09),'wood')


def grain_tile():
 G.box('TileSoil',(0,0,-.06),(4,4,.12),'wheat_soil',0)
 # Four broad crop masses, each with four longitudinal stations: 284 triangles total.
 # Periodic low waves and shallow crosswise teeth suggest ears without per-plant meshes.
 brightness=[.92,1.06,.97,1.10]
 for ix in range(4):
  mat=bpy.data.materials.new('WheatRow_%02d'%ix);mat.use_nodes=True
  base=G.rgb('e2b94f');mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=tuple(v*brightness[ix] for v in base[:3])+(1,)
  mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.76
  key='row_%02d'%ix;G.M[key]=mat
  x=-2+(ix+.5);radius=.47;rise=.60+.04*(ix%2);sign=1 if ix%2==0 else -1
  waves=[0,.04*sign,-.04*sign,0];ys=[-2,-2/3,2/3,2]
  teeth=[0,.008,-.012,.018,-.012,.008,0];sections=[]
  for wave in waves:
   sections.append([(-radius,.006)]+[(-radius*math.cos(j*math.pi/6),.10+(rise+wave)*math.sin(j*math.pi/6)+teeth[j]) for j in range(7)]+[(radius,.006)])
  n=len(sections[0]);vs=[(x+xx,y,z) for y,section in zip(ys,sections) for xx,z in section]
  faces=[tuple(reversed(range(n))),tuple(range(3*n,4*n))]
  faces += [(k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j) for k in range(3) for j in range(n)]
  ob=mesh('WheatRibbon_%02d'%ix,vs,faces,key);ob['row_center_x_m']=x;ob['row_width_m']=radius*2;ob['crop_height_m']=max(z for _,_,z in vs);ob['brightness_factor']=brightness[ix];ob['wave_amplitude_m']=.04
  # Both edge profiles and edge tangents repeat. Cap faces never affect canopy normals.
  slopes=[.03*sign,-.015*sign,-.015*sign,.03*sign];normals=[]
  for poly in ob.data.polygons:
   poly.use_smooth=True
   for loop_index in poly.loop_indices:
    vertex=ob.data.loops[loop_index].vertex_index;station,vi=divmod(vertex,n)
    side=(poly.index-2)%n
    if poly.index<2:normal=(0,-1 if poly.index==0 else 1,0)
    elif side==0:normal=(-1,0,0)
    elif side==n-2:normal=(1,0,0)
    elif side==n-1:normal=(0,0,-1)
    else:
     angle=max(0,min(6,vi-1))*math.pi/6
     normal=Vector((-(rise+waves[station])*math.cos(angle),-radius*math.sin(angle)**2*slopes[station],radius*math.sin(angle))).normalized()
    normals.append(normal)
  ob.data.normals_split_custom_set(normals)


def bounds():
 bpy.context.view_layer.update();dep=bpy.context.evaluated_depsgraph_get();points=[];tri=0
 for o in bpy.context.scene.objects:
  if o.type not in ['MESH','FONT']:continue
  e=o.evaluated_get(dep);me=e.to_mesh();points.extend(e.matrix_world@v.co for v in me.vertices);tri+=sum(len(p.vertices)-2 for p in me.polygons);e.to_mesh_clear()
 return points,[[min(v[i] for v in points) for i in range(3)],[max(v[i] for v in points) for i in range(3)]],tri

def studio(points,size):
 scene=bpy.context.scene;low,high=[min(v.z for v in points),max(v.z for v in points)];target=Vector((0,0,(low+high)*.48));dist=40
 bpy.ops.object.camera_add(location=target+Vector((dist,-dist,math.sqrt(2)*dist*math.tan(math.pi/6))));cam=bpy.context.object;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=4;scene.camera=cam
 scene.render.resolution_x,scene.render.resolution_y=size;scene.render.resolution_percentage=100
 for _ in range(12):
  bpy.context.view_layer.update();ps=[world_to_camera_view(scene,cam,v) for v in points];ratio=max(max(abs(p.x-.5)/.44,abs(p.y-.5)/.44) for p in ps)
  if ratio<=1.001:break
  cam.data.ortho_scale*=ratio*1.01
 cam['target_m']=list(target);cam['elevation_degrees']=30
 bpy.ops.object.light_add(type='AREA',location=(-12,-14,28));light=bpy.context.object;light.name='Key';light.data.energy=2800;light.data.shape='DISK';light.data.size=12;light.rotation_euler=(Vector((0,0,high*.35))-light.location).to_track_quat('-Z','Y').to_euler()
 scene.world=bpy.data.worlds.new('World');scene.world.use_nodes=True;bg=scene.world.node_tree.nodes['Background'];bg.inputs['Color'].default_value=(.55,.65,.75,1);bg.inputs['Strength'].default_value=.55
 scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=48;scene.cycles.use_denoising=False;scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
 return cam

def build(ident,name,tile):
 G.COLORS.update(soil='a69b7c',furrow='968a6d',grain='c4ae6b',straw='a4a16c',wheat_gold='e2b94f',wheat_light='ebc96b',wheat_soil='786342');G.reset();scene=bpy.context.scene
 (grain_tile if tile else farmhouse)();points,bb,tri=bounds();width=4 if tile else 16
 assert all(bb[0][i]>=-width/2-.001 and bb[1][i]<=width/2+.001 for i in [0,1])
 assert not tile or 0<tri<=300,tri  # User approved lower counts for repeated ribbon tiles.
 if not tile:
  marker=bpy.data.objects.new('RoadFront_BlenderMinusY',None);scene.collection.objects.link(marker);marker.location=(0,-8,.12)
 cam=studio(points,(900,900) if tile else (900,1100));out=OUT/ident;out.mkdir(parents=True,exist_ok=True)
 meta=dict(id=ident,name=name,kind='primary_work_tile' if tile else 'primary_main',industry='farm_grain',footprint_cells=[1,1] if tile else [4,4],cell_meters=4,lot_meters=[width,width],floors=0 if tile else 2,footprint_status='user-specified',front='-Y (Blender) / +Z (Godot)',front_blender='-Y',front_godot='+Z',vertex_bounds_m=bb,measured_dimensions_m=[bb[1][i]-bb[0][i] for i in range(3)],triangles=tri,camera_elevation_degrees=30,game_registered=False,approval_status='pending-user-review',source='original scripted Blender geometry; system DejaVu font; no external models, textures or generation APIs')
 if tile:meta.update(edge_period_m=[4,4],soil_surface_z_m=0,furrow_surface_z_m=0,base_min_z_m=-.12,crop_representation='continuous rounded row ribbons',crop_counts={'rows':4,'individual_plants':0},row_pitch_m=1,row_width_m=.94,furrow_width_m=.06,ground_coverage_fraction=.94,crop_height_range_m=[.678,.798],longitudinal_wave_amplitude_m=.04,cross_profile_tooth_offsets_m=[0,.008,-.012,.018,-.012,.008,0],brightness_space='linear RGB scale; fixed hue',row_brightness_factors=[.92,1.06,.97,1.10],growth_building=False)
 else:meta.update(main_storey_height_m=3.05,main_floors=2,garage_floors=1,silo_count=2,silo_floors=0,floor_reference_m=.12,plinth_min_z_m=-.12)
 (out/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
 for f in bpy.data.fonts:
  if f.filepath and Path(f.filepath).is_file():f.pack()
 bpy.ops.wm.save_as_mainfile(filepath=str(out/(ident+'.blend')))
 scene.render.filepath=str(out/('tile.png' if tile else 'building.png'));bpy.ops.render.render(write_still=True)
 if tile:
  # Copy actual meshes at exact 4m offsets, without borders or image compositing.
  originals=[o for o in scene.objects if o.type=='MESH']
  for dx in [-4,0,4]:
   for dy in [-4,0,4]:
    if dx==dy==0:continue
    for ob in originals:
     cp=ob.copy();scene.collection.objects.link(cp);cp.location=ob.location+Vector((dx,dy,0))
  pts,_,_=bounds();cam.data.ortho_scale*=3;scene.render.filepath=str(out/'tile-3x3.png');bpy.ops.render.render(write_still=True)
 print('PRIMARY_DONE',ident,meta['measured_dimensions_m'],tri,flush=True)

if __name__=='__main__':
 import argparse
 p=argparse.ArgumentParser();p.add_argument('--only',choices=['primary-farm-grain-01','primary-tile-grain-01']);a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
 if not a.only or a.only=='primary-farm-grain-01':build('primary-farm-grain-01','곡물 농장',False)
 if not a.only or a.only=='primary-tile-grain-01':build('primary-tile-grain-01','곡물 밭',True)
