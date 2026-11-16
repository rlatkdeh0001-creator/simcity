"""Childv2 verification/preview adapter; original adult andv1 files are untouched."""
from pathlib import Path
import argparse,json,sys
import numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import citizen_remaining_pipeline as Q
FULL=Q.FULL;BASE=FULL/'child-v2/child-base-01-v2';BATCH='child-v2'

def options(_):
 rows=Q.catalog(BATCH)
 return BASE,*[[ROOT/e['source'] for e in rows if e['layer']==p] for p in ['hair','top','bottom']]
Q.options=options

def prepare(cache):
 Q.prepare(BATCH,cache)
 for row in json.loads((cache/'run.json').read_text())['parts']:
  p=Path(row['stage'])/'tools/verify_citizen_adult_pilot.py';t=p.read_text(encoding='utf-8');assert 'abs(overlap-.042)' in t;t=t.replace('abs(overlap-.042)','abs(overlap-.0392)').replace('waist_child_4p2cm','waist_child_3p92cm');p.write_text(t,encoding='utf-8')
 print('V2_PREPARED',flush=True)

def preview(cache):
 base,heads,tops,bottoms=options(BATCH);rng=np.random.default_rng(202611166);rows=[];samples=[]
 def distribute(seq):return [seq[int(i)] for i in np.resize(rng.permutation(len(seq)),12)]
 hs,ts,bs=distribute(heads),distribute(tops),distribute(bottoms);directions=list(rng.permutation(['S','SE','E','NE','N','NW','W','SW']))+['S','SE','E','NE']
 combos=[(base,h,t,b,1.1,f'CHILD H{heads.index(h)+1} T{tops.index(t)+1} B{bottoms.index(b)+1}') for h,t,b in zip(hs,ts,bs)]
 adultheads=json.loads((FULL/'adult-heads/catalog.json').read_text())['parts'];adulttops=Q.catalog('adult-tops');adultbottom=ROOT/Q.catalog('adult-bottoms')[0]['source']
 ah=[ROOT/adultheads[0]['source'],ROOT/next(h['source'] for h in adultheads if h['id']=='adult-hair-f02-bob')]
 for i in range(2):combos.append((Q.PILOT,ah[i],ROOT/adulttops[i*2]['source'],adultbottom,1.75,f'ADULT {i+1} /1.75m'))
 for i,(body,h,t,b,height,label) in enumerate(combos):
  key=f'case-{i+1:02d}';dest=cache/'comparison'/key;Q.resolved_view(body,dest,{'body':body,'hair':h,'top':t,'bottom':b},False)
  colors=[[225,182,145],[65,45,33],[int(v) for v in rng.integers(65,175,3)],[int(v) for v in rng.integers(45,130,3)]]
  rows.append(dict(id=key,stage=str(dest),direct_root=True));samples.append(dict(citizen_id=i+1,hair=key,label=label,direction=directions[i] if i<12 else 'S',frame='idle' if i>=12 else str(rng.choice(Q.F.FRAMES)),tints_rgb=colors,height_m=height,parts={p:f.relative_to(ROOT).as_posix() for p,f in [('body',body),('hair',h),('top',t),('bottom',b)]}))
 doc=ROOT/'docs/citizens-full/child-v2';Q.write(doc/'preview-samples.json',dict(batch=BATCH,count=14,child_count=12,adult_count=2,height_m=1.1,game_scale=14/4*np.sqrt(2)/40,samples=samples));Q.write(cache/'preview-run.json',dict(batch=BATCH,parts=rows));print('V2_COMPARISON_READY children=12 adults=2',flush=True)

def main():
 p=argparse.ArgumentParser();p.add_argument('--phase',choices=['prepare','rig','check','combinations','preview'],required=True);p.add_argument('--cache',type=Path,required=True);a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else None)
 if a.phase=='prepare':prepare(a.cache)
 elif a.phase=='preview':preview(a.cache)
 elif a.phase=='rig':Q.rig(BATCH,a.cache)
 elif a.phase=='combinations':Q.combinations(BATCH,a.cache)
 else:
  Q.check(BATCH,a.cache);path=ROOT/'docs/citizens-full/child-v2/validation-results.json';m=json.loads(path.read_text());m['parameterization']='Only nominal1.10m height, actual .0392m waist overlap and anatomical points adapted. Alpha240/error1e-5/14bones/poses/loop/camera unchanged.';Q.write(path,m)
if __name__=='__main__':main()
