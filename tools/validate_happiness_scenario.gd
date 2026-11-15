extends SceneTree
const Model=preload("res://core/city_model.gd")
var city
var game
var homes:Array[Dictionary]=[]
var captured:=false
func _initialize():run.call_deferred()
func private_near(point:Vector2,zone:String,size:int=2)->Dictionary:
 var parcels:Array=city.zoning_grid.parcels.values().filter(func(p):return p.v==0)
 parcels.sort_custom(func(a,b):return a.center.distance_squared_to(point)<b.center.distance_squared_to(point))
 for p in parcels:
  if p.center.distance_to(point)>6:continue
  var result:Dictionary=city.add_building_at(p.center,zone,0,size)
  if result.ok:return result.building
 assert(false,"authored scenario lacks a legal lot near "+str(point));return {}
func public_near(asset:String,point:Vector2):
 var result:Dictionary=city.public_facilities.place(asset,point,0,true)
 assert(result.ok,"public facility placement failed "+asset+" "+str(result));return result.record
func setup():
 city=Model.new(180,240,20261115);city.funds=2000000
 # Controlled immigration education profile isolates services/buffering from labor-band shortages.
 city.population.config.immigrant_education_weights=[0,1,0,0,0]
 for y in [45,115,185]:assert(city.add_road(PackedVector2Array([Vector2(12,y),Vector2(150,y)])).ok)
 var people:Array=[];var households:Array=[]
 for district in range(3):
  var y:float=[45,115,185][district]
  var home:Dictionary=private_near(Vector2(50,y+3),"residential");homes.append(home)
  private_near(Vector2(70,y+3),"industrial")
  for x in [90,110,130]:private_near(Vector2(x,y+3),"commercial",4)
  for h in range(2):
   var household:int=households.size()+1;households.append({"id":household,"home_id":home.id})
   for adult in range(2):people.append({"id":people.size()+1,"household_id":household,"education":1,"age_years":30.0,"origin":"scenario","workplace_id":-1,"job_stage":-1})
  if district>0:
   public_near("medical-large-hospital",Vector2(90,y-6));public_near("police-station",Vector2(110,y-5));public_near("small-fire-station",Vector2(130,y-4))
  if district==2:public_near("park-garden-2x2",Vector2(60,y+3))
  var source:=Vector2(18,y+13)*4
  assert(city.power.add_plant(source,100000)>=0)
  assert(city.power.add_wire(PackedVector2Array([source,Vector2(18,y)*4,Vector2(150,y)*4])).ok)
  var intake:=Vector2(12,y+13)*4;var sewage:=Vector2(12,y+17)*4
  assert(city.water.add_facility(intake,"water",100000)>=0);assert(city.water.add_facility(sewage,"sewage",100000)>=0)
  assert(city.water.add_pipe(PackedVector2Array([intake,sewage,Vector2(18,y)*4,Vector2(150,y)*4])).ok)
 city.population.import_fixture_state({"people":people,"households":households,"workplaces":{},"next_person":people.size()+1,"next_household":households.size()+1});city.population.sync(city.buildings)
 city.advance_utilities(0)
 for home in homes:assert(home.has_power and home.has_water,"real network supply, not forced happiness flags")
func run():
 create_timer(110).timeout.connect(func():push_error("Happiness scenario deadline");quit(1))
 setup()
 root.mode=Window.MODE_EXCLUSIVE_FULLSCREEN;root.size=Vector2i(1920,1080);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 game=load("res://main.tscn").instantiate();game.city=city;game.paused=true;root.add_child(game);current_scene=game
 for i in range(7350):
  city.advance_utilities(2);city.advance_society(2)
  if i%300==0:await RenderingServer.frame_post_draw
 var levels:Array=[];var targets:Array=[];var pollution:Array=[]
 for home in homes:levels.append(home.level);targets.append(home.happiness_target);pollution.append(home.happiness_factors.pollution_noise)
 print("HAPPINESS_SCENARIO_STATE ",JSON.stringify({"levels":levels,"targets":targets,"pollution":pollution}))
 if levels!=[1,4,5]:push_error("facilities and a physical park buffer must change real automatic stage growth");quit(1);return
 assert(pollution==[-10.0,-10.0,-5.0],"park buffer halves only its local source")
 for home in homes:assert(home.has_power and home.has_water)
 game.map_zoom=.32;game.origin=Vector2.ZERO;game.origin=Vector2(960,470)-game.screen(Vector2(85,115));game.drawer.hide();game.mode="select";game.refresh();game.queue_redraw()
 for i in range(10):await RenderingServer.frame_post_draw
 var title:=Label.new();title.position=Vector2(35,24);title.add_theme_font_size_override("font_size",24);title.text="Happiness / automatic growth - same jobs and utilities, 4 game days";root.add_child(title)
 var labels:Array=["No services","Services","Services + park buffer"]
 for i in range(3):
  var label:=Label.new();var home:Dictionary=homes[i]
  var center:=Vector2.ZERO
  for p in city.footprint(home):center+=p
  center/=4
  label.position=game.screen(center)+Vector2(-90,-95);label.add_theme_font_size_override("font_size",20)
  label.add_theme_color_override("font_shadow_color",Color.BLACK);label.add_theme_constant_override("shadow_offset_x",2);label.add_theme_constant_override("shadow_offset_y",2)
  label.text="%s\nLevel %d | happiness %.0f\nPollution %.0f"%[labels[i],home.level,home.happiness,home.happiness_factors.pollution_noise];root.add_child(label)
 await RenderingServer.frame_post_draw
 var folder:="D:/project/simcity/docs/happiness-validation";DirAccess.make_dir_recursive_absolute(folder)
 var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1920,1080));assert(image.save_png(folder+"/facilities-park-buffer-1920.png")==OK);captured=true
 var file:=FileAccess.open(folder+"/scenario.json",FileAccess.WRITE);file.store_string(JSON.stringify({"levels":levels,"targets":targets,"pollution":pollution,"game_seconds":city.clock.game_seconds,"real_supply":true,"homes":homes,"stats":city.population.stats()},"  "));file.close()
 print("HAPPINESS_SCENARIO_PASS levels=",levels," targets=",targets," pollution=",pollution)
 game.queue_free();await process_frame;quit()
