extends SceneTree
var checked := 0
var failed := 0
func verify(value: bool, detail: String) -> void:
 checked+=1
 if not value:
  failed+=1
  push_error("FAIL "+detail)
 else: print("PASS "+detail)
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 var entry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/services/catalog.json")).facilities[0]
 verify(entry.id=="crematorium-4x4" and entry.metres==[16.0,16.0],"crematorium keeps 4m cell scale")
 verify(not entry.simulation_enabled and entry.status=="asset_preview_only","asset catalog does not claim working service")
 var model: Node3D=load(entry.model).instantiate()
 root.add_child(model)
 var bounds := AABB()
 var first := true
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  var box: AABB=mesh.global_transform*mesh.get_aabb()
  bounds=box if first else bounds.merge(box)
  first=false
 verify(not first and bounds.position.is_finite() and bounds.size.is_finite(),"GLB imports with finite geometry")
 verify(is_equal_approx(bounds.size.x,16) and is_equal_approx(bounds.size.z,16),"model footprint exactly 16 x 16 metres")
 verify(absf(bounds.position.y)<.001 and absf(bounds.size.y-float(entry.height_m))<.01,"ground and full accessory height match specification")
 var doors=model.find_children("EntranceDoor*","Node3D",true,false)
 verify(doors.size()==1 and (doors[0].global_transform*doors[0].get_aabb()).get_center().z>3.0,"main entrance faces GLB +Z")
 model.queue_free()
 await process_frame
 var gallery=load("res://service_assets_showcase.tscn").instantiate()
 root.add_child(gallery)
 await process_frame
 verify(gallery.rigs.size()==4 and gallery.entries.size()==4,"dedicated gallery loads all four actual GLB assets")
 verify(gallery.entries.slice(0,3).all(func(e):return e.category=="service"),"public vehicles have separate service category")
 gallery.same_scale=true
 gallery.update_scale()
 verify(gallery.cameras.all(func(c):return is_equal_approx(c.size,30)),"same metre scale accommodates the full facility lot")
 gallery.queue_free()
 await process_frame
 print("RESULT %d/%d service asset checks passed" % [checked-failed,checked])
 quit(1 if failed else 0)
