extends RefCounted
## Derived at-grade paint only. Follow the actual shared section chain, not nearby positions.
const Junctions=preload("res://core/road_junctions.gd")
const Geometry=preload("res://core/road_geometry.gd")
const Profile=preload("res://core/road_profile.gd")
const Height=preload("res://core/road_height.gd")
const Parcels=preload("res://core/road_parcels.gd")

static func close_approaches(topology:Dictionary,roads:Array) -> Array[Dictionary]:
 var result:Array[Dictionary]=[]
 if topology.junctions.size()<2:return result
 var links:={}
 for section in topology.sections:
  if section.start_node==section.end_node:continue
  var a:Dictionary=topology.nodes[section.start_node];var b:Dictionary=topology.nodes[section.end_node]
  if absf(a.height_m)>Height.EPS or absf(b.height_m)>Height.EPS:continue
  var road:Dictionary=roads[section.road]
  if Height.off_ground(road):
   var flat:=true
   for point:Vector2 in section.points:
    if absf(Height.height_at(road,point))>Height.EPS:flat=false;break
   if not flat:continue
  if not links.has(a.key):links[a.key]=[]
  if not links.has(b.key):links[b.key]=[]
  links[a.key].append(section);links[b.key].append(section)
 for junction in topology.junctions:
  for section in links.get(junction.key,[]):
   var span:=_shared_span(topology,links,junction.key,section)
   if span.is_empty() or junction.key>=span.end:continue # Process once with stable stripe orientation.
   var other:Dictionary=topology.junctions[topology.nodes[span.end].junction]
   var points:PackedVector2Array=span.points
   var a:=_facing_arm(junction,(points[1]-points[0]).normalized())
   var b:=_facing_arm(other,(points[-2]-points[-1]).normalized())
   if a.is_empty() or b.is_empty():continue
   var edges:=Profile.asphalt_edges(b)
   if not Profile.asphalt_edges(a).is_equal_approx(Vector2(-edges.y,-edges.x)):continue
   var length:=Junctions.length_of(points)
   var d0:=Junctions.crosswalk_distance(junction,a);var d1:=Junctions.crosswalk_distance(other,b)
   if absf(d0+d1-length)>=2*Junctions.CROSSWALK_HALF_LENGTH-Junctions.EPS:continue
   var first:=_extend_arm(a,points,length)
   var reversed:=points.duplicate();reversed.reverse()
   var last:=_extend_arm(b,reversed,length)
   var band0:=Junctions.crosswalk_band(Junctions.crosswalk_shapes(first,d0))
   var band1:=Junctions.crosswalk_band(Junctions.crosswalk_shapes(last,d1))
   if band0.is_empty() or band1.is_empty() or not _overlap(band0,band1):continue
   if not Junctions.marker_slot_clear(junction,a,band0) or not Junctions.marker_slot_clear(other,b,band1):continue
   var zebra:=Junctions.crosswalk_shapes(first,length*.5)
   # Never put shared paint inside either crossed road, including acute branches.
   var blocked:Array[PackedVector2Array]=[]
   for entry in [[junction,a],[other,b]]:
    for arm in entry[0].arms:
     if arm!=entry[1]:blocked.append_array(Junctions.arm_asphalt(arm))
   zebra=Geometry.outside_regions(zebra,blocked)
   if zebra.is_empty():continue
   var stops:Array[PackedVector2Array]=[]
   var edge_offset:=Junctions.CROSSWALK_HALF_LENGTH+Junctions.CROSSWALK_EDGE_GAP
   for entry in [[junction,a,first,d1],[other,b,last,d0]]:
    var distance:=Junctions.stop_line_distance(entry[0],entry[1])
    # A stop must be on the incoming side of the shared crossing and entirely
    # before the far junction edge. No stop bar if the short slot cannot fit it.
    if distance-Junctions.STOP_LINE_HALF_LENGTH<length*.5+Junctions.CROSSWALK_HALF_LENGTH:continue
    if distance+Junctions.STOP_LINE_HALF_LENGTH>length-float(entry[3])+edge_offset:continue
    var stop:=Junctions.stop_line_shape(entry[2],distance)
    if stop.is_empty() or blocked.any(func(p):return _overlap(stop,p)) or zebra.any(func(p):return _overlap(stop,p)):continue
    stops.append(stop)
   var region:=Geometry2D.offset_polyline(points,float(a.width)*.5,Geometry2D.JOIN_ROUND,Geometry2D.END_BUTT)
   result.append({"a":junction.key,"arm_a":a,"b":other.key,"arm_b":b,"zebra":zebra,"stops":stops,"regions":region})
 return result

static func _shared_span(topology:Dictionary,links:Dictionary,start:String,section:Dictionary) -> Dictionary:
 var points:=PackedVector2Array()
 var key:=start
 var visited:={start:true}
 while true:
  var path:PackedVector2Array=section.points
  if key==section.start_node:key=section.end_node
  else:path=path.duplicate();path.reverse();key=section.start_node
  if visited.has(key):return {}
  visited[key]=true
  if not points.is_empty():path=path.slice(1)
  points.append_array(path)
  var node:Dictionary=topology.nodes[key]
  if node.junction>=0:return {"end":key,"points":points}
  # Only continue through an uncontrolled straight authored seam.
  if node.join>=0 or node.arms.size()!=2 or links[key].size()!=2:return {}
  var edges:Array=links[key]
  section=edges[1] if edges[0].id==section.id else edges[0]
 return {}

static func _facing_arm(junction:Dictionary,direction:Vector2) -> Dictionary:
 for arm in junction.arms:
  if direction.dot(arm.direction)>.99999:return arm
 return {}

static func _extend_arm(arm:Dictionary,points:PackedVector2Array,length:float) -> Dictionary:
 var result:=arm.duplicate();result.points=points;result.length=length
 return result

static func _overlap(a:PackedVector2Array,b:PackedVector2Array) -> bool:
 for piece in Geometry2D.intersect_polygons(a,b):
  if Parcels.area(piece)>.000001:return true
 return false

static func clip_shared_paint(shapes:Array[PackedVector2Array],surfaces:Array[PackedVector2Array]) -> Array[PackedVector2Array]:
 var result:Array[PackedVector2Array]=[]
 for shape in shapes:
  var remaining:Array[PackedVector2Array]=[shape]
  # Render boxes can share asphalt. Assign each area to its first supporting
  # polygon so a merged stripe never gets reissued by a second render box.
  for surface in surfaces:
   var covered:Array[PackedVector2Array]=[]
   for piece in remaining:
    covered.append_array(Junctions.clip_paint(piece,[surface]))
   if covered.is_empty():continue
   result.append_array(covered)
   remaining=Geometry.outside_regions(remaining,covered)
   if remaining.is_empty():break
 return result
