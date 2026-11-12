extends RefCounted
## Painter order for disjoint convex lot footprints, looking along world (-1,-1).
## Cache indices, not model records: replacing a city must never reuse old dictionaries.
const EPS:=0.00001
var signature: Array=[]
var indices: Array[int]=[]
func sorted(records: Array,polygons: Array) -> Array:
 var current: Array=[]
 for i in range(records.size()):current.append([records[i].get("id",i),polygons[i].duplicate()])
 if current!=signature:
  signature=current
  indices=ordered_indices(polygons,records)
 var result: Array=[]
 for i in indices:result.append(records[i])
 return result
static func span(polygon: PackedVector2Array) -> Vector2:
 var result:=Vector2(INF,-INF)
 for p in polygon:result.x=minf(result.x,p.x-p.y);result.y=maxf(result.y,p.x-p.y)
 return result
static func ray_interval(polygon: PackedVector2Array,x: float) -> Vector2:
 var result:=Vector2(INF,-INF)
 for i in range(polygon.size()):
  var a: Vector2=polygon[i];var b: Vector2=polygon[(i+1)%polygon.size()]
  var ax: float=a.x-a.y;var bx: float=b.x-b.y
  if absf(bx-ax)<EPS:continue
  var t: float=(x-ax)/(bx-ax)
  if t < -EPS or t > 1+EPS:continue
  var point:=a.lerp(b,clampf(t,0,1));var depth: float=point.x+point.y
  result.x=minf(result.x,depth);result.y=maxf(result.y,depth)
 return result
static func relation(a: PackedVector2Array,b: PackedVector2Array,sa: Vector2,sb: Vector2) -> int:
 var left:=maxf(sa.x,sb.x);var right:=minf(sa.y,sb.y)
 if right-left<EPS:return 0
 # Height moves a pixel vertically, not horizontally. On a shared isometric
 # horizontal ray, the closer ground footprint must paint after the farther lot.
 var da:=ray_interval(a,(left+right)/2);var db:=ray_interval(b,(left+right)/2)
 if not da.is_finite() or not db.is_finite():return 0
 if da.y<=db.x+EPS:return -1
 if db.y<=da.x+EPS:return 1
 return 0 # Overlapping/invalid footprints retain deterministic fallback ordering.
static func ordered_indices(polygons: Array,records: Array) -> Array[int]:
 var edges: Array=[];var degrees: Array[int]=[];var spans: Array[Vector2]=[];var depths: Array[float]=[]
 for polygon: PackedVector2Array in polygons:
  edges.append([]);degrees.append(0);spans.append(span(polygon));var depth: float=-INF
  for p in polygon:depth=maxf(depth,p.x+p.y)
  depths.append(depth)
 for i in range(polygons.size()):
  for j in range(i+1,polygons.size()):
   var direction:=relation(polygons[i],polygons[j],spans[i],spans[j])
   if direction==0:continue
   var back:=i if direction<0 else j;var front:=j if direction<0 else i
   edges[back].append(front);degrees[front]+=1
 var done: Dictionary={};var result: Array[int]=[]
 while result.size()<polygons.size():
  var best: int=-1
  for pass_index in range(2):
   for i in range(polygons.size()):
    if done.has(i) or (pass_index==0 and degrees[i]!=0):continue
    if best<0 or depths[i]<depths[best] or (depths[i]==depths[best] and int(records[i].get("id",i))<int(records[best].get("id",best))):best=i
   if best>=0:break
  done[best]=true;result.append(best)
  for front: int in edges[best]:degrees[front]-=1
 return result
