extends "res://tests/test_happiness.gd"
func run():
 var core=fresh()
 check(core.has_method("CityHappiness"),"city happiness is a cached simulation result")
 if not core.has_method("CityHappiness"):quit(1);return
 check(core.CityHappiness()==null,"no residents has no invented average")
 var a:Dictionary=body(75,100);a.employed=0
 var b:Dictionary=body(150,1000);b.occupants=12;b.eligible=12;b.employed=12
 var business:Dictionary=body(225,1500,1,"commercial");business.occupants=1000
 core.SetWorld([a,b,business],[],PackedFloat64Array([0,0,0,2000,0]));core.Tick(48,PackedInt64Array())
 var weighted:float=(4*20.0+12*50.0)/16
 check(core.CityHappiness()==weighted,"resident weighting, not building average or workplace double counting")
 b.employed=0;core.SetWorld([a,b,business],[],PackedFloat64Array([0,0,0,2000,0]))
 check(core.CityHappiness()==weighted,"world edits do not calculate HUD statistics between simulation ticks")
 core.Tick(48,PackedInt64Array([75,0,1,150,0,1]))
 check(core.CityHappiness()==0,"same-tick supply interruption updates the cached city average")
 core.SetWorld([],[],PackedFloat64Array());core.Tick(48,PackedInt64Array())
 check(core.CityHappiness()==null,"removing all residents restores unknown display")
 root.size=Vector2i(1280,820)
 var game=load("res://main.tscn").instantiate();game.paused=true;game.set_process(false);root.add_child(game);await process_frame
 check(game.happiness_label.name=="HappinessValue" and game.happiness_label.text=="—","empty-city approved happiness slot stays a dash")
 game.queue_free();await process_frame
 game=load("res://main.tscn").instantiate();game.paused=true;game.set_process(false)
 var city=game.city
 city.buildings.append({"id":75,"x":10,"y":10,"size":2,"level":1,"zone":"residential","score":0.0,"asset_id":""})
 city.population.import_fixture_state({"people":[{"id":1,"household_id":1,"age_years":30.0,"education":0,"origin":"test","workplace_id":-1,"job_stage":-1}],"households":[{"id":1,"home_id":75}],"workplaces":{},"next_person":2,"next_household":2})
 root.add_child(game);await process_frame
 while not city.simulation.is_ready():await process_frame
 city.advance_society(2);city.simulation.validation_publish();city.simulation.resume()
 check(game.happiness_label.text=="0","simulation result drives existing icon-plus-number HUD without explanatory text")
 var refreshes:int=game.hud_refresh_count
 game.refresh_status();game.refresh_status()
 check(game.hud_refresh_count==refreshes,"unchanged values do not reassign HUD contents")
 city.buildings[0].happiness=99;game.refresh_status()
 check(game.happiness_label.text=="0","HUD reads cached simulation average, not per-frame building scans")
 city.demolish("building",75)
 city.advance_society(2);city.simulation.validation_publish();city.simulation.resume()
 check(game.happiness_label.text=="—","no housed residents returns the existing dash through a published demolition")
 game.queue_free();await process_frame
 for script in ["power_overlay.gd","water_overlay.gd"]:
  var source:String=FileAccess.get_file_as_string("res://core/"+script)
  check(not source.contains("draw_string("),"production map renderer contains no facility-name text: "+script)
 print("RESULT %d/%d happiness HUD and map-label checks passed"%[passed,passed+failed]);quit(1 if failed else 0)
