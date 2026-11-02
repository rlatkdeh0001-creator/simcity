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
 viewport.add_child(load(entry.model).instantiate())
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
 camera.size=24
 viewport.add_child(camera)
 camera.position=Vector3(28,25,28)
 camera.look_at(Vector3(0,2.5,0))
 camera.current=true
 var label := Label.new()
 label.text="%s · 16 × 16m · 애셋" % entry.name
 label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 column.add_child(label)
 popup_centered()
