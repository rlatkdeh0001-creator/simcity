extends SceneTree

const City=preload("res://core/city_model.gd")
const Height=preload("res://core/road_height.gd")
const Adapter=preload("res://core/city_simulation_worker.gd")
const Network=preload("res://core/traffic_network.gd")
var spine:=PackedVector2Array([Vector2(30,75),Vector2(74,75),Vector2(110,75)])
var levels:=PackedFloat64Array([0,10,0])
var checks:=0
var failures:=0
var journal:Dictionary={}
var replay:Array=[]

class InspectAdapter extends "res://core/city_simulation_worker.gd":
 func export_validation()->Dictionary:return {"roads":city.roads.duplicate(true),"next_road_id":city.next_road_id,"checkpoint":capture(city)}

func _initialize():run.call_deferred()

func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)

func run():
 test_crossings()
 test_warnings_and_profiles()
 test_support_continuation()
 test_fifo_checkpoint()
 print("E4C_EDITS checks=%d failed=%d"%[checks,failures])
 quit(1 if failures else 0)

func road(city,points:PackedVector2Array,count:int=2)->Dictionary:
 return city.add_road(points,"local",true,count,false,true)

func test_crossings():
 for crossing_first:bool in [false,true]:
  var city=City.new(160,160)
  var cross:=PackedVector2Array([Vector2(70,57),Vector2(70,93)])
  if crossing_first:check(road(city,cross).ok,"first-order crossing fixture")
  var res:Dictionary=city.add_center_flyover(spine,levels)
  check(res.ok,"flyover allows 10m crossing over full pavement: "+res.reason)
  if not res.ok:continue
  if not crossing_first:
   var result:=road(city,cross)
   check(result.ok,"reverse-order crossing at +10m: "+result.reason)
  check(city.junctions.size()==2,"full crossing makes exactly two ground junctions")
  if city.junctions.size()==2:
   check(is_equal_approx(city.junctions[0].position.distance_to(city.junctions[1].position)*4,14),"actual junction pair uses universal 14m spacing")
  var rejected:=road(city,PackedVector2Array([Vector2(55,53),Vector2(55,97)]))
  check(not rejected.ok and rejected.reason=="수직 간격 부족","full interior ramp crossing denied by vertical rule")
  var outer_t:=road(city,PackedVector2Array([Vector2(54,94.75),Vector2(54,76.75)]))
  check(outer_t.ok,"outer-only T at same ramp chainage remains legal: "+outer_t.reason)
  var spine_overlap:Dictionary=city.add_road(PackedVector2Array([Vector2(68,75),Vector2(72,75)]),"local",false,2,false,true)
  check(not spine_overlap.ok,"a parallel insertion under the deck is not an undercrossing")
  for piece:Dictionary in res.new_roads[0].piers:
   check(piece.positions.size()==1 and absf(piece.positions[0].x-70)>2.0,"supports avoid actual crossing")
 var forward=City.new(160,160)
 check(road(forward,PackedVector2Array([Vector2(55,53),Vector2(55,97)])).ok,"ground crossing first fixture")
 var state:=city_state(forward)
 var denied:Dictionary=forward.add_center_flyover(spine,levels)
 check(not denied.ok and denied.reason=="수직 간격 부족" and city_state(forward)==state,"reverse-order ramp rejection is also atomic")

func test_warnings_and_profiles():
 var points:=PackedVector2Array([Vector2(30,75),Vector2(78,75)])
 var city=City.new(160,160)
 city.buildings.append({"id":91,"x":72,"y":75,"size":2,"level":1,"zone":"residential","asset_id":""})
 city.buildings.append({"id":90,"x":70,"y":74,"size":2,"level":1,"zone":"residential","asset_id":""})
 city.buildings.append({"id":92,"x":72,"y":79,"size":2,"level":1,"zone":"residential","asset_id":""})
 var heights:=PackedFloat64Array([0,10])
 var before:=city_state(city)
 var warning:Dictionary=city.add_center_flyover(points,heights,false)
 check(warning.ok and warning.warning and warning.demolish_ids==[90,91],"preview reports sorted exact affected IDs")
 check(city_state(city)==before,"warning preview is side-effect free")
 check(not city.add_center_flyover(points,heights).ok and city_state(city)==before,"unconfirmed warning is atomic")
 check(not city.add_center_flyover(points,heights,true,4,true,1,{},[91]).ok and city_state(city)==before,"stale approval is atomic")
 check(city.add_center_flyover(points,heights,true,4,true,1,{},[90,91]).ok and city.buildings.size()==1 and city.buildings[0].id==92,"exact approval commits all three roads and preserves the neighbor")
 var empty=City.new(160,160)
 check(not empty.add_center_flyover(points,PackedFloat64Array([0,5])).ok and empty.roads.is_empty(),"+5m flat target rejected")
 var surface:Dictionary=empty.add_center_flyover(points,PackedFloat64Array([0,0]))
 check(surface.ok and empty.roads.size()==1 and not empty.roads[0].has("center_family"),"surface-only stroke is an ordinary road")
 var multiple:=PackedVector2Array([Vector2(30,75),Vector2(34,75),Vector2(40,75),Vector2(48,75),Vector2(66,75),Vector2(78,75)])
 var fit:Dictionary=City.new(160,160).add_center_flyover(multiple,PackedFloat64Array([0,0,0,0,10,10]))
 check(fit.ok and Height.height_at(fit.new_roads[0],Vector2(66,75))==10,"waypoint samples do not restart cumulative ramp length")

func test_support_continuation():
 for lanes:int in [4,8]:
  for upward_first:bool in [true,false]:
   var city=City.new(160,160)
   var up:=PackedVector2Array([spine[0],spine[1]])
   var down:=PackedVector2Array([spine[1],spine[2]])
   var first:Dictionary=city.add_center_flyover(up if upward_first else down,PackedFloat64Array([0,10] if upward_first else [10,0]),true,lanes)
   var stored:PackedByteArray=var_to_bytes(city.roads)
   var next:Dictionary=city.add_center_flyover(down if upward_first else up,PackedFloat64Array([10,0] if upward_first else [0,10]),true,lanes)
   check(first.ok and next.ok and city.roads.size()==6,"two independent central strokes support the same continuous raised section: "+str([first.reason,next.reason]))
   if not first.ok or not next.ok:continue
   check(var_to_bytes(city.roads.slice(0,3))==stored,"the second edit leaves the committed family and its pier ownership unchanged")
   var x_positions:Array[float]=[]
   for member:Dictionary in [first.new_roads[0],next.new_roads[0]]:
    for station:Dictionary in member.piers:
     x_positions.append(station.positions[0].x)
   x_positions.sort()
   var safe:=x_positions.size()>1
   for i in range(1,x_positions.size()):
    var gap:float=x_positions[i]-x_positions[i-1]
    safe=safe and gap>=4.0-.0001 and gap<=12.0+.0001
   check(safe,"joined support stations follow 16–48m spacing without duplicate piers: "+str(x_positions))
   check(x_positions==[50.0,58.0,66.0,74.0,82.0,90.0],"clear ground retains the 32m phase across the seam in both insertion orders")

func test_fifo_checkpoint():
 var city=City.new(160,160)
 city.population_enabled=false;city.happiness_enabled=false
 var initial:Dictionary=Adapter.capture(city)
 var probe=load("res://core/city_native_mailbox.gd").new()
 probe.Initialize(InspectAdapter.new(),initial);probe.Suspend()
 city.enable_simulation_worker();city.simulation.worker.Suspend()
 city.simulation.edit_completed.connect(func(result):
  replay.append([result.ok,result.get("new_roads",[]).map(func(r):return r.get("parcel_id",-1))])
  journal=city.simulation._make_delta(city))
 city.simulation.worker.SetValidationGate(true);city.advance_society(2)
 var trunk:=PackedVector2Array([Vector2(14,75),spine[0]])
 var after:=PackedVector2Array([spine[-1],Vector2(126,75)])
 var watermark:int=city.next_road_id
 check(road(city,trunk,4).get("queued",false),"worker holds earlier ordinary edit")
 check(city.add_center_flyover(spine,levels).get("queued",false),"whole family queued once")
 check(city.add_center_flyover(spine,levels).get("queued",false),"duplicate family queued for fresh replay validation")
 check(road(city,after,4).get("queued",false),"worker holds later connecting edit")
 check(city.roads.is_empty() and city.next_road_id==watermark,"no early geometry or ID allocation")
 city.simulation.validation_publish();city.simulation.resume();city.advance_society(2);city.simulation.validation_publish()
 check(replay==[[true,[watermark]],[true,[watermark+1,watermark+2,watermark+3]],[false,[]],[true,[watermark+4]]],"FIFO results carry exactly the allocated IDs in request order: "+str(replay))
 check(city.roads.size()==5 and city.next_road_id==watermark+5 and city.road_topology_revision==3,"rejected replay leaves no allocation or topology revision")
 check(journal.get("world",{}).get("roads",[])==city.roads,"production world replacement carries all member and stable portal records")
 if not journal.is_empty():
  var delta:Dictionary=journal.duplicate(true);delta.base_tick=probe.GetPublishedTick();delta.base_revision=probe.GetPublishedRevision()
  check(probe.Submit(delta,2),"native observer accepts production journal")
  probe.Suspend();check(not probe.PublishBoundary().is_empty(),"native observer publishes accepted replacement")
  var state:Dictionary=probe.ExportValidationState()
  check(state.get("roads",[])==city.roads and state.get("next_road_id",-1)==city.next_road_id,"worker preserves membership, links and ID watermark")
  if state.has("checkpoint"):
   var restored=InspectAdapter.new()
   check(restored.boot(state.checkpoint).ok and restored.city.roads==city.roads,"checkpoint restores exact three-road metadata")
   var network:=Network.new()
   check(network.build(restored.city.roads) and network.junctions.is_empty() and network.lanes.any(func(lane):return not lane.next.is_empty()),"restored graph materializes the primitive links")
   check(restored.city.demolish("road",watermark+1).ok and restored.city.roads.size()==4 and network.build(restored.city.roads),"first edit after restoration removes the selected member only")
 check(city.simulation.get_fault().is_empty(),"production worker reports no fault")
 city.simulation.shutdown();probe.Shutdown()

func city_state(city)->PackedByteArray:
 return var_to_bytes([city.roads,city.next_road_id,city.road_topology_revision,city.funds,city.buildings,city.zoning_grid,city.public_facilities.lots])
