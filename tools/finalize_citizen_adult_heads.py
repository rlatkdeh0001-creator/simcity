"""Finalize/verify a modular citizen batch without modifying pilot originals or validators.
Run with Blender's Python3.11 + approved D: Pillow path. Original validators execute
unchanged in a temporary resolved100-sprite view; deliver only25 new images per part.
"""
from pathlib import Path
import argparse,json,math,os,runpy,shutil
from collections import Counter
import numpy as np
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1];PILOT=ROOT/'assets/citizens/adult-pilot-01';BASE_DOC=ROOT/'docs/citizen-adult-pilot'
ASSET_ROOT=Path(os.environ.get('CITIZEN_ASSET_ROOT',str(ROOT))).resolve()
PART_ROOT=ASSET_ROOT/'assets/citizens/full-set/adult-heads';DOC=ASSET_ROOT/'docs/citizens-full/adult-heads'
LAYERS=['body','hair','top','bottom'];DIRS=['S','SE','E','NE','N'];FRAMES=['idle','1','2','3','4'];W,H=64,96;SCALE=4
MIRRORS={'SW':'SE','W':'E','NW':'NE'}
TINT=np.array([[225,182,145],[77,54,40],[65,147,166],[63,73,97]],dtype=np.float32)/255


def compose(parts,dep,tints=TINT):
 parts=parts.astype(np.float32)/255;order=np.argsort(dep,axis=0)[::-1]
 rgb=np.zeros((H,W,3),np.float32);alpha=np.zeros((H,W),np.float32)
 for rank in range(4):
  index=order[rank];chosen=np.take_along_axis(parts,index[None,:,:,None],axis=0)[0];a=chosen[:,:,3];color=chosen[:,:,:3]*tints[index]
  rgb=color*a[:,:,None]+rgb*(1-a[:,:,None]);alpha=a+alpha*(1-a)
 rgb=np.divide(rgb,np.maximum(alpha[:,:,None],1e-8))
 return np.uint8(np.clip(np.concatenate([rgb,alpha[:,:,None]],axis=2)*255+.5,0,255))


def finalize_hair(folder,work):
 spr=folder/'sprites';sidecar=folder/'layer-depths.npz'
 if sidecar.exists():
  assert len(list(spr.glob('*.png')))==25
  return
 spr.mkdir(exist_ok=True);names=[];depths=[]
 for direction in DIRS:
  for frame in FRAMES:
   stem=f'hair_{direction}_{frame}'
   with Image.open(work/(stem+'.png')) as im:
    im=im.convert('RGBA');alpha_hi=np.asarray(im)[:,:,3]>0
    im=im.convert('RGBa').resize((W,H),Image.Resampling.LANCZOS).convert('RGBA');arr=np.array(im,dtype=np.uint8)
   d=np.load(work/(stem+'.npy'));assert d.shape==(H*SCALE,W*SCALE)
   d=np.where(alpha_hi & np.isfinite(d) & (d>0) & (d<60),d,np.inf)
   d=d.reshape(H,SCALE,W,SCALE).min(axis=(1,3));dm=np.where(np.isfinite(d),np.minimum(d*1000,65534),65535).astype(np.uint16)
   for _ in range(3):
    invalid=(arr[:,:,3]>0)&(dm==65535)
    if not np.any(invalid):break
    padded=np.pad(dm,1,constant_values=65535);near=np.minimum.reduce([padded[y:y+H,x:x+W] for y in range(3) for x in range(3)])
    missing=dm==65535;dm[missing]=near[missing]
   dm[arr[:,:,3]==0]=65535
   assert np.all(dm[arr[:,:,3]>0]<65535),stem
   bb=Image.fromarray(arr[:,:,3]).getbbox();assert bb and min(bb[:2])>0 and bb[2]<W and bb[3]<H,stem
   chroma=arr[:,:,:3].max(axis=2).astype(int)-arr[:,:,:3].min(axis=2).astype(int);assert chroma[arr[:,:,3]>0].max()<=1,stem
   target=spr/(stem+'.png')
   if target.exists():raise RuntimeError('Refusing to overwrite finalized image: '+str(target))
   Image.fromarray(arr).save(target);names.append(stem);depths.append(dm)
 np.savez_compressed(sidecar,depth_mm=np.stack(depths),names=np.array(names))
 print('PART_FINALIZED',folder.name,len(names),flush=True)


def arrays(folder):
 base=np.load(PILOT/'layer-depths.npz');part=np.load(folder/'layer-depths.npz')
 deps={str(n):v for n,v in zip(base['names'],base['depth_mm'])};deps.update({str(n):v for n,v in zip(part['names'],part['depth_mm'])})
 rgba={}
 for direction in DIRS:
  for frame in FRAMES:
   for layer in LAYERS:
    name=f'{layer}_{direction}_{frame}';path=(folder if layer=='hair' else PILOT)/'sprites'/(name+'.png')
    with Image.open(path) as im:rgba[name]=np.array(im.convert('RGBA'))
 return rgba,deps


def make_composites(rgba,deps):
 return {(d,f):compose(np.stack([rgba[f'{p}_{d}_{f}'] for p in LAYERS]),np.stack([deps[f'{p}_{d}_{f}'] for p in LAYERS])) for d in DIRS for f in FRAMES}


def validation_stage(folder,stage):
 out=stage/'assets/citizens/adult-pilot-01';doc=stage/'docs/citizen-adult-pilot';tools=stage/'tools'
 for p in [out/'sprites',doc,tools]:p.mkdir(parents=True,exist_ok=True)
 shutil.copy2(folder/'citizen.blend',out/'citizen.blend')
 meta=json.loads((folder/'spec.json').read_text(encoding='utf-8'));meta.update(sprite_count=100,part_sprite_count=25,resolved_view=True)
 (out/'spec.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 rgba,deps=arrays(folder);base_depth=np.load(PILOT/'layer-depths.npz');names=[str(n) for n in base_depth['names']]
 for name in names:shutil.copy2((folder if name.startswith('hair_') else PILOT)/'sprites'/(name+'.png'),out/'sprites'/(name+'.png'))
 np.savez_compressed(out/'layer-depths.npz',depth_mm=np.stack([deps[n] for n in names]),names=np.array(names))
 original=json.loads((BASE_DOC/'render-manifest.json').read_text(encoding='utf-8'))
 new=json.loads((folder/'render-manifest.json').read_text(encoding='utf-8'));replacement={r['stem']:r for r in new['images']}
 records=[replacement.get(r['stem'],r) for r in original['images']];assert len(records)==100
 (doc/'render-manifest.json').write_text(json.dumps({'supersampling':4,'images':records,'inherited_pilot_records':75,'fresh_variant_records':25},indent=2)+'\n',encoding='utf-8')
 shutil.copy2(BASE_DOC/'attachment-projections.json',doc/'attachment-projections.json')
 for name in ['citizen_pilot_common.py','audit_citizen_projection.py','verify_citizen_adult_pilot.py','verify_citizen_sprites.py']:shutil.copy2(ROOT/'tools'/name,tools/name)
 images=make_composites(rgba,deps);np.savez_compressed(doc/'composite-check.npz',rgba=np.stack([images[(d,f)] for d in DIRS for f in FRAMES]))
 font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',12);sheet=Image.new('RGB',(432,570),'#eceee5');draw=ImageDraw.Draw(sheet)
 for row,f in enumerate(FRAMES):
  draw.text((5,42+row*106),f,font=font,fill='#34413e')
  for col,d in enumerate(DIRS):
   x=64+col*72;y=32+row*106
   if row==0:draw.text((x+22,10),d,font=font,fill='#34413e')
   draw.rectangle((x,y,x+63,y+95),fill='#fafaf4');im=Image.fromarray(images[(d,f)]);sheet.paste(im,(x,y),im)
 sheet.save(out/'preview-sheet.png');gif=[]
 for f in ['1','2','3','4']:
  strip=Image.new('RGB',(360,106),'#eceee5')
  for col,d in enumerate(DIRS):im=Image.fromarray(images[(d,f)]);strip.paste(im,(col*72,0),im)
  gif.append(strip)
 gif[0].save(out/'walk-preview.gif',save_all=True,append_images=gif[1:],duration=200,loop=0,disposal=2,optimize=False)
 return {'id':folder.name,'source':folder.relative_to(ASSET_ROOT).as_posix(),'stage':str(stage)}


def batch_preview(parts):
 DOC.mkdir(parents=True,exist_ok=True);rng=np.random.default_rng(20261116)
 selected=list(rng.permutation(len(parts)))+[int(rng.integers(len(parts))) for _ in range(2)]
 directions=list(rng.permutation(['S','SE','E','NE','N','SW','W','NW']))+[str(rng.choice(['S','SE','E','NE','N','SW','W','NW'])) for _ in range(4)]
 skin=np.array([[225,182,145],[190,143,109],[134,91,68]],float);hair=np.array([[45,35,30],[90,61,40],[149,111,64],[40,46,48]],float)
 clothes=np.array([[63,136,157],[150,85,75],[99,127,84],[193,163,96],[92,101,151],[137,103,143]],float)
 sheet=Image.new('RGB',(1100,610),'#eceee5');draw=ImageDraw.Draw(sheet);font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',14);small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',11)
 draw.text((16,10),'ADULT HEADS 10 / 12 randomized combinations / unchanged pilot body + clothes',font=font,fill='#263c3e')
 game_scale=14/4*math.sqrt(2)/40
 draw.text((16,39),'Game scale @ map_zoom 1.0: demo/citizens-100 formula (14/4 * sqrt(2) /40). Native source + head zoom below.',font=small,fill='#526360')
 draw.line((16,105,1084,105),fill='#a8b6ac',width=1);samples=[]
 for i,index in enumerate(selected):
  folder=ASSET_ROOT/parts[index]['source'];rgba,deps=arrays(folder);direction=str(directions[i]);frame=str(rng.choice(FRAMES));physical=MIRRORS.get(direction,direction)
  data=np.stack([rgba[f'{p}_{physical}_{frame}'] for p in LAYERS]);depth=np.stack([deps[f'{p}_{physical}_{frame}'] for p in LAYERS])
  if direction in MIRRORS:data=data[:,:,::-1,:];depth=depth[:,:,::-1]
  colors=np.stack([skin[int(rng.integers(len(skin)))],hair[int(rng.integers(len(hair)))],clothes[int(rng.integers(len(clothes)))],clothes[int(rng.integers(len(clothes)))]])/255
  arr=compose(data,depth,colors);im=Image.fromarray(arr)
  tiny=im.convert('RGBa').resize((max(1,round(W*game_scale)),max(1,round(H*game_scale))),Image.Resampling.NEAREST).convert('RGBA')
  gx=26+i*88;sheet.paste(tiny,(gx,105-round(84*game_scale)),tiny);draw.text((gx-7,113),str(i+1),font=small,fill='#526360')
  x=16+(i%6)*180;y=155+(i//6)*205
  draw.rectangle((x,y,x+170,y+190),fill='#fafaf4',outline='#d2d9ce')
  short=folder.name.removeprefix('adult-hair-');draw.text((x+7,y+6),short,font=small,fill='#263c3e')
  sheet.paste(im,(x+7,y+29),im)
  zoom=im.crop((20,18,44,42)).resize((72,72),Image.Resampling.NEAREST);sheet.paste(zoom,(x+88,y+38),zoom)
  draw.text((x+7,y+134),direction+' / '+frame,font=small,fill='#526360');draw.text((x+7,y+153),'native 1x       head 3x',font=small,fill='#526360')
  samples.append({'citizen_id':i+1,'hair':folder.name,'direction':direction,'frame':frame,'tints_rgb':np.rint(colors*255).astype(int).tolist()})
 draw.text((16,577),'64x96 RGBA / 40px per metre / foot anchor(32,84) / 5 stored directions +3 mirrored RGBA and depth',font=small,fill='#526360')
 path=DOC/'adult-heads-combinations.png';sheet.save(path)
 ref=json.loads((ROOT/'tools/citizen_demo_reference/reference.json').read_text(encoding='utf-8'))['source_commit']
 (DOC/'preview-samples.json').write_text(json.dumps({'seed':20261116,'count':len(samples),'game_scale':game_scale,'game_scale_ref':ref,'samples':samples},indent=2)+'\n',encoding='utf-8')
 return str(path)


def prepare(cache):
 catalog=json.loads((PART_ROOT/'catalog.json').read_text(encoding='utf-8'));assert len(catalog['parts'])==10
 assert Counter(e['gender'] for e in catalog['parts'])==Counter(male=5,female=5)
 rows=[]
 for entry in catalog['parts']:
  folder=ASSET_ROOT/entry['source'];finalize_hair(folder,cache/folder.name);rows.append(validation_stage(folder,cache/'validation'/folder.name))
 (cache/'run.json').write_text(json.dumps({'parts':rows},indent=2)+'\n',encoding='utf-8');print('VALIDATION_STAGES_READY',len(rows),flush=True)


def verify(cache):
 run=json.loads((cache/'run.json').read_text(encoding='utf-8'));results=[];mirror_cases=0
 for entry in run['parts']:
  stage=Path(entry['stage']);runpy.run_path(str(stage/'tools/verify_citizen_sprites.py'),run_name='__main__')
  doc=stage/'docs/citizen-adult-pilot';rig=json.loads((doc/'rig-validation.json').read_text());sprite=json.loads((doc/'composite-validation.json').read_text());assert rig['passed'] and sprite['passed']
  folder=ASSET_ROOT/entry['source'];rgba,deps=arrays(folder)
  for physical in MIRRORS.values():
   for frame in FRAMES:
    data=np.stack([rgba[f'{p}_{physical}_{frame}'] for p in LAYERS]);depth=np.stack([deps[f'{p}_{physical}_{frame}'] for p in LAYERS])
    assert np.array_equal(compose(data[:,:,::-1,:],depth[:,:,::-1]),compose(data,depth)[:,::-1,:]);mirror_cases+=1
  spec=json.loads((folder/'spec.json').read_text(encoding='utf-8'))
  results.append({'id':entry['id'],'rig_checks':rig['checks'],'sprite_checks':sprite['checks'],'minimum_joint_alpha':sprite['minimum_joint_alpha'],'triangles_by_layer':rig['triangles_by_layer'],'height_m':rig['idle_bounds_m'][1][2]-rig['idle_bounds_m'][0][2],'passed':True})
 DOC.mkdir(parents=True,exist_ok=True);preview=batch_preview(run['parts'])
 output={'baseline':'957d806','variant_count':len(results),'native_png_count':sum(len(list((ASSET_ROOT/e['source']/'sprites').glob('*.png'))) for e in run['parts']),'rig_check_count':sum(len(e['rig_checks']) for e in results),'sprite_check_count':sum(len(e['sprite_checks']) for e in results),'mirror_cases':mirror_cases,'parts':results,'passed':all(e['passed'] for e in results),'preview':preview,'validation_method':'unchanged original audit/rig/sprite validators executed in temporary resolved100-sprite views;75 pilot PNGs+depth reused,25 new hair sprites+depth per variant'}
 (DOC/'validation-results.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print('ADULT_HEADS_VERIFIED',json.dumps({k:output[k] for k in ['variant_count','native_png_count','rig_check_count','sprite_check_count','mirror_cases','passed']}),flush=True)
 print('COMBINATION_SHEET',preview,flush=True)


def main():
 ap=argparse.ArgumentParser();ap.add_argument('phase',choices=['prepare','verify']);ap.add_argument('--cache',type=Path,required=True);args=ap.parse_args();(prepare if args.phase=='prepare' else verify)(args.cache)
if __name__=='__main__':main()
