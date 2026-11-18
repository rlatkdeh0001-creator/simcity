extends SceneTree
## Static 48x20m sawtooth layout, five actual bus GLBs; no traffic simulation.
func _initialize():run.call_deferred()

func bounds(item: Node3D) -> AABB:
	var result:=AABB();var first:=true
	for child in item.find_children("*","MeshInstance3D",true,false):
		var b:AABB=child.global_transform*child.get_aabb()
		if first:result=b;first=false
		else:result=result.merge(b)
	return result

func label(text: String,pos: Vector2,size: int=22):
	var node:=Label.new();node.text=text;node.position=pos;node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",Color("f2f5ed"));root.add_child(node)

func run():
	root.size=Vector2i(1600,1000)
	var bg:=ColorRect.new();bg.color=Color("172d35");bg.size=Vector2(1600,1000);root.add_child(bg)
	label("BUS STATION v2 / 48 x 20m / five 30-degree sawtooth bays",Vector2(20,12),28)
	label("Right-side entry -> 3.5m one-way front aisle -> left-side exit | full rear waiting canopy",Vector2(20,54))
	var container:=SubViewportContainer.new();container.position=Vector2(20,95);container.size=Vector2(1560,830);root.add_child(container)
	var stage:=SubViewport.new();stage.size=Vector2i(1560,830);stage.own_world_3d=true;stage.msaa_3d=Viewport.MSAA_4X
	stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(stage)
	var world:=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color("bbc9c2");world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=.7;stage.add_child(world)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-35,0);light.light_energy=1.;stage.add_child(light)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=34.;stage.add_child(camera)
	var target:=Vector3(0,1,-8.8);camera.position=target+Vector3(22,29,40);camera.look_at(target);camera.current=true
	var doc:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/facilities/catalog.json"))
	var entry:Dictionary=doc.facilities.filter(func(e):return e.id=="bus-station-01")[0]
	assert(entry.model.ends_with("bus-station-01-v2.glb") and is_equal_approx(float(entry.metres[0]),48.) and is_equal_approx(float(entry.metres[1]),20.))
	var station:Node3D=load(entry.model).instantiate();stage.add_child(station)
	var b:=bounds(station);assert(abs(b.size.x-48.)<.002 and abs(b.size.z-20.)<.002)
	assert(station.position==Vector3.ZERO and abs(b.end.z)<.002)
	var road:=MeshInstance3D.new();var slab:=BoxMesh.new();slab.size=Vector3(52,.08,4.8);road.mesh=slab
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("4c5659");road.material_override=mat;stage.add_child(road);road.position=Vector3(0,-.04,2.4)
	var buses:Array[Node3D]=[]
	for x in [-18.,-9.,0.,9.,18.]:
		var bus:Node3D=load("res://assets/vehicles/bus-city-01.glb").instantiate();stage.add_child(bus)
		bus.position=Vector3(x,.1,-7.6);bus.rotation_degrees.y=-60.;buses.append(bus)
		assert(bounds(bus).end.z < -3.5,"Parked bus intrudes into reserved aisle")
	var perpendicular:=Vector3(.5,0,.8660254)
	for i in range(4):assert(abs((buses[i+1].position-buses[i].position).dot(perpendicular))>2.70,"Buses overlap across parallel bay width")
	label("Existing bus-city-01 x 5 | covered rear platform + small waiting room | v1 preserved",Vector2(20,945),20)
	label("Static bay/aisle fit verified; actual swept turning paths and live attachment are not implemented",Vector2(20,975),18)
	for frame in range(14):await process_frame
	await RenderingServer.frame_post_draw
	var output:=ProjectSettings.globalize_path("res://../docs/transit-validation/bus-station-v2-1600.png")
	var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1600,1000));assert(image.save_png(output)==OK)
	print("BUS_STATION_V2_GRAPHICAL_PASS 12 checks; 5 parked buses clear 3.5m aisle, no pair overlap; ",output)
	quit()
