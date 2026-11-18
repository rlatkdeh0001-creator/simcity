extends "res://tests/test_transit_commuting.gd"
# Untimed native-worker regression; inherited SceneTree entry calls this run only.
func step(city):
 city.simulation.resume();city.advance_society(2);city.simulation.validation_publish()
func bus_flows(city,line_id:int)->bool:
 return city.commuting.last_plan.get("flows",[]).any(func(flow):return flow.get("route",{}).get("legs",[]).any(func(leg):return leg.get("line_id",-1)==line_id))
func test_replacement(kind:String):
 var city=load("res://tests/transit_operations_fixture.gd").rail_city(kind)
 city.width=320;city.height=180
 var p:PackedVector2Array=city.public_facilities.lots[0].internal_points
 var left:Vector2=p[0] if p[0].x<p[-1].x else p[-1]
 check(city.add_transit_route(PackedVector2Array([Vector2(0,left.y),Vector2(16,left.y)]),kind).ok,kind+" regional boundary connected")
 check(city.create_transit_line(kind,city.public_facilities.lots.map(func(lot):return lot.id)).ok,kind+" passenger line created")
 for pair:Array in [[Vector2(110,40),Vector2(300,40)],[Vector2(300,40),Vector2(300,100)],[Vector2(300,100),Vector2(2,100)],[Vector2(2,100),Vector2(2,40)]]:
  check(city.add_road(PackedVector2Array(pair),"local",true,4).ok,"bus returning road placed")
 var stops:Array=[]
 for x:float in [90.0,250.0]:
  var stop:Dictionary=city.public_facilities.place("bus-stop-01",Vector2(x,42.1875),0,true)
  check(stop.ok,"physical transfer bus stop placed")
  if not stop.ok:return
  stops.append(stop.record.id)
 var created:Dictionary=city.create_transit_line("bus",stops,{"dwell_seconds":1.0})
 check(created.ok,"initial bus line created")
 var old_id:int=created.line.id
 var work:Dictionary={}
 for parcel:Dictionary in city.zoning_grid.parcels.values():
  if parcel.center.x<260 or parcel.center.y<40 or parcel.center.y>50:continue
  work=city.add_building_at(parcel.center,"industrial")
  if work.ok:break
 check(work.get("ok",false),"remote workplace beyond station walking access")
 city.population.sync(city.buildings)
 city.population_enabled=true
 city.enable_simulation_worker();city.simulation.worker.Suspend()
 step(city)
 check(city.commuting_status().inbound>0 and bus_flows(city,old_id),kind+" native inbound uses bus transfer")
 check(city.transit_state.bus.get("vehicles",[]).size()==1,"old bus occupies original topology")
 city.simulation.resume()
 check(city.add_road(PackedVector2Array([Vector2(140,140),Vector2(160,140)]),"local",true,4).ok,"real topology edit blocks occupied bus")
 step(city)
 check(city.transit_state.lines[old_id].status=="blocked","occupied old bus remains topology blocked")
 check(not bus_flows(city,old_id) and city.commuting_status().inbound==0,"blocked transfer is not eligible")
 var day:int=city.clock.day()
 city.simulation.resume()
 check(city.remove_transit_line(old_id).ok,"remove blocked line at idle boundary")
 var replacement:Dictionary=city.create_transit_line("bus",stops,{"dwell_seconds":1.0})
 check(replacement.ok,"create valid replacement before next worker step")
 var new_id:int=replacement.line.id
 var before_seconds:float=city.transit_state.seconds
 step(city)
 check(city.transit_state.lines[new_id].status!="blocked" and city.transit_state.bus.vehicles.all(func(v):return v.line_id==new_id),"same boundary discards stale vehicles and operates replacement")
 check(is_equal_approx(city.transit_state.seconds,before_seconds+2),"replacement advances operational time exactly once")
 check(city.commuting_status().inbound>0 and bus_flows(city,new_id),kind+" replacement selected at first eligible boundary")
 var Adapter=load("res://core/city_simulation_worker.gd")
 var saved:Dictionary=Adapter.capture(city)
 check(not saved.is_empty(),"replacement checkpoint captured at idle boundary")
 var restored=Adapter.new();check(restored.boot(saved).ok,"replacement checkpoint boots")
 var expected:Dictionary=restored.run_step({"base_tick":0,"base_revision":0},2.0,1)
 for i in range(3):
  step(city)
  check(city.clock.day()==day and city.commuting_status().inbound>0 and bus_flows(city,new_id),kind+" eligible transfer remains selected without unrelated dirty/day "+str(i))
  if i==0:
   check(expected.commuting_summary==city.commuting_status() and restored.city.commuting.last_plan==city.commuting.last_plan,"checkpoint preserves exact commuting choice")
   check(expected.transit_state==city.transit_state,"checkpoint preserves exact single-advance vehicle continuation")
 city.simulation.shutdown()
func run():
 for kind:String in ["rail","metro"]:test_replacement(kind)
 print("TRANSIT_COMMUTING_BUS_REPLACEMENT checks=%d failed=%d"%[checks,failed]);quit(1 if failed else 0)
