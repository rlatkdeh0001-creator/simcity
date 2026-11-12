extends SceneTree
const Paths=preload("res://core/road_junctions.gd")
const Network=preload("res://core/traffic_network.gd")
const City=preload("res://core/city_model.gd")
const Geometry=preload("res://core/road_geometry.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(value: bool,label: String):
 checks+=1
 if value:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func length_ok(points: PackedVector2Array) -> bool:
 var length:=Paths.length_of(points)
 return length>=2-.001 and absf(length-roundf(length/2)*2)<.001
func reset(game):
 game.activate_tool("reset");game.activate_tool("road")
 game.city.add_road(PackedVector2Array([Vector2(10,30),Vector2(30,30)]))
func run():
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);await process_frame
 var drawing=game.road_drawer
 for kind in ["straight","curve","free"]:
  reset(game);drawing.set_kind(kind);drawing.click(Vector2(30,30))
  if kind=="curve":drawing.click(Vector2(42,39))
  game.pointer=Vector2(51.3,42.7) if kind!="straight" else Vector2(43.3,31.2)
  var original:=var_to_str(game.city.roads)
  var candidate: Dictionary=drawing.preview()
  verify(candidate.ok and length_ok(candidate.points),kind+" green preview uses actual path length in eight-metre units")
  verify(candidate.points[0]==Vector2(30,30) and var_to_str(game.city.roads)==original,"length preview preserves existing endpoint and authored roads")
  var expected: PackedVector2Array=candidate.points.duplicate();drawing.click(game.pointer)
  verify(game.city.roads.size()==2 and game.city.roads[-1].points==expected,kind+" saved construction exactly equals quantized green preview")
 reset(game);drawing.set_kind("straight");drawing.click(Vector2(20,30));game.pointer=Vector2(22,43.3)
 var perpendicular: Dictionary=drawing.preview()
 verify(perpendicular.ok and length_ok(perpendicular.points) and absf((perpendicular.points[-1]-perpendicular.points[0]).normalized().dot(Vector2.RIGHT))<.00001,"eight-metre quantization preserves exact 90-degree assistance")
 reset(game);game.city.add_road(PackedVector2Array([Vector2(30,45),Vector2(50,45)]));drawing.set_kind("straight");drawing.click(Vector2(30,30));game.pointer=Vector2(30,45)
 var fixed_before:=var_to_str(game.city.roads);var incompatible: Dictionary=drawing.preview()
 verify(not incompatible.ok and incompatible.points[0]==Vector2(30,30) and incompatible.points[-1]==Vector2(30,45),"non-unit straight between fixed contacts is red without moving endpoints")
 drawing.click(game.pointer);verify(game.city.roads.size()==2 and var_to_str(game.city.roads)==fixed_before,"invalid pinned straight cannot be committed")
 for kind in ["curve","free"]:
  reset(game);game.city.add_road(PackedVector2Array([Vector2(30,45),Vector2(50,45)]));drawing.set_kind(kind);drawing.click(Vector2(30,30))
  if kind=="curve":drawing.click(Vector2(40,40))
  game.pointer=Vector2(30,45);var raw: PackedVector2Array=drawing.raw_path();var candidate: Dictionary=drawing.preview()
  verify(candidate.ok and length_ok(candidate.points) and candidate.points[0]==Vector2(30,30) and candidate.points[-1]==Vector2(30,45),kind+" adjusts internal arc length while retaining both existing contacts")
  verify(candidate.points[1]==raw[1] and candidate.points[-2]==raw[-2],"pinned curved quantization preserves angle-snapped first and final sampled tangents")
 reset(game);drawing.set_kind("straight");drawing.click(Vector2(50,50));game.pointer=Vector2(50.2,50)
 verify(length_ok(drawing.preview().points),"minimum new road is one eight-metre construction unit")
 reset(game);drawing.set_kind("curve");drawing.click(Vector2(30,30));game.pointer=Vector2(42.3,38.2)
 var guide: Dictionary=drawing.preview();drawing.click(game.pointer)
 verify(length_ok(guide.points) and drawing.anchors.size()==2 and drawing.anchors[1]==guide.points[-1],"curve control guide and stored handle share eight-metre snapped geometry")
 reset(game);drawing.set_kind("straight");drawing.click(Vector2(30.2,18.7));game.pointer=Vector2(30,30)
 var arrival: Dictionary=drawing.preview()
 verify(arrival.ok and length_ok(arrival.points) and arrival.points[-1]==Vector2(30,30) and absf((arrival.points[-1]-arrival.points[-2]).normalized().dot(Vector2.RIGHT))<.00001,"free approach start adjusts without detaching its pinned perpendicular destination")
 var odd:=PackedVector2Array([Vector2(60,60),Vector2(63,60)])
 verify(not game.city.add_road(odd,"local",false,2,false,true).ok and game.city.add_road(odd,"local",false,2,false,false).ok,"model guard rejects non-unit player construction without rewriting authored legacy paths")
 verify(game.city.has_method("demolish_road_unit"),"model supports a four-metre bulldozer interval")
 if game.city.has_method("demolish_road_unit"):await check_demolition(game)
 game.queue_free();await process_frame
 print("RESULT %d/%d road length unit checks passed" % [checks-failures,checks]);quit(1 if failures else 0)
func check_demolition(game):
 var city:=City.new(100,100)
 city.add_road(PackedVector2Array([Vector2(10,30),Vector2(50,30)]),"local",true,4)
 var colors:={}
 for parcel in city.zoning_grid.parcels.values():
  city.zone_designations[parcel.id]="residential";colors[parcel.id]=parcel.center
 var before:=Paths.length_of(city.roads[0].points)
 var result: Dictionary=city.demolish_road_unit(0,Vector2(30.4,30))
 var after:=0.0
 for road in city.roads:after+=Paths.length_of(road.points)
 verify(result.ok and is_equal_approx(before-after,1) and city.roads.size()==2,"middle click removes exactly one four-metre centreline interval")
 verify(city.roads[0].parcel_id==0 and city.roads[1].parcel_id==1 and city.roads[0].points[-1]==Vector2(30,30) and city.roads[1].points[0]==Vector2(31,30),"cut retains left ID and allocates a fresh right-fragment ID")
 verify(city.zone_designations.keys().all(func(id):return colors.has(id) and city.zoning_grid.parcels[id].center==colors[id]),"surviving zoning IDs/colors never shift to another world location")
 verify(not city.zoning_grid.parcels.values().any(func(p):return p.center.x>30 and p.center.x<31),"cut interval leaves no phantom roadside cells")
 var covered:=false
 for visual in city.road_visuals:
  for shape in Geometry.ribbons(visual.points,visual.width*.8125,visual.flat_start,visual.flat_end):covered=covered or Geometry2D.is_point_in_polygon(Vector2(30.5,30),shape)
 verify(not covered,"flat pavement caps cannot paint back over the four-metre demolition gap")
 var network:=Network.new();verify(network.build(city.roads),"lane graph rebuilds after a split")
 var cross_gap:=false
 for a in network.lanes:
  for b in network.lanes:
   if a.road==0 and b.road==1 and not network.route(a.id,b.id).is_empty():cross_gap=true
 verify(not cross_gap,"traffic graph does not bridge demolished road interval")
 var unchanged:=var_to_str(city.roads)
 verify(not city.demolish_road_unit(0,Vector2(90,90)).ok and var_to_str(city.roads)==unchanged and city.funds==50000,"out-of-range demolition is nonmutating and no new refund or fee is invented")
 var first_points: PackedVector2Array=city.roads[0].points.duplicate()
 city.demolish_road_unit(1,Vector2(31.2,30))
 verify(city.roads[0].points==first_points and city.roads[1].points[0]==Vector2(32,30),"repeated deletion uses original one-cell arc grid and leaves unrelated fragment intact")
 var curve:=City.new(100,100);curve.add_road(PackedVector2Array([Vector2(10,20),Vector2(20,25),Vector2(35,40)]))
 before=Paths.length_of(curve.roads[0].points);curve.demolish_road_unit(0,Paths.sample(curve.roads[0].points,14.3));after=0
 for road in curve.roads:after+=Paths.length_of(road.points)
 verify(absf(before-after-1)<.001,"curved-road demolition measures arc length, not chord length")
 var loop:=City.new(100,100);loop.add_road(PackedVector2Array([Vector2(20,20),Vector2(40,20),Vector2(40,40),Vector2(20,40),Vector2(20,20)]))
 before=Paths.length_of(loop.roads[0].points);loop.demolish_road_unit(0,Vector2(30.2,20));after=0
 for road in loop.roads:after+=Paths.length_of(road.points)
 verify(absf(before-after-1)<.001 and network.build(loop.roads),"closed-loop cut retains remaining arc geometry and a valid lane graph")
 var short:=City.new(100,100);short.add_road(PackedVector2Array([Vector2(10,20),Vector2(10.4,20)]));short.demolish_road_unit(0,Vector2(10.2,20))
 verify(short.roads.is_empty(),"old terminal shorter than four metres can be removed without leaving an undeletable stub")
 game.activate_tool("reset");game.city.add_road(PackedVector2Array([Vector2(10,30),Vector2(70,30)]));game.map_zoom=.8;game.origin=Vector2(850,20);game.toggle_demolition()
 var target: Dictionary=game.demolition_target(game.screen(Vector2(40.2,30)))
 verify(target.get("kind","")=="road" and absf(Paths.length_of(target.road.points)-1)<.001,"bulldozer hover selects only the actual four-metre interval")
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=game.screen(Vector2(40.2,30));root.push_input(event,true);await process_frame
 event.pressed=false;root.push_input(event,true);await process_frame
 after=0
 for road in game.city.roads:after+=Paths.length_of(road.points)
 verify(absf(after-59)<.001 and game.city.roads.size()==2 and game.mode=="demolish","actual player bulldozer uses partial removal rather than whole-object deletion")
