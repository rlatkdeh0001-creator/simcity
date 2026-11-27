extends RefCounted
## Display-only paving across the sub-cell strip, never road/lot placement geometry.
const Geometry=preload("res://core/road_geometry.gd")
const Parcels=preload("res://core/road_parcels.gd")
const COLOR=Color("4c5659")
const EPS:=.0005
# Metres along original Blender +X, with original front -Y facing the local road.
# Read-only source bounds: OuterCurb openings (including side-curb clearance),
# and parking tower EntryCanopy [0.35,3.65]. These are display spans, not vehicle capacities.
const ENTRY_SPANS:={
 "parking-small-2x4":[Vector2(1,3.81)],
 "parking-medium-4x4":[Vector2(-3,0),Vector2(5,7.81)],
 "parking-large-4x8":[Vector2(-3,0),Vector2(5,7.81)],
 "parking-tower-4x4-4f":[Vector2(.35,3.65)]
}
static func build(city)->Array[PackedVector2Array]:
 var result:Array[PackedVector2Array]=[]
 var records:Array=city.buildings.duplicate();records.append_array(city.public_facilities.lots)
 var occupied:Array[PackedVector2Array]=[];occupied.append_array(city.road_pavement);occupied.append_array(city.junction_pavement)
 for record in records:occupied.append(city.footprint(record))
 var border:=PackedVector2Array([Vector2.ZERO,Vector2(city.width,0),Vector2(city.width,city.height),Vector2(0,city.height)])
 for record:Dictionary in records:
  var spans:Array=record.get("entrance_spans_m",ENTRY_SPANS.get(record.get("public_asset_id",record.get("asset_id","")),[]))
  if spans.is_empty() or int(record.get("front_road_id",-1))<0:continue
  var shape:PackedVector2Array=city.footprint(record);var center:=Vector2.ZERO
  for p in shape:center+=p
  center/=shape.size()
  var front:Vector2=city.front_direction(record).normalized();var side:=Vector2(front.y,-front.x);var reach:float=-INF
  for p in shape:reach=maxf(reach,(p-center).dot(front))
  var face:Vector2=center+front*reach
  for span:Vector2 in spans:
   var a:Vector2=face+side*span.x/4;var b:Vector2=face+side*span.y/4
   for road:Dictionary in city.roads:
    if road.kind!="local" or int(road.get("parcel_id",-2))!=int(record.front_road_id):continue
    for i in range(1,road.points.size()):
     var start:Vector2=road.points[i-1];var end:Vector2=road.points[i];var axis:Vector2=(end-start).normalized()
     var normal:=Vector2(-axis.y,axis.x)
     if normal.dot(front)<0:normal=-normal
     if normal.dot(front)<.98:continue
     var near_a:Vector2=Geometry2D.get_closest_point_to_segment(a,start,end)-normal*float(road.width)/2
     var near_b:Vector2=Geometry2D.get_closest_point_to_segment(b,start,end)-normal*float(road.width)/2
     if (near_a-a).dot(front)<-EPS or (near_b-b).dot(front)<-EPS:continue
     if maxf(a.distance_to(near_a),b.distance_to(near_b))>1+EPS or maxf(a.distance_to(near_a),b.distance_to(near_b))<EPS:continue
     var polygon:=PackedVector2Array([a,b,near_b,near_a]);var pieces:=Geometry.outside_regions(Geometry2D.intersect_polygons(polygon,border),occupied)
     var cells:Array[PackedVector2Array]=[]
     for cell in city.zoning_grid.parcels_in(Rect2i(Parcels.bounds(polygon).grow(1))):cells.append(cell.polygon)
     pieces=Geometry.outside_regions(pieces,cells);pieces=Geometry.outside_regions(pieces,result);result.append_array(pieces)
 return result
