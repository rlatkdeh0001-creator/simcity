extends SceneTree
const Viewer=preload("res://vehicle_showcase.gd")
var failures:=0
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	if ok:print("PASS ",label)
	else:failures+=1;push_error(label)
func run():
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/catalog.json"))
	var counts:Dictionary={"bus":0,"taxi":0,"citizen":0,"industrial":0};var ids:Dictionary={}
	check(data.entries.size()==20,"catalog has all 20 requested vehicles")
	for entry in data.entries:
		counts[entry.category]+=1;ids[entry.id]=true
		var model:Node3D=load(entry.model).instantiate();root.add_child(model)
		var bounds:=Viewer.model_bounds(model);var wheels:=Viewer.spin_nodes(model)
		check(wheels.size()==entry.wheel_count and wheels.size()>=4,entry.id+" exported wheel pivots preserved")
		check(bounds.size.x<3.52 and bounds.size.y>1 and bounds.size.z>3 and bounds.position.y>-.03,entry.id+" metre-scale bounds fit lane and ground")
		check(model.find_child("Seat_FL",true,false)!=null and model.find_child("SteeringWheel",true,false)!=null and model.find_child("Seat_FL",true,false).global_position.x>0,entry.id+" left-hand driver anchors exist")
		if entry.category=="bus":
			var right_doors:=true;var count:=0
			for child in model.find_children("Door_Right*","MeshInstance3D",true,false):
				count+=1;right_doors=right_doors and child.global_transform.origin.x+child.get_aabb().get_center().x<0
			check(count==4 and right_doors,"bus passenger door leaves are on right side")
		if entry.body_type in ["container","tanker"]:check(model.find_child("Trailer_Pivot",true,false)!=null,"semi-trailer articulation pivot exists")
		if entry.body_type in ["dump","heavy_dump"]:check(model.find_child("Dump_Bed_Pivot",true,false)!=null,"dump body hinge exists")
		# A complete wheel rotation must not throw the tyre away from its axle.
		var initial:Vector3=wheels[0].global_position;var before:=Viewer.model_bounds(wheels[0]);wheels[0].rotate_x(PI/2)
		var after:=Viewer.model_bounds(wheels[0])
		check(wheels[0].global_position.distance_to(initial)<.0001 and after.get_center().distance_to(before.get_center())<.05,entry.id+" wheel rotation keeps axle centre")
		model.queue_free();await process_frame
	check(ids.size()==20 and counts=={"bus":1,"taxi":1,"citizen":10,"industrial":8},"exact requested category counts and unique IDs")
	var gallery=load("res://vehicle_showcase.tscn").instantiate();root.add_child(gallery)
	for i in range(3):await process_frame
	check(gallery.previews.size()==20,"real game gallery loads all 20 GLBs")
	gallery.choose(19);check(gallery.selected==19 and "덤프" in gallery.info.text,"gallery selects a vehicle and shows its specification")
	gallery.same_scale=true;gallery.reset_cameras();check(gallery.previews[0].camera.size>10,"same-scale comparison includes large vehicles")
	gallery.queue_free();await process_frame
	print("RESULT ",checks-failures,"/",checks," vehicle checks passed")
	quit(1 if failures else 0)
