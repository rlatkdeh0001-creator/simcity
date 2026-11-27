extends "D:/project/simcity/tools/validate_happiness_scenario.gd"
func run():
 # Functional screenshot only: no FPS, frame-time, trace or tick-cost sampling.
 Engine.max_fps=60
 setup()
 for i in range(75):city.advance_utilities(2);city.advance_society(2)
 assert(city.population.stats().population>0 and city.happiness.city_average!=null)
 root.mode=Window.MODE_EXCLUSIVE_FULLSCREEN;root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();game.city=city;game.paused=true;root.add_child(game);current_scene=game
 game.map_zoom=.32;game.origin=Vector2.ZERO;game.origin=Vector2(960,470)-game.screen(Vector2(85,115));game.drawer.hide();game.mode="select";game.refresh();game.queue_redraw()
 for i in range(8):await RenderingServer.frame_post_draw
 assert(game.happiness_label.text==str(city.happiness.city_average))
 assert(not game.power_overlay.tab_open and not game.water_overlay.tab_open)
 var folder:="D:/project/simcity/docs/happiness-hud-validation";DirAccess.make_dir_recursive_absolute(folder)
 var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1920,1080));assert(image.save_png(folder+"/resident-happiness-1920.png")==OK)
 var file:=FileAccess.open(folder+"/native.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"resident_population":city.population.stats().population,"happiness":city.happiness.city_average,"display":game.happiness_label.text,"prototype_power_plants":city.power.plants.size(),"prototype_water_facilities":city.water.facilities.size(),"performance_measurements":false},"  "));file.close()
 print("HAPPINESS_HUD_NATIVE_PASS population=",city.population.stats().population," happiness=",game.happiness_label.text," performance_measurements=false")
 game.queue_free();await process_frame;quit()
