"""Confirmed round/flared pier and 40x12m elevated sample, original geometry only."""
import json,math,sys,shutil
from pathlib import Path
import bpy,bmesh
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_elevated_strips as E
import build_transit_subway as S
F=E.F;C=E.C;T=E.T

def lathe(name,rings,material,parent):
 n=48;vs=[(r*math.cos(i*math.tau/n),r*math.sin(i*math.tau/n),z) for r,z in rings for i in range(n)]
 faces=[tuple(reversed(range(n))),tuple((len(rings)-1)*n+i for i in range(n))]
 faces +=[(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(len(rings)-1) for i in range(n)]
 ob=F.mesh(name,vs,faces,material,parent)
 for poly in ob.data.polygons:poly.use_smooth=len(poly.vertices)==4
 return ob

def save_source(src,dst,filename):
 C.update();tri,lo,hi=T.measure()
 bpy.ops.export_scene.gltf(filepath=str(dst/(filename+'.glb')),export_format='GLB',export_extras=True,export_animations=False)
 bpy.ops.wm.save_as_mainfile(filepath=str(src/'structure.blend'),compress=True)
 render=S.studio(src/'preview.png',lo,hi);shutil.copy2(src/'preview.png',dst/(filename+'.png'))
 return tri,lo,hi,render

def main():
 src=ROOT/'assets/structures/viaduct-pier-01';dst=ROOT/'cities_do/assets/structures/viaduct-pier-01';assert not src.exists();src.mkdir(parents=True);dst.mkdir(parents=True)
 E.setup();E.ROOT_NODE.name='PierRoot';m=F.material('PierConcrete','a7aca7')
 lathe('PierBase',[(1.3,0),(1.3,.3)],m,E.ROOT_NODE)
 lathe('PierShaft',[(1,.3),(1,6)],m,E.ROOT_NODE)
 lathe('PierCap',[(1,6),(1.05,6.4),(1.3,7),(1.65,7.6),(2,8)],m,E.ROOT_NODE)
 tri,lo,hi,render=save_source(src,dst,'viaduct-pier-01');assert 600<=tri<=2000 and abs(hi[2]-8)<.001
 spec={'id':'viaduct-pier-01','status':'inspection_only','column_diameter_m':2.,'cap_top_diameter_m':4.,'cap_height_m':2.,'base_diameter_m':2.6,'base_height_m':.3,'min_deck_level_m':5.,'rotationally_symmetric':True,'radial_segments':48,'twin_rule':'W ≥ 16m: ±W/4','spacing_m':{'default':32,'min':16,'max':48},'reference_deck_level_m':10,'shaft_height_m':5.7,'triangles':tri,'bounds_blender_m':{'min':lo,'max':hi},'source':'assets/structures/viaduct-pier-01/structure.blend','model':'res://assets/structures/viaduct-pier-01/viaduct-pier-01.glb','parts':None,'render':render}
 F.write_json(src/'spec.json',spec)
 (src/'build.py').write_text('import runpy\nfrom pathlib import Path\nrunpy.run_path(str(Path(__file__).resolve().parents[3]/"tools/build_viaduct_samples.py"),run_name="__main__")\n')
 print('PIER_BUILT',tri,lo,hi,flush=True)
 sample()

def sample():
 src=ROOT/'assets/structures/viaduct-pier-01'
 # A library must not be appended from the active .blend filepath (Blender4.3 crash).
 bpy.ops.wm.read_factory_settings(use_empty=True)
 E.setup();E.ROOT_NODE.name='ViaductSample';E.ROOT_NODE['frontGltf']=[0,0,1]
 E.M.update({k:F.material(k,v) for k,v in {'asphalt':'4c5659','shoulder':'c8cbc3'}.items()})
 for x in [-16,16]:
  with bpy.data.libraries.load(str(src/'structure.blend'),link=False) as (a,b):b.objects=a.objects
  for ob in b.objects:
   if ob.type=='MESH':
    bpy.context.scene.collection.objects.link(ob);ob.data=ob.data.copy();ob.data.transform(ob.matrix_world);ob.parent=E.ROOT_NODE;ob.matrix_world=Matrix.Translation((x,0,0));ob.name='Support_'+str(x)+'_'+ob.name
   else:bpy.data.objects.remove(ob)
 for sign in [-1,1]:
  for x in range(-18,20,4):
   with bpy.data.libraries.load(str(ROOT/'assets/structures/viaduct-side-01/member.blend'),link=False) as (a,b):b.objects=a.objects
   for ob in b.objects:
    if ob.type=='MESH':
     bpy.context.scene.collection.objects.link(ob);ob.data=ob.data.copy();ob.data.transform(ob.matrix_world);ob.parent=E.ROOT_NODE
     ob.matrix_world=Matrix.Translation((x,sign*(5.8 if ob.name.startswith('Barrier') else 5.75),10));ob.name='Deck_'+ob.name
    else:bpy.data.objects.remove(ob)
 # Closed core/end faces; no hollow underside or open cut ends.
 E.box('ClosedDeckCore',(40,11.02,1.7),(0,0,8.85),'girder')
 E.box('ClosedDeckSlab',(40,11,.29),(0,0,9.845),'shoulder')
 E.box('Asphalt',(40,10.5,.01),(0,0,9.995),'asphalt')
 for y in [-5.375,5.375]:E.box('ShoulderSurface',(40,.25,.01),(0,y,9.995),'shoulder')
 s2=ROOT/'assets/structures/viaduct-sample-01';d2=ROOT/'cities_do/assets/structures/viaduct-sample-01';assert not s2.exists();s2.mkdir(parents=True);d2.mkdir(parents=True)
 tri2,lo2,hi2,r2=save_source(s2,d2,'viaduct-sample-01');assert tri2<=8000 and all(abs(a-b)<.002 for a,b in zip([hi2[0]-lo2[0],hi2[1]-lo2[1],hi2[2]],[40,12,11.1]))
 sp={'id':'viaduct-sample-01','name':'고가도로 견본','kind':'structure_sample','width':10,'depth':3,'metres':[40,12],'height_m':11.1,'triangles':tri2,'status':'inspection_only','source':'assets/structures/viaduct-sample-01/structure.blend','model':'res://assets/structures/viaduct-sample-01/viaduct-sample-01.glb','preview':'res://assets/structures/viaduct-sample-01/viaduct-sample-01.png','deck_level_m':10,'underdeck_clear_m':8,'pier_positions_blender_m':[[-16,0,0],[16,0,0]],'components':['viaduct-pier-01','viaduct-side-01'],'bounds_blender_m':{'min':lo2,'max':hi2},'render':r2,'front_blender':'-Y','map_placement_implemented':False}
 F.write_json(s2/'spec.json',sp);shutil.copy2(src/'build.py',s2/'build.py')
 cat=ROOT/'cities_do/assets/facilities/catalog.json';doc=json.loads(cat.read_text(encoding='utf-8'));assert not any(e['id']==sp['id'] for e in doc['facilities']);doc['facilities'].append(sp);F.write_json(cat,doc)
 bpy.ops.wm.open_mainfile(filepath=str(s2/'structure.blend'));C.update();assert T.measure()[0]==tri2
 print('VIADUCT_BUILT_RELOADED',tri2,lo2,hi2,flush=True)
if __name__=='__main__':
 if '--sample-only' in sys.argv:sample()
 else:main()
