"""PNG/depth correspondence, native-size seams and loop-sheet checks."""
from pathlib import Path
import json,numpy as np,hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/citizens/adult-pilot-01';DOC=ROOT/'docs/citizen-adult-pilot';m=json.loads((OUT/'spec.json').read_text());expected={f'{p}_{d}_{f}.png' for p in m['layers'] for d in m['directions'] for f in m['frames']};paths=list((OUT/'sprites').glob('*.png'));checks={'exactly_100_expected_names':len(paths)==100 and {p.name for p in paths}==expected};data=np.load(OUT/'layer-depths.npz');checks['depth_sidecar_shape']=data['depth_mm'].shape==(100,96,64) and data['depth_mm'].dtype==np.uint16;checks['all_depth_names_present']=set(data['names'])=={p[:-4] for p in expected}
for index,name in enumerate(data['names']):
 with Image.open(OUT/'sprites'/(str(name)+'.png')) as im:
  im.load();arr=np.array(im);assert im.size==(64,96) and im.mode=='RGBA';assert np.max(arr[:,:,:3],axis=2)[arr[:,:,3]>0].size>0
  assert np.all(data['depth_mm'][index][arr[:,:,3]>0]<65535) and np.all(data['depth_mm'][index][arr[:,:,3]==0]==65535)
checks['depth_valid_for_every_covered_pixel']=True
frames=np.load(DOC/'composite-check.npz')['rgba'];checks['all_25_composites']=frames.shape==(25,96,64,4)
probes=json.loads((DOC/'attachment-projections.json').read_text());joints=[]
for probe,im in zip(probes,frames):
 alpha={name:int(im[int(y),int(x),3]) for name,(x,y) in probe['attachment_px'].items()};joints.append(dict(direction=probe['direction'],frame=probe['frame'],joint_alpha=alpha))
checks['waist_neck_wrist_no_transparent_gaps']=all(min(row['joint_alpha'].values())>=240 for row in joints)
with Image.open(OUT/'walk-preview.gif') as im:
 checks['four_gif_frames_looping']=im.n_frames==4 and im.info.get('loop')==0
 durations=[]
 for frame in range(4):im.seek(frame);durations.append(im.info['duration'])
 checks['four_equal_200ms_steps']=durations==[200]*4
with Image.open(OUT/'preview-sheet.png') as im:checks['native_sheet_not_upscaled']=im.size==(432,570)
manifest=json.loads((DOC/'render-manifest.json').read_text());checks['all_rendered_views_poses_present']={(r['part'],r['direction'],r['frame']) for r in manifest['images']}=={(p,d,f) for p in m['layers'] for d in m['directions'] for f in m['frames']}
checks={k:bool(v) for k,v in checks.items()};result=dict(checks=checks,passed=all(checks.values()),joint_probes=joints,minimum_joint_alpha=min(min(r['joint_alpha'].values()) for r in joints),sprite_count=100,composite_count=25)
(DOC/'composite-validation.json').write_text(json.dumps(result,indent=2)+'\n');assert all(checks.values());print('RESULT',len(checks),'sprite/depth/composite checks passed; 100 attachment probes min alpha',result['minimum_joint_alpha'])
