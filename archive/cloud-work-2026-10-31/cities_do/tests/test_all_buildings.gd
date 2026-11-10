extends SceneTree
var failures := 0
var checks := 0
func verify(value: bool,label: String):
	checks+=1
	if value:print("PASS ",label)
	else:failures+=1;push_error(label)
func _initialize():
	root.content_scale_size=Vector2i(3600,2400)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size=Vector2i(3600,2400)
	call_deferred("run")
func run():
	var scene=load("res://all_buildings_showcase.tscn").instantiate();root.add_child(scene)
	await process_frame;await process_frame
	verify(scene.data.map_size==[100.0,100.0],"100x100 map")
	verify(scene.assets.size()==54 and scene.instances.size()==59,"54 definitions and 59 placed buildings")
	var seen:={};var bounds_ok:=true;var collision_free:=true;var access_ok:=true;var visible_types:={}
	for i in range(scene.instances.size()):
		var b: Dictionary=scene.instances[i];var a: Dictionary=scene.assets[b.asset_id]
		seen[b.asset_id]=true
		var lot:=Rect2(b.x,b.y,a.footprint[0],a.footprint[1])
		if not Rect2(0,0,100,100).encloses(lot):bounds_ok=false
		for j in range(i):
			var other: Dictionary=scene.instances[j];var aa: Dictionary=scene.assets[other.asset_id]
			if lot.intersects(Rect2(other.x,other.y,aa.footprint[0],aa.footprint[1])):collision_free=false
		if b.asset_id!="power-hydro":
			var touching:=false
			for road in scene.data.roads:
				var p0=road.points[0];var p1=road.points[1];var half:float=road.width/2
				var rr:=Rect2(minf(p0[0],p1[0])-half,minf(p0[1],p1[1])-half,absf(p1[0]-p0[0])+half*2,absf(p1[1]-p0[1])+half*2)
				if lot.intersects(rr):access_ok=false
				if lot.grow(.002).intersects(rr):touching=true
			if not touching:access_ok=false
		var im: Image=scene.images[b.asset_id];var rect: Rect2=scene.sprite_rect(b)
		for yy in range(10,im.get_height(),35):
			if visible_types.has(b.asset_id):break
			for xx in range(10,im.get_width(),35):
				if im.get_pixel(xx,yy).a<.9:continue
				var p:Vector2=rect.position+Vector2(float(xx)/im.get_width(),float(yy)/im.get_height())*rect.size
				if p.y<150 or not Rect2(Vector2.ZERO,scene.get_viewport_rect().size).has_point(p):continue
				if scene.pick_building(p)==i:
					visible_types[b.asset_id]=true;break
	verify(seen.size()==54,"every asset definition is placed at least once")
	verify(bounds_ok,"all lots fit map bounds")
	verify(collision_free,"no building footprints overlap")
	verify(access_ok,"ordinary and shore facilities touch roads without intersecting; dam has bank-side access")
	verify(visible_types.size()==54,"all 54 types have visible selectable opaque pixels in overview")
	for id in scene.assets:
		if not visible_types.has(id):print("HIDDEN TYPE ",id)
	scene.queue_free();await process_frame
	print("RESULT ",checks-failures,"/",checks," all-building checks passed")
	quit(1 if failures else 0)
