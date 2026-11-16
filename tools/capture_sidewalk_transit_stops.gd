extends SceneTree
## Actual RoadProfile/RoadGeometry/RoadParcels determine roadway, sidewalk and grid.
## Only an authored inspection fixture: no new placement/simulation/UI code.
const Profile=preload("res://core/road_profile.gd")
const Geometry=preload("res://core/road_geometry.gd")
const Parcels=preload("res://core/road_parcels.gd")
var checks:=0
var grid_count:=0
var road:Dictionary
var sidewalk_m:=0.0
var curb_z:=0.0
var outer_z:=0.0
var frames:Array
var facilities:Array

func _initialize():run.call_deferred()

func label(text: String,pos: Vector2,size: int=22):
	var item:=Label.new();item.text=text;item.position=pos;item.add_theme_font_size_override("font_size",size)
	item.add_theme_color_override("font_color",Color("f2f5ed"));root.add_child(item)

func stage(pos: Vector2,dimensions: Vector2i,span: float,target: Vector3,offset: Vector3,top=false) -> SubViewport:
	var holder:=SubViewportContainer.new();holder.position=pos;holder.size=dimensions;root.add_child(holder)
	var viewport:=SubViewport.new();viewport.size=dimensions;viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;holder.add_child(viewport)
	var world:=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color("bacac1");world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=.7;viewport.add_child(world)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-35,0);light.light_energy=1.;viewport.add_child(light)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=span;viewport.add_child(camera)
	camera.position=target+offset;camera.look_at(target,Vector3(0,0,-1) if top else Vector3.UP);camera.current=true
	return viewport

func flat_polygon(viewport: SubViewport,poly: PackedVector2Array,y: float,color: Color):
	var ids:=Geometry2D.triangulate_polygon(poly);assert(not ids.is_empty())
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,ids.size(),3):
		for index in [ids[i],ids[i+2],ids[i+1]]:
			surface.set_normal(Vector3.UP);surface.add_vertex(Vector3(poly[index].x*4,y,poly[index].y*4))
	var node:=MeshInstance3D.new();node.mesh=surface.commit()
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.roughness=1.;node.material_override=mat
	viewport.add_child(node)

func bar(viewport: SubViewport,a: Vector3,b: Vector3,width: float,color: Color):
	var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(a.distance_to(b),.012,width);node.mesh=mesh
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;node.material_override=mat;viewport.add_child(node)
	node.position=(a+b)/2;node.rotation.y=-atan2(b.z-a.z,b.x-a.x)

func model(viewport: SubViewport,path: String,pos: Vector3,yaw: float=0.) -> Node3D:
	var packed=load(path);assert(packed is PackedScene)
	var instance:Node3D=packed.instantiate();viewport.add_child(instance);instance.position=pos;instance.rotation_degrees.y=yaw
	return instance

func body_bounds(item: Node3D) -> AABB:
	var result:=AABB();var first:=true
	for child in item.find_children("*","MeshInstance3D",true,false):
		if str(child.name).to_lower().contains("decal"):continue
		var b:AABB=child.global_transform*child.get_aabb()
		if first:result=b;first=false
		else:result=result.merge(b)
	return result

func context(viewport: SubViewport):
	for p in Geometry.ribbons(road.points,road.width,true,true):flat_polygon(viewport,p,-.012,Color("c8cbc3"))
	for p in Geometry.ribbons(road.points,Profile.asphalt_width(road),true,true):flat_polygon(viewport,p,0.,Color("4c5659"))
	for z in [-Profile.travel_width(road)*2,Profile.travel_width(road)*2]:bar(viewport,Vector3(-20,.008,z),Vector3(20,.008,z),.07,Color("e8e7dc"))
	bar(viewport,Vector3(-20,.008,0),Vector3(20,.008,0),.09,Color("e4bd5f"))
	var polygons:Array[PackedVector2Array]=[]
	for frame in frames:
		if frame.side!=-1:continue
		for u in range(frame.columns):
			for v in range(4):
				var poly:PackedVector2Array=Parcels.polygon(frame,u,v);polygons.append(poly)
				flat_polygon(viewport,poly,-.006,Color("8ba77c"))
				for i in range(poly.size()):
					var a:=poly[i]*4;var b:=poly[(i+1)%poly.size()]*4
					bar(viewport,Vector3(a.x,.012,a.y),Vector3(b.x,.012,b.y),.035,Color("d2e3bf"))
	bar(viewport,Vector3(-20,.020,outer_z),Vector3(20,.020,outer_z),.045,Color("36b7ff"))
	for pair in [["bus-stop-01",-6.],["taxi-stop-01",5.]]:
		var entry:Dictionary=facilities.filter(func(e):return e.id==pair[0])[0]
		var instance:=model(viewport,entry.model,Vector3(pair[1],0,curb_z))
		var bounds:=body_bounds(instance)
		assert(bounds.position.z>=outer_z-.0005,"Stop invades zoning boundary")
		assert(bounds.end.z<=curb_z+.0005,"Stop body leaves sidewalk toward road")
		assert(bounds.size.z<=sidewalk_m+.0005)
		assert(entry.placement=="road_edge" and entry.zoning_occupancy_cells==0)
		var footprint:=PackedVector2Array([Vector2(bounds.position.x,bounds.position.z)/4,Vector2(bounds.end.x,bounds.position.z)/4,Vector2(bounds.end.x,bounds.end.z)/4,Vector2(bounds.position.x,bounds.end.z)/4])
		for poly in polygons:assert(not Parcels.overlap(footprint,poly),"Stop overlaps actual road-local zoning cell")
		assert(not instance.find_children("*Decal*","MeshInstance3D",true,false).is_empty())
		checks+=6
	model(viewport,"res://assets/vehicles/bus-city-01.glb",Vector3(-4,0,-3.8),-90)
	model(viewport,"res://assets/vehicles/taxi-sedan-01.glb",Vector3(5,0,-3.9),-90)
	grid_count=polygons.size()

func run():
	root.size=Vector2i(1600,1000)
	road={"kind":"local","lanes":2,"major_side":1,"width":Profile.width_for("local",2),"points":PackedVector2Array([Vector2(-5,0),Vector2(5,0)])}
	sidewalk_m=(road.width-Profile.asphalt_width(road))*4/2
	curb_z=-Profile.asphalt_width(road)*4/2;outer_z=-road.width*4/2
	assert(abs(sidewalk_m-.75)<.0001)
	frames=Parcels.blocks(road.points,road.width/2,1)
	facilities=JSON.parse_string(FileAccess.get_file_as_string("res://assets/facilities/catalog.json")).facilities
	assert(facilities.filter(func(e):return e.id=="bus-stop-01")[0].model.ends_with("bus-stop-01-v2.glb"))
	var bg:=ColorRect.new();bg.size=Vector2(1600,1000);bg.color=Color("172d35");root.add_child(bg)
	label("SIDEWALK STOPS / ordinary 2-lane road / zero zoning-cell occupancy",Vector2(20,12),28)
	label("RoadProfile: total %.2fm / asphalt %.2fm / sidewalk %.2fm | stop bodies 0.72m deep"%[road.width*4,Profile.asphalt_width(road)*4,sidewalk_m],Vector2(20,56),22)
	var main:=stage(Vector2(20,100),Vector2i(1560,510),24.,Vector3(0,.4,-6),Vector3(14,30,25));context(main)
	label("TOP VIEW / blue line = actual road outer edge and first zoning-cell boundary",Vector2(20,632),22)
	var top:=stage(Vector2(20,675),Vector2i(1560,240),8.,Vector3(0,0,-5.3),Vector3(0,50,0),true);context(top)
	label("Actual RoadGeometry + RoadParcels grid | standalone attachment fixture, not implemented live placement",Vector2(20,947),20)
	for frame in range(16):await process_frame
	await RenderingServer.frame_post_draw
	var output:=ProjectSettings.globalize_path("res://../docs/transit-validation/sidewalk-stops-1600.png")
	var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1600,1000));assert(image.save_png(output)==OK)
	print("SIDEWALK_STOPS_GRAPHICAL_PASS ",checks," checks; sidewalk=",sidewalk_m,"m, body=0.72m; ",grid_count," actual grid cells; no stop-cell overlap; ",output)
	quit()
