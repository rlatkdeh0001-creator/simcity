extends RefCounted
## Parent-owned capture fixture. Not a SceneTree entry point; never captures images.
static func populate(game)->Array[Dictionary]:
 if game.city.simulation!=null:game.city.simulation.shutdown()
 game.city=load("res://core/city_model.gd").new(100,100,42)
 game.city.population_enabled=false;game.city.happiness_enabled=false;game.paused=true
 game.map_zoom=.65;game.origin=Vector2(620,-100)
 var results:Array[Dictionary]=[]
 results.append(game.city.add_road(PackedVector2Array([Vector2(2,40),Vector2(94,40)]),"local",true,4))
 for item in [["train-station-01",Vector2(30,33)],["train-station-01",Vector2(60,47)],["bus-station-01",Vector2(50,35)],["park-large-8x8",Vector2(77,46.5)],["bus-stop-01",Vector2(15,37.8125)],["subway-entrance-01",Vector2(85,36.5)]]:
  results.append(game.city.public_facilities.place(item[0],item[1],0,true))
 results.append(game.city.add_transit_route(PackedVector2Array([Vector2(10,30.5),Vector2(26,30.5)]),"rail"))
 results.append(game.city.add_transit_route(PackedVector2Array([Vector2(34,30.5),Vector2(66,30.5)]),"rail"))
 game.public_controller.cancel();game.mode="select";game.drawer.hide();game.world_renderer.synchronize();game.refresh()
 return results
