"""Approved item6 only: 32x16m closed underpass, original members reused read-only."""
import argparse,json,math,shutil,sys
from pathlib import Path
import bpy,bmesh
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_elevated_strips as E
import build_transit_subway as S
T=E.T;F=E.F;C=E.C

def road(x):return -5.36+.08*x

def append_member(kind,x,y,angle=0,side=0):
 path=ROOT/'assets/structures'/kind/'member.blend'
 with bpy.data.libraries.load(str(path),link=False) as (src,dst):dst.objects=src.objects
 meshes=[ob for ob in dst.objects if ob and ob.type=='MESH']
 for ob in meshes:
  bpy.context.scene.collection.objects.link(ob)
  # Bake the source transform, preserving each original material and closed box.
  ob.data=ob.data.copy();ob.data.transform(ob.matrix_world);ob.parent=None;ob.matrix_world=Matrix.Identity(4)
  if side:
   for v in ob.data.vertices:
    v.co.x+=x;v.co.y+=y+(side*.05 if ob.name.startswith('Barrier') else 0)
    v.co.z=max(v.co.z,road(v.co.x)-.20)
  else:
   ob.data.transform(Matrix.Translation((x,y,0))@Matrix.Rotation(angle,4,'Z'))
   # Butt the portal into side members, never overlap coplanar corner tops.
   limit=5.6 if ob.name.startswith('Barrier') else 5.5
   for v in ob.data.vertices:v.co.y=max(-limit,min(limit,v.co.y))
  ob.parent=E.ROOT_NODE
  ob.name=('Side'+str(side)+'_' if side else 'Portal_')+ob.name
 for ob in dst.objects:
  if ob and ob.type!='MESH':bpy.data.objects.remove(ob)
 return meshes

def wedge(name,x0,x1,y0,y1,z0,z1,thick,material):
 verts=[(x,y,z-d) for d in [0,thick] for x,z in [(x0,z0),(x1,z1)] for y in [y0,y1]]
 faces=[(0,2,3,1),(4,5,7,6),(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3)]
 return F.mesh(name,verts,faces,E.M[material],E.ROOT_NODE)

def main():
 p=argparse.ArgumentParser();p.add_argument('--output-root',type=Path,default=ROOT);a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
 src=a.output_root/'assets/structures/tunnel-sample-01';dst=a.output_root/'cities_do/assets/structures/tunnel-sample-01'
 assert not src.exists();src.mkdir(parents=True);dst.mkdir(parents=True)
 E.setup();E.ROOT_NODE.name='TunnelSample';E.ROOT_NODE['frontGltf']=[1,0,0]
 E.M.update({k:F.material(k,v) for k,v in {'ground':'7e9275','asphalt':'4c5659','shoulder':'c8cbc3','interior':'15181a','line':'d9d3b6'}.items()})
 for side in [-1,1]:
  for x in [-14,-10,-6,-2,2,6,10,14]:append_member('retaining-wall-01',x,side*5.75,side=side)
  # Finite ground slabs outside the trench, top precisely z=0.
  E.box('SideGround',(32,2,.30),(0,side*7,-.15),'ground')
 for y in [-4,0,4]:append_member('tunnel-portal-01',-8.25,y,math.pi/2)
 wedge('ClosedRoadFloor',-16,16,-5.5,5.5,road(-16)-.01,road(16)-.01,.19,'shoulder')
 wedge('Asphalt',-16,16,-5.25,5.25,road(-16),road(16),.01,'asphalt')
 for y0,y1 in [(-5.5,-5.25),(5.25,5.5)]:wedge('Shoulder',-16,16,y0,y1,road(-16),road(16),.01,'shoulder')
 for y in [-5.05,5.05]:wedge('RoadEdgeLine',-16,16,y-.06,y+.06,road(-16)+.001,road(16)+.001,.001,'line')
 for x in [-14,-6,2,10]:wedge('CentreLine',x,x+3,-.06,.06,road(x)+.001,road(x+3)+.001,.001,'line')
 E.box('CoverSlab',(8,12,.97),(-12,0,-.515),'cap')
 E.box('CoverGround',(8,12,.03),(-12,0,-.015),'ground')
 E.box('ClosedDarkEnd',(.20,11,5.64),(-15.9,0,-3.82),'interior')
 # Recalculate normals on closed slope meshes, without changing protected sources.
 for ob in bpy.context.scene.objects:
  if ob.type=='MESH':
   bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
 C.update();tri,lo,hi=T.measure();assert tri<=6000
 assert all(abs(v-w)<.002 for v,w in zip([hi[0]-lo[0],hi[1]-lo[1],lo[2],hi[2]],[32,16,-6.84,1.1])),(lo,hi)
 bpy.ops.export_scene.gltf(filepath=str(dst/'tunnel-sample-01.glb'),export_format='GLB',export_extras=True,export_animations=False)
 bpy.ops.wm.save_as_mainfile(filepath=str(src/'sample.blend'),compress=True)
 render=S.studio(src/'preview.png',lo,hi);shutil.copy2(src/'preview.png',dst/'tunnel-sample-01.png')
 spec={'id':'tunnel-sample-01','name':'지하차도 입구 견본','kind':'structure_sample','width':8,'depth':4,'metres':[32,16],'height_m':round(hi[2]-lo[2],4),'triangles':tri,'status':'inspection_only','source':'assets/structures/tunnel-sample-01/sample.blend','model':'res://assets/structures/tunnel-sample-01/tunnel-sample-01.glb','preview':'res://assets/structures/tunnel-sample-01/tunnel-sample-01.png','portal_road_z_m':-6.,'portal_mouth_top_z_m':-1.5,'mouth_clear_road_m':4.5,'road_surface_range_m':[-6.64,-4.08],'road_grade':.08,'road_width_m':12,'trench_inner_width_m':11,'trench_length_m':24,'cover_length_m':8,'cover_slab_m':1.,'barrier_height_m':1.1,'barrier_thickness_m':.4,'wall_thickness_m':.5,'origin':'sample centre at ground z=0','front_blender':'+X','front_gltf':'+X','components':['retaining-wall-01','tunnel-portal-01'],'bounds_blender_m':{'min':lo,'max':hi},'render':render,'map_placement_implemented':False,'closed_floor_and_end':True,'details':'Read-only appended 4m members; slope-trimmed bottoms. Asphalt surface is nominal road datum; 1mm road paint overlay. Ground z=0 retained.'}
 F.write_json(src/'spec.json',spec)
 (src/'build.py').write_text('import runpy\nfrom pathlib import Path\nrunpy.run_path(str(Path(__file__).resolve().parents[3]/"tools/build_tunnel_sample.py"),run_name="__main__")\n')
 catalog=a.output_root/'cities_do/assets/facilities/catalog.json';doc=json.loads(catalog.read_text(encoding='utf-8'));assert not any(e['id']==spec['id'] for e in doc['facilities']);doc['facilities'].append(spec);F.write_json(catalog,doc)
 # Saved-source reload gate; no further saves and no extra render.
 bpy.ops.wm.open_mainfile(filepath=str(src/'sample.blend'));C.update();tri2,lo2,hi2=T.measure();assert tri2==tri and all(abs(a-b)<.0001 for a,b in zip(lo+hi,lo2+hi2))
 print('TUNNEL_SAMPLE_BUILT_RELOADED',tri,lo,hi,flush=True)
if __name__=='__main__':main()
