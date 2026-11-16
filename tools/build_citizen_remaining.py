"""Original scripted wardrobe + child extension; protected pilot/head sources are read-only.
Blender4.3.2. Each new source has four compatible meshes; only changed layers render.
"""
from pathlib import Path
import argparse,json,math,sys
import bpy,numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import citizen_pilot_common as C
PILOT=ROOT/'assets/citizens/adult-pilot-01'
assert (PILOT/'citizen.blend').is_file()
import build_citizen_adult_pilot as P
from build_citizen_adult_heads import make_hair
FULL=ROOT/'assets/citizens/full-set'
PRIMARY=FULL
TOPS=['sweater','bomber','shirt','cardigan','hoodie','uniform']
BOTTOMS=['straight','cargo','wide','jogger']
CHILD_HAIR=[('m01','male','crew'),('m02','male','fringe'),('m03','male','curly'),('f01','female','bob'),('f02','female','ponytail'),('f03','female','double-bun')]

def clear():
 for p in C.PARTS:P.V[p]=[];P.F[p]=[];P.WEIGHTS[p]=[]
 P.SHOE.clear()

def box(part,center,size,bone):
 x,y,z=center;rx,ry,rz=[v/2 for v in size]
 back=max(y+ry,-.085) if part=='top' and y<0 else y+ry
 v=[(x+a*rx,yy,z+c*rz) for c in [-1,1] for yy in [y-ry,back] for a in [-1,1]]
 P.add(part,v,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],{bone:1})

def panel(v):P.add('top',v+[(x,y+.055,z) for x,y,z in v],[(0,1,2),(3,5,4),(0,3,4,1),(1,4,5,2),(2,5,3,0)],{'spine':1})

def top_geometry(style,child=False):
 # Identical generous12-sided waist envelope for every top, including uniform.
 profiles={'sweater':(1.03,1.04),'bomber':(1.13,1.16),'shirt':(.99,1.0),'cardigan':(1.04,1.03),'hoodie':(1.09,1.12),'uniform':(1.015,1.035)}
 torso,sleeve=profiles[style]
 P.loft('top',[(0,0,.935,.186,.134),(0,0,1.04,.174,.119),(0,0,1.28,.194*torso,.110*torso),(0,0,1.385,.174,.098)],
  [{'pelvis':1},{'pelvis':.65,'spine':.35},{'spine':1},{'spine':1}],12)
 for side,sign in [('L',1),('R',-1)]:
  cf=1.3 if child else 1
  P.loft('top',[(sign*.195,0,1.345,.068*sleeve,.073*sleeve),(sign*.225,0,1.22,.063*sleeve,.065*sleeve),(sign*.245,0,1.10,.056*sleeve,.056*sleeve),(sign*.257,0,1.015,.049*sleeve,.050*sleeve),(sign*.264,0,.937,.044*cf,.047*cf)],
   [{'spine':.45,'upper_arm.'+side:.55},{'upper_arm.'+side:1},{'upper_arm.'+side:.5,'forearm.'+side:.5},{'forearm.'+side:1},{'forearm.'+side:1}])
 if style in ['bomber','cardigan','uniform']:
  box('top',(0,-.124,1.13),(.012,.010,.23),'spine')
 if style in ['shirt','uniform','cardigan']:
  for sign in [-1,1]:
   panel([(sign*.028,-.105,1.397),(sign*.087,-.118,1.34),(sign*.045,-.132,1.28)])
 if style=='uniform':
  for sign in [-1,1]:
   panel([(sign*.035,-.128,1.33),(sign*.108,-.124,1.27),(sign*.025,-.140,1.19)])
  for z in [1.20,1.12,1.045]:P.ellipsoid('top',(0,-.123,z),(.012,.018,.012),'spine',6,3)
 elif style=='hoodie':
  P.ellipsoid('top',(0,.105,1.33),(.105,.060,.060),'spine',10,4)
  box('top',(0,-.126,1.105),(.165,.014,.080),'spine')
 elif style=='bomber':
  for sign in [-1,1]:box('top',(sign*.075,-.125,1.11),(.050,.015,.075),'spine')
 elif style=='sweater':
  # Raised front knit yoke is geometry, not a texture or a colour patch.
  box('top',(0,-.119,1.275),(.190,.013,.035),'spine')
 elif style=='shirt':box('top',(.080,-.117,1.25),(.055,.012,.060),'spine')

def bottom_geometry(style):
 P.loft('bottom',[(0,0,.91,.149,.102),(0,0,1.005,.148,.102)],[{'pelvis':1},{'pelvis':1}])
 factors={'straight':(1.,1.),'cargo':(1.17,1.08),'wide':(1.32,1.48),'jogger':(1.10,.88)}
 thigh,ankle=factors[style]
 for side,x in [('L',.095),('R',-.095)]:
  P.loft('bottom',[(x,0,.955,.076,.088),(x,0,.73,.070*thigh,.074*thigh),(x,0,.52,.061*thigh,.065*thigh),(x,.022,.30,.051*ankle,.054*ankle),(x,.035,.105,.044*ankle,.047*ankle)],
   [{'pelvis':.4,'thigh.'+side:.6},{'thigh.'+side:1},{'thigh.'+side:.5,'shin.'+side:.5},{'shin.'+side:1},{'shin.'+side:.65,'foot.'+side:.35}])
  P.shoe(side,x)
 # Append after both shoes; recorded shoe vertex indices remain the true soles.
 for side,x in [('L',.095),('R',-.095)]:
  if style=='cargo':box('bottom',(x,-.083,.70),(.100,.030,.115),'thigh.'+side)
  if style=='jogger':box('bottom',(x,-.073,.064),(.098,.10,.028),'foot.'+side)
  if style=='wide':box('bottom',(x,-.062,.058),(.100,.12,.026),'foot.'+side)

def replace(part,v,f,weights):
 ob=bpy.data.objects[part];mat=ob.data.materials[0];mesh=bpy.data.meshes.new(part+'_new');mesh.from_pydata(v,[],f);mesh.update();mesh.materials.append(mat);ob.data=mesh;ob.vertex_groups.clear()
 for b in bpy.data.objects['CitizenRig'].data.bones:ob.vertex_groups.new(name=b.name)
 for i,w in enumerate(weights):
  for bone,weight in w.items():ob.vertex_groups[bone].add([i],weight,'REPLACE')
 for face in mesh.polygons:face.use_smooth=False

def map_child(v,head=False):
 x,y,z=v
 return (x*.78,y*.78,.9635+(z-1.575)*.78) if head else (x*.6,y*.6,z*.6)

def build_child_base():
 # Same14 names/parents/angles/timebase, shorter bones and translations; larger head ratio.
 rig=bpy.data.objects['CitizenRig'];rig.animation_data.action=bpy.data.actions['Idle'];bpy.context.scene.frame_set(1)
 for part in C.PARTS:
  for vert in bpy.data.objects[part].data.vertices:
   p=vert.co.copy()
   if part=='hair' or (part=='body' and vert.index<26):vert.co=map_child(p,True)
   elif part=='body' and p.z<1.0:
    centre=Vector((.264 if p.x>0 else -.264,-.003,.884));q=p-centre;vert.co=centre*.6+Vector((q.x*.8,q.y*.8,q.z*.66))
   elif part=='body':vert.co=(p.x*.72,p.y*.72,p.z*.6)
   else:vert.co=map_child(p)
 bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
 for bone in rig.data.edit_bones:bone.head*=.6;bone.tail*=.6
 bpy.ops.object.mode_set(mode='OBJECT')
 for action in bpy.data.actions:
  for fc in action.fcurves:
   if fc.data_path.endswith('.location'):
    for key in fc.keyframe_points:key.co.y*=.6;key.handle_left.y*=.6;key.handle_right.y*=.6
 clear();top_geometry('sweater',True);replace('top',[map_child(v) for v in P.V['top']],P.F['top'],P.WEIGHTS['top'])
 clear();bottom_geometry('straight');replace('bottom',[map_child(v) for v in P.V['bottom']],P.F['bottom'],P.WEIGHTS['bottom'])
 bpy.context.scene.frame_set(1);bpy.context.view_layer.update()

def dump_source(folder,ident,part,style,parent,child=False,gender=None,base=False):
 if folder.exists():raise RuntimeError('Protected output exists: '+str(folder))
 bpy.ops.wm.open_mainfile(filepath=str(parent/'citizen.blend'));meta=json.loads((parent/'spec.json').read_text(encoding='utf-8'))
 clear();shoes=None
 if base:build_child_base();shoes={k:list(v) for k,v in P.SHOE.items()}
 elif part=='top':
  top_geometry(style,child);replace(part,[map_child(v) for v in P.V[part]] if child else P.V[part],P.F[part],P.WEIGHTS[part])
 elif part=='bottom':
  bottom_geometry(style);shoes={k:list(v) for k,v in P.SHOE.items()};replace(part,[map_child(v) for v in P.V[part]] if child else P.V[part],P.F[part],P.WEIGHTS[part])
 else:
  h=make_hair(style);replace('hair',[map_child(v,True) for v in h.v],h.f,[{'head':1} for _ in h.v])
 rig=bpy.data.objects['CitizenRig'];rig.animation_data.action=bpy.data.actions['Idle'];bpy.context.scene.frame_set(1);bpy.context.view_layer.update();C.studio(scale=1);C.set_view('S')
 tri={p:sum(len(f.vertices)-2 for f in bpy.data.objects[p].data.polygons) for p in C.PARTS};assert sum(tri.values())<=1500,tri
 sources=meta.get('layer_sources',{p:PILOT.relative_to(ROOT).as_posix() for p in C.PARTS}).copy()
 for p in (C.PARTS if base else [part]):sources[p]=folder.relative_to(ROOT).as_posix()
 scale=.6 if child else 1.
 points=[('waist','pelvis',[0,0,.97*scale]),('neck','head',[0,0,1.40*scale]),('wrist_L','forearm.L',[.264*scale,0,.942*scale]),('wrist_R','forearm.R',[-.264*scale,0,.942*scale])]
 meta.update(id=ident,name=style,archetype='child' if child else 'adult-neutral',height_m=1.1 if child else 1.75,variant_layer=part,style=style,
  rendered_layers=C.PARTS if base else [part],sprite_count=100 if base else 25,sprite_directory='sprites',depth_sidecar='layer-depths.npz',layer_sources=sources,
  source='citizen.blend',part_model='body.glb' if base else part+'.glb',triangles_by_layer=tri,triangles_total=sum(tri.values()),
  bone_count=14,rest_bones={b.name:dict(head=list(b.head_local),tail=list(b.tail_local),parent=b.parent.name if b.parent else None) for b in rig.data.bones},
  attachment_points=points,waist_overlap_m=.07*scale,body_scale=scale,head_scale=.78 if child else 1.,age_min=0 if child else (12 if part=='bottom' or style=='uniform' else 18),
  age_max=11 if child else (17 if style=='uniform' else None),game_registered=False,gender=gender,
  directions=dict(C.DIRECTIONS),frames=list(C.FRAMES),mirror_missing_directions={'SW':'SE','W':'E','NW':'NE'},
  waist_profile=[[.935*scale,.186*scale,.134*scale],[1.04*scale,.174*scale,.119*scale]],
  not_validated=['live city population / part selection integration','large-crowd performance'])
 if shoes:meta['shoe_vertex_indices']=shoes
 bounds={p:[min(v.co.z for v in bpy.data.objects[p].data.vertices),max(v.co.z for v in bpy.data.objects[p].data.vertices)] for p in C.PARTS};meta['layer_z_bounds']=bounds
 if part=='top' or base:assert bounds['top'][1]<=1.4*scale+1e-6
 if child:assert abs(bounds['hair'][1]-1.1)<1e-5
 folder.mkdir(parents=True);(folder/'spec.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');bpy.context.preferences.filepaths.save_version=0
 bpy.ops.wm.save_as_mainfile(filepath=str(folder/'citizen.blend'),compress=True)
 bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.data.objects[part].select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(folder/meta['part_model']),export_format='GLB',use_selection=True,export_animations=False)
 batch='child' if child else ('adult-tops' if part=='top' else 'adult-bottoms')
 (folder/'build.py').write_text('import runpy,sys\nfrom pathlib import Path\nr=next(p for p in Path(__file__).resolve().parents if (p/"tools/build_citizen_remaining.py").is_file())\nargs=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []\nsys.argv=[sys.argv[0],"--","--batch","'+batch+'","--only","'+ident+'"]+args\nrunpy.run_path(str(r/"tools/build_citizen_remaining.py"),run_name="__main__")\n',encoding='utf-8')
 print('PART_SOURCE',ident,part,tri,flush=True);return meta

def render(folder,work,layers):
 work.mkdir(parents=True,exist_ok=True);bpy.ops.wm.open_mainfile(filepath=str(folder/'citizen.blend'));C.studio(scale=4)
 scene=bpy.context.scene;scene.view_layers[0].use_pass_z=True;scene.use_nodes=True;nodes=scene.node_tree.nodes;nodes.clear();r=nodes.new('CompositorNodeRLayers');comp=nodes.new('CompositorNodeComposite');scene.node_tree.links.new(r.outputs['Image'],comp.inputs[0]);out=nodes.new('CompositorNodeOutputFile');out.base_path=str(work);out.format.file_format='OPEN_EXR';out.format.color_mode='BW';out.format.color_depth='32';scene.node_tree.links.new(r.outputs['Depth'],out.inputs[0]);records=[]
 for d in C.DIRECTIONS:
  view=C.set_view(d)
  for frame in C.FRAMES:
   C.set_pose(frame)
   for part in layers:
    stem=f'{part}_{d}_{frame}'
    for p in C.PARTS:bpy.data.objects[p].hide_render=p!=part
    if not ((work/(stem+'.png')).exists() and (work/(stem+'.npy')).exists()):
     scene.render.filepath=str(work/(stem+'.png'));out.file_slots[0].path=stem+'_depth_';bpy.ops.render.render(write_still=True);paths=sorted(work.glob(stem+'_depth_*.exr'));im=bpy.data.images.load(str(paths[-1]),check_existing=False);im.colorspace_settings.name='Non-Color';w,h=im.size;raw=np.array(im.pixels[:],np.float32);channels=len(raw)//(w*h);np.save(work/(stem+'.npy'),np.flipud(raw.reshape(h,w,channels)[:,:,0]).copy());bpy.data.images.remove(im)
    records.append(dict(stem=stem,part=part,frame=frame,**view))
   (work/'render-progress.json').write_text(json.dumps({'images':records}),encoding='utf-8')
 (folder/'render-manifest.json').write_text(json.dumps({'supersampling':4,'images':records},indent=2)+'\n',encoding='utf-8');print('PART_RENDERED',folder.name,len(records),flush=True)

def entries(batch):
 if batch=='adult-tops':return [(f'adult-top-{i+1:02d}-{s}-v2','top',s,PILOT,False,None,False) for i,s in enumerate(TOPS)]
 if batch=='adult-bottoms':
  p=FULL/'adult-tops/adult-top-01-sweater-v2';p=p if p.exists() else PRIMARY/'adult-tops/adult-top-01-sweater-v2'
  return [(f'adult-bottom-{i+1:02d}-{s}','bottom',s,p,False,None,False) for i,s in enumerate(BOTTOMS)]
 base=FULL/'child/child-base-01'
 return [('child-base-01','body','child-body-base',PILOT,True,None,True)]+[(f'child-hair-{k}-{s}','hair',s,base,True,g,False) for k,g,s in CHILD_HAIR]+[(f'child-top-{i+1:02d}-{s}','top',s,base,True,None,False) for i,s in enumerate(TOPS[:3]+['hoodie'])]+[(f'child-bottom-{i+1:02d}-{s}','bottom',s,base,True,None,False) for i,s in enumerate(['straight','cargo','jogger'])]

def main():
 global FULL
 ap=argparse.ArgumentParser();ap.add_argument('--batch',choices=['adult-tops','adult-bottoms','child'],required=True);ap.add_argument('--cache',type=Path,required=True);ap.add_argument('--only');ap.add_argument('--output-root',type=Path,default=ROOT);ap.add_argument('--resume',action='store_true');args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);catalog=[]
 args.output_root=args.output_root.resolve();args.output_root.relative_to(ROOT);FULL=args.output_root/'assets/citizens/full-set'
 rows=entries(args.batch)
 if args.only and args.only not in [r[0] for r in rows]:ap.error('Unknown part ID for batch')
 for ident,part,style,parent,child,gender,base in rows:
  if args.only and ident!=args.only:continue
  if child and not base and not parent.exists():parent=PRIMARY/'child/child-base-01'
  folder=FULL/args.batch/ident
  if base and not args.only and (folder/'layer-depths.npz').exists():
   catalog.append(dict(id=ident,layer=part,style=style,gender=gender,base=True,source=folder.relative_to(ROOT).as_posix()));continue
  if folder.exists() and args.resume:
   if (folder/'layer-depths.npz').exists():raise RuntimeError('Completed part protected: '+str(folder))
   meta=json.loads((folder/'spec.json').read_text(encoding='utf-8'))
  else:meta=dump_source(folder,ident,part,style,parent,child,gender,base)
  render(folder,args.cache/ident,meta['rendered_layers']);catalog.append(dict(id=ident,layer=part,style=style,gender=gender,base=base,source=folder.relative_to(ROOT).as_posix()))
  path=FULL/args.batch/'catalog.json';path.write_text(json.dumps({'batch':args.batch,'parts':catalog},indent=2)+'\n',encoding='utf-8')
 print('BATCH_RENDERED',args.batch,len(catalog),flush=True)
if __name__=='__main__':main()
