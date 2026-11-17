extends "res://common.gd"
# Common inspection helpers are copied from the preserved freight fixture.
func person(v:SubViewport,p:Vector3):
	var n:=MeshInstance3D.new();var m:=CapsuleMesh.new();m.radius=.20;m.height=1.75;n.mesh=m;v.add_child(n);n.position=p+Vector3(0,.875,0)
func station_scene(v:SubViewport,verify:bool):
	var e:=entry("facilities","train-station-01");var n:=model(v,e.model,Vector3.ZERO)
	for x in [-12.,0.,12.]:
		var rail:=model(v,entry("facilities","rail-track-01").model,Vector3(x,0,-10),90)
		for part in rail.find_children("EndBuffer*","MeshInstance3D",true,false):part.hide()
	var a:=model(v,entry("vehicles","train-loco-01").model,Vector3(11,0,-8),90)
	var b:=model(v,entry("vehicles","train-passenger-01").model,Vector3(.5,0,-8),90)
	var c:=model(v,entry("vehicles","train-passenger-01").model,Vector3(-10.5,0,-8),90)
	var f:=model(v,entry("vehicles","train-loco-freight-01").model,Vector3(-8,0,-12),-90)
	var g:=model(v,entry("vehicles","train-flatcar-01").model,Vector3(1,0,-12),-90)
	var h:=model(v,entry("vehicles","train-flatcar-01").model,Vector3(9,0,-12),-90)
	for x in [1.,9.]:model(v,entry("vehicles","container-20ft-01").model,Vector3(x,1.2,-12),-90)
	model(v,"res://assets/vehicles/taxi-sedan-01.glb",Vector3(-6.5,.14,13.3),-90);person(v,Vector3(12,.22,11.4))
	if not verify:return
	var bb:=bounds(n);assert(abs(bb.size.x-32)<.002 and abs(bb.size.z-36)<.002 and abs(bb.position.y+3.85)<.002 and abs(bb.end.y-10.56)<.002);checks+=1
	assert(n.get_child_count()==2 and n.get_child(0).name in ["StationFront","StationRear"] and n.get_child(1).name in ["StationFront","StationRear"]);checks+=1
	for m in n.find_children("*","MeshInstance3D",true,false):
		var mb:=bounds(m);assert(mb.end.z<=-13.8+.002 or mb.position.z>=-6.2-.002,"Trackway intrusion: "+m.name)
	checks+=1
	assert(n.find_children("WellWall*","MeshInstance3D",true,false).size()==8);checks+=1
	var bottoms:=n.find_children("WellBottom*","MeshInstance3D",true,false);assert(bottoms.size()==2)
	for bottom in bottoms:assert(abs(bounds(bottom).end.y+3.6)<.002)
	checks+=1
	assert(n.find_children("UnderpassIntermediateLanding*","MeshInstance3D",true,false).size()==2);checks+=1
	assert(abs(bounds(a).position.x-bounds(b).end.x)<.002 and abs(bounds(b).position.x-bounds(c).end.x)<.002 and abs(bounds(a).end.x-bounds(c).position.x-32)<.002);checks+=1
	assert(abs(bounds(f).end.x-bounds(g).position.x)<.002 and abs(bounds(g).end.x-bounds(h).position.x)<.002 and abs(bounds(h).end.x-bounds(f).position.x-26)<.002);checks+=1
	assert(abs(bounds(a).end.z-(-6.5))<.002 and abs(bounds(f).position.z-(-13.5))<.002);checks+=1
	assert(e.platform_surface_blender_z_m==1.1 and e.underpass_trackside_walk_width_m>=2 and e.track_included==false);checks+=1
	var portal:Node3D=n.find_child("MainEntryDoor",true,false);assert(bounds(portal).get_center().z>10);checks+=1
func run():
	root.size=Vector2i(1600,1000);var bg:=ColorRect.new();bg.size=Vector2(1600,1000);bg.color=Color("172d35");root.add_child(bg)
	label("STATION V2 / 32 x 36m / paired platforms + enclosed underpass stairs",Vector2(20,10),26)
	label("FRONT / unchanged v1 building + plaza / taxi and 1.75m person",Vector2(20,52),19)
	label("REAR / 32m passenger + 26m freight / actual repeated rail sample",Vector2(810,52),19)
	var front:=stage(Vector2(20,82),Vector2i(770,515),55,Vector3(0,2,-1),Vector3(28,34,42));station_scene(front,true)
	var rear:=stage(Vector2(810,82),Vector2i(770,515),55,Vector3(0,2,-1),Vector3(-26,37,-43));station_scene(rear,false)
	label("V1 / same metres-to-pixels scale as upper views",Vector2(20,611),19)
	var old:=stage(Vector2(20,644),Vector2i(770,310),55,Vector3(0,4,0),Vector3(28,34,42))
	# KEEP_WIDTH makes span horizontal, matching both upper views exactly.
	for v in [front,rear,old]:
		for camera in v.get_children():
			if camera is Camera3D:camera.keep_aspect=Camera3D.KEEP_WIDTH
	model(old,"res://assets/facilities/train-station-01.glb",Vector3.ZERO)
	label("STAIR DETAIL / canopy hidden on inspection instance ONLY",Vector2(810,611),19)
	var detail:=stage(Vector2(810,644),Vector2i(770,310),9,Vector3(-12.3,-.9,-17),Vector3(0,24,2))
	for camera in detail.get_children():
		if camera is Camera3D:camera.keep_aspect=Camera3D.KEEP_WIDTH
		if camera is WorldEnvironment:camera.environment.ambient_light_energy=.3
		if camera is DirectionalLight3D:
			camera.shadow_enabled=true;camera.rotation_degrees=Vector3(-55,60,0);camera.light_energy=.75
	var cut:=model(detail,entry("facilities","train-station-01").model,Vector3.ZERO)
	for m in cut.find_children("Canopy*","MeshInstance3D",true,false):m.hide()
	label("Floor -3.60m / closed bottom -3.85m / inner width 1.80m / track-side walk 2.10m",Vector2(20,968),20)
	for i in range(16):await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1600,1000));assert(image.save_png(OS.get_cmdline_user_args()[0])==OK)
	print("STATION_V2_GRAPHICAL_PASS checks=",checks," dimensions32x36 top10.56 bottom-3.85 landing-3.6 layers2 empty_trackway couplers4 consists32/26 gaps0.3 front-Y");quit()
