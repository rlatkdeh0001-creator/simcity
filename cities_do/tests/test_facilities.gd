extends SceneTree
const Parking = preload("res://core/modular_parking.gd")
const LEGACY_KINDS := {"park":4,"surface_parking":3,"parking_tower":1}
const CATALOG_KINDS := {"park":5,"surface_parking":3,"parking_tower":1,
 "transit_sidewalk_stop":2,"transit_road_edge":2,"subway_entrance":1,
 "subway_underground_silhouette":1,"transit_rail_station":1,"rail_track":1,"structure_sample":2}
var checks := 0
var failed := 0
func _initialize(): run.call_deferred()
func verify(value: bool, message: String):
 checks += 1
 if value: print("PASS "+message)
 else:
  failed += 1
  push_error("FAIL "+message)

func run():
 var p := Parking.new()
 var a := p.add("surface_parking",Vector2i.ZERO,Vector2i(2,4))
 var b := p.add("surface_parking",Vector2i(2,0),Vector2i(4,4))
 var c := p.add("surface_parking",Vector2i(2,4),Vector2i(4,8))
 verify(a>0 and b>0 and c>0,"all three requested surface lot sizes accepted")
 var groups: Array = p.groups()
 verify(groups.size()==1 and groups[0].lot_ids==[a,b,c],"shared edges produce one complex preserving all lot IDs")
 verify(groups[0].capacity==28,"merged capacity equals 4+8+16 spaces")
 var mesh: ArrayMesh = Parking.combined_mesh(groups[0])
 verify(mesh.get_surface_count()==3,"one combined mesh with asphalt/curb/paint surfaces")
 var perimeter: int = groups[0].boundary.size()
 verify(perimeter<24,"interior boundaries removed from merged L shape")
 verify(p.add("surface_parking",Vector2i.ZERO,Vector2i(2,4))==-1 and p.lots.size()==3,"overlap rejected without mutation")
 verify(p.add("surface_parking",Vector2i(7,0),Vector2i(2,4))==-1,"unaligned module placement rejected")
 verify(p.add("surface_parking",Vector2i(30,30),Vector2i(4,4))==-1,"out-of-bounds placement rejected")
 verify(p.add("surface_parking",Vector2i(8,20),Vector2i(3,4))==-1,"unsupported footprint rejected")
 verify(p.remove(b) and p.groups().size()==2,"removing the connecting lot splits corner-only contact")
 verify(not p.remove(b),"removing unknown/already removed ID has no effect")
 var tower := p.add("parking_tower",Vector2i(6,4),Vector2i(4,4))
 verify(tower>0 and p.groups().size()==2,"adjacent tower is excluded from surface merging")
 var reverse := Parking.new()
 reverse.add("surface_parking",Vector2i(2,4),Vector2i(4,8))
 reverse.add("surface_parking",Vector2i(2,0),Vector2i(4,4))
 reverse.add("surface_parking",Vector2i.ZERO,Vector2i(2,4))
 verify(reverse.groups()[0].boundary==groups[0].boundary,"layout is independent of insertion order")
 var fixtures = JSON.parse_string(FileAccess.get_file_as_string("res://assets/facilities/layout-fixtures.json"))
 for name in fixtures:
  var expected: Dictionary = fixtures[name]
  var blocks := []
  for pair in expected.blocks: blocks.append(Vector2i(pair[0],pair[1]))
  var actual: Dictionary = Parking.layout(blocks)
  var normalized_edges := []
  for edge in expected.boundary: normalized_edges.append([int(edge[0]),int(edge[1]),String(edge[2])])
  verify(actual.capacity==int(expected.capacity) and actual.boundary==normalized_edges,"Python/Godot capacity and edges agree: "+name)
  var match_boxes: bool = actual.boxes.size()==expected.boxes.size()
  for i in range(actual.boxes.size()):
   var x: Dictionary = actual.boxes[i]
   var y: Dictionary = expected.boxes[i]
   match_boxes = match_boxes and x.name==y.name and x.mat==y.mat and x.pos.is_equal_approx(Vector3(y.pos[0],y.pos[1],y.pos[2])) and x.size.is_equal_approx(Vector3(y.size[0],y.size[1],y.size[2]))
  verify(match_boxes,"Python/Godot mesh recipe agrees: "+name)
 var hole := Parking.layout([Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(0,1),Vector2i(2,1),Vector2i(0,2),Vector2i(1,2),Vector2i(2,2)])
 verify(hole.boundary.size()==16 and hole.blocks.size()==8,"hole retains its inner curb and has no asphalt fill")
 var entries = JSON.parse_string(FileAccess.get_file_as_string("res://assets/facilities/catalog.json")).facilities
 verify(entries.size()==19,"catalog contains the original eight facilities and eleven additions")
 var counts := {}
 var legacy_counts := {}
 var imports: Dictionary = {}
 for entry in entries:
  counts[entry.kind]=counts.get(entry.kind,0)+1
  var legacy: bool = LEGACY_KINDS.has(entry.kind) and entry.id!="park-large-8x8"
  if legacy:legacy_counts[entry.kind]=legacy_counts.get(entry.kind,0)+1
  verify(not imports.has(entry.id),entry.id+" unique ID")
  var path: String = entry.model
  var resource: PackedScene
  if FileAccess.file_exists(path) and ResourceLoader.exists(path,"PackedScene"):
   resource=ResourceLoader.load(path,"PackedScene") as PackedScene
  imports[entry.id]=resource!=null
  verify(resource!=null,entry.id+" GLB imports as PackedScene: "+path)
  if resource!=null:
   var model: Node3D = resource.instantiate()
   root.add_child(model)
   var meshes := model.find_children("*","MeshInstance3D",true,false)
   if legacy:
    verify(meshes.size()==1,entry.id+" exported as one combined mesh")
    if meshes.size()==1:
     var bounds: AABB = meshes[0].global_transform*meshes[0].get_aabb()
     verify(bounds.size.x>=entry.width*4-.1 and bounds.size.x<=entry.width*4+.25 and bounds.size.z>=entry.depth*4-.1 and bounds.size.z<=entry.depth*4+(.75 if entry.kind=="parking_tower" else .1),entry.id+" preserves rectangular metre footprint")
     verify(bounds.size.y<5 if entry.kind!="parking_tower" else bounds.size.y>12 and bounds.size.y<14,entry.id+" ground/height axes remain correct")
   else:
    # Station parts, curb decals and structure samples are not combined parking meshes.
    verify(meshes.any(func(node):return node.mesh!=null),entry.id+" has real model geometry")
   model.free()
  var image := Image.load_from_file(ProjectSettings.globalize_path(entry.preview))
  verify(image!=null and image.get_size()==Vector2i(800,680) and image.get_format()==Image.FORMAT_RGBA8,entry.id+" preview has expected RGBA resolution")
 verify(legacy_counts==LEGACY_KINDS,"original park and parking category counts")
 verify(counts==CATALOG_KINDS,"expanded facility category counts")
 if imports.values().has(false):
  quit(1) # Do not enter a gallery whose asset dependency already failed.
  return
 var scene = load("res://main.tscn").instantiate()
 root.add_child(scene)
 current_scene=scene
 var saved_city=scene.city
 scene.map_zoom=1.17
 scene.select_category("park")
 verify(scene.find_children("Tool_facilities_gallery","Button",true,false).is_empty(),"facilities demonstration button removed from player HUD")
 set_meta("construction_session",{"city":scene.city,"map_zoom":scene.map_zoom,"origin":scene.origin})
 change_scene_to_file("res://facilities_showcase.tscn") # Test fixture only: retain standalone scene and return-path coverage.
 await process_frame
 await process_frame
 var showcase=current_scene
 verify(showcase.scene_file_path=="res://facilities_showcase.tscn","standalone facilities fixture remains usable without a player HUD button")
 verify(showcase.gallery.get_child_count()==entries.size(),"standalone gallery presents the complete expanded catalog")
 var displayed_models := []
 for viewport in showcase.gallery.find_children("*","SubViewport",true,false):
  for child in viewport.get_children():
   if child is Node3D and not child.scene_file_path.is_empty():displayed_models.append(child.scene_file_path)
 verify(displayed_models==entries.map(func(entry):return entry.model),"standalone gallery instantiates every catalog GLB from its imported path")
 verify(showcase.parking.groups().size()==1,"runtime starts with merged L shape")
 showcase.act("merge")
 verify(showcase.merge_view.visible,"merge mode shows runtime geometry")
 showcase.act("bridge")
 verify(showcase.parking.groups().size()==2 and showcase.merged_root.get_child_count()==3,"bridge removal rebuilds two meshes plus independent tower")
 showcase.act("bridge")
 verify(showcase.parking.groups().size()==1 and showcase.merged_root.get_child_count()==2,"bridge restoration recombines to one mesh plus tower")
 showcase.act("small")
 verify(showcase.parking.groups().size()==1,"new adjacent small lot joins same complex")
 showcase.act("back")
 await process_frame
 await process_frame
 verify(current_scene.city==saved_city and is_equal_approx(current_scene.map_zoom,1.17),"return preserves original city/camera")
 current_scene.queue_free()
 await process_frame
 print("RESULT %d/%d facility checks passed" % [checks-failed,checks])
 quit(1 if failed else 0)
