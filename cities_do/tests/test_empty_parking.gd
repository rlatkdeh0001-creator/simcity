extends SceneTree
const IDS:=["parking-small-2x4","parking-medium-4x4","parking-large-4x8","parking-tower-4x4-4f"]
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func run():
 var path:=ProjectSettings.globalize_path("res://../docs/empty-parking-game-validation/before-models.json")
 var record:=OS.get_cmdline_user_args().has("--record-before")
 var before: Dictionary={} if record else JSON.parse_string(FileAccess.get_file_as_string(path))
 var current:={}
 for id in IDS:
  var model=load("res://assets/facilities/"+id+".glb").instantiate();root.add_child(model)
  var meshes: Array=model.find_children("*","MeshInstance3D",true,false)
  verify(meshes.size()==1 and meshes[0].name=="FacilityCombinedMesh",id+" retains its single visible facility mesh")
  var mesh: MeshInstance3D=meshes[0];var box: AABB=mesh.global_transform*mesh.get_aabb();var cars:=false
  for i in range(mesh.mesh.get_surface_count()):
   var material: Material=mesh.mesh.surface_get_material(i)
   if material!=null and material.resource_name.begins_with("car"):cars=true
  verify(not cars,id+" has no baked parked-car material geometry")
  current[id]={"x":box.position.x,"y":box.position.y,"z":box.position.z,"width":box.size.x,"depth":box.size.z,"root_transform":var_to_str(model.transform),"mesh_transform":var_to_str(mesh.global_transform)}
  if not record:
   var old: Dictionary=before[id];var now: Dictionary=current[id]
   verify(["x","y","z","width","depth"].all(func(k):return absf(float(now[k])-float(old[k]))<.001),id+" retains its metre footprint and ground datum")
   verify(now.root_transform==old.root_transform and now.mesh_transform==old.mesh_transform,id+" retains front orientation and coordinate transforms")
  model.free()
 if record:
  var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(current,"  "));file.close()
 print("RESULT %d/%d empty parking checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
