extends Window
## Asset inspection only. Closing leaves the current city and tool state intact.
func show_asset(entry: Dictionary) -> void:
 title=entry.name+" · 애셋"
 size=Vector2i(680,570)
 transient=true
 exclusive=true
 close_requested.connect(queue_free)
 var column := VBoxContainer.new()
 column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(column)
 var container := SubViewportContainer.new()
 container.stretch=true
 container.custom_minimum_size=Vector2(660,490)
 container.size_flags_vertical=Control.SIZE_EXPAND_FILL
 column.add_child(container)
 var viewport := SubViewport.new()
 viewport.size=Vector2i(660,490)
 viewport.own_world_3d=true
 container.add_child(viewport)
 var model: Node3D=load(entry.model).instantiate()
 model.name="InspectedAssetModel"
 viewport.add_child(model)
 var measured:=AABB()
 var first:=true
 for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
  var bounds: AABB=mesh.global_transform*mesh.get_aabb()
  measured=bounds if first else measured.merge(bounds)
  first=false
 var height_m: float=entry.get("height_m",measured.size.y)
 var environment := WorldEnvironment.new()
 environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR
 environment.environment.background_color=Color("c6d7d2")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color("e5efea")
 environment.environment.ambient_light_energy=.7
 viewport.add_child(environment)
 var light := DirectionalLight3D.new()
 light.rotation_degrees=Vector3(-55,-35,0)
 viewport.add_child(light)
 var camera := Camera3D.new()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 # Camera size is calibrated from the physical footprint, including 8x8 campuses.
 camera.size=maxf(24.0,Vector2(entry.width*4,entry.depth*4).length()*.62+height_m)
 viewport.add_child(camera)
 camera.position=Vector3(28,25,28)
 camera.look_at(Vector3(0,height_m*.4,0))
 camera.current=true
 var label := Label.new()
 label.text="%s · %d × %dm · 애셋" % [entry.name,entry.width*4,entry.depth*4]
 if entry.get("recovered_batch","")=="remaining_30":
  label.text="%s · %.2f × %.2f × %.2fm · 애셋" % [entry.name,entry.width_m,entry.length_m,entry.height_m]
  label.clip_text=true
  label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
  label.tooltip_text=label.text
 label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 label.add_theme_font_size_override("font_size",18)
 column.add_child(label)
 popup_centered()
