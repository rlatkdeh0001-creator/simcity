extends SceneTree
func _initialize() -> void:run.call_deferred()
func capture(path: String) -> void:
 for i in range(3):await process_frame
 await RenderingServer.frame_post_draw
 var error := root.get_texture().get_image().save_png(path)
 if error!=OK:push_error("Capture failed "+str(error))
func run() -> void:
 root.size=Vector2i(1800,1100)
 var scene=load("res://bottom_ui_preview.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 scene.city=scene.Model.new(64,64,42)
 for y in [18,34,50]:scene.city.add_road(PackedVector2Array([Vector2(12,y),Vector2(52,y)]))
 scene.power_snapshot=scene.city.power_state()
 scene.water_snapshot=scene.city.water_state()
 scene.power_overlay.queue_redraw()
 scene.water_overlay.queue_redraw()
 scene.paused=true
 scene.select_category("build")
 scene.fit_preview()
 var zones := ["residential","commercial","industrial"]
 var painted := {}
 for frame in scene.city.zoning_grid.frames.values():
  if not frame.id.split(":")[1]=="1":continue
  var zone_type: String=zones[int(frame.road_index)]
  scene.drawer_box.find_child("Tool_"+{"residential":"build","commercial":"build_commercial","industrial":"build_industrial"}[zone_type],false,false).pressed.emit()
  var poly: PackedVector2Array=scene.city.Parcels.polygon(frame,0,0,4)
  var rect := Rect2(scene.screen(poly[0]),Vector2.ZERO)
  for corner in poly:rect=rect.expand(scene.screen(corner))
  var press := InputEventMouseButton.new()
  press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=rect.position-Vector2.ONE
  scene._unhandled_input(press)
  scene.finish_zoning(rect.end+Vector2.ONE)
  painted[zone_type]=true
 await capture("/workspace/simcity/docs/zoning-validation/zones-painted.png")
 for i in range(6):scene.city.advance_development(16)
 scene.refresh()
 scene.power_overlay.queue_redraw()
 scene.water_overlay.queue_redraw()
 await capture("/workspace/simcity/docs/zoning-validation/zones-developed.png")
 var counts := {}
 for b in scene.city.buildings:counts[b.zone]=counts.get(b.zone,0)+1
 var manifest := {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"source":"Actual Godot bottom_ui_preview renderer; input-driven rectangle designation and model development; no generated image or compositing","zone_cells":scene.city.zone_designations.size(),"building_counts":counts,"funds":scene.city.funds,"game_seconds_advanced":96,"temporary_interval_seconds":scene.city.config.development_interval_seconds}
 var file=FileAccess.open("/workspace/simcity/docs/zoning-validation/capture.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(manifest,"  ")+"\n")
 print("ZONING_CAPTURE ",JSON.stringify(manifest))
 quit(0 if painted.size()==3 and counts.size()==3 and scene.city.funds==50000 else 1)
