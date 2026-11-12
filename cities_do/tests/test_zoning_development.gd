extends SceneTree
const Model=preload("res://core/city_model.gd")
var checked := 0
var failed := 0
func verify(value: bool, detail: String) -> void:
 checked+=1
 if value:print("PASS "+detail)
 else:
  failed+=1
  push_error("FAIL "+detail)
func town(diagonal: bool=false):
 var city=Model.new(60,60,42)
 city.population_enabled=false
 city.add_road(PackedVector2Array([Vector2(10,30),Vector2(42,42) if diagonal else Vector2(42,30)]))
 return city
func paint(city,frame,u: int,v: int,size: int,zone: String):
 return city.paint_zones(city.Parcels.polygon(frame,u,v,size),zone)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var c=town()
 var frame: Dictionary=c.zoning_grid.frames.values()[0]
 verify(paint(c,frame,0,0,4,"residential").changed==16,"paint sixteen road-local cells")
 verify(c.buildings.is_empty() and c.funds==50000,"designation is free and does not construct immediately")
 verify(c.advance_development(0).is_empty() and c.advance_development(-1).is_empty(),"pause and negative delta cannot develop")
 verify(c.advance_development(1).is_empty(),"construction waits for complete game-time interval")
 verify(c.advance_development(1).size()==1,"one tick develops one eligible largest initial lot")
 var b: Dictionary=c.buildings[0]
 verify(b.size==4 and b.level==1 and b.zone=="residential" and b.automatically_developed,"wide zoning records automatic stage1 4x4 origin")
 verify(c.parcel_placement_error(b.frame,b.u,b.v,b.size,b.id)=="" and b.front_road_id==0,"automatic placement uses shared frontage collision checks")
 verify(b.asset_id in ["small-4x4-a","small-4x4-b"] and c.catalog.get_asset(b.asset_id).density=="small","wide new construction uses a real small 4x4 original, never a mansion")
 var before: Dictionary=b.duplicate(true)
 paint(c,frame,0,0,4,"commercial")
 verify(c.buildings[0]==before,"repainting preserves existing building ID zone frontage and model")
 paint(c,frame,0,0,4,"")
 verify(c.zone_designations.is_empty() and c.buildings[0]==before,"zone erasure does not demolish buildings")
 b.score=100
 verify(not c.upgrade_chain(b.id).ok,"automatic building cannot grow into erased or differently zoned cells")
 verify(c.advance_development(100).is_empty() and c.funds==50000,"unpainted land cannot develop or charge construction fees")
 var mixed=town()
 frame=mixed.zoning_grid.frames.values()[0]
 paint(mixed,frame,0,0,2,"commercial")
 paint(mixed,frame,1,0,1,"") # Mixed fixture must erase before changing an existing designation.
 paint(mixed,frame,1,0,1,"industrial")
 verify(mixed.advance_development(2).is_empty(),"mixed-use 2x2 cells cannot form one building")
 verify(paint(mixed,frame,0,0,2,"industrial").changed==0,"mixed existing designations cannot be overwritten to force uniform development")
 paint(mixed,frame,0,0,2,"")
 paint(mixed,frame,0,0,2,"industrial")
 verify(mixed.advance_development(2).size()==1 and mixed.buildings[0].zone=="industrial","industrial zones develop without residential facade substitution")
 verify(not mixed.buildings[0].asset_id.is_empty() and mixed.catalog.get_asset(mixed.buildings[0].asset_id).zone=="industrial" and mixed.catalog.get_asset(mixed.buildings[0].asset_id).density=="small","industrial development uses its own real small facade instead of a temporary block")
 var deep=town()
 frame=deep.zoning_grid.frames.values()[0]
 paint(deep,frame,0,2,2,"residential")
 verify(deep.advance_development(2).is_empty(),"deep zoning never bypasses 1.5 metre frontage rule")
 for diagonal in [false,true]:
  var city=town(diagonal)
  for f in city.zoning_grid.frames.values():paint(city,f,0,0,2,"commercial")
  city.advance_development(16)
  verify(not city.buildings.is_empty() and city.buildings.all(func(lot):return city.parcel_placement_error(lot.frame,lot.u,lot.v,2,lot.id)==""),"both road sides develop valid lots diagonal="+str(diagonal))
 var a=town()
 var d=town()
 for city in [a,d]:
  for f in city.zoning_grid.frames.values():paint(city,f,0,0,4,"residential")
 for i in range(8):a.advance_development(.5)
 d.advance_development(4)
 verify(a.buildings==d.buildings,"development is deterministic across frame rates")
 var surviving: Dictionary=a.zone_designations.duplicate()
 a.add_road(PackedVector2Array([Vector2(10,50),Vector2(42,50)]))
 verify(surviving.keys().all(func(id):return a.zone_designations.get(id)==surviving[id]),"adding separate road preserves painted stable parcel IDs")
 var count: int=a.buildings.size()
 a.demolish("road",0)
 verify(a.buildings.size()==count and not a.zone_designations.keys().any(func(id):return id.begins_with("0:")),"road demolition prunes removed designations without moving buildings")
 var fairness=town()
 var families := ["residential","commercial","industrial"]
 var index := 0
 for f in fairness.zoning_grid.frames.values():
  paint(fairness,f,0,0,2,families[index%3])
  index+=1
 for i in range(6):fairness.advance_development(16)
 verify(families.all(func(z):return fairness.buildings.any(func(lot):return lot.zone==z)),"bounded round-robin scanning develops all three zoning types")
 var lots: Array=fairness.buildings.duplicate(true)
 fairness.advance_development(16)
 verify(fairness.buildings==lots,"occupied zones cannot repeatedly spawn overlapping buildings")
 var highway=Model.new(40,40,42)
 highway.add_road(PackedVector2Array([Vector2(2,20),Vector2(38,20)]),"highway")
 verify(highway.zoning_grid.count()==0 and highway.advance_development(2).is_empty(),"highway cannot create development frontage")
 # Exercise the actual bottom category buttons and captured map gesture.
 var scene=load("res://bottom_ui_preview.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 scene.city=town()
 scene.select_category("build")
 var zone_tools: Array=scene.drawer_box.get_children().filter(func(n):return n.name in ["Tool_build","Tool_build_commercial","Tool_build_industrial","Tool_build_erase"])
 verify(zone_tools.size()==4,"zoning tab provides three zone tools and one eraser alongside retained actions")
 var tool=scene.drawer_box.find_child("Tool_build_commercial",false,false)
 tool.pressed.emit()
 verify(scene.mode=="build" and scene.zone=="commercial","commercial button selects drag brush")
 frame=scene.city.zoning_grid.frames.values()[0]
 var poly: PackedVector2Array=scene.city.Parcels.polygon(frame,0,0,4)
 var selection_rect := Rect2(scene.screen(poly[0]),Vector2.ZERO)
 for corner in poly:selection_rect=selection_rect.expand(scene.screen(corner))
 var first: Vector2=scene.screen(frame.origin+(frame.along+frame.outward)*.5)
 var last: Vector2=scene.screen(frame.origin+(frame.along+frame.outward)*3.5)
 var press := InputEventMouseButton.new()
 press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=first
 scene._unhandled_input(press)
 verify(scene.zoning_drag and scene.city.zone_designations.is_empty(),"mouse press starts preview only")
 scene.finish_zoning(last,true)
 verify(scene.city.zone_designations.is_empty(),"release above HUD cancels captured paint")
 scene._unhandled_input(press)
 scene.select_category("water")
 verify(not scene.zoning_drag and scene.city.zone_designations.is_empty(),"tab switch cancels pending drag")
 scene.select_category("build")
 tool=scene.drawer_box.find_child("Tool_build_commercial",false,false)
 tool.pressed.emit()
 scene._unhandled_input(press)
 var motion := InputEventMouseMotion.new()
 motion.position=last
 scene._input(motion)
 var release := InputEventMouseButton.new()
 release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;release.position=last
 scene._input(release)
 scene._unhandled_input(release)
 verify(not scene.zoning_drag,"captured mouse release commits exactly once")
 verify(not scene.city.zone_designations.is_empty() and scene.city.buildings.is_empty(),"drag release paints without clicking a building")
 scene.paused=true
 scene._process(3)
 verify(scene.city.buildings.is_empty(),"bottom pause stops automatic construction")
 scene.paused=false;scene.simulation_speed=3
 scene._process(2.0/3)
 verify(scene.city.buildings.size()==1,"3x advances automatic development in game seconds")
 scene.drawer_box.find_child("Tool_build_erase",false,false).pressed.emit()
 verify(scene.zone=="" and scene.mode=="build","eraser uses zoning brush instead of bulldozer")
 scene._unhandled_input(press)
 var escape := InputEventKey.new()
 escape.keycode=KEY_ESCAPE;escape.pressed=true
 scene._unhandled_key_input(escape)
 verify(not scene.zoning_drag,"Escape cancels active drag")
 scene._unhandled_input(press)
 var right := InputEventMouseButton.new()
 right.button_index=MOUSE_BUTTON_RIGHT;right.pressed=true
 scene._unhandled_input(right)
 verify(not scene.zoning_drag,"right click cancels active drag")
 scene.select_category("power")
 verify(not scene.show_zoning_tiles(),"zoning overlay is hidden outside zoning and road tabs")
 scene.queue_free()
 await process_frame
 print("RESULT %d/%d zoning checks passed" % [checked-failed,checked])
 quit(1 if failed else 0)
