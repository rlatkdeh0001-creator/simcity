extends SceneTree
## Render the actual City/RoadGeometry generator in the building-view studio.
const City=preload("res://core/city_model.gd")
const Geometry=preload("res://core/road_geometry.gd")
const Profile=preload("res://core/road_profile.gd")
func _initialize():run.call_deferred()
func paint(stage: Node3D,polygon: PackedVector2Array,color: Color,height: float,unshaded: bool=false):
 var indices:=Geometry2D.triangulate_polygon(polygon)
 var vertices:=PackedVector3Array();var normals:=PackedVector3Array()
 for index in indices:
  var p: Vector2=polygon[index]-Vector2(50,50)
  vertices.append(Vector3(p.x*4,height,p.y*4));normals.append(Vector3.UP)
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var material:=StandardMaterial3D.new();material.albedo_color=color;material.roughness=1;material.cull_mode=BaseMaterial3D.CULL_DISABLED
 if unshaded:material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 mesh.surface_set_material(0,material)
 var node:=MeshInstance3D.new();node.mesh=mesh;stage.add_child(node)
func run():
 var folder:=ProjectSettings.globalize_path("res://assets/ui/roads")
 DirAccess.make_dir_recursive_absolute(folder)
 var report:=[]
 for count in Profile.LOCAL_LANES:
  var fraction: float=(count-2)/6.0
  # Approved A: the real isometric road crosses opposite card corners; its ends stay outside the frame.
  var segment_metres:=128.0
  var direction:=Vector2.DOWN
  var points:=PackedVector2Array([Vector2(50,50)-direction*segment_metres/8,Vector2(50,50)+direction*segment_metres/8])
  var city:=City.new(100,100);assert(city.add_road(points,"local",true,count).ok)
  var road: Dictionary=city.roads[0]
  var viewport:=SubViewport.new();viewport.size=Vector2i(768,672);viewport.transparent_bg=true;viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
  var stage:=Node3D.new();viewport.add_child(stage)
  # The game's terrain is this unlit world-map polygon (main.gd::_draw), not a stock grass picture.
  paint(stage,PackedVector2Array([Vector2.ZERO,Vector2(city.width,0),Vector2(city.width,city.height),Vector2(0,city.height)]),Color("7e9275"),-.01,true)
  for shape in Geometry.ribbons(road.points,road.width,true,true):paint(stage,shape,Color("c8cbc3"),0)
  for shape in Geometry.ribbons(road.points,Profile.asphalt_width(road),true,true):paint(stage,shape,Color("4c5659"),.015)
  # Increasing visible width, with one native card pixel per marking; live road geometry is unchanged.
  var card_width_pixels:=lerpf(22,40,fraction)
  var marking_width:=maxf(.03,road.width/card_width_pixels)
  for shape in Geometry.ribbons(Profile.offset_path(road.points,Profile.median_offset(road)),maxf(.035,marking_width),true,true):paint(stage,shape,Color("e4bd5f"),.03)
  for dash in Geometry.lane_marks(road):
   for shape in Geometry.ribbons(dash,marking_width,true,true):paint(stage,shape,Color("e8e7dc"),.035)
  # Same environment, light and 45deg/30deg orthographic camera as building_views.gd.
  var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_CLEAR_COLOR;environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("d9e4f0");environment.environment.ambient_light_energy=.75;stage.add_child(environment)
  var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-35,0);light.light_energy=1.1;stage.add_child(light)
  # 45deg/30deg projects the two ground axes at the game's 2:1 isometric angle.
  var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.size=road.width*4*sqrt(.4)*80/card_width_pixels;stage.add_child(camera);camera.position=Vector3(60,60*sqrt(2.0)*tan(PI/6),60);camera.look_at(Vector3.ZERO);camera.v_offset=-camera.size*.18;camera.current=true
  for i in range(3):viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;await RenderingServer.frame_post_draw
  var image:=viewport.get_texture().get_image();assert(image.get_used_rect().has_area())
  image.resize(256,224,Image.INTERPOLATE_LANCZOS)
  var path: String=folder+"/local-%d.png"%count;assert(image.save_png(path)==OK)
  report.append({"lanes":count,"major_side":road.major_side,"size":str(image.get_size()),"actual_generator":"City.add_road + RoadGeometry.ribbons/lane_marks + RoadProfile","studio":"building_views.gd camera angle/light/environment","ground":"main.gd::_draw terrain polygon, unshaded #7e9275","composition":"approved A: bottom-left to top-right; grass on both sides; no trees or parcel grid","camera_size":camera.size,"camera_vertical_offset":camera.v_offset,"native_card_road_width_px":card_width_pixels,"segment_metres":segment_metres,"flat_cut_ends_outside_frame":true,"thumbnail_only_marking_width_cells":marking_width,"separators":Profile.separators(road).size()})
  viewport.queue_free();await process_frame
 var file:=FileAccess.open(folder+"/render-manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("ROAD_THUMBNAILS_PASS 5 actual generated road meshes rendered with building studio");quit()
