extends SceneTree
## Actual construction scene capture; run with a graphics renderer, never --headless.
func _initialize(): run.call_deferred()
func run():
 var scene=load("res://main.tscn").instantiate()
 root.add_child(scene)
 current_scene=scene
 scene.city.add_road(PackedVector2Array([Vector2(10,44),Vector2(90,44)]))
 scene.city.add_building(32,41)
 scene.city.add_building(50,41)
 scene.city.add_water_facility(Vector2(20,41),"water",1000)
 scene.city.add_water_facility(Vector2(70,41),"sewage",2400)
 scene.city.water.add_pipe(PackedVector2Array([Vector2(84,168),Vector2(284,168)]))
 scene.origin=Vector2(660,100)
 scene.map_zoom=.5
 scene.water_overlay.toggle()
 await create_timer(2).timeout
 await RenderingServer.frame_post_draw
 var path := OS.get_cmdline_user_args()[0]
 quit(0 if root.get_texture().get_image().save_png(path)==OK else 1)
