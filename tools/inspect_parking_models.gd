extends SceneTree
## Read-only inspection: never hide whole combined meshes or edit imported resources.
const IDS:=["parking-small-2x4","parking-medium-4x4","parking-large-4x8","parking-tower-4x4-4f"]
func _initialize():run.call_deferred()
func run():
 var path:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
 var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/facilities/catalog.json")).facilities
 var report:={"mode":"read-only; approved empty sources integrated; no runtime hiding or original edits","parking":[],"solar":{}}
 var checks:=0
 for id in IDS:
  var entry: Dictionary=catalog.filter(func(e):return e.id==id)[0]
  var model=load(entry.model).instantiate()
  var meshes: Array=model.find_children("*","MeshInstance3D",true,false)
  assert(meshes.size()==1 and meshes[0].name=="FacilityCombinedMesh");checks+=1
  var mesh: Mesh=meshes[0].mesh
  var surfaces:=[]
  for i in range(mesh.get_surface_count()):
   var material: Material=mesh.surface_get_material(i)
   surfaces.append(material.resource_name if material!=null else "")
  assert(surfaces.all(func(n):return not str(n).begins_with("car")));checks+=1
  report.parking.append({"id":id,"model":entry.model,"mesh_instance_count":meshes.size(),"mesh_node":str(meshes[0].name),"surfaces":surfaces,"separate_vehicle_node":false,"removal_applied":true})
  model.free()
 var solar=load("res://assets/services/power-solar.glb").instantiate()
 var lot: MeshInstance3D=solar.find_child("Lot",true,false)
 assert(lot!=null)
 var bounds: AABB=lot.transform*lot.get_aabb()
 assert(is_equal_approx(bounds.position.x,-8) and is_equal_approx(bounds.position.z,-8) and is_equal_approx(bounds.size.x,16) and is_equal_approx(bounds.size.z,16));checks+=1
 report.solar={"lot_bounds_local_m":str(bounds),"base_width_m":bounds.size.x,"base_depth_m":bounds.size.z,"declared_cells":Vector2i(4,4),"base_matches_declared_footprint":true,"screenshot_road_encroachment":"unconfirmed without original world positions; local base is within declared lot","existing_order_fix":"14177349d8d4762c914616c55b588f00c09e49b4"}
 solar.free()
 var file:=FileAccess.open(path,FileAccess.WRITE);assert(file!=null);file.store_string(JSON.stringify(report,"  "));file.close()
 print("RESULT %d/%d read-only asset structure checks passed; EMPTY_PARKING_INTEGRATED" % [checks,checks]);quit()
