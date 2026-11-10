from pathlib import Path
import json,shutil
root=Path(__file__).resolve().parents[1];out=root/'cities_do/assets/all_buildings';entries=[]
cat=json.loads((root/'cities_do/assets/buildings/catalog.json').read_text())['buildings']
# Existing ten residential definitions carry their correct established pivots.
for a in cat:
 if a['zone']!='residential':continue
 src=root/'cities_do'/a['texture'].replace('res://','')
 dest=out/(a['id']+'.png');shutil.copyfile(src,dest)
 entries.append(dict(id=a['id'],name=a['name'],group='residential',footprint=a['footprint'],anchor=a['anchor_px'],image_size=a['image_size'],width_px=a['lot_width_px'],texture='res://assets/all_buildings/'+dest.name,height=a['storeys']*3,source=a['source']))
groups=['commercial','industrial','power','water','waste','fire','police','prison','medical','education']
for group in groups:
 for p in sorted((root/'assets'/f'{group}-study').glob('*/metadata.json')):
  m=json.loads(p.read_text());ident=m['id'];fp=m.get('footprint_cells')
  if group=='power' and ident=='power-hydro':fp=[m['presentation_lot_meters'][0]/4,m['presentation_lot_meters'][1]/4]
  src=p.parent/'building.png'
  if not src.exists():src=p.parent/('mart.png' if 'mart' in ident else 'auto.png')
  assert src.exists(),src
  dest=out/(ident+'.png');shutil.copyfile(src,dest)
  corners=m['lot_corners_px'];width=max(v[0] for v in corners)-min(v[0] for v in corners)
  entries.append(dict(id=ident,name=m['name'],group=group,footprint=fp,anchor=m['anchor_px'],image_size=m['image_size'],width_px=width,texture='res://assets/all_buildings/'+dest.name,height=m['vertex_bounds_m'][1][2],source=str(p.relative_to(root))))
assert len(entries)==54 and len({e['id'] for e in entries})==54,len(entries)
# Put taller buildings at the back so short neighbours do not hide them.
water_ids={'water-intake','water-sewage-outfall','power-hydro'}
normal=sorted([e for e in entries if e['id'] not in water_ids],key=lambda e:-e['height'])
placements=[]
for i,e in enumerate(normal):
 col=i%8;row=i//8;w,d=e['footprint']
 # Align bottom edge to the local street; keep larger footprints inside the 8x8 block.
 placements.append(dict(asset_id=e['id'],x=5+10*col+(8-w)/2,y=5+10*row+8-d))
for col,ident in zip(range(3,8),['small-2x2-a','small-2x2-b','small-4x4-a','small-4x4-b','small-2x2-mart-01']):
 e=next(e for e in entries if e['id']==ident);w,d=e['footprint'];placements.append(dict(asset_id=ident,x=5+10*col+(8-w)/2,y=73-d))
placements.extend([dict(asset_id='water-intake',x=5,y=80),dict(asset_id='water-sewage-outfall',x=15,y=80),dict(asset_id='power-hydro',x=84,y=60)])
roads=[]
for x in range(4,85,10):roads.append(dict(points=[[x,4],[x,78]],width=2,lanes=2))
for y in range(4,75,10):roads.append(dict(points=[[4,y],[84,y]],width=2,lanes=2))
roads.append(dict(points=[[4,78],[84,78]],width=4,lanes=4))
for p in placements:
 e=next(e for e in entries if e['id']==p['asset_id']);w,d=e['footprint'];assert p['x']>=0 and p['y']>=0 and p['x']+w<=100 and p['y']+d<=100
# Authored scenario, independent of growth eligibility and pending simulation rules.
data=dict(map_size=[100,100],cell_meters=4,entries=entries,placements=placements,roads=roads,unique_types=54,building_count=len(placements),water_polygons=[[[0,83.6],[100,83.6],[100,100],[0,100]],[[85.5,0],[97.5,0],[97.5,100],[85.5,100]]])
(root/'cities_do/maps/all_buildings_100.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print('Prepared',len(entries),'types,',len(placements),'placements')
