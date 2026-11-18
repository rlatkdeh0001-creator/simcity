"""Original double track and orthographic emission strips. Blender 4.3.2.
Replay with --output-root NEW_WORKSPACE; never overwrite delivered sources.
"""
import argparse,json,math,random,shutil,sys
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_transit_vehicles as T
import build_transit_subway as S
F=T.F;C=T.C

def main():
 p=argparse.ArgumentParser();p.add_argument('--output-root',type=Path,default=ROOT);a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
 out=a.output_root;src=out/'assets/rail/rail-track-01';game=out/'cities_do/assets/rail/rail-track-01'
 if src.exists():raise RuntimeError('Protected source exists')
 src.mkdir(parents=True);game.mkdir(parents=True,exist_ok=True);C.reset_scene()
 scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
 root=C.empty('RailTrackRoot');root['asset_id']='rail-track-01';root['units']='metres'
 colors={'Ballast':'a59c8e','ScatterLight':'b1a99c','ScatterDark':'958d80','Sleeper':'5b5046','Rail':'cfd6d6','Buffer':'414b4d','Marker':'d4c7a7'}
 mats={k:F.material(k,c) for k,c in colors.items()}
 def box(n,size,pos,mat):return F.box(n,size,pos,mats[mat],root,0)
 box('CentrePlainBallastGap',(.4,12,.23),(0,0,-.235),'Ballast')
 for track,x in enumerate([-2.,2.]):
  box('BallastBed_'+str(track),(3.6,12,.23),(x,0,-.235),'Ballast')
  for segment,cy in enumerate([-4.,0.,4.]):
   rng=random.Random(271)
   for i in range(80):
    px=x+rng.uniform(-1.70,1.70);py=cy+rng.uniform(-1.90,1.90);sx=rng.uniform(.04,.12);sy=rng.uniform(.04,.14)
    F.mesh('FlatScatter',[(px-sx/2,py-sy/2,-.119),(px+sx/2,py-sy/3,-.119),(px+sx/3,py+sy/2,-.119)],[(0,1,2)],mats['ScatterLight' if i%2 else 'ScatterDark'],root)
   for dy in [-1.5,-.5,.5,1.5]:box('Sleeper',(2.6,.3,.10),(x,cy+dy,-.07),'Sleeper')
   for side in [-1,1]:box('Rail_'+str(track)+'_'+str(segment)+'_'+str(side),(.15,4,.12),(x+side*.7925,cy,-.06),'Rail')
  for dx in [-.9,.9]:
   box('EndBufferPost',(.16,.20,.70),(x+dx,5.1,.23),'Buffer')
   box('EndBufferFoot',(.28,.70,.10),(x+dx,4.95,-.01),'Buffer')
  box('EndBufferCrossbar',(2.3,.20,.23),(x,5.1,.695),'Buffer')
  for dx in [-.7,0,.7]:box('EndBufferMarker',(.24,.015,.16),(x+dx,4.992,.695),'Marker')
 C.update();tri,lo,hi=T.measure();assert tri<=6000 and abs(hi[0]-lo[0]-7.6)<.001 and abs(hi[1]-lo[1]-12)<.001
 bpy.ops.export_scene.gltf(filepath=str(game/'rail-track-01.glb'),export_format='GLB',export_extras=True,export_yup=True,export_animations=False)
 bpy.ops.wm.save_as_mainfile(filepath=str(src/'rail.blend'),compress=True)
 # Unlit materials preserve exact sRGB palette, with no directional shading.
 original={m.name:m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value[:] for m in mats.values()}
 for m in mats.values():
  nt=m.node_tree;bs=nt.nodes.get('Principled BSDF');em=nt.nodes.new('ShaderNodeEmission');em.inputs['Color'].default_value=original[m.name];nt.links.new(em.outputs[0],nt.nodes.get('Material Output').inputs['Surface'])
 scene.render.engine='CYCLES';scene.cycles.samples=1;scene.cycles.use_denoising=False;scene.render.film_transparent=True;scene.view_settings.view_transform='Standard';scene.render.image_settings.color_mode='RGBA'
 scene.render.resolution_x=320;scene.render.resolution_y=288;scene.render.resolution_percentage=100
 camdata=bpy.data.cameras.new('StripCamera');cam=bpy.data.objects.new('StripCamera',camdata);scene.collection.objects.link(cam);scene.camera=cam;camdata.type='ORTHO';camdata.ortho_scale=4.;cam.rotation_euler=(0,0,math.pi/2)
 for name,cy in [('strip',-4.),('strip_end',4.),('strip_rails',-4.)]:
  for ob in scene.objects:
   if ob.type=='MESH':ob.hide_render=name=='strip_rails' and not ob.name.startswith('Rail_')
  cam.location=(-2,cy,20);scene.render.filepath=str(game/(name+'.png'));bpy.ops.render.render(write_still=True)
 for ob in scene.objects:ob.hide_render=False
 for m in mats.values():m.node_tree.links.new(m.node_tree.nodes['Principled BSDF'].outputs[0],m.node_tree.nodes.get('Material Output').inputs['Surface'])
 bpy.data.objects.remove(cam,do_unlink=True)
 ppm=S.studio(game/'rail-track-01.png',lo,hi)
 shutil.copy2(game/'rail-track-01.png',src/'preview.png')
 spec={'id':'rail-track-01','name':'복선 철도 견본','kind':'rail_track','width':2,'depth':3,'metres':[7.6,12.0],'height_m':hi[2]-lo[2],'triangles':tri,'status':'inspection_only','capacity':0,'source':'assets/rail/rail-track-01/rail.blend','model':'res://assets/rail/rail-track-01/rail-track-01.glb','preview':'res://assets/rail/rail-track-01/rail-track-01.png','gauge_m':1.435,'rail_inner_face_x_m':[-.7175,.7175],'rail_width_m':.15,'rail_top_z_m':0,'bed_bottom_z_m':-.35,'bed_width_m':3.6,'sleeper_pitch_m':1.,'sleeper_size_m':[2.6,.3,.1],'strip':{'files':['strip.png','strip_end.png','strip_rails.png'],'period_m':4,'width_m':3.6,'pixels_per_metre':80,'resolution':[320,288],'projection':'vertical orthographic emission, no shadows; horizontal pixel axis follows length'},'colors':{'ballast':'a59c8e','sleeper':'5b5046','rail':'cfd6d6'},'platform_edge_to_track_centre_m':1.8,'default_track_count':2,'double_track_spacing_m':4.,'track_centre_offsets_m':[-2.,2.],'double_track_bed_width_m':7.6,'double_track_gap_m':.4,'min_curve_radius_m':32,'straight_length_m':8,'end_length_m':4,'bounds_blender_m':{'min':lo,'max':hi},'render':ppm,'map_placement_implemented':False}
 F.write_json(src/'spec.json',spec)
 (src/'build.py').write_text('import runpy,sys\nfrom pathlib import Path\nr=Path(__file__).resolve().parents[3]\nrunpy.run_path(str(r/"tools/build_rail_track.py"),run_name="__main__")\n')
 cat=out/'cities_do/assets/facilities/catalog.json';doc=json.loads(cat.read_text(encoding='utf-8')) if cat.exists() else {'facilities':[]};assert not any(e['id']==spec['id'] for e in doc['facilities']);doc['facilities'].append(spec);F.write_json(cat,doc)
 print('RAIL_BUILT',tri,lo,hi,flush=True)
if __name__=='__main__':main()
