extends SceneTree
## Render the actual City/RoadGeometry generator in the building-view studio.
const City=preload("res://core/city_model.gd")
const Geometry=preload("res://core/road_geometry.gd")
const Profile=preload("res://core/road_profile.gd")
func _initialize():run.call_deferred()
func paint(stage: Node3D,polygon: PackedVector2Array,color: Color,height: float):
 var indices:=Geometry2D.triangulate_polygon(polygon)
 var vertices:=PackedVector3Array();var normals:=PackedVector3Array()
 for index in indices:
  var p: Vector2=polygon[index]-Vector2(50,50)
  vertices.append(Vector3(p.x*4,height,p.y*4));normals.append(Vector3.UP)
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var material:=StandardMaterial3D.new();material.albedo_color=color;material.roughness=1;material.cull_mode=BaseMaterial3D.CULL_DISABLED
 mesh.surface_set_material(0,material)
 var node:=MeshInstance3D.new();node.mesh=mesh;stage.add_child(node)
func run():
 var folder:=ProjectSettings.globalize_path("res://assets/ui/roads")
 DirAccess.make_dir_recursive_absolute(folder)
 var report:=[]
 for count in Profile.LOCAL_LANES:
  var city:=City.new(100,100);assert(city.add_road(PackedVector2Array([Vector2(44,50),Vector2(56,50)]),"local",true,count).ok)
  var road: Dictionary=city.roads[0]
  var viewport:=SubViewport.new();viewport.size=Vector2i(640,480);viewport.transparent_bg=true;viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
  var stage:=Node3D.new();viewport.add_child(stage)
  for shape in Geometry.ribbons(road.points,road.width):paint(stage,shape,Color("c8cbc3"),0)
  for shape in Geometry.ribbons(road.points,Profile.asphalt_width(road)):paint(stage,shape,Color("4c5659"),.015)
  for shape in Geometry.ribbons(Profile.offset_path(road.points,Profile.median_offset(road)),.035):paint(stage,shape,Color("e4bd5f"),.03)
  for dash in Geometry.lane_marks(road):
   for shape in Geometry.ribbons(dash,.03):paint(stage,shape,Color("e8e7dc"),.035)
  # Same environment, light and 45deg/30deg orthographic camera as building_views.gd.
  var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_CLEAR_COLOR;environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("d9e4f0");environment.environment.ambient_light_energy=.75;stage.add_child(environment)
  var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-35,0);light.light_energy=1.1;stage.add_child(light)
  var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.size=(12+road.width*2)*4*.707*.75*1.08;stage.add_child(camera);camera.position=Vector3(60,60*sqrt(2.0)*tan(PI/6),60);camera.look_at(Vector3.ZERO);camera.current=true
  for i in range(3):viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;await RenderingServer.frame_post_draw
  var image:=viewport.get_texture().get_image();assert(image.get_used_rect().has_area())
  image.resize(256,192,Image.INTERPOLATE_LANCZOS)
  var path: String=folder+"/local-%d.png"%count;assert(image.save_png(path)==OK)
  report.append({"lanes":count,"major_side":road.major_side,"size":str(image.get_size()),"actual_generator":"City.add_road + RoadGeometry.ribbons/lane_marks + RoadProfile","studio":"building_views.gd camera/light/environment","camera_size":camera.size,"separators":Profile.separators(road).size()})
  viewport.queue_free();await process_frame
 var file:=FileAccess.open(folder+"/render-manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("ROAD_THUMBNAILS_PASS 5 actual generated road meshes rendered with building studio");quit()
