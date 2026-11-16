extends SceneTree
## Graphical inspection only: finite surface opening and true -12m single-material silhouette.
func _initialize():run.call_deferred()

func label(text: String,pos: Vector2,size: int=22):
	var item:=Label.new();item.text=text;item.position=pos;item.add_theme_font_size_override("font_size",size)
	item.add_theme_color_override("font_color",Color("f2f5ed"));root.add_child(item)

func stage(pos: Vector2,dimensions: Vector2i,span: float,target: Vector3,offset: Vector3) -> SubViewport:
	var container:=SubViewportContainer.new();container.position=pos;container.size=dimensions;root.add_child(container)
	var viewport:=SubViewport.new();viewport.size=dimensions;viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(viewport)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("c4d0c9");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7;viewport.add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-35,0);light.light_energy=1.;viewport.add_child(light)
	var cam:=Camera3D.new();cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=span;viewport.add_child(cam)
	cam.position=target+offset;cam.look_at(target);cam.current=true
	return viewport

func bounds(item: Node3D) -> AABB:
	if item is MeshInstance3D:return item.global_transform*item.get_aabb()
	var result:=AABB();var first:=true
	for child in item.find_children("*","MeshInstance3D",true,false):
		var box:AABB=child.global_transform*child.get_aabb()
		if first:result=box;first=false
		else:result=result.merge(box)
	return result

func model(viewport: SubViewport,path: String,pos: Vector3=Vector3.ZERO,yaw: float=0.) -> Node3D:
	var packed=load(path);assert(packed is PackedScene)
	var item:Node3D=packed.instantiate();viewport.add_child(item);item.position=pos;item.rotation_degrees.y=yaw
	return item

func person(viewport: SubViewport,pos: Vector3):
	var node:=MeshInstance3D.new();var mesh:=CapsuleMesh.new();mesh.radius=.20;mesh.height=1.75;node.mesh=mesh
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("b28063");node.material_override=mat
	viewport.add_child(node);node.position=pos+Vector3(0,.875,0)

func run():
	root.size=Vector2i(1600,1000)
	var background:=ColorRect.new();background.size=Vector2(1600,1000);background.color=Color("172d35");root.add_child(background)
	label("SUBWAY / original entrance + underground mass silhouette / GLB inspection",Vector2(20,12),27)
	label("Entrance 8 x 8m / actual descending steps + escalator",Vector2(20,65),22)
	var left:=stage(Vector2(20,110),Vector2i(760,430),12.5,Vector3(0,.35,1.4),Vector3(12,13.46,20))
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/facilities/catalog.json"))
	var entrance:Dictionary=catalog.facilities.filter(func(e):return e.id=="subway-entrance-01")[0]
	var silhouette:Dictionary=catalog.facilities.filter(func(e):return e.id=="subway-platform-silhouette-01")[0]
	var surface:=model(left,entrance.model);var b:=bounds(surface)
	assert(abs(b.size.x-8.)<.002 and abs(b.size.z-8.)<.002)
	assert(surface.position==Vector3.ZERO)
	assert(surface.find_child("WellBottom",true,false)!=null)
	var landing:Node3D=surface.find_child("FiniteBottomLanding",true,false)
	assert(landing!=null and abs(bounds(landing).end.y+2.52)<.002)
	# Display-only road/taxi context; no baked-in vehicle in the source model.
	var road:=MeshInstance3D.new();var slab:=BoxMesh.new();slab.size=Vector3(11,.08,3.2);road.mesh=slab
	var asphalt:=StandardMaterial3D.new();asphalt.albedo_color=Color("4c5659");road.material_override=asphalt;left.add_child(road);road.position=Vector3(0,-.04,5.6)
	model(left,"res://assets/vehicles/taxi-sedan-01.glb",Vector3(0,0,5.6),90.)
	person(left,Vector3(-3.25,0,2.75))
	label("Inspection cutaway / roof panels hidden in this view only",Vector2(20,560),21)
	var overhead:=stage(Vector2(20,600),Vector2i(760,330),11.5,Vector3(0,-.3,0),Vector3(0,25,9))
	var cutaway:=model(overhead,entrance.model)
	for panel in cutaway.find_children("CanopyPanel*","MeshInstance3D",true,false):panel.visible=false
	label("Underground only / 64 x 12m / platform surface y = -12m",Vector2(820,65),21)
	var right:=stage(Vector2(820,110),Vector2i(760,500),46.,Vector3(0,-10.75,0),Vector3(20,26,42))
	var mass:=model(right,silhouette.model);var mb:=bounds(mass)
	assert(abs(mb.size.x-64.)<.002 and abs(mb.size.z-12.)<.002)
	var platform:Node3D=mass.find_child("IslandPlatform",true,false)
	assert(platform!=null and abs(bounds(platform).end.y+12.)<.002)
	var materials:={}
	for child in mass.find_children("*","MeshInstance3D",true,false):
		for i in range(child.mesh.get_surface_count()):materials[child.mesh.surface_get_material(i).get_instance_id()]=true
	assert(materials.size()==1)
	assert(silhouette.visibility=="underground_only")
	label("One material / island + two recessed track troughs",Vector2(820,640),22)
	label("Entrance corridor represented by simple connected boxes",Vector2(820,680),20)
	label("Surface opening has walls and a finite bottom landing",Vector2(820,740),20)
	label("Taxi 4.65m + 1.75m mannequin are scale references",Vector2(820,780),20)
	label("Source geometry preserved at actual underground depth",Vector2(820,820),20)
	label("Inspection only: terrain cutout / subway placement / passengers / escalator operation not integrated",Vector2(20,950),20)
	for frame in range(14):await process_frame
	await RenderingServer.frame_post_draw
	var output:=ProjectSettings.globalize_path("res://../docs/transit-validation/subway-1600.png")
	var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1600,1000));assert(image.save_png(output)==OK)
	print("SUBWAY_GRAPHICAL_PASS 8 checks; 2 GLBs; finite landing -2.52m; platform -12m; one silhouette material; ",output)
	quit()
