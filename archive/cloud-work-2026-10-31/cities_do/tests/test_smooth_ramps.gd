extends SceneTree
const Model=preload("res://core/city_model.gd")
const Ramp=preload("res://core/ramp_geometry.gd")
var checks:=0
var failures:=0
func _initialize():call_deferred("run")
func check(value:bool,label:String):
	checks+=1
	if value:print("PASS ",label)
	else:failures+=1;push_error(label)
func run():
	for rotation in [0.0,.24,-.21]:
		for reversed in [false,true]:
			var city=Model.new(100,100)
			var u:=Vector2.RIGHT.rotated(rotation);var v:=Vector2.DOWN.rotated(rotation)
			var center:=Vector2(50,50)
			city.add_road(PackedVector2Array([center-v*40,center+v*40]),"local",true,3)
			city.add_road(PackedVector2Array([center-u*40,center+u*40]),"highway",true,5,reversed)
			var preview:Dictionary=city.add_interchange_at(center,false)
			var result:Dictionary=city.add_interchange_at(center)
			check(preview.ok and result.ok,"rotated and reversed roads create smooth ramps")
			if not result.ok:continue
			var smooth_ends:=true;var smooth_width:=true;var smooth_outline:=true;var preview_matches:=true;var right_hand_ports:=true
			for ri in range(result.ramps.size()):
				var r:Dictionary=result.ramps[ri]
				preview_matches=preview_matches and r.points==preview.ramps[ri].points and r.width_factors==preview.ramps[ri].width_factors
				for port in [r.start_attachment,r.end_attachment]:right_hand_ports=right_hand_ports and port.heading.cross(port.normal)>.999
				var c:PackedVector2Array=r.curve_controls
				smooth_ends=smooth_ends and (c[2]-c[1]*2+c[0]).length()<.0001 and (c[5]-c[4]*2+c[3]).length()<.0001
				smooth_ends=smooth_ends and Ramp.derivative(r,0).normalized().dot(r.start_attachment.heading)>.99999 and Ramp.derivative(r,1).normalized().dot(r.end_attachment.heading)>.99999
				smooth_width=smooth_width and Ramp.width_factor(r,0)==0 and Ramp.width_factor(r,1)==0 and Ramp.width_factor(r,.5)==1
				smooth_width=smooth_width and Ramp.smooth_derivative(0)==0 and Ramp.smooth_derivative(1)==0
				var polygon:=Ramp.ribbon(r)
				smooth_outline=smooth_outline and not Geometry2D.triangulate_polygon(polygon).is_empty()
				for side in [-1,1]:
					var edge:=Ramp.edge(r,side)
					smooth_outline=smooth_outline and edge[0].distance_to(r.start_attachment.position)<.0001 and edge[-1].distance_to(r.end_attachment.position)<.0001
			check(smooth_ends,"both ramp ends have matching tangents and zero curvature")
			check(smooth_width,"taper width and grade start and end with zero slope")
			check(smooth_outline,"variable-width welded outlines are closed, triangulatable and meet parent edges")
			check(preview_matches,"game preview and committed ramps share the exact smooth geometry")
			check(right_hand_ports,"both ramp ends attach to the right-hand carriageway")
	# Verify the actual construction tool, not only the authored comparison scene.
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.city.add_road(PackedVector2Array([Vector2(50,5),Vector2(50,95)]),"local",true,4)
	scene.city.add_road(PackedVector2Array([Vector2(5,50),Vector2(95,50)]),"highway",true,4)
	scene.mode="interchange"
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=scene.screen(Vector2(50,50));scene._unhandled_input(click)
	var applied:bool=scene.city.roads.size()==6
	for road in scene.city.roads:
		if road.kind=="ramp":applied=applied and road.get("smooth_join",false) and road.width_factors[0]==0 and road.width_factors[-1]==0
	check(applied,"in-game interchange tool enforces smooth-join geometry")
	scene.queue_free();await process_frame
	print("RESULT ",checks-failures,"/",checks," smooth-ramp checks passed")
	quit(1 if failures else 0)
