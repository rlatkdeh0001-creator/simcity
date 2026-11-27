extends SceneTree
var checks:=0
var failures:=0
func verify(value: bool,label: String):
 checks+=1
 if value:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.paused=true;game.city.population_enabled=false
 var road:Dictionary=game.city.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"local",true,4)
 verify(road.ok and is_equal_approx(float(game.city.roads[0].width),5.0),"four-lane fixture has the approved five-cell sidewalk-inclusive width")
 root.add_child(game);await process_frame
 game.city.simulation.worker.Suspend() # Wait for boot so the click is an idle worker edit.
 # Centre y=40, half-road width 2.5, half of the 6x6 lot 3.0.
 var north:=Vector2(12,34.5)
 var south:=Vector2(28,45.5)
 # Offset along the curb normal only, so along-road rounding cannot change
 # the distance to the candidate center used by the two-cell snap test.
 const SNAP_INSIDE := 1.999
 const SNAP_OUTSIDE := 2.001
 var controller=game.public_controller;controller.begin("fire-station")
 game.pointer=north+Vector2.UP*SNAP_INSIDE
 var result: Dictionary=controller.preview()
 verify(result.ok,"north cursor 1.999 cells from snapped center acquires valid road frontage")
 verify(result.record.position.distance_to(north)<.001,"6x6 ghost front sits on sidewalk edge, not rounded free cursor")
 verify(result.record.front_direction.distance_to(Vector2.DOWN)<.001,"snapped actual model front faces road")
 verify(game.city.funds==50000 and game.city.public_facilities.lots.is_empty(),"snapping preview has no debit or placement side effect")
 # Final frontage measures the lot edge, not the cursor-to-center distance.
 const FRONTAGE_LIMIT := 1.5/4.0
 var frontage: float=game.city.config.road_access_distance
 var at_limit: PackedVector2Array=game.city.public_facilities.polygon(north+Vector2.UP*FRONTAGE_LIMIT,6,6,0)
 var over_limit: PackedVector2Array=game.city.public_facilities.polygon(north+Vector2.UP*(FRONTAGE_LIMIT+.001),6,6,0)
 verify(is_equal_approx(frontage,FRONTAGE_LIMIT)
  and game.city.Frontage.candidates(at_limit,game.city.roads,frontage).any(func(candidate):return is_equal_approx(float(candidate.gap),FRONTAGE_LIMIT))
  and game.city.Frontage.candidates(over_limit,game.city.roads,frontage).is_empty(),"final lot frontage accepts 1.5m at the sidewalk and rejects 1.504m independently of cursor snap")
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=game.screen(game.pointer);event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
 await process_frame
 verify(controller.last_result.get("ok",false) and game.city.public_facilities.lots.size()==1,"actual world click commits the snapped ghost instead of original cursor")
 if not game.city.public_facilities.lots.is_empty():verify(game.city.public_facilities.lots[0].position.distance_to(north)<.001 and game.city.funds==30000,"committed snapped position matches ghost and charges exactly once")
 controller.begin("fire-station");game.pointer=south+Vector2.DOWN*SNAP_INSIDE;result=controller.preview()
 verify(result.ok and result.record.position.distance_to(south)<.001 and result.record.front_direction.distance_to(Vector2.UP)<.001,"south cursor 1.999 cells away snaps to the opposite curb and reverses facing")
 controller.turns=1;result=controller.preview()
 verify(result.record.front_direction.distance_to(Vector2.UP.rotated(PI/2))<.001 and not result.ok,"R is relative to snapped road orientation and still validates frontage")
 controller.turns=0
 for side in [[north,Vector2.UP,"north"],[south,Vector2.DOWN,"south"]]:
  game.pointer=side[0]+side[1]*SNAP_OUTSIDE
  result=controller.preview()
  verify(game.city.public_facilities.road_anchor("fire-station",game.pointer).is_empty() and not result.ok and result.has("record") and result.record.position.distance_to(side[0])>.001,"%s cursor 2.001 cells from snapped center does not acquire the curb" % side[2])
 game.pointer=Vector2(28,28);result=controller.preview()
 verify(not result.ok and result.record.position.distance_to(game.pointer)<.001,"far from road stays freely movable and invalid")
 game.queue_free();await process_frame
 for points in [PackedVector2Array([Vector2(40,5),Vector2(40,90)]),PackedVector2Array([Vector2(10,20),Vector2(80,60)]),PackedVector2Array([Vector2(10,60),Vector2(40,60),Vector2(70,69)])]:
  var city=preload("res://core/city_model.gd").new(100,100,42)
  city.add_road(points,"local",true,4)
  var tested:=false
  for frame in city.zoning_grid.frames.values():
   if frame.columns<6:continue
   var center: Vector2=frame.origin+frame.along*4+frame.outward*3
   var probe: Dictionary=city.public_facilities.preview("fire-station",center+frame.outward*1.4,0,true)
   if not probe.ok:continue
   verify(probe.record.position.distance_to(center)<.001 and probe.record.front_direction.dot(-frame.outward)>.999,"vertical/diagonal/curved polyline uses its real local road frame")
   verify(absf(city.Parcels.area(probe.record.polygon)-36)<.001,"snapping preserves real square 6x6 lot area")
   verify(city.Frontage.candidates(probe.record.polygon,city.roads,city.config.road_access_distance).any(func(c):return c.gap<=.3755),"snapped front still obeys original 1.5m frontage, not acquisition distance")
   tested=true;break
  verify(tested,"each angled road fixture has a valid near-front snap")
 var highway=preload("res://core/city_model.gd").new(100,100,42)
 highway.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"highway",true,4)
 verify(highway.public_facilities.road_anchor("fire-station",Vector2(12,33.4)).is_empty() and not highway.public_facilities.preview("fire-station",Vector2(12,33.4),0,true).ok,"highway never attracts public ghost or grants frontage")
 print("RESULT %d/%d public road snap checks passed" % [checks-failures,checks]);quit(1 if failures else 0)
