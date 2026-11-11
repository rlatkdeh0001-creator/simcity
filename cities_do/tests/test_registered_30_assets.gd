extends SceneTree
var checks:=0
var failed:=0
const NO_ENTRANCE: Array[String]=["power-coal","power-hydro","power-nuclear","power-oil","power-solar","power-wind","water-water-tower"]
func _initialize():run.call_deferred()
func verify(value: bool,detail: String):
 checks+=1
 if value:print("PASS "+detail)
 else:failed+=1;push_error("FAIL "+detail)
func mesh_bounds(model: Node3D) -> AABB:
 var result:=AABB()
 var first:=true
 for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
  var box: AABB=mesh.global_transform*mesh.get_aabb()
  result=box if first else result.merge(box)
  first=false
 return result
func city_state(city) -> String:
 return JSON.stringify([city.funds,city.city_name,city.width,city.height,city.buildings,city.roads,city.junctions,
  city.zone_designations,city.zoning_grid.chunks,city.zoning_grid.frames,city.zoning_grid.parcels,
  city.external_infrastructure,city.power.plants,city.power.wires,city.power.revision,city.power.pending_doth,
  city.water.facilities,city.water.geometry.wires,city.water.geometry.revision,city.water.pending_doth,
  city.population.stats(),city.population.demand(city.buildings),city.clock.caption(),city.next_id,city.next_road_id,
  city.rng.state,city.appearance_rng.state])
func run():
 root.size=Vector2i(1280,820)
 root.gui_embed_subwindows=true
 var path:="res://assets/registered_30.json"
 verify(FileAccess.file_exists(path),"remaining thirty assets have an actual registry")
 if not FileAccess.file_exists(path):quit(1);return
 var doc=JSON.parse_string(FileAccess.get_file_as_string(path))
 verify(doc is Dictionary and doc.assets.size()==30,"registry contains all thirty original asset IDs")
 var entries: Array=doc.assets
 var counts:={}
 for entry: Dictionary in entries:
  counts[entry.group]=counts.get(entry.group,0)+1
  var id: String=entry.id
  verify(FileAccess.file_exists(entry.spec),id+" real spec exists")
  verify(FileAccess.file_exists(entry.preview) and ResourceLoader.exists(entry.model),id+" original preview copy and actual GLB exist")
  verify(not entry.simulation_enabled and not entry.growth_enabled and entry.status=="asset_preview_only",id+" inspection-only status, no growth/operation")
  verify(entry.source_metadata.cell_meters==4 and Vector2(entry.front_axis[0],entry.front_axis[1])==Vector2(0,1),id+" metre/cell convention and +Z front axis")
  var model: Node3D=load(entry.model).instantiate()
  root.add_child(model)
  var actual:=mesh_bounds(model)
  var low: Array=entry.full_bounds_blender[0]
  var high: Array=entry.full_bounds_blender[1]
  var expected:=AABB(Vector3(low[0],low[2],-high[1]),Vector3(high[0]-low[0],high[2]-low[2],high[1]-low[1]))
  verify(actual.position.distance_to(expected.position)<.06 and actual.size.distance_to(expected.size)<.06,id+" GLB round-trip physical W/D/H and ground offset match measured source")
  verify(absf(actual.size.x-entry.width_m)<.05 and absf(actual.size.z-entry.length_m)<.05 and absf(actual.size.y-entry.height_m)<.05,id+" spec reports actual mesh dimensions")
  if id=="power-wind":
   verify(entry.source_metadata.rotor_overhang_allowed and actual.size.x>entry.width*4 and Vector2(entry.footprint_cells[0],entry.footprint_cells[1])==Vector2(2,2),id+" original rotor overhang retained, never resized to 2x2")
  elif id=="power-hydro":
   verify(entry.footprint_cells==null and not entry.fixed_footprint and Vector2(entry.presentation_lot_meters[0],entry.presentation_lot_meters[1])==Vector2(60,32),id+" parametric original retains null fixed footprint and original presentation dimensions")
  else:
   verify(absf(actual.size.x-entry.width*4)<.05 and absf(actual.size.z-entry.depth*4)<.05,id+" actual horizontal extent matches original lot at 4m/cell")
  if not entry.ground_reference_node.is_empty():
   var ground: MeshInstance3D=model.find_child(entry.ground_reference_node,true,false)
   verify(ground!=null and absf((ground.global_transform*ground.get_aabb()).position.y)<.05,id+" original support datum aligned without deleting underground geometry")
  else:verify(absf(actual.position.y)<.05,id+" original lowest support is at zero")
  var marker: Node3D=model.find_child("ServiceFrontage",true,false)
  verify(marker!=null and absf(marker.position.z-entry.depth*2)<.01,id+" exported +Z inspection frontage marker")
  if id in NO_ENTRANCE:
   verify(entry.front_feature_node.is_empty() and entry.frontage_verification=="equipment_convention_only_no_named_entrance",id+" absence of original human entrance is explicit, never claimed verified")
  else:
   var frontage: MeshInstance3D=model.find_child(entry.front_feature_node,true,false)
   var p: Array=entry.front_feature_position_gltf
   var frontage_ok:=frontage!=null
   if frontage_ok:
    var box: AABB=frontage.global_transform*frontage.get_aabb()
    frontage_ok=box.get_center().distance_to(Vector3(p[0],p[1],p[2]))<.05
   verify(frontage_ok and not "Planter" in entry.front_feature_node and not "Label" in entry.front_feature_node,id+" actual authored door/entry geometry survives axis conversion")
  model.free()
 verify(counts=={"commercial":10,"industrial":8,"power":6,"water":4,"waste":2},"all five original groups match requested counts")
 var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/buildings/catalog.json")).buildings
 var private_entries: Array=catalog.filter(func(e):return e.get("recovered_batch","")=="remaining_30")
 verify(private_entries.size()==18 and private_entries.all(func(e):return e.growth_enabled==false),"ten commercial and eight industrial entries remain excluded from growth")
 var building_catalog=preload("res://core/building_catalog.gd").new()
 for entry: Dictionary in private_entries:
  verify(not str(entry.industry).is_empty() and entry.storeys==entry.source_metadata.occupied_storeys,entry.id+" original industry/storey metadata retained")
  verify(not entry.id in building_catalog.eligible({"size":int(entry.width),"level":999,"zone":entry.zone}),entry.id+" cannot be selected by automatic growth")
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/thumbnails/manifest.json"))
 for entry: Dictionary in entries:
  verify(manifest.has(entry.id),entry.id+" derived thumbnail exists in common manifest")
  if manifest.has(entry.id):
   var image: Image=load(str(manifest[entry.id].thumbnail)).get_image()
   verify(image.get_size()==Vector2i(256,192),entry.id+" uses existing 256x192 thumbnail convention")
 var hud=load("res://bottom_ui_preview.tscn").instantiate()
 hud.paused=true
 root.add_child(hud)
 await process_frame
 await process_frame
 verify(hud.has_method("open_registered_asset"),"shared registered-asset route exists")
 if hud.has_method("open_registered_asset"):
  for entry: Dictionary in entries:
   var before:=city_state(hud.city)
   var mode: String=hud.mode
   verify(hud.open_registered_asset(str(entry.id)),entry.id+" shared read-only route opens real GLB inspector")
   var preview: Window=hud.get_node_or_null("ServiceAssetPreview")
   verify(preview!=null and preview.get_meta("asset_id","")==entry.id and preview.find_child("InspectedAssetModel",true,false)!=null,entry.id+" inspector identifies the actual requested model")
   if preview:preview.queue_free()
   await process_frame
   verify(city_state(hud.city)==before and hud.mode==mode,entry.id+" inspection leaves funds, city, infrastructure, demand, RNG and active tool unchanged")
  for tab in ["power","water","environment"]:
   hud.select_category(tab)
   await process_frame
   var expected_entries: Array=entries.filter(func(e):return e.ui_category==tab)
   var cards: Array=hud.drawer_box.get_children().filter(func(n):return n is Button and n.has_meta("registered_asset_id"))
   verify(cards.size()==expected_entries.size(),tab+" has exactly its approved inspection cards")
   for entry: Dictionary in expected_entries:
    var matches: Array=cards.filter(func(n):return n.get_meta("registered_asset_id")==entry.id)
    verify(matches.size()==1,entry.id+" C-card is bound to the real registered entry")
    if matches.size()!=1:continue
    var card: Button=matches[0]
    verify(card.has_node("AssetThumbnail") and card.has_node("NameBand/AssetName") and card.custom_minimum_size==Vector2(128,96),entry.id+" unchanged approved C-card layout")
    var before:=city_state(hud.city)
    var mode: String=hud.mode
    card.pressed.emit()
    var preview: Window=hud.get_node_or_null("ServiceAssetPreview")
    verify(preview!=null and preview.get_meta("asset_id","")==entry.id,entry.id+" actual card click opens its GLB inspector")
    if preview:preview.queue_free()
    await process_frame
    verify(city_state(hud.city)==before and hud.mode==mode,entry.id+" card click never places or charges anything")
    var scroll=card.get_parent().get_parent()
    verify(scroll is ScrollContainer,entry.id+" existing horizontal scroll hosts the new card")
    if scroll is ScrollContainer:scroll.ensure_control_visible(card)
    await process_frame
    var point:=card.get_global_rect().get_center()
    verify(root.get_visible_rect().has_point(point),entry.id+" card remains mouse-accessible after horizontal scrolling")
    before=city_state(hud.city)
    for down in [true,false]:
     var event:=InputEventMouseButton.new()
     event.position=point
     event.button_index=MOUSE_BUTTON_LEFT
     event.pressed=down
     root.push_input(event,true)
    preview=hud.get_node_or_null("ServiceAssetPreview")
    verify(preview!=null and preview.get_meta("asset_id","")==entry.id,entry.id+" real viewport mouse press/release opens the correct inspector")
    if preview:preview.queue_free()
    await process_frame
    verify(city_state(hud.city)==before and hud.mode==mode,entry.id+" real mouse activation is also read-only")
   var original_tools: Array={"power":["power_plant","power_wire"],"water":["water_supply","water_treatment","water_pipe"],"environment":[]}[tab]
   for tool: String in original_tools:
    var old: Button=hud.drawer_box.get_node_or_null("Tool_"+tool)
    verify(old!=null and not old.has_node("AssetThumbnail"),tool+" original placement/drawing tool remains separate from preview cards")
  verify(not hud.open_registered_asset("not-a-real-asset"),"unknown registered ID cannot open or mutate the city")
 hud.free()
 var gallery=load("res://vehicle_showcase.tscn").instantiate()
 gallery.facility_group="commercial_industrial"
 root.add_child(gallery)
 await process_frame
 verify(gallery.entries.size()==18 and gallery.rigs.size()==18,"existing exhibition grid exposes all eighteen commercial/industrial GLBs without a new menu/layout")
 verify(gallery.entries.all(func(e):return e.get("growth_enabled",true)==false and e.get("recovered_batch","")=="remaining_30"),"exhibition uses only actual disabled-growth registered originals")
 gallery.same_scale=true
 gallery.update_scale()
 verify(gallery.cameras.all(func(camera):return is_equal_approx(camera.size,gallery.cameras[0].size)),"existing same-scale switch gives all eighteen models identical metre-to-pixel scale")
 for index in range(gallery.rigs.size()):
  var actual:=mesh_bounds(gallery.rigs[index].get_child(0))
  var camera: Camera3D=gallery.cameras[index]
  verify(camera.global_position.distance_to(actual.get_center())>actual.size.length()/2,gallery.entries[index].id+" inspection camera stays outside the original model")
  var visible:=true
  for corner in range(8):visible=visible and camera.is_position_in_frustum(actual.get_endpoint(corner))
  verify(visible,gallery.entries[index].id+" common-scale framing retains all measured mesh bounds")
 gallery.free()
 print("RESULT %d/%d registered30 checks passed" % [checks-failed,checks])
 quit(1 if failed else 0)
