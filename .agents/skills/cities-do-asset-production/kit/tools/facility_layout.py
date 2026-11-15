"""Original deterministic parking layout, metres. Shared 8m module on a 2-cell grid."""
from collections import deque
SPECS=[
 {'id':'park-pocket-2x2','name':'쉼터 공원','kind':'park','width':2,'depth':2,'storeys':0,'style':'pocket'},
 {'id':'park-garden-2x2','name':'꽃정원 공원','kind':'park','width':2,'depth':2,'storeys':0,'style':'garden'},
 {'id':'park-plaza-4x4','name':'분수 광장 공원','kind':'park','width':4,'depth':4,'storeys':0,'style':'plaza'},
 {'id':'park-play-4x4','name':'놀이터 공원','kind':'park','width':4,'depth':4,'storeys':0,'style':'play'},
 {'id':'parking-small-2x4','name':'소형 주차장','kind':'surface_parking','width':2,'depth':4,'storeys':0},
 {'id':'parking-medium-4x4','name':'중형 주차장','kind':'surface_parking','width':4,'depth':4,'storeys':0},
 {'id':'parking-large-4x8','name':'대형 주차장','kind':'surface_parking','width':4,'depth':8,'storeys':0},
 {'id':'parking-tower-4x4-4f','name':'4층 주차타워','kind':'parking_tower','width':4,'depth':4,'storeys':4},
]

def parking_layout(blocks):
 blocks=set(map(tuple,blocks));boxes=[];capacity=2*len(blocks);edges=[]
 def box(name,pos,size,mat):boxes.append({'name':name,'pos':list(pos),'size':list(size),'mat':mat})
 for x,z in sorted(blocks):
  ox=x*8;oz=z*8
  box('Asphalt',(ox+4,.08,oz+4),(8,.16,8),'asphalt')
  for y in [3.03,5.5,7.94]:box('BayLine',(ox+2.5,.17,oz+y),(5,.025,.055),'paint')
  box('BayBack',(ox+.12,.17,oz+5.5),(.055,.025,4.94),'paint')
  box('AisleDash',(ox+6.5,.17,oz+5.3),(.07,.025,1.25),'paint')
  for dx,dz,side in [(0,-1,'north'),(1,0,'east'),(0,1,'south'),(-1,0,'west')]:
   if (x+dx,z+dz) in blocks:continue
   edges.append([x,z,side])
   if side in ['north','south']:
    # Common 3m portal at the longitudinal aisle. Every module can connect.
    box('OuterCurb',(ox+2.5,.25,oz+(.10 if side=='north' else 7.9)),(5,.25,.18),'curb')
   else:
    # Leave cross-aisle portals at every exterior horizontal edge.
    box('OuterCurb',(ox+(.10 if side=='west' else 7.9),.25,oz+5.5),(.18,.25,5),'curb')
 return {'blocks':[list(b) for b in sorted(blocks)],'capacity':capacity,'boundary':edges,'boxes':boxes}

def components(blocks):
 pending=set(map(tuple,blocks));out=[]
 while pending:
  seed=min(pending);pending.remove(seed);group={seed};queue=deque([seed])
  while queue:
   x,z=queue.popleft()
   for p in [(x-1,z),(x+1,z),(x,z-1),(x,z+1)]:
    if p in pending:pending.remove(p);group.add(p);queue.append(p)
  out.append(parking_layout(group))
 return out
