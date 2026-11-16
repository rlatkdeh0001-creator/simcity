"""Adult hair10, sharing the protected pilot skeleton/body/clothes without mutation.
Original low-poly geometry only. Blender4.3.2; native contract remains5 stored views +3 mirrors.
"""
from pathlib import Path
import argparse,json,math,os,sys
import bpy
import numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import citizen_pilot_common as C
PILOT=ROOT/'assets/citizens/adult-pilot-01'
VARIANTS=[
 ('adult-hair-m01-crew','male','crew'),('adult-hair-m02-fringe','male','fringe'),
 ('adult-hair-m03-centre-part','male','centre-part'),('adult-hair-m04-curly','male','curly'),
 ('adult-hair-m05-swept-back','male','swept-back'),('adult-hair-f01-pixie','female','pixie'),
 ('adult-hair-f02-bob','female','bob'),('adult-hair-f03-ponytail','female','ponytail'),
 ('adult-hair-f04-double-bun','female','double-bun'),('adult-hair-f05-low-bun','female','low-bun')]

class Hair:
 def __init__(self):self.v=[];self.f=[]
 def add(self,v,f):
  start=len(self.v);self.v.extend(v);self.f.extend(tuple(start+i for i in face) for face in f)
 def cap(self,rx=.129,ry=.117,front=1.65,side=1.58,back=1.51,apex=1.75,shift_y=0):
  n=12;rings=4;v=[(0,shift_y,apex)];f=[]
  for j in range(1,rings+1):
   t=j/rings;radius=math.sin(t*math.pi/2);drop=1-math.cos(t*math.pi/2)
   for i in range(n):
    a=i*math.tau/n;s=math.sin(a);bottom=side+(back-side)*max(s,0)+(front-side)*max(-s,0)
    v.append((rx*radius*math.cos(a),shift_y+ry*radius*s,apex-(apex-bottom)*drop))
  f.extend((0,1+i,1+(i+1)%n) for i in range(n))
  for j in range(rings-1):
   for i in range(n):f.append((1+j*n+i,1+(j+1)*n+i,1+(j+1)*n+(i+1)%n,1+j*n+(i+1)%n))
  start=1+(rings-1)*n
  for i in range(n):
   x,y,z=v[start+i];v.append((x*.95,shift_y+(y-shift_y)*.95,z+.003))
  for i in range(n):f.append((start+i,start+n+i,start+n+(i+1)%n,start+(i+1)%n))
  self.add(v,f)
 def ellipsoid(self,center,radii,n=8,lat=4):
  cx,cy,cz=center;rx,ry,rz=radii;v=[(cx,cy,cz-rz)];f=[]
  for j in range(1,lat):
   a=-math.pi/2+math.pi*j/lat
   v.extend((cx+rx*math.cos(a)*math.cos(i*math.tau/n),cy+ry*math.cos(a)*math.sin(i*math.tau/n),cz+rz*math.sin(a)) for i in range(n))
  v.append((cx,cy,cz+rz));end=len(v)-1
  f.extend((0,1+(i+1)%n,1+i) for i in range(n))
  for j in range(lat-2):
   for i in range(n):f.append((1+j*n+i,1+j*n+(i+1)%n,1+(j+1)*n+(i+1)%n,1+(j+1)*n+i))
  f.extend((end,1+(lat-2)*n+i,1+(lat-2)*n+(i+1)%n) for i in range(n));self.add(v,f)
 def fringe(self,x0,x1,z0,z1):
  v=[(x,y,z) for y in [-.124,-.110] for z in [z0,z1] for x in [x0,x1]]
  self.add(v,[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)])


def make_hair(style):
 h=Hair()
 if style=='crew':h.cap(.122,.110,1.66,1.60,1.54)
 elif style=='fringe':h.cap(.131,.119,1.64,1.57,1.51);h.fringe(-.104,.104,1.585,1.665)
 elif style=='centre-part':
  h.cap(.128,.117,1.67,1.57,1.51,1.74)
  for x in [-.05,.05]:h.ellipsoid((x,-.015,1.69),(.080,.100,.060))
 elif style=='curly':
  h.cap(.131,.120,1.63,1.57,1.51)
  for x,y in [(-.09,-.06),(0,-.085),(.09,-.06),(-.055,.055),(.055,.055)]:h.ellipsoid((x,y,1.68),(.062,.062,.070))
 elif style=='swept-back':h.cap(.130,.135,1.69,1.57,1.47,shift_y=.014);h.ellipsoid((0,.085,1.65),(.095,.09,.10))
 elif style=='pixie':h.cap(.132,.122,1.66,1.52,1.48);h.fringe(-.09,.09,1.61,1.66)
 elif style=='bob':h.cap(.148,.132,1.66,1.46,1.44)
 elif style=='ponytail':h.cap();h.ellipsoid((0,.18,1.58),(.075,.115,.12))
 elif style=='double-bun':
  h.cap()
  for x in [-.135,.135]:h.ellipsoid((x,.05,1.64),(.065,.07,.085))
 elif style=='low-bun':h.cap(.130,.122,1.66,1.56,1.49);h.ellipsoid((0,.17,1.48),(.09,.08,.04))
 else:raise ValueError(style)
 assert min(z for x,y,z in h.v)>=1.43
 assert abs(max(z for x,y,z in h.v)-1.75)<1e-6
 return h


def build_source(folder,ident,gender,style):
 if folder.exists():raise RuntimeError('Protected source exists: '+str(folder))
 bpy.ops.wm.open_mainfile(filepath=str(PILOT/'citizen.blend'))
 rig=bpy.data.objects['CitizenRig'];ob=bpy.data.objects['hair'];mat=ob.data.materials[0]
 h=make_hair(style);mesh=bpy.data.meshes.new(ident);mesh.from_pydata(h.v,[],h.f);mesh.update();mesh.materials.append(mat);ob.data=mesh
 for p in mesh.polygons:p.use_smooth=False
 ob.vertex_groups.clear()
 for bone in rig.data.bones:ob.vertex_groups.new(name=bone.name)
 ob.vertex_groups['head'].add(list(range(len(mesh.vertices))),1.,'REPLACE')
 rig.animation_data.action=bpy.data.actions['Idle'];bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
 C.studio(scale=1);C.set_view('S');folder.mkdir(parents=True)
 meta=json.loads((PILOT/'spec.json').read_text(encoding='utf-8'))
 tri={p:sum(len(face.vertices)-2 for face in bpy.data.objects[p].data.polygons) for p in C.PARTS}
 assert sum(tri.values())<=1500
 meta.update(id=ident,name=style,gender=gender,variant_layer='hair',style=style,variant_of='adult-pilot-01',source_revision='957d806',
  triangles_by_layer=tri,triangles_total=sum(tri.values()),sprite_directory='sprites',sprite_count=25,rendered_layers=['hair'],
  depth_sidecar='layer-depths.npz',source='citizen.blend',part_model='hair.glb',
  shared_layer_reference={p:'assets/citizens/adult-pilot-01' for p in ['body','top','bottom']},
  directions=dict(C.DIRECTIONS),frames=list(C.FRAMES),mirror_missing_directions={'SW':'SE','W':'E','NW':'NE'},
  mirror_contract='flip both RGBA and depth, continuous axis x=32',
  compositing='same original per-pixel depth sort, tint and alpha-over; resolve three unchanged layers from pilot',
  hair_min_z_m=round(min(z for x,y,z in h.v),5),hair_clothing_interface=dict(hair_min_z_m=1.43,max_future_top_neck_z_m=1.40),
  glb_scope='rigged hair part, bind geometry; Idle/Walk animation source retained in citizen.blend',game_registered=False)
 (folder/'spec.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 bpy.ops.wm.save_as_mainfile(filepath=str(folder/'citizen.blend'),compress=True)
 bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);rig.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(folder/'hair.glb'),export_format='GLB',use_selection=True,export_extras=True,export_animations=False)
 (folder/'build.py').write_text('import runpy,sys\nfrom pathlib import Path\nr=next(p for p in Path(__file__).resolve().parents if (p/"tools/build_citizen_adult_heads.py").is_file())\nsys.argv=[sys.argv[0],"--","--only","'+ident+'"]+sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [sys.argv[0],"--","--only","'+ident+'"]\nrunpy.run_path(str(r/"tools/build_citizen_adult_heads.py"),run_name="__main__")\n',encoding='utf-8')
 print('ADULT_HEAD_BUILT',ident,tri,flush=True)
 return meta


def render_hair(folder,work):
 work.mkdir(parents=True,exist_ok=True);bpy.ops.wm.open_mainfile(filepath=str(folder/'citizen.blend'));C.studio(scale=4)
 scene=bpy.context.scene;scene.view_layers[0].use_pass_z=True;scene.use_nodes=True;nodes=scene.node_tree.nodes;nodes.clear()
 r=nodes.new('CompositorNodeRLayers');composite=nodes.new('CompositorNodeComposite');scene.node_tree.links.new(r.outputs['Image'],composite.inputs[0])
 output=nodes.new('CompositorNodeOutputFile');output.base_path=str(work);output.format.file_format='OPEN_EXR';output.format.color_mode='BW';output.format.color_depth='32';scene.node_tree.links.new(r.outputs['Depth'],output.inputs[0])
 for p in C.PARTS:bpy.data.objects[p].hide_render=p!='hair'
 manifest=[]
 for direction in C.DIRECTIONS:
  view=C.set_view(direction)
  for frame in C.FRAMES:
   C.set_pose(frame);stem=f'hair_{direction}_{frame}'
   if not ((work/(stem+'.png')).exists() and (work/(stem+'.npy')).exists()):
    scene.render.filepath=str(work/(stem+'.png'));output.file_slots[0].path=stem+'_depth_';bpy.ops.render.render(write_still=True)
    paths=sorted(work.glob(stem+'_depth_*.exr'));assert paths
    im=bpy.data.images.load(str(paths[-1]),check_existing=False);im.colorspace_settings.name='Non-Color';w,h=im.size;raw=np.array(im.pixels[:],dtype=np.float32);channels=len(raw)//(w*h)
    depth=np.flipud(raw.reshape(h,w,channels)[:,:,0]).copy();np.save(work/(stem+'.npy'),depth);bpy.data.images.remove(im)
   manifest.append(dict(stem=stem,part='hair',direction=direction,frame=frame,**{k:v for k,v in view.items() if k!='direction'}))
   (work/'render-manifest.json').write_text(json.dumps({'supersampling':4,'images':manifest},indent=2)+'\n',encoding='utf-8')
 assert len(manifest)==25
 (folder/'render-manifest.json').write_text(json.dumps({'supersampling':4,'images':manifest},indent=2)+'\n',encoding='utf-8')
 print('ADULT_HEAD_RENDERED',folder.name,len(manifest),flush=True)


def main():
 ap=argparse.ArgumentParser();ap.add_argument('--only',choices=[x[0] for x in VARIANTS]);ap.add_argument('--cache',type=Path,required=True);ap.add_argument('--output-root',type=Path,default=ROOT);ap.add_argument('--resume',action='store_true');args=ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
 entries=[]
 for ident,gender,style in VARIANTS:
  if args.only and ident!=args.only:continue
  folder=args.output_root/'assets/citizens/full-set/adult-heads'/ident
  if folder.exists() and args.resume:
   if (folder/'layer-depths.npz').exists():raise RuntimeError('Completed part is protected; use a fresh output root: '+str(folder))
   meta=json.loads((folder/'spec.json').read_text(encoding='utf-8'))
  else:meta=build_source(folder,ident,gender,style)
  render_hair(folder,args.cache/ident);entries.append(dict(id=ident,gender=gender,style=style,source=folder.relative_to(args.output_root).as_posix(),triangles=meta['triangles_by_layer']['hair']))
 base=args.output_root/'assets/citizens/full-set/adult-heads';base.mkdir(parents=True,exist_ok=True)
 catalog=base/'catalog.json';doc={'archetype':'adult-neutral','part_layer':'hair','pilot_reference':'assets/citizens/adult-pilot-01','logical_directions':8,'physical_directions':5,'parts':entries}
 if catalog.exists() and args.only:
  previous=json.loads(catalog.read_text(encoding='utf-8'));replacements={e['id']:e for e in entries};ids={e['id'] for e in previous['parts']};previous['parts']=[replacements.get(e['id'],e) for e in previous['parts']]+[e for e in entries if e['id'] not in ids];doc=previous
 catalog.write_text(json.dumps(doc,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print('ADULT_HEAD_BATCH_DONE',len(entries),flush=True)
if __name__=='__main__':main()
