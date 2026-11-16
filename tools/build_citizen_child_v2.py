"""Childv2: authored .28m skull,1.10m stature, shorter/stouter limbs. V1 read-only."""
from pathlib import Path
import argparse,json,sys,math
import bpy,numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_citizen_remaining as R
from build_citizen_adult_heads import make_hair
C=R.C;P=R.P;OUT=R.FULL/'child-v2';S=.56;HS=.28/.31;HC=1.1-.175*HS

def mz(z):return z*S+.0144*max(0,min(1,(z-1.28)/.105))
def head(v):x,y,z=v;return (x*HS,y*HS,HC+(z-1.575)*HS)
def garment(part,i,v):
 x,y,z=v;w=P.WEIGHTS[part][i]
 if part=='top':
  if 48<=i<128:
   side=(i-48)//40;ring=((i-48)%40)//8;cx=[.195,.225,.245,.257,.264][ring]*(1 if side==0 else -1)
   return (cx*S+(x-cx)*S*1.12,y*S*1.12,mz(z))
  return (x*S,y*S,mz(z))
 shoes=set(sum(P.SHOE.values(),[]));sign=1 if x>=0 else -1;cx=sign*.095
 if i in shoes or any(k.startswith('foot.') for k in w):return (cx*S+(x-cx)*S*1.1,y*S,z*S)
 if 16<=i<56 or 64<=i<104:
  offset=i-16 if i<56 else i-64;ring=offset//8;cy=[0,0,0,.022,.035][ring];factor=1 if ring==0 else 1.12
  return (cx*S+(x-cx)*S*factor,cy*S+(y-cy)*S*factor,z*S)
 if i>=112:return (cx*S+(x-cx)*S*1.12,y*S*1.12,z*S)
 return (x*S,y*S,z*S)

def replace_garment(part,style):
 R.clear()
 if part=='top':R.top_geometry(style,True)
 else:R.bottom_geometry(style)
 shoes={k:list(v) for k,v in P.SHOE.items()};R.replace(part,[garment(part,i,v) for i,v in enumerate(P.V[part])],P.F[part],P.WEIGHTS[part]);return shoes

def new_base():
 rig=bpy.data.objects['CitizenRig'];rig.animation_data.action=bpy.data.actions['Idle'];bpy.context.scene.frame_set(1)
 for v in bpy.data.objects['body'].data.vertices:
  p=v.co.copy()
  if v.index<26:v.co=head(p)
  elif p.z<1:
   centre=R.Vector((.264 if p.x>0 else -.264,-.003,.884));q=p-centre;v.co=centre*S+R.Vector((q.x*.84,q.y*.84,q.z*.70))
  else:v.co=(p.x*.72,p.y*.72,mz(p.z))
 for v in bpy.data.objects['hair'].data.vertices:v.co=head(v.co)
 bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
 for b in rig.data.edit_bones:b.head*=S;b.tail*=S
 bpy.ops.object.mode_set(mode='OBJECT')
 for a in bpy.data.actions:
  for f in a.fcurves:
   if f.data_path.endswith('.location'):
    for k in f.keyframe_points:k.co.y*=S;k.handle_left.y*=S;k.handle_right.y*=S
 replace_garment('top','sweater');return replace_garment('bottom','straight')

def source(ident,part,style,parent,base=False,gender=None):
 folder=OUT/ident;assert not folder.exists(),'Protected source exists: '+str(folder)
 bpy.ops.wm.open_mainfile(filepath=str(parent/'citizen.blend'));m=json.loads((parent/'spec.json').read_text(encoding='utf-8'));shoes=None;reuse=False
 if base:shoes=new_base()
 elif part=='hair':
  h=make_hair(style);R.replace('hair',[head(v) for v in h.v],h.f,[{'head':1} for _ in h.v])
 elif (part,style) in [('top','sweater'),('bottom','straight')]:reuse=True
 else:shoes=replace_garment(part,style)
 rig=bpy.data.objects['CitizenRig'];rig.animation_data.action=bpy.data.actions['Idle'];bpy.context.scene.frame_set(1);bpy.context.view_layer.update();C.studio(scale=1);C.set_view('S')
 tri={p:sum(len(f.vertices)-2 for f in bpy.data.objects[p].data.polygons) for p in C.PARTS};assert sum(tri.values())<=1500
 sources=m.get('layer_sources',{p:R.PILOT.relative_to(ROOT).as_posix() for p in C.PARTS}).copy()
 for p in C.PARTS if base else [part]:sources[p]=folder.relative_to(ROOT).as_posix()
 verts=bpy.data.objects['body'].data.vertices;skull=[v.co for v in list(verts)[:26]];skullheight=max(v.z for v in skull)-min(v.z for v in skull)
 assert abs(skullheight-.28)<1e-6
 m.update(id=ident,name=style,archetype='child',revision=2,variant_layer=part,style=style,gender=gender,height_m=1.1,body_scale=S,head_scale=HS,
  skull_height_m=skullheight,skull_heads_tall=1.1/skullheight,skull_width_m=max(v.x for v in skull)-min(v.x for v in skull),skull_depth_m=max(v.y for v in skull)-min(v.y for v in skull),
  shape_note='Uniform skull enlargement; shorter0.56 skeleton/translation scale; narrower shoulder centres,1.12 radial limb thickening, short neck collar. V1 preserved.',
  rendered_layers=C.PARTS if base else [part],sprite_count=100 if base else 25,sprite_directory='sprites',depth_sidecar='layer-depths.npz',layer_sources=sources,
  source='citizen.blend',part_model=part+'.glb',triangles_by_layer=tri,triangles_total=sum(tri.values()),
  rest_bones={b.name:dict(head=list(b.head_local),tail=list(b.tail_local),parent=b.parent.name if b.parent else None) for b in rig.data.bones},
  waist_overlap_m=.07*S,waist_profile=[[.935*S,.186*S,.134*S],[1.04*S,.174*S,.119*S]],
  attachment_points=[('waist','pelvis',[0,0,.97*S]),('neck','head',[0,0,mz(1.40)]),('wrist_L','forearm.L',[.264*S,0,.942*S]),('wrist_R','forearm.R',[-.264*S,0,.942*S])],
  age_min=0,age_max=11,game_registered=False,not_validated=['live population/selection integration','crowd performance'])
 if shoes:m['shoe_vertex_indices']=shoes
 m.pop('reused_render_from',None)
 if reuse:m['reused_render_from']=parent.relative_to(ROOT).as_posix()
 bounds={p:[min(v.co.z for v in bpy.data.objects[p].data.vertices),max(v.co.z for v in bpy.data.objects[p].data.vertices)] for p in C.PARTS};m['layer_z_bounds']=bounds
 assert abs(bounds['hair'][1]-1.1)<1e-5 and bounds['top'][1]<.80
 folder.mkdir(parents=True);(folder/'spec.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(folder/'citizen.blend'),compress=True)
 bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.data.objects[part].select_set(True);bpy.ops.export_scene.gltf(filepath=str(folder/m['part_model']),export_format='GLB',use_selection=True,export_animations=False)
 (folder/'build.py').write_text('import runpy,sys\nfrom pathlib import Path\nr=next(p for p in Path(__file__).resolve().parents if (p/"tools/build_citizen_child_v2.py").is_file())\na=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []\nsys.argv=[sys.argv[0],"--","--only","'+ident+'"]+a\nrunpy.run_path(str(r/"tools/build_citizen_child_v2.py"),run_name="__main__")\n',encoding='utf-8')
 print('V2_SOURCE',ident,'skull',skullheight,'height',bounds['hair'][1],flush=True);return folder,m

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--cache',type=Path,required=True);ap.add_argument('--only');args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);base=OUT/'child-base-01-v2'
 rows=[('child-base-01-v2','body','child-body-base-v2',R.PILOT,True,None)]+[(f'child-hair-{k}-{s}-v2','hair',s,base,False,g) for k,g,s in R.CHILD_HAIR]+[(f'child-top-{i+1:02d}-{s}-v2','top',s,base,False,None) for i,s in enumerate(['sweater','bomber','shirt','hoodie'])]+[(f'child-bottom-{i+1:02d}-{s}-v2','bottom',s,base,False,None) for i,s in enumerate(['straight','cargo','jogger'])]
 assert args.only is None or args.only in [r[0] for r in rows];entries=[]
 for ident,part,style,parent,isbase,gender in rows:
  if args.only and args.only!=ident:continue
  folder=OUT/ident
  if isbase and not args.only and (folder/'layer-depths.npz').exists():m=json.loads((folder/'spec.json').read_text(encoding='utf-8'))
  else:
   folder,m=source(ident,part,style,parent,isbase,gender)
   if m.get('reused_render_from'):
    inherited=json.loads((parent/'render-manifest.json').read_text());images=[r for r in inherited['images'] if r['part']==part];assert len(images)==25;(folder/'render-manifest.json').write_text(json.dumps({'supersampling':4,'images':images,'reused_from':m['reused_render_from']},indent=2)+'\n')
   else:R.render(folder,args.cache/ident,m['rendered_layers'])
  entries.append(dict(id=ident,layer=part,style=style,gender=gender,base=isbase,source=folder.relative_to(ROOT).as_posix()));(OUT/'catalog.json').write_text(json.dumps({'batch':'child-v2','parts':entries},indent=2)+'\n')
 print('V2_BUILD_DONE',len(entries),flush=True)
if __name__=='__main__':main()
