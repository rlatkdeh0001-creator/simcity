extends RefCounted
## Display-only sub-cell curb gaps from the existing shared parcel lattice.
const Grid=preload("res://core/road_grid_snap.gd")
const Parcels=preload("res://core/road_parcels.gd")
const Geometry=preload("res://core/road_geometry.gd")
const Paths=preload("res://core/road_junctions.gd")
const COLOR=Color("8fa570")
static func build(city)->Array[PackedVector2Array]:
 var result:Array[PackedVector2Array]=[]
 var border:=PackedVector2Array([Vector2.ZERO,Vector2(city.width,0),Vector2(city.width,city.height),Vector2(0,city.height)])
 var occupied:Array[PackedVector2Array]=[];occupied.append_array(city.road_pavement);occupied.append_array(city.junction_pavement)
 for index in range(city.roads.size()):
  var road:Dictionary=city.roads[index]
  if road.kind!="local" or index>=city.zoning_lattices.size():continue
  var raw:=Parcels.blocks(road.get("zoning_source_points",road.points),road.width/2,road.get("zoning_source_id",road.get("parcel_id",index)),city.config.parcel_block_length,city.config.parcel_turn_degrees,city.config.parcel_max_deviation)
  var aligned:=Grid.aligned_blocks(raw.duplicate(true),city.zoning_lattices[index])
  for i in range(raw.size()):
   var frame:Dictionary=raw[i]
   if not Grid.straight(frame):continue
   var gap:float=(aligned[i].origin-Vector2(frame.origin)).dot(frame.outward)
   if gap<=Grid.EPS or gap>=1.0-Grid.EPS:continue
   var start:Vector2=frame.origin;var finish:Vector2=start+frame.along*Paths.length_of(frame.centerline)
   var band:=PackedVector2Array([start,finish,finish+frame.outward*gap,start+frame.outward*gap])
   var pieces:Array[PackedVector2Array]=Geometry.outside_regions(Geometry2D.intersect_polygons(band,border),occupied)
   var cells:Array[PackedVector2Array]=[]
   for parcel in city.zoning_grid.parcels_in(Rect2i(Parcels.bounds(band).grow(2))):cells.append(parcel.polygon)
   pieces=Geometry.outside_regions(pieces,cells)
   # Orthogonal roads can describe the same corner; keep a single opaque patch.
   pieces=Geometry.outside_regions(pieces,result)
   result.append_array(pieces)
 return result
