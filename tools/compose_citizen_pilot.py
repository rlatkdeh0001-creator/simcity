"""Finalize 100 neutral PNGs, depth sidecar, actual-size tinted sheet and 4-frame GIF.
Depth-aware alpha composition preserves interchangeable unoccluded body parts.
"""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np,json,hashlib
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/citizens/adult-pilot-01';DOC=ROOT/'docs/citizen-adult-pilot';WORK=Path('/tmp/citizen-adult-pilot-render');SPR=OUT/'sprites';SPR.mkdir(exist_ok=True)
LAYERS=['body','hair','top','bottom'];DIRS=['S','SE','E','NE','N'];FRAMES=['idle','1','2','3','4'];W,H=64,96;SCALE=4
TINT=np.array([[225,182,145],[77,54,40],[65,147,166],[63,73,97]],dtype=np.float32)/255
records=[];depths=[];rgba={}
for direction in DIRS:
 for frame in FRAMES:
  for part in LAYERS:
   stem=f'{part}_{direction}_{frame}'
   with Image.open(WORK/(stem+'.png')) as im:
    im=im.convert('RGBA');alpha_hi=np.asarray(im)[:,:,3]>0;im=im.convert('RGBa').resize((W,H),Image.Resampling.LANCZOS).convert('RGBA');im.save(SPR/(stem+'.png'));arr=np.array(im,dtype=np.uint8)
   d=np.load(WORK/(stem+'.npy'));assert d.shape==(H*SCALE,W*SCALE)
   d=np.where(alpha_hi & np.isfinite(d) & (d>0) & (d<60),d,np.inf);d=d.reshape(H,SCALE,W,SCALE).min(axis=(1,3));dm=np.where(np.isfinite(d),np.minimum(d*1000,65534),65535).astype(np.uint16)
   # Lanczos may give a fringe alpha outside the corresponding high-res block.
   # Carry its nearest valid geometric depth, keeping true-transparent pixels at sentinel.
   for _ in range(3):
    invalid=(arr[:,:,3]>0)&(dm==65535)
    if not np.any(invalid):break
    padded=np.pad(dm,1,constant_values=65535);near=np.minimum.reduce([padded[y:y+H,x:x+W] for y in range(3) for x in range(3)]);missing=(dm==65535);dm[missing]=near[missing]
   dm[arr[:,:,3]==0]=65535;assert np.all(dm[arr[:,:,3]>0]<65535),stem
   rgba[stem]=arr;depths.append(dm);bb=Image.fromarray(arr[:,:,3]).getbbox();assert bb and min(bb[:2])>0 and bb[2]<W and bb[3]<H,stem
   chroma=np.max(arr[:,:,:3],axis=2).astype(int)-np.min(arr[:,:,:3],axis=2).astype(int);assert np.max(chroma[arr[:,:,3]>0])<=1,stem
   records.append(dict(file=stem+'.png',alpha_bbox_px=bb,sha256=hashlib.sha256((SPR/(stem+'.png')).read_bytes()).hexdigest()))
DEPTH=np.stack(depths);np.savez_compressed(OUT/'layer-depths.npz',depth_mm=DEPTH,names=np.array([r['file'][:-4] for r in records]))

def compose(direction,frame):
 parts=np.stack([rgba[f'{p}_{direction}_{frame}'] for p in LAYERS]).astype(np.float32)/255
 start=(DIRS.index(direction)*len(FRAMES)+FRAMES.index(frame))*4;dep=DEPTH[start:start+4];order=np.argsort(dep,axis=0)[::-1];rgb=np.zeros((H,W,3),np.float32);alpha=np.zeros((H,W),np.float32)
 for rank in range(4):
  index=order[rank];chosen=np.take_along_axis(parts,index[None,:,:,None],axis=0)[0];a=chosen[:,:,3];color=chosen[:,:,:3]*TINT[index]
  rgb=color*a[:,:,None]+rgb*(1-a[:,:,None]);alpha=a+alpha*(1-a)
 rgb=np.divide(rgb,np.maximum(alpha[:,:,None],1e-8));return np.uint8(np.clip(np.concatenate([rgb,alpha[:,:,None]],axis=2)*255+.5,0,255))

font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',12);sheet=Image.new('RGB',(432,570),'#eceee5');draw=ImageDraw.Draw(sheet);composites={}
for row,frame in enumerate(FRAMES):
 draw.text((5,42+row*106),frame,font=font,fill='#34413e')
 for col,direction in enumerate(DIRS):
  x=64+col*72;y=32+row*106;arr=compose(direction,frame);composites[(direction,frame)]=arr
  if row==0:draw.text((x+22,10),direction,font=font,fill='#34413e')
  draw.rectangle((x,y,x+63,y+95),fill='#fafaf4');sprite=Image.fromarray(arr);sheet.paste(sprite,(x,y),sprite)
sheet.save(OUT/'preview-sheet.png');sheet.resize((1728,2280),Image.Resampling.NEAREST).save(DOC/'preview-sheet-4x.png')
frames=[]
for frame in ['1','2','3','4']:
 strip=Image.new('RGB',(5*72,106),'#eceee5')
 for col,direction in enumerate(DIRS):
  im=Image.fromarray(composites[(direction,frame)]);strip.paste(im,(col*72,0),im)
 frames.append(strip)
frames[0].save(OUT/'walk-preview.gif',save_all=True,append_images=frames[1:],duration=200,loop=0,disposal=2)
frames_large=[im.resize((1440,424),Image.Resampling.NEAREST) for im in frames];frames_large[0].save(DOC/'walk-preview-4x.gif',save_all=True,append_images=frames_large[1:],duration=200,loop=0,disposal=2)
# Native composed RGBA is stored in one sidecar for verification, not 25 extra sprite PNGs.
np.savez_compressed(DOC/'composite-check.npz',rgba=np.stack([composites[(d,f)] for d in DIRS for f in FRAMES]))
render_info=json.loads((DOC/'render-manifest.json').read_text())['images'][0]
meta=json.loads((OUT/'spec.json').read_text());meta.update(sprite_directory='sprites',sprite_count=100,pixels_per_meter=round(render_info['pixels_per_metre'],5),canvas_px=[W,H],foot_anchor_px=[round(v,3) for v in render_info['foot_anchor_px']],supersampling=4,alpha_mode='straight',sprites_are_unoccluded=True,depth_sidecar='layer-depths.npz',depth_units='millimetres of camera Z pass; smaller is nearer; 65535 means transparent',compositing='tint each grayscale RGB, sort four layers per pixel by depth, alpha-over back to front',mirror_missing_directions={'SW':'SE','W':'E','NW':'NE'},mirror_contract='flip both RGBA and depth horizontally around continuous canvas x=32',tint_example_rgb={p:list(map(int,np.round(c*255))) for p,c in zip(LAYERS,TINT)})
(OUT/'spec.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n');(DOC/'sprite-validation.json').write_text(json.dumps(dict(images=records,count=len(records),same_canvas=[W,H],grayscale=True,no_clipping=True,depth_covers_every_alpha_pixel=True,passed=True),indent=2)+'\n')
print('100 grayscale PNGs, depth sidecar, native tinted sheet and 4-frame walk GIF finalized.')
