extends RefCounted
## Identity-preserving lots -> 4-neighbour components -> one combined mesh each.
var lots: Array[Dictionary] = []
var next_id := 1
var limit := Vector2i(32,32)

func add(kind: String, origin: Vector2i, size: Vector2i) -> int:
 if kind not in ["surface_parking","parking_tower"]: return -1
 if size not in [Vector2i(2,4),Vector2i(4,2),Vector2i(4,4),Vector2i(4,8),Vector2i(8,4)]: return -1
 if kind == "parking_tower" and size != Vector2i(4,4): return -1
 if origin.x%2 or origin.y%2 or origin.x<0 or origin.y<0 or origin.x+size.x>limit.x or origin.y+size.y>limit.y: return -1
 var rect := Rect2i(origin,size)
 for lot in lots:
  if rect.intersects(Rect2i(lot.origin,lot.size)): return -1
 var id := next_id
 next_id += 1
 lots.append({"id":id,"kind":kind,"origin":origin,"size":size})
 return id

func remove(id: int) -> bool:
 for i in range(lots.size()):
  if lots[i].id == id:
   lots.remove_at(i)
   return true
 return false

func groups() -> Array:
 var remaining := {}
 for lot in lots:
  if lot.kind != "surface_parking": continue
  for x in range(lot.origin.x/2,(lot.origin.x+lot.size.x)/2):
   for z in range(lot.origin.y/2,(lot.origin.y+lot.size.y)/2): remaining[Vector2i(x,z)] = lot.id
 var output := []
 var keys: Array = remaining.keys()
 keys.sort_custom(func(a,b):return a.x<b.x or (a.x==b.x and a.y<b.y))
 for seed in keys:
  if not remaining.has(seed): continue
  var queue := [seed]
  var blocks := []
  var ids := {}
  while not queue.is_empty():
   var p: Vector2i = queue.pop_back()
   if not remaining.has(p): continue
   ids[remaining[p]] = true
   remaining.erase(p)
   blocks.append(p)
   for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
    if remaining.has(p+d): queue.append(p+d)
  blocks.sort_custom(func(a,b):return a.x<b.x or (a.x==b.x and a.y<b.y))
  var group := layout(blocks)
  group.lot_ids = ids.keys()
  group.lot_ids.sort()
  output.append(group)
 return output

static func layout(blocks: Array) -> Dictionary:
 var occupied := {}
 for p in blocks: occupied[p] = true
 var boxes := []
 var edges := []
 for p in blocks:
  var x: float = p.x*8
  var z: float = p.y*8
  boxes.append(item("Asphalt",Vector3(x+4,.08,z+4),Vector3(8,.16,8),"asphalt"))
  for y in [3.03,5.5,7.94]: boxes.append(item("BayLine",Vector3(x+2.5,.17,z+y),Vector3(5,.025,.055),"paint"))
  boxes.append(item("BayBack",Vector3(x+.12,.17,z+5.5),Vector3(.055,.025,4.94),"paint"))
  boxes.append(item("AisleDash",Vector3(x+6.5,.17,z+5.3),Vector3(.07,.025,1.25),"paint"))
  for pair in [[Vector2i.UP,"north"],[Vector2i.RIGHT,"east"],[Vector2i.DOWN,"south"],[Vector2i.LEFT,"west"]]:
   if occupied.has(p+pair[0]): continue
   var side: String = pair[1]
   edges.append([p.x,p.y,side])
   if side in ["north","south"]:
    boxes.append(item("OuterCurb",Vector3(x+2.5,.25,z+(.10 if side=="north" else 7.9)),Vector3(5,.25,.18),"curb"))
   else:
    boxes.append(item("OuterCurb",Vector3(x+(.10 if side=="west" else 7.9),.25,z+5.5),Vector3(.18,.25,5),"curb"))
 return {"blocks":blocks,"capacity":2*blocks.size(),"boundary":edges,"boxes":boxes}

static func item(name: String, pos: Vector3, size: Vector3, mat: String) -> Dictionary:
 return {"name":name,"pos":pos,"size":size,"mat":mat}

static func combined_mesh(group: Dictionary) -> ArrayMesh:
 var output := ArrayMesh.new()
 for entry in [["asphalt",Color("4c5659")],["curb",Color("c8cbc3")],["paint",Color("eee7cf")]]:
  var surface := SurfaceTool.new()
  surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  var count := 0
  for shape in group.boxes:
   if shape.mat != entry[0]: continue
   var primitive := BoxMesh.new()
   primitive.size = shape.size
   surface.append_from(primitive,0,Transform3D(Basis.IDENTITY,shape.pos))
   count += 1
  if count == 0: continue
  var material := StandardMaterial3D.new()
  material.albedo_color = entry[1]
  material.roughness = .8
  surface.set_material(material)
  surface.commit(output)
 return output
