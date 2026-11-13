extends SceneTree
## Derived from approved render_road_lane_thumbnails.gd; only render changed width grades.
const City=preload("res://core/city_model.gd")
const Geometry=preload("res://core/road_geometry.gd")
const Profile=preload("res://core/road_profile.gd")
const RENDER_LANES:=[2,4,6,7]
const PRESERVE_LANES:=[3,5,8]
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
 var manifest_path:=folder+"/render-manifest.json"
 var previous: Array=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
 var report:=[]
 var preserved_hashes: Dictionary={}
 for count in PRESERVE_LANES:
  var matches:=previous.filter(func(entry):return int(entry.lanes)==count)
  assert(matches.size()==1,"Missing or duplicate preserved manifest entry")
  report.append(matches[0])
  preserved_hashes[count]=FileAccess.get_sha256(folder+"/local-%d.png"%count)
  assert(not preserved_hashes[count].is_empty())
 for count in RENDER_LANES:
  # Approved A: real isometric road across opposite corners, with ends outside frame.
  var segment_metres:=128.0
  var direction:=Vector2.DOWN
  var points:=PackedVector2Array([Vector2(50,50)-direction*segment_metres/8,Vector2(50,50)+direction*segment_metres/8])
  var city:=City.new(100,100);assert(city.add_road(points,"local",true,count).ok)
  var road: Dictionary=city.roads[0]
  assert(is_equal_approx(road.width,Profile.width_for("local",count)))
  var viewport:=SubViewport.new();viewport.size=Vector2i(768,672);viewport.transparent_bg=true;viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
  var stage:=Node3D.new();viewport.add_child(stage)
  # Actual unlit game terrain, without grid or trees.
  paint(stage,PackedVector2Array([Vector2.ZERO,Vector2(city.width,0),Vector2(city.width,city.height),Vector2(0,city.height)]),Color("7e9275"),-.01,true)
  for shape in Geometry.ribbons(road.points,road.width,true,true):paint(stage,shape,Color("c8cbc3"),0)
  for shape in Geometry.ribbons(road.points,Profile.asphalt_width(road),true,true):paint(stage,shape,Color("4c5659"),.015)
  # Fit physical width: 2/3, 4/5 and 6/7 share their respective width grades.
  var card_width_pixels:=lerpf(22,40,(road.width-2)/6.0)
  var marking_width:=maxf(.03,road.width/card_width_pixels)
  for shape in Geometry.ribbons(Profile.offset_path(road.points,Profile.median_offset(road)),maxf(.035,marking_width),true,true):paint(stage,shape,Color("e4bd5f"),.03)
  for dash in Geometry.lane_marks(road):
   for shape in Geometry.ribbons(dash,marking_width,true,true):paint(stage,shape,Color("e8e7dc"),.035)
  var shoulders:=Geometry.shoulder_marks(road)
  assert(shoulders.size()==(2 if count in [2,4,6] else 0))
  for shoulder in shoulders:
   for shape in Geometry.ribbons(shoulder,marking_width,true,true):paint(stage,shape,Color("e8e7dc"),.035)
  # Unchanged approved studio environment, lighting and 45deg/30deg camera.
  var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_CLEAR_COLOR;environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("d9e4f0");environment.environment.ambient_light_energy=.75;stage.add_child(environment)
  var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-35,0);light.light_energy=1.1;stage.add_child(light)
  var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.size=road.width*4*sqrt(.4)*80/card_width_pixels;stage.add_child(camera);camera.position=Vector3(60,60*sqrt(2.0)*tan(PI/6),60);camera.look_at(Vector3.ZERO);camera.v_offset=-camera.size*.18;camera.current=true
  for i in range(3):viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;await RenderingServer.frame_post_draw
  var image:=viewport.get_texture().get_image();assert(image.get_used_rect().has_area())
  image.resize(256,224,Image.INTERPOLATE_LANCZOS)
  var path: String=folder+"/local-%d.png"%count;assert(image.save_png(path)==OK)
  assert(Image.load_from_file(path).get_size()==Vector2i(256,224))
  report.append({"lanes":count,"major_side":road.major_side,"size":str(image.get_size()),"actual_generator":"City.add_road + RoadGeometry.ribbons/lane_marks/shoulder_marks + RoadProfile","studio":"building_views.gd camera angle/light/environment","ground":"main.gd::_draw terrain polygon, unshaded #7e9275","composition":"approved A: bottom-left to top-right; grass on both sides; no trees or parcel grid","camera_size":camera.size,"camera_vertical_offset":camera.v_offset,"native_card_road_width_px":card_width_pixels,"segment_metres":segment_metres,"flat_cut_ends_outside_frame":true,"thumbnail_only_marking_width_cells":marking_width,"separators":Profile.separators(road).size(),"physical_width_cells":road.width,"shoulder_lines":shoulders.size(),"direction_lanes":[Profile.direction_count(road,1),Profile.direction_count(road,-1)]})
  print("ROAD_GRADE_RENDER lanes=%d width=%s card_width=%s shoulders=%d directions=%d+%d sha256=%s"%[count,road.width,card_width_pixels,shoulders.size(),Profile.direction_count(road,1),Profile.direction_count(road,-1),FileAccess.get_sha256(path)])
  viewport.queue_free();await process_frame
 for count in PRESERVE_LANES:assert(FileAccess.get_sha256(folder+"/local-%d.png"%count)==preserved_hashes[count],"Protected PNG changed")
 report.sort_custom(func(a,b):return int(a.lanes)<int(b.lanes))
 assert(report.size()==7)
 var file:=FileAccess.open(manifest_path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("ROAD_GRADE_THUMBNAILS_PASS 4 actual generated road meshes; 256x224; preserved 3/5/8; manifest 7 sorted entries");quit()
