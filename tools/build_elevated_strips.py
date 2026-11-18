"""Original metre-scale concrete members; Blender 4.3.2, no external art.
Run once in a new output root. Source members are also reused by tunnel sample.
"""
import argparse,json,math,shutil,sys
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_transit_vehicles as T
F=T.F;C=T.C
COLORS={'barrier':'b9bbb3','barrier_top':'ced0c7','joint':'7d827d','cap':'c1c3ba','drip':'6f756f','girder':'8f948f','wall':'a3a89f','beam':'8c8a80'}
M={};ROOT_NODE=None

def setup():
 global M,ROOT_NODE
 C.reset_scene();bpy.context.preferences.filepaths.save_version=0
 bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
 ROOT_NODE=C.empty('ConcreteMember');M={k:F.material(k,v) for k,v in COLORS.items()}

def box(n,size,pos,mat):return F.box(n,size,pos,M[mat],ROOT_NODE,0)
def member(kind):
 # Exterior at Y=-.25; all surface detail stays inside 0.5m thickness.
 box('Barrier',(4,.384,1.1),(0,0,.55),'barrier')
 for side in [-1,1]:
  box('BarrierTopEdge',(4,.008,.0375),(0,side*.196,1.08125),'barrier_top')
  box('BarrierVerticalJoint',(.05,.008,1.0625),(.35,side*.196,.53125),'joint')
 if kind=='inner':return
 box('Cap',(4,.49,.3),(0,0,-.15),'cap')
 for side in [-1,1]:box('DripProfile',(4,.008,.0375),(0,side*.246,-.28125),'drip')
 h={'deck':1.7,'wall':7.6,'portal':1.2}[kind];mat={'deck':'girder','wall':'wall','portal':'beam'}[kind]
 box('LowerMember',(4,.48,h),(0,0,-.3-h/2),mat)
 for side in [-1,1]:
  box('LowerVerticalJoint',(.05,.008,h),(.35,side*.244,-.3-h/2),'joint')
  if kind=='portal':box('BeamRecess',(4,.008,.05),(0,side*.246,-.85),'drip')

def render_strip(path,height,inner=False):
 s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=8;s.cycles.use_denoising=False
 s.cycles.pixel_filter_type='GAUSSIAN';s.cycles.filter_width=.01
 s.render.film_transparent=True;s.render.image_settings.color_mode='RGBA';s.render.image_settings.file_format='PNG'
 s.view_settings.view_transform='Standard';s.render.dither_intensity=0
 s.render.resolution_x=320;s.render.resolution_y=round(height*80);s.render.resolution_percentage=100
 for m in M.values():
  nt=m.node_tree;bs=nt.nodes.get('Principled BSDF');em=nt.nodes.new('ShaderNodeEmission');em.inputs['Color'].default_value=bs.inputs['Base Color'].default_value;nt.links.new(em.outputs[0],nt.nodes.get('Material Output').inputs['Surface'])
 data=bpy.data.cameras.new('FaceCamera');cam=bpy.data.objects.new('FaceCamera',data);s.collection.objects.link(cam);s.camera=cam
 data.type='ORTHO';data.ortho_scale=max(4,height);cam.location=(0, -20 if not inner else 20,1.1-height/2)
 cam.rotation_euler=(Vector((0,0,1.1-height/2))-cam.location).to_track_quat('-Z','Y').to_euler()
 s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
 for m in M.values():m.node_tree.links.new(m.node_tree.nodes['Principled BSDF'].outputs[0],m.node_tree.nodes.get('Material Output').inputs['Surface'])
 bpy.data.objects.remove(cam,do_unlink=True)

def main():
 p=argparse.ArgumentParser();p.add_argument('--output-root',type=Path,default=ROOT);p.add_argument('--cache',type=Path,required=True)
 a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);a.cache.mkdir(parents=True,exist_ok=True)
 for ident,kind,filename,height,bands in [('viaduct-side-01','deck','deck_side',3.1,[0,88,112,248]),('retaining-wall-01','wall','wall',9.,[0,88,112,720]),('tunnel-portal-01','portal','portal',2.6,[0,88,112,208])]:
  src=a.output_root/'assets/structures'/ident;dst=a.output_root/'cities_do/assets/structures'/ident
  assert not src.exists(),src
  src.mkdir(parents=True);dst.mkdir(parents=True)
  setup();member(kind);C.update();tri,lo,hi=T.measure();assert tri<=1500
  bpy.ops.export_scene.gltf(filepath=str(a.cache/(ident+'.glb')),export_format='GLB',export_extras=True,export_animations=False)
  bpy.ops.wm.save_as_mainfile(filepath=str(src/'member.blend'),compress=True)
  render_strip(dst/(filename+'.png'),height);shutil.copy2(dst/(filename+'.png'),src/'preview.png')
  files=[filename+'.png'];res={files[0]:[320,round(height*80)]};bandmap={files[0]:bands}
  if kind=='deck':
   for ob in bpy.context.scene.objects:
    if ob.type=='MESH':ob.hide_render=not ob.name.startswith('Barrier')
   render_strip(dst/'barrier_inner.png',1.1,True);files.append('barrier_inner.png');res[files[-1]]=[320,88];bandmap[files[-1]]=[0,88]
  spec={'id':ident,'status':'inspection_only','files':files,'period_m':4,'pixels_per_metre':80,'resolution':res,'projection':'vertical face orthographic emission, no shadows; horizontal pixel axis follows length, top = barrier top','bands_px':bandmap,'colors':COLORS,'barrier_height_m':1.1,'barrier_thickness_m':.4,'triangles':tri,'bounds_blender_m':{'min':lo,'max':hi},'source':f'assets/structures/{ident}/member.blend','face_shade':None,'face_shade_method':'Measured in requested Godot capture, directional rotation(-55,-35,0), energy1.1, ambient d9e4f0 energy0.75; mean display RGB luminance / emission image luminance.'}
  if kind=='deck':spec['structure_depth_m']=2.
  if kind=='wall':spec['wall_thickness_m']=.5
  if kind=='portal':spec.update(mouth_top_below_ground_m=1.5,mouth_clear_road_m=4.5,mouth_clear_rail_m=5.5,interior_color='15181a')
  F.write_json(src/'spec.json',spec)
  (src/'build.py').write_text('import runpy\nfrom pathlib import Path\nrunpy.run_path(str(Path(__file__).resolve().parents[3]/"tools/build_elevated_strips.py"),run_name="__main__")\n')
  print('MEMBER_BUILT',ident,tri,lo,hi,flush=True)
if __name__=='__main__':main()
