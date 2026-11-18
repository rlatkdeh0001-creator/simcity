extends RefCounted
# Real placed stations and authored continuous turnaround loops. No capture side effects.
static func rail_city(kind:String="rail"):
 var city=load("res://core/city_model.gd").new(120,120,42)
 city.population_enabled=false;city.happiness_enabled=false
 city.add_road(PackedVector2Array([Vector2(2,40),Vector2(110,40)]),"local",true,4)
 var asset:String="subway-entrance-01" if kind=="metro" else "train-station-01"
 var y:float=36.5 if kind=="metro" else 33.0
 for x:float in [30.0,70.0]:
  var placed:Dictionary=city.public_facilities.place(asset,Vector2(x,y),0,true)
  assert(placed.ok,str(placed))
 var a:PackedVector2Array=city.public_facilities.lots[0].internal_points
 var b:PackedVector2Array=city.public_facilities.lots[1].internal_points
 if a[0].x>a[-1].x:a.reverse()
 if b[0].x>b[-1].x:b.reverse()
 var join:Dictionary=city.add_transit_route(PackedVector2Array([a[-1],b[0]]),kind)
 assert(join.ok,str(join))
 var path:=PackedVector2Array([b[-1],Vector2(94,a[0].y)])
 for i in range(1,49):
  var angle:float=-PI/2+PI*i/48
  path.append(Vector2(94,a[0].y+15)+Vector2(cos(angle),sin(angle))*15)
 path.append(Vector2(16,a[0].y+30))
 for i in range(1,49):
  var angle:float=PI/2+PI*i/48
  path.append(Vector2(16,a[0].y+15)+Vector2(cos(angle),sin(angle))*15)
 path.append(a[0])
 var loop:Dictionary=city.add_transit_route(path,kind)
 assert(loop.ok,str(loop))
 return city
static func populate(game,kind:String="rail",accepted_steps:int=3)->Dictionary:
 if game.city.simulation!=null:game.city.simulation.shutdown()
 game.city=load("res://tests/test_scheduled_buses.gd").fixture(4) if kind=="bus" else rail_city("metro" if kind=="metro" else "rail")
 var ids:Array=game.city.public_facilities.lots.map(func(lot):return lot.id)
 var result:Dictionary=game.city.create_transit_line(kind,ids)
 assert(result.ok,str(result))
 game.city.enable_simulation_worker();game.city.simulation.worker.Suspend()
 for i in range(accepted_steps):
  game.city.simulation.resume();game.city.advance_society(game.city.config.development_interval_seconds);game.city.simulation.validation_publish()
 game.city.simulation.resume();game.paused=true
 game.map_zoom=.7;game.origin=Vector2(620,-100)
 game.public_controller.cancel();game.select_category("transport")
 if kind=="metro":game.activate_tool("metro")
 else:game.mode="select"
 game.world_renderer.synchronize();game.refresh()
 return {"kind":kind,"line":result.line,"snapshot":game.city.transit_snapshot()}
