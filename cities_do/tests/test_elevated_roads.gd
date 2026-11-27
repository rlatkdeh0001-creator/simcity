extends SceneTree
## E1 correctness only: no benchmark, wall-clock sampling or graphical capture.
const City = preload("res://core/city_model.gd")
var passed := 0
var failed := 0
func _initialize() -> void:
 call_deferred("run")
func check(value: bool, label: String) -> void:
 if value:
  passed += 1
  print("PASS ", label)
 else:
  failed += 1
  print("FAIL ", label)
func run() -> void:
 var city = City.new(100,100)
 check(city.has_method("add_elevated_road"), "E1 exposes the authoritative height-aware road transaction")
 if city.has_method("add_elevated_road"):
  var points := PackedVector2Array([Vector2(20,40),Vector2(60,40)])
  var before := var_to_bytes(city.roads)
  var preview: Dictionary = city.call("add_elevated_road", points, PackedFloat64Array([0,10]), "local", false, 2)
  check(preview.get("ok",false), "160m local ramp accepts 10m rise")
  check(var_to_bytes(city.roads)==before, "height preview preserves authoritative road records")
  var result: Dictionary = city.call("add_elevated_road", points, PackedFloat64Array([0,10]), "local", true, 2)
  check(result.get("ok",false), "same resolved ramp commits")
  check(city.roads.size()==1 and city.roads[0].get("heights_m",PackedFloat64Array())==PackedFloat64Array([0,10]), "committed road preserves per-point heights")
  var short_path := PackedVector2Array([Vector2(10,20),Vector2(40,20)])
  var steep:Dictionary=city.call("add_elevated_road",short_path,PackedFloat64Array([0,10]),"local",false,2)
  check(not steep.get("ok",true),"120m local ramp rejects 10m rise")
  var highway:Dictionary=city.call("add_elevated_road",points,PackedFloat64Array([0,10]),"highway",false,2)
  check(not highway.get("ok",true),"160m highway ramp rejects 10m rise")
  var offmap:Dictionary=city.call("add_elevated_road",PackedVector2Array([Vector2(-1,20),Vector2(40,20)]),PackedFloat64Array([10,10]),"local",false,2)
  check(not offmap.get("ok",true),"height transaction rejects out of map points")
  var invalid_layer:Dictionary=city.call("add_elevated_road",points,PackedFloat64Array([6,6]),"local",false,2)
  check(not invalid_layer.get("ok",true),"flat layers remain multiples of 5m")
  var crossing:Dictionary=city.call("add_elevated_road",PackedVector2Array([Vector2(45,10),Vector2(45,70)]),PackedFloat64Array([10,10]),"local",false,2)
  check(not crossing.get("ok",true),"full-width crossing rejects intermediate ramp clearance below 10m")
 test_topology_and_parcels()
 test_supports_and_demolition()
 test_geometry_preservation()
 test_support_boundaries()
 test_short_support_candidate_cluster()
 test_separate_deck_runs()
 test_solid_ramp_parks()
 test_park_over_shallow_dip()
 test_flat_end_obstacles()
 test_junction_obstacles()
 test_junction_obstacles(true)
 test_unchanged_junction_legacy_lot()
 print("E1 elevated roads: %d passed, %d failed" % [passed,failed])
 quit(1 if failed else 0)
func test_separate_deck_runs():
 var points:=PackedVector2Array([Vector2(10,40),Vector2(45.2,40),Vector2(80,40)])
 var heights:=PackedFloat64Array([10,0,10])
 for survivor in [false,true]:
  var city=City.new(100,100)
  if survivor:
   # Legacy authored record: trim the last two cells without touching the two ramps.
   city.roads.append({"parcel_id":0,"points":PackedVector2Array([points[0],points[1],points[2],Vector2(90,40)]),"heights_m":PackedFloat64Array([10,0,10,10]),"kind":"local","lanes":2,"width":3.0,"major_side":1})
   city.next_road_id=1
  var result:Dictionary=city.demolish_road_selection(city.road_demolition_selection(0,Vector2(88,40),Vector2(90,40))) if survivor else city.add_elevated_road(points,heights)
  check(result.ok,"separate +10 to 0 to +10 deck runs accept without a span across solid ground; survivor="+str(survivor)+" reason="+result.reason)
  if not result.ok:continue
  var left_boundary:=false;var right_boundary:=false;var solid:=false
  for pier in city.roads[0].piers:
   left_boundary=left_boundary or absf(pier.distance-17.6)<.0001
   right_boundary=right_boundary or absf(pier.distance-52.6)<.0001
   solid=solid or (pier.distance>17.6001 and pier.distance<52.5999)
  check(left_boundary and right_boundary and not solid,"both off-search-grid +5m boundaries are used without placing piers in the solid gap")
  var length:float=city.RoadJunctions.length_of(city.roads[0].points)
  check(max_emitted_span_m(city.roads[0],0.0,17.6)<=48.001 and max_emitted_span_m(city.roads[0],52.6,length)<=48.001,"actual supports meet 48m independently on each side of the solid interval")

func max_emitted_span_m(road:Dictionary,first:float,last:float)->float:
 var previous:=first;var largest:=0.0;var found:=false
 for pier:Dictionary in road.piers:
  if pier.distance<first-.0001 or pier.distance>last+.0001:continue
  # Straight two-lane fixture: measure the actual emitted pier centre.
  if pier.positions.size()!=1:return INF
  var distance:float=(Vector2(pier.positions[0])-Vector2(road.points[0])).dot(Vector2.RIGHT)
  if absf(distance-float(pier.distance))>.0001 or distance<previous-.0001:return INF
  if found and distance-previous<4-.0001:return INF
  largest=maxf(largest,distance-previous);previous=distance;found=true
 return maxf(largest,last-previous)*4 if found else INF

func test_short_support_candidate_cluster():
 for survivor in [false,true]:
  for ground_start in [14.25,14.0,13.75]:
   var city=City.new(100,100)
   check(city.add_road(PackedVector2Array([Vector2(ground_start,40),Vector2(40,40)])).ok,"short cluster ground obstacle")
   var end:=Vector2(24,40);var heights:=PackedFloat64Array([10,10])
   var path:=PackedVector2Array([Vector2(10,40),end])
   var selection:Dictionary={}
   if survivor:
    var host:=PackedVector2Array([Vector2(6,40),end])
    if ground_start==13.75:
     # This end was never supportable beside the obstacle; model a legacy authored host.
     city.roads.append({"parcel_id":1,"points":host,"heights_m":heights,"kind":"local","lanes":2,"width":3.0,"major_side":1})
     city.next_road_id=2
    else:check(city.add_elevated_road(host,heights).ok,"longer host places legal supports before trimming")
    selection=city.road_demolition_selection(1,Vector2(6,40),Vector2(10,40))
    check(selection.ok,"actual demolition selection trims exactly four cells")
   var before:=var_to_bytes([city.roads,city.next_road_id])
   var result:Dictionary=city.demolish_road_selection(selection) if survivor else city.add_elevated_road(path,heights)
   var label:=" ground="+str(ground_start)+" demolition="+str(survivor)
   if ground_start==13.75:
    check(not result.ok and result.reason=="교각을 세울 자리가 없습니다" and var_to_bytes([city.roads,city.next_road_id])==before,"49m minimum unsupported end rejects atomically"+label)
   elif result.ok:
    var emitted:Dictionary=city.roads[-1]
    var span:=max_emitted_span_m(emitted,0,14)
    check(emitted.points==path and emitted.piers.size()==1 and span<=48.001 and (ground_start!=14.0 or is_equal_approx(span,48.0)),"actual single emitted pier with legal end spans"+label+" max_m="+str(span))
   else:check(false,"legal short cluster accepted"+label+" reason="+result.reason)
func test_park_over_shallow_dip():
 for dip in [true,false]:
  for park_first in [true,false]:
   var city=City.new(100,100);city.funds=1000000
   check(city.add_road(PackedVector2Array([Vector2(33.5,10),Vector2(33.5,90)])).ok,"shallow dip park frontage")
   var path:=PackedVector2Array([Vector2(30,10),Vector2(30,28),Vector2(30,30),Vector2(30,32),Vector2(30,90)])
   var heights:=PackedFloat64Array([5,5,4.9 if dip else 5.0,5,5])
   if park_first:
    check(city.public_facilities.place("park-plaza-4x4",Vector2(30,30),0).ok,"shallow dip park first fixture")
    var result:Dictionary=city.add_elevated_road(path,heights)
    check(result.ok if not dip else not result.ok and result.reason=="공공시설과 겹침","interior shallow dip road after park; dip="+str(dip)+" reason="+result.reason)
   else:
    check(city.add_elevated_road(path,heights).ok,"shallow dip road first fixture")
    var park:Dictionary=city.public_facilities.place("park-plaza-4x4",Vector2(30,30),3)
    check(park.ok if not dip else not park.ok and park.reason=="도로와 충돌합니다","park after interior shallow dip road; dip="+str(dip)+" reason="+park.reason)
func test_flat_end_obstacles():
 var city=City.new(100,100)
 var path:=PackedVector2Array([Vector2(20,40),Vector2(40,40)])
 var heights:=PackedFloat64Array([10,10])
 city.buildings.append({"id":71,"x":40.25,"y":39,"size":2,"level":1,"zone":"residential","asset_id":""})
 city.buildings.append({"id":72,"x":36,"y":39,"size":2,"level":1,"zone":"residential","asset_id":""})
 var outside:=city.footprint(city.buildings[0])
 var plan:Dictionary=city.add_elevated_road(path,heights,"local",false)
 check(plan.ok and plan.demolish_ids==[72],"only actual flat ribbon overlap produces a confirmation ID: "+str(plan.get("demolish_ids",[])))
 city.public_facilities.lots.append({"id":73,"public_asset_id":"medical-clinic","polygon":outside})
 var committed:Dictionary=city.add_elevated_road(path,heights,"local",true,2,true,1,{},[72])
 check(committed.ok and city.find_building(72).is_empty() and not city.find_building(71).is_empty(),"cap-only public lot cannot block exact confirmed road: "+committed.reason)

 var empty_lot:=city.footprint({"x":18,"y":39,"size":2})
 check(city._polygon_error(empty_lot,-1,false)=="","lot can reach the flat start without overlapping the road")
func test_support_boundaries():
 for reverse in [false,true]:
  var city=City.new(100,100)
  var ground:=PackedVector2Array([Vector2(10,40),Vector2(50,40)]) if not reverse else PackedVector2Array([Vector2(50,40),Vector2(90,40)])
  check(city.add_road(ground).ok,"boundary support obstacle fixture")
  var before:=var_to_bytes([city.roads,city.next_road_id])
  var result:Dictionary=city.add_elevated_road(PackedVector2Array([Vector2(10,40),Vector2(90,40)]),PackedFloat64Array([10,10]))
  check(not result.ok and result.reason=="교각을 세울 자리가 없습니다","unsupported first/last 160m boundary span rejected")
  check(var_to_bytes([city.roads,city.next_road_id])==before,"unsupported boundary rejection is atomic")
func test_solid_ramp_parks():
 var fragment_city=City.new(100,100)
 check(fragment_city.add_elevated_road(PackedVector2Array([Vector2(10,40),Vector2(90,40)]),PackedFloat64Array([10,10])).ok,"fragment support host")
 # Load a legacy ground record directly: new construction now refuses a shaft intersection.
 var legacy:Dictionary=fragment_city.add_road(PackedVector2Array([Vector2(10,40),Vector2(50,40)]),"local",false)
 check(not legacy.ok and legacy.reason=="교각과 겹침","new construction rejects the legacy fragment obstacle")
 fragment_city.roads.append({"points":PackedVector2Array([Vector2(10,40),Vector2(50,40)]),"kind":"local","width":3.0,"lanes":2,"major_side":1,"parcel_id":fragment_city.next_road_id})
 fragment_city.next_road_id+=1
 var selection:Dictionary=fragment_city.road_demolition_selection(0,Vector2(70,40),Vector2(78,40))
 var before:=var_to_bytes([fragment_city.roads,fragment_city.next_road_id])
 var removed:Dictionary=fragment_city.demolish_road_selection(selection)
 check(not removed.ok and removed.reason=="교각을 세울 자리가 없습니다" and var_to_bytes([fragment_city.roads,fragment_city.next_road_id])==before,"actual demolition rejects unsupported fragment boundary atomically")
 for deck in [false,true]:
  for park_first in [false,true]:
   var city=City.new(100,100)
   city.funds=1000000
   check(city.add_road(PackedVector2Array([Vector2(33.5,10),Vector2(33.5,90)])).ok,"park frontage fixture")
   var points:=PackedVector2Array([Vector2(30,10),Vector2(30,90)])
   var heights:=PackedFloat64Array([10,10]) if deck else PackedFloat64Array([0,10])
   if park_first:
    var park:Dictionary=city.public_facilities.place("park-plaza-4x4",Vector2(30,30),0)
    check(park.ok,"park first valid frontage placement")
    var result:Dictionary=city.add_elevated_road(points,heights)
    check(result.ok==deck,"road over park rejects solid retaining ramp but permits usable deck")
   else:
    check(city.add_elevated_road(points,heights).ok,"ramp first valid placement")
    var park:Dictionary=city.public_facilities.place("park-plaza-4x4",Vector2(30,30),3)
    if not park.ok:print("PARK_BOUNDARY_DIAGNOSTIC ",park.reason)
    check(park.ok==deck,"park under road rejects solid retaining ramp but permits usable deck")
func test_junction_obstacles(cross:bool=false):
 for public in [false,true]:
  var city=City.new(100,100)
  check(city.add_road(PackedVector2Array([Vector2(20,45),Vector2(80,45)])).ok,"junction obstacle host")
  if cross:check(city.add_road(PackedVector2Array([Vector2(50,15),Vector2(50,45)])).ok,"cross junction narrow north host")
  var building:Dictionary={"id":71,"x":44.5,"y":40.5,"size":2,"level":1,"zone":"residential","asset_id":""}
  var shape:PackedVector2Array=city.footprint(building)
  var points:=PackedVector2Array([Vector2(50,45),Vector2(50,75)])
  var clear_plan:Dictionary=city.add_elevated_road(points,PackedFloat64Array([0,0]),"local",false,8)
  check(clear_plan.ok,"unobstructed transaction emits the T/cross addition")
  if not clear_plan.ok:continue
  var topology:Dictionary=city.RoadJunctions.analyze(city.roads+clear_plan.new_roads)
  var final_patch:PackedVector2Array=topology.junctions[0].footprint
  var old_topology:Dictionary=city.RoadJunctions.analyze(city.roads)
  check((old_topology.junctions.is_empty() if not cross else not city.Parcels.overlap(shape,old_topology.junctions[0].footprint)) and city.Parcels.overlap(shape,final_patch) and not city._road_ribbon_overlap(shape,city.RoadGeometry.ribbons(clear_plan.new_roads[0].points,clear_plan.new_roads[0].width,true,true)),"lot misses old patch and emitted ribbons but intersects final T/cross patch; cross="+str(cross))
  if public:city.public_facilities.lots.append({"id":71,"public_asset_id":"medical-clinic","polygon":shape})
  else:city.buildings.append(building)
  var before:=var_to_bytes([city.roads,city.buildings,city.public_facilities.lots,city.next_road_id,city.funds])
  var plan:Dictionary=city.add_elevated_road(points,PackedFloat64Array([0,0]),"local",false,8)
  check(not plan.ok if public else plan.ok and plan.demolish_ids==[71],"final junction patch public rejection or exact private warning IDs")
  var rejected:Dictionary=city.add_elevated_road(points,PackedFloat64Array([0,0]),"local",true,8,true,1,{},[])
  check(not rejected.ok and var_to_bytes([city.roads,city.buildings,city.public_facilities.lots,city.next_road_id,city.funds])==before,"junction patch rejection preserves transaction state")
  if not public:
   check(city.add_elevated_road(points,PackedFloat64Array([0,0]),"local",true,8,true,1,{},[71]).ok and city.find_building(71).is_empty() and city.RoadJunctions.analyze(city.roads).junctions[0].footprint==final_patch,"exact confirmation removes the patch-only lot and commits the same final patch")
func test_unchanged_junction_legacy_lot():
 for public in [false,true]:
  var city=City.new(100,100)
  check(city.add_road(PackedVector2Array([Vector2(20,45),Vector2(80,45)])).ok,"legacy junction horizontal host")
  check(city.add_elevated_road(PackedVector2Array([Vector2(50,45),Vector2(50,75)]),PackedFloat64Array([0,0]),"local",true,8).ok,"legacy wide T junction")
  var building:Dictionary={"id":71,"x":44.5,"y":40.5,"size":2,"level":1,"zone":"residential","asset_id":""}
  var shape:PackedVector2Array=city.footprint(building)
  var patch_before:PackedVector2Array=city.RoadJunctions.analyze(city.roads).junctions[0].footprint
  check(city.Parcels.overlap(shape,patch_before),"legacy lot really conflicts with the existing emitted patch")
  if public:city.public_facilities.lots.append({"id":71,"public_asset_id":"medical-clinic","polygon":shape})
  else:city.buildings.append(building)
  var existing:=var_to_bytes([city.roads.slice(0,2),city.buildings,city.public_facilities.lots,city.funds])
  var stroke:=PackedVector2Array([Vector2(25,15),Vector2(65,15)])
  var preview:Dictionary=city.add_elevated_road(stroke,PackedFloat64Array([10,10]),"local",false)
  check(preview.ok and not preview.get("warning",true) and preview.get("demolish_ids",[71]).is_empty(),"unrelated stroke preview ignores unchanged patch; public="+str(public)+" result="+str(preview.get("reason",""))+" IDs="+str(preview.get("demolish_ids",[])))
  var result:Dictionary=city.add_elevated_road(stroke,PackedFloat64Array([10,10]))
  check(result.ok and city.roads.size()==3 and city.roads[-1].points==stroke,"unrelated stroke commits exact geometry; public="+str(public))
  check(var_to_bytes([city.roads.slice(0,2),city.buildings,city.public_facilities.lots,city.funds])==existing and city.RoadJunctions.analyze(city.roads).junctions[0].footprint==patch_before,"existing records and emitted legacy patch remain untouched")

func test_topology_and_parcels():
 var city=City.new(100,100)
 check(city.add_road(PackedVector2Array([Vector2(10,50),Vector2(90,50)])).ok,"ground crossing fixture")
 check(city.add_elevated_road(PackedVector2Array([Vector2(50,10),Vector2(50,90)]),PackedFloat64Array([10,10])).ok,"10m separated crossing accepted")
 var topology:Dictionary=city.RoadJunctions.analyze(city.roads)
 check(topology.junctions.is_empty() and topology.sections.size()==2,"grade separation does not produce a traffic junction")
 var elevated_parcels:=0
 for parcel:Dictionary in city.zoning_grid.parcels.values():
  if parcel.frame.road_index==1:elevated_parcels+=1
 check(elevated_parcels==0,"elevated road generates no adjacent parcels")
 var isolated=City.new(100,100)
 isolated.add_elevated_road(PackedVector2Array([Vector2(10,40),Vector2(90,40)]),PackedFloat64Array([10,10]))
 check(isolated.road_pavement.is_empty() and isolated.road_asphalt.is_empty(),"raised deck not painted into ground road layer")
 var top=City.new(100,100)
 top.add_elevated_road(PackedVector2Array([Vector2(10,40),Vector2(50,40)]),PackedFloat64Array([10,10]))
 top.add_elevated_road(PackedVector2Array([Vector2(50,40),Vector2(90,40)]),PackedFloat64Array([10,10]))
 var graph:Dictionary=top.RoadJunctions.analyze(top.roads)
 check(graph.nodes.size()==3,"equal-height ends remain connected")
 var visuals:Array=preload("res://core/road_geometry.gd").continuous_roads(top.roads,graph)
 check(visuals.size()==1 and visuals[0].heights_m.size()==visuals[0].points.size(),"equal-height visual chains preserve continuous geometry and every point height")
 check(preload("res://core/building_frontage.gd").candidates(PackedVector2Array([Vector2(10,42),Vector2(12,42),Vector2(12,44),Vector2(10,44)]),top.roads,4).is_empty(),"raised decks never create ground building frontage")
func test_supports_and_demolition():
 var city=City.new(100,100)
 var path:=PackedVector2Array([Vector2(10,40),Vector2(90,40)])
 var heights:=PackedFloat64Array([10,10])
 city.buildings.append({"id":1,"x":40,"y":40,"size":2,"level":1,"zone":"residential","asset_id":""})
 var preview:Dictionary=city.add_elevated_road(path,heights,"local",false,4)
 check(preview.get("ok",false) and preview.get("demolish_ids",[])==[1],"private buildings produce yellow plan with exact IDs")
 check(city.buildings.size()==1,"yellow preview does not demolish")
 var unconfirmed:Dictionary=city.add_elevated_road(path,heights,"local",true,4)
 check(not unconfirmed.get("ok",true) and city.buildings.size()==1 and city.roads.is_empty(),"commit requires demolition confirmation")
 var result:Dictionary=city.add_elevated_road(path,heights,"local",true,4,true)
 check(result.get("ok",false) and city.buildings.is_empty(),"confirmed road removes only its overlapping building")
 check(not result.get("piers",[]).is_empty(),"elevated plan contains production support positions")
 if not result.get("piers",[]).is_empty():
  check(result.piers[0].positions.size()==2,"20m wide deck has two piers per station")
 var boundary=City.new(100,100)
 boundary.public_facilities.lots.append({"id":1,"asset_id":"medical-clinic","polygon":PackedVector2Array([Vector2(40,38),Vector2(44,38),Vector2(44,42),Vector2(40,42)])})
 var red:Dictionary=boundary.add_elevated_road(path,heights,"local",false,2)
 check(not red.get("ok",true),"public facility remains red and is not demolishable")
func test_geometry_preservation():
 var city=City.new(160,160)
 var points:=PackedVector2Array([Vector2(10,40),Vector2(42,40),Vector2(82,40)])
 check(city.add_elevated_road(points,PackedFloat64Array([0,10,10])).ok,"8m-rounded 128m ramp then flat deck commits")
 var copy:Dictionary=city.add_elevated_road(points,PackedFloat64Array([0,10,10]),"local",false)
 check(not copy.get("ok",true),"duplicate elevated stroke is rejected")
 var fragment:Dictionary=city.RoadUnits.fragment(city.roads[0],16,60)
 check(fragment.get("heights_m",PackedFloat64Array())==PackedFloat64Array([5,10,10]),"demolition fragment interpolates heights at both cuts")
 var Height=load("res://core/road_height.gd")
 check(Height.minimum_ramp_m(10,"local")==128 and Height.minimum_ramp_m(10,"highway")==200,"minimum ramp lengths round up to 8m")
 var vertical=City.new(100,100)
 vertical.add_elevated_road(PackedVector2Array([Vector2(10,40),Vector2(90,40)]),PackedFloat64Array([10,10]))
 var ground:Dictionary=vertical.add_elevated_road(PackedVector2Array([Vector2(50,10),Vector2(50,90)]),PackedFloat64Array([0,0]),"local",false)
 check(not ground.get("ok",true),"new lower road cannot intersect an existing support")
 var short_ramp:Dictionary=city.add_elevated_road(PackedVector2Array([Vector2(10,90),Vector2(41.25,90)]),PackedFloat64Array([0,10]),"local",false)
 check(not short_ramp.get("ok",true),"exact 8 percent 125m ramp still requires 128m construction rounding")
 var rail=City.new(100,100)
 rail.transit_routes.append({"id":1,"kind":"rail","width":2.5,"points":PackedVector2Array([Vector2(50,10),Vector2(50,90)])})
 check(not rail.add_elevated_road(PackedVector2Array([Vector2(10,40),Vector2(90,40)]),PackedFloat64Array([5,5]),"local",false).ok,"full rail structure width blocks a 5m crossing")
 var parks=City.new(100,100)
 parks.add_road(PackedVector2Array([Vector2(10,50.5),Vector2(90,50.5)]))
 parks.add_elevated_road(PackedVector2Array([Vector2(30,10),Vector2(30,90)]),PackedFloat64Array([10,10]))
 var park:Dictionary=parks.public_facilities.preview("park-pocket-2x2",Vector2(30,52.5),2)
 if not park.ok:print("PARK_FIXTURE ",park," roads=",parks.roads)
 check(park.ok,"park placement remains allowed beneath existing elevated deck")
