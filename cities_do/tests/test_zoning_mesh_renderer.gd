extends SceneTree
const City=preload("res://core/city_model.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok:bool,label:String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func settle():
 for i in range(5):await process_frame
func run():
 verify(FileAccess.file_exists("res://core/zoning_mesh_renderer.gd"),"chunked zoning mesh renderer exists")
 if failures:quit(1);return
 root.size=Vector2i(1280,820)
 var game=load("res://main.tscn").instantiate();game.city=City.new(100,100);game.paused=true
 game.city.add_road(PackedVector2Array([Vector2(20,30),Vector2(40,30),Vector2(55,40),Vector2(60,55)]))
 game.city.add_road(PackedVector2Array([Vector2(20,75),Vector2(80,75)]))
 var snapshot:=var_to_bytes([game.city.roads,game.city.zoning_grid.parcels])
 root.add_child(game);await settle();game.select_category("build");game.map_zoom=.9;await settle()
 var mesh=game.world_renderer.zones
 verify(mesh.blocks.size()>1 and mesh.blocks.size()<game.city.zoning_grid.count(),"real straight/curved grids are grouped into cullable frame blocks")
 verify(mesh.cell_slots.size()==game.city.zoning_grid.count(),"every unchanged road-local cell has exactly one palette entry")
 var instances:Array=[];var high_vertices:=0;var low_vertices:=0
 for block in mesh.blocks:
  verify(block.node is MeshInstance2D and block.detail is ArrayMesh and block.plain is ArrayMesh,"one cullable mesh node reuses two static LOD resources")
  instances.append(block.detail.get_rid());instances.append(block.plain.get_rid())
  high_vertices+=block.detail.surface_get_array_len(0);low_vertices+=block.plain.surface_get_array_len(0)
 verify(high_vertices==game.city.zoning_grid.count()*20 and low_vertices==game.city.zoning_grid.count()*4,"inset cells and gap bands replace all polygon/line draw commands")
 var generation:int=mesh.geometry_generation;var slot:String=mesh.cell_slots.keys()[0];var palette_id:RID=mesh.palette_texture.get_rid();var previous:int=mesh.palette_generation
 game.city.zone_designations[slot]="industrial";game.refresh();await settle()
 verify(mesh.geometry_generation==generation and mesh.palette_generation==previous+1 and mesh.palette_texture.get_rid()==palette_id,"zoning paint updates existing palette pixels without rebuilding meshes or textures")
 verify(mesh.palette_pixel(slot).is_equal_approx(Color(game.ZONE_COLORS.industrial, .5)),"designated cell preserves its production tint and alpha")
 var current:Array=[]
 for block in mesh.blocks:current.append(block.detail.get_rid());current.append(block.plain.get_rid())
 verify(instances==current,"paint preserves every chunk ArrayMesh identity")
 game.origin+=Vector2(35,20);game.map_zoom=.35;await settle()
 verify(mesh.geometry_generation==generation and mesh.blocks.all(func(b):return b.node.mesh==b.plain),"far zoom swaps cached full cells without lines or geometry regeneration")
 game.map_zoom=.8;await settle()
 verify(mesh.blocks.all(func(b):return b.node.mesh==b.detail),"normal zoom restores inset gap representation")
 game.select_category("water");await settle();verify(not mesh.visible,"existing tab visibility still hides zoning meshes")
 verify(var_to_bytes([game.city.roads,game.city.zoning_grid.parcels])==snapshot,"rendering and camera changes do not mutate model roads or curved grid cells")
 game.city.zoning_grid.clear();game.refresh();await settle()
 verify(mesh.geometry_generation==generation+1 and mesh.cell_slots.is_empty() and mesh.blocks.is_empty(),"independent parcel cache changes invalidate static geometry even when roads are unchanged")
 game.queue_free();await process_frame
 print("RESULT %d/%d zoning mesh checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
