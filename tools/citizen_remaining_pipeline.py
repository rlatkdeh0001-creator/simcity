"""BatchII-IV: unchanged native/depth contract; child-only dimensional parameters.
All original validators/sources remain unchanged. Child staging substitutes nominal
height/overlap and anatomical anchor coordinates, never alpha/error/bone/frame limits.
"""
from pathlib import Path
import argparse,json,math,os,runpy,shutil,sys
import numpy as np
# Blender intentionally ignores PYTHONPATH; add only the approved D: imaging target.
site=Path(os.environ.get('CITIZEN_PILLOW_SITE','D:/tools/cities-asset-python311/site-packages'))
if site.is_dir():sys.path.insert(0,str(site))
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import finalize_citizen_adult_heads as F
FULL=ROOT/'assets/citizens/full-set';PILOT=ROOT/'assets/citizens/adult-pilot-01';BASE_DOC=ROOT/'docs/citizen-adult-pilot'
CACHE={}

def write(path,data):path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def meta(folder):return json.loads((folder/'spec.json').read_text(encoding='utf-8'))
def catalog(batch):return json.loads((FULL/batch/'catalog.json').read_text(encoding='utf-8'))['parts']
def refs(folder):
 m=meta(folder)
 if 'layer_sources' in m:return {p:ROOT/m['layer_sources'][p] for p in F.LAYERS}
 r={p:PILOT for p in F.LAYERS}
 for p in m.get('rendered_layers',[]):r[p]=folder
 return r

def load(folder):
 key=str(folder)
 if key not in CACHE:
  z=np.load(folder/'layer-depths.npz');depth={str(n):v for n,v in zip(z['names'],z['depth_mm'])};rgba={}
  for n in depth:
   with Image.open(folder/'sprites'/(n+'.png')) as im:rgba[n]=np.array(im.convert('RGBA'))
  manifest=BASE_DOC/'render-manifest.json' if folder==PILOT else folder/'render-manifest.json'
  rows=json.loads(manifest.read_text(encoding='utf-8'))['images'];CACHE[key]=(rgba,depth,{x['stem']:x for x in rows})
 return CACHE[key]

def resolve(sources):
 rgba={};depth={};records=[]
 for d in F.DIRS:
  for frame in F.FRAMES:
   for p in F.LAYERS:
    n=f'{p}_{d}_{frame}';a,z,r=load(sources[p]);rgba[n]=a[n];depth[n]=z[n];records.append(r[n])
 return rgba,depth,records

def finalize(folder,work):
 m=meta(folder);layers=m['rendered_layers'];spr=folder/'sprites';side=folder/'layer-depths.npz'
 if side.exists():assert len(list(spr.glob('*.png')))==25*len(layers);return
 spr.mkdir(exist_ok=True);names=[];depths=[]
 if m.get('reused_render_from'):
  source=ROOT/m['reused_render_from'];z=np.load(source/'layer-depths.npz')
  for n,d in zip(z['names'],z['depth_mm']):
   if str(n).split('_')[0] in layers:shutil.copy2(source/'sprites'/(str(n)+'.png'),spr/(str(n)+'.png'));names.append(str(n));depths.append(d)
  assert len(names)==25;np.savez_compressed(side,depth_mm=np.stack(depths),names=np.array(names));print('NATIVE_REUSED',folder.name,len(names),flush=True);return
 for d in F.DIRS:
  for frame in F.FRAMES:
   for p in layers:
    n=f'{p}_{d}_{frame}'
    with Image.open(work/(n+'.png')) as im:
     im=im.convert('RGBA');hi=np.asarray(im)[:,:,3]>0;im=im.convert('RGBa').resize((64,96),Image.Resampling.LANCZOS).convert('RGBA');a=np.array(im,np.uint8)
    z=np.load(work/(n+'.npy'));assert z.shape==(384,256);z=np.where(hi&np.isfinite(z)&(z>0)&(z<60),z,np.inf);z=z.reshape(96,4,64,4).min(axis=(1,3));z=np.where(np.isfinite(z),np.minimum(z*1000,65534),65535).astype(np.uint16)
    for _ in range(3):
     if not np.any((a[:,:,3]>0)&(z==65535)):break
     padded=np.pad(z,1,constant_values=65535);near=np.minimum.reduce([padded[y:y+96,x:x+64] for y in range(3) for x in range(3)]);missing=z==65535;z[missing]=near[missing]
    z[a[:,:,3]==0]=65535;assert np.all(z[a[:,:,3]>0]<65535),n
    bb=Image.fromarray(a[:,:,3]).getbbox();assert bb and min(bb[:2])>0 and bb[2]<64 and bb[3]<96,n
    chroma=a[:,:,:3].max(axis=2).astype(int)-a[:,:,:3].min(axis=2).astype(int);assert chroma[a[:,:,3]>0].max()<=1,n
    assert not (spr/(n+'.png')).exists();Image.fromarray(a).save(spr/(n+'.png'));names.append(n);depths.append(z)
 np.savez_compressed(side,depth_mm=np.stack(depths),names=np.array(names));print('NATIVE_PART',folder.name,len(names),flush=True)

def resolved_view(folder,dest,sources=None,copy_blend=True):
 m=meta(folder);sources=sources or refs(folder);rgba,depth,records=resolve(sources);(dest/'sprites').mkdir(parents=True,exist_ok=True)
 for n in depth:shutil.copy2(sources[n.split('_')[0]]/'sprites'/(n+'.png'),dest/'sprites'/(n+'.png'))
 np.savez_compressed(dest/'layer-depths.npz',depth_mm=np.stack(list(depth.values())),names=np.array(list(depth)))
 m.update(sprite_count=100,resolved_view=True,image_only_preview=not copy_blend);write(dest/'spec.json',m);write(dest/'render-manifest.json',{'supersampling':4,'images':records})
 if copy_blend:shutil.copy2(folder/'citizen.blend',dest/'citizen.blend')
 return rgba,depth

def prepare(batch,cache):
 rows=[]
 for entry in catalog(batch):
  folder=ROOT/entry['source'];finalize(folder,cache/folder.name);inp=cache/'resolved'/folder.name;resolved_view(folder,inp)
  # Reuse the exact existing100-sprite validation-view constructor, with all
  # four inputs already materialized; no conditional layer data can go stale.
  F.PILOT=inp;F.ASSET_ROOT=cache;F.BASE_DOC=BASE_DOC
  stage=cache/'validation'/folder.name;F.validation_stage(inp,stage)
  m=meta(folder);doc=stage/'docs/citizen-adult-pilot';manifest=json.loads((doc/'render-manifest.json').read_text());manifest.update(fresh_variant_records=25*len(m['rendered_layers']),inherited_pilot_records=100-25*len(m['rendered_layers']));write(doc/'render-manifest.json',manifest)
  if m['archetype']=='child':
   tool=stage/'tools/verify_citizen_adult_pilot.py';text=tool.read_text(encoding='utf-8');assert 'hi[2]-lo[2]-1.75' in text and 'abs(overlap-.07)' in text
   text=text.replace("'idle_height_175'","'idle_height_matches_child_110'").replace('hi[2]-lo[2]-1.75','hi[2]-lo[2]-1.10').replace("'shirt_overlaps_waist_7cm'","'shirt_overlaps_waist_child_4p2cm'").replace('abs(overlap-.07)','abs(overlap-.042)');tool.write_text(text,encoding='utf-8')
   tool=stage/'tools/audit_citizen_projection.py';text=tool.read_text(encoding='utf-8');start=text.index("[('waist','pelvis',");end=text.index(']:',start)+1;text=text[:start]+repr(m['attachment_points'])+text[end:];tool.write_text(text,encoding='utf-8')
  rows.append(dict(id=entry['id'],source=entry['source'],stage=str(stage),base=entry.get('base',False)))
 write(cache/'run.json',{'batch':batch,'parts':rows});print('RESOLVED_STAGES',batch,len(rows),flush=True)

def rig(batch,cache):
 import bpy
 from mathutils import Vector
 import citizen_pilot_common as C
 run=json.loads((cache/'run.json').read_text());done=[]
 for row in run['parts']:
  tools=Path(row['stage'])/'tools';sys.path.insert(0,str(tools));runpy.run_path(str(tools/'audit_citizen_projection.py'),run_name='__main__');runpy.run_path(str(tools/'verify_citizen_adult_pilot.py'),run_name='__main__')
  m=meta(ROOT/row['source']);profile=m['waist_profile'];scale=m['body_scale'];rigob=bpy.data.objects['CitizenRig'];minimum=1e9
  for ring,(z,rx,ry) in enumerate(profile):
   for j in range(12):
    expected=Vector((rx*math.cos(j*math.tau/12),ry*math.sin(j*math.tau/12),z));assert (bpy.data.objects['top'].data.vertices[ring*12+j].co-expected).length<1e-6
  # Actual deformed trouser vertices must lie inside the common12-sided shirt
  # envelope throughout the overlap. All tops retain those identical lower rings.
  for frame in C.FRAMES:
   C.set_pose(frame);dz=rigob.pose.bones['pelvis'].head.z-rigob.data.bones['pelvis'].head_local.z;ob=bpy.data.objects['bottom'];e=ob.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=e.to_mesh()
   for vert in mesh.vertices:
    x,y,z=e.matrix_world@vert.co;z-=dz
    if z<profile[0][0]-1e-5:continue
    u=(z-profile[0][0])/(profile[1][0]-profile[0][0]);assert u<=1+1e-5
    rx=profile[0][1]*(1-u)+profile[1][1]*u;ry=profile[0][2]*(1-u)+profile[1][2]*u
    poly=np.array([(rx*math.cos(i*math.tau/12),ry*math.sin(i*math.tau/12)) for i in range(12)])
    for i in range(12):
     a=poly[i];b=poly[(i+1)%12];edge=b-a;distance=(edge[0]*(y-a[1])-edge[1]*(x-a[0]))/np.linalg.norm(edge);minimum=min(minimum,float(distance))
   e.to_mesh_clear()
  assert minimum>=-1e-5,(row['id'],'waist surface penetration',minimum)
  if m['archetype']=='adult-neutral':
   baseline=json.loads((PILOT/'spec.json').read_text(encoding='utf-8'))
   assert all(np.max(np.abs(np.array(m['rest_bones'][b]['head'])-baseline['rest_bones'][b]['head']))<1e-6 for b in m['rest_bones'])
  done.append({'id':row['id'],'waist_min_clearance_m':minimum,'passed':True});write(cache/'interfaces.json',done)
  print('PART_RIG_OK',row['id'],'waist_clearance',minimum,flush=True)
 print('BATCH_RIG_OK',batch,len(done),flush=True)

def check(batch,cache):
 run=json.loads((cache/'run.json').read_text());results=[];mirrors=0
 interfaces={r['id']:r for r in json.loads((cache/'interfaces.json').read_text())}
 for row in run['parts']:
  stage=Path(row['stage']);runpy.run_path(str(stage/'tools/verify_citizen_sprites.py'),run_name='__main__');doc=stage/'docs/citizen-adult-pilot';a=json.loads((doc/'rig-validation.json').read_text());b=json.loads((doc/'composite-validation.json').read_text());assert a['passed'] and b['passed'];m=meta(ROOT/row['source']);rgba,depth,_=resolve(refs(ROOT/row['source']))
  for d in F.MIRRORS.values():
   for frame in F.FRAMES:
    aa=np.stack([rgba[f'{p}_{d}_{frame}'] for p in F.LAYERS]);zz=np.stack([depth[f'{p}_{d}_{frame}'] for p in F.LAYERS]);assert np.array_equal(F.compose(aa[:,:,::-1],zz[:,:,::-1]),F.compose(aa,zz)[:,::-1]);mirrors+=1
  results.append(dict(id=row['id'],base=row['base'],rig_checks=a['checks'],sprite_checks=b['checks'],minimum_joint_alpha=b['minimum_joint_alpha'],height_m=a['idle_bounds_m'][1][2]-a['idle_bounds_m'][0][2],triangles_by_layer=a['triangles_by_layer'],interface=interfaces[row['id']],passed=True))
 output=dict(batch=batch,part_count=sum(not r['base'] for r in results),base_count=sum(r['base'] for r in results),rig_checks=sum(len(r['rig_checks']) for r in results),sprite_checks=sum(len(r['sprite_checks']) for r in results),mirror_cases=mirrors,native_png_count=sum(len(list((ROOT/r['source']/'sprites').glob('*.png'))) for r in run['parts']),results=results,passed=True)
 if batch=='child':output['parameterization']='Only1.10m height, .042m waist overlap and scaled anatomical points; original alpha240, error1e-5,14bones,4poses,40ppm,64x96,foot(32,84) unchanged.'
 write(ROOT/f'docs/citizens-full/{batch}/validation-results.json',output);print('BATCH_VERIFIED',json.dumps({k:v for k,v in output.items() if k!='results'}),flush=True)

def options(batch):
 child=batch=='child';base=FULL/'child/child-base-01' if child else PILOT
 if child:parts=catalog('child');heads=[ROOT/e['source'] for e in parts if e['layer']=='hair'];tops=[ROOT/e['source'] for e in parts if e['layer']=='top'];bottoms=[ROOT/e['source'] for e in parts if e['layer']=='bottom']
 else:
  heads=[ROOT/e['source'] for e in json.loads((FULL/'adult-heads/catalog.json').read_text())['parts']];tops=[ROOT/e['source'] for e in catalog('adult-tops')];bottoms=[ROOT/e['source'] for e in catalog('adult-bottoms')] if batch=='adult-bottoms' else [PILOT]
 return base,heads,tops,bottoms

def combinations(batch,cache):
 base,heads,tops,bottoms=options(batch);probes=json.loads((Path(json.loads((cache/'run.json').read_text())['parts'][0]['stage'])/'docs/citizen-adult-pilot/attachment-projections.json').read_text())
 minimum=255;count=0;clearance=1e9;top_limit=max(meta(t)['layer_z_bounds']['top'][1] for t in tops);head_min=min(min(v for v in meta(h).get('layer_z_bounds',{}).get('hair',[meta(h).get('hair_min_z_m',1.44)])) for h in heads);assert head_min>top_limit
 for head in heads:
  for top in tops:
   for bottom in bottoms:
    sources={'body':base,'hair':head,'top':top,'bottom':bottom}
    for probe in probes:
     d=probe['direction'];f=probe['frame']
     for x,y in probe['attachment_px'].values():
      alphas=np.array([load(sources[p])[0][f'{p}_{d}_{f}'][int(y),int(x),3] for p in F.LAYERS],float)/255
      alpha=int(round((1-np.prod(1-alphas))*255));minimum=min(minimum,alpha)
    count+=1
 assert minimum>=240,(batch,minimum)
 result=dict(complete_combinations=count,poses_per_combination=25,logical_directions=8,minimum_joint_alpha=minimum,minimum_head_top_gap_m=head_min-top_limit,waist='all5 model poses, evaluated points inside common12-sided waist envelope',passed=True)
 write(ROOT/f'docs/citizens-full/{batch}/combination-checks.json',result);print('ALL_COMBINATIONS_OK',batch,json.dumps(result),flush=True)

def preview(batch,cache):
 base,heads,tops,bottoms=options(batch);rng=np.random.default_rng({'adult-tops':202611162,'adult-bottoms':202611163,'child':202611164}[batch]);sources=[];samples=[]
 def distribute(seq):return [seq[int(i)] for i in np.resize(rng.permutation(len(seq)),12)]
 hs,ts,bs=distribute(heads),distribute(tops),distribute(bottoms);directions=list(rng.permutation(['S','SE','E','NE','N','NW','W','SW']))+[str(rng.choice(F.DIRS)) for _ in range(4)]
 for i,(h,t,b) in enumerate(zip(hs,ts,bs)):
  ident=f'case-{i+1:02d}';dest=cache/'combinations'/ident;resolved_view(base,dest,{'body':base,'hair':h,'top':t,'bottom':b},False)
  skin=[[225,182,145],[190,143,109],[134,91,68]][int(rng.integers(3))];hair=[[45,35,30],[90,61,40],[149,111,64],[40,46,48]][int(rng.integers(4))]
  colors=[skin,hair,list(rng.integers(60,190,3).astype(int)),list(rng.integers(45,140,3).astype(int))];colors=[[int(v) for v in c] for c in colors]
  sources.append({'id':ident,'stage':str(dest),'direct_root':True});age=8 if batch=='child' else (14 if meta(t).get('style')=='uniform' else 25)
  samples.append({'citizen_id':i+1,'hair':ident,'label':f'H{heads.index(h)+1} T{tops.index(t)+1} B{bottoms.index(b)+1}','parts':{'hair':h.relative_to(ROOT).as_posix(),'top':t.relative_to(ROOT).as_posix(),'bottom':b.relative_to(ROOT).as_posix()},'direction':str(directions[i]),'frame':str(rng.choice(F.FRAMES)),'tints_rgb':colors,'age':age})
 doc=ROOT/f'docs/citizens-full/{batch}';doc.mkdir(parents=True,exist_ok=True)
 write(doc/'preview-samples.json',{'batch':batch,'count':12,'height_m':1.1 if batch=='child' else 1.75,'game_scale':14/4*math.sqrt(2)/40,'samples':samples});write(cache/'preview-run.json',{'batch':batch,'parts':sources})
 print('PREVIEW_INPUTS_READY',batch,len(samples),flush=True)

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--batch',choices=['adult-tops','adult-bottoms','child'],required=True);ap.add_argument('--phase',choices=['prepare','rig','check','combinations','preview'],required=True);ap.add_argument('--cache',type=Path,required=True);args=ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else None)
 {'prepare':prepare,'rig':rig,'check':check,'combinations':combinations,'preview':preview}[args.phase](args.batch,args.cache)
if __name__=='__main__':main()
