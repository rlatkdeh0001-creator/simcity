extends SceneTree
const City=preload("res://core/city_model.gd")
const Parcels=preload("res://core/road_parcels.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func aligned(city,basis: Dictionary) -> bool:
 for cell in city.zoning_grid.parcels.values():
  for p in cell.polygon:
   var delta: Vector2=p-basis.origin
   for value in [delta.dot(basis.along),delta.dot(basis.outward)]:
    if absf(value-roundf(value))>.001:return false
 return true
func run():
 for shape in ["L","T","cross","rotated","single_stroke"]:
  var city:=City.new(100,100)
  var start:=Vector2(20.25,30.5);var axis:=Vector2.RIGHT
  if shape=="rotated":start=Vector2(30,20);axis=Vector2(.8,.6)
  var normal:=Vector2(-axis.y,axis.x);var end:=start+axis*30
  var points:=PackedVector2Array([start,end])
  if shape=="single_stroke":points.append(end+normal*30)
  verify(city.add_road(points,"local",true,3).ok,shape+" creates its real first road")
  var basis: Dictionary=Parcels.blocks(PackedVector2Array([start,end]),1.5,0)[1]
  var original: PackedVector2Array=city.roads[0].points.duplicate();var far: Dictionary=city.zoning_grid.parcel_at(start+axis*2.5+normal*2)
  if shape!="single_stroke":
   var joint: Vector2=end if shape in ["L","rotated"] else start+axis*15
   var branch:=PackedVector2Array([joint,joint+normal*25])
   if shape=="cross":branch[0]=joint-normal*15
   verify(city.add_road(branch,"local",true,5 if shape=="T" else 3).ok,shape+" creates its orthogonal connection")
  verify(aligned(city,basis),shape+" connected roads share both axes of one boundary lattice without half-cell double lines")
  verify(city.roads[0].points==original,shape+" grid alignment never moves authored road points")
  verify(not far.is_empty() and city.zoning_grid.parcels.has(far.id) and city.zoning_grid.parcels[far.id].polygon==far.polygon,shape+" preserves unaffected first-road parcel identities and positions")
 var city:=City.new(100,100);city.add_road(PackedVector2Array([Vector2(10,30),Vector2(50,30)]),"local",true,3)
 city.add_road(PackedVector2Array([Vector2(50,30),Vector2(50,60)]),"local",true,3)
 var frame: Dictionary=preload("res://core/road_grid_snap.gd").frame_near(city,Vector2(50,48))
 verify(absf(frame.along.dot(Vector2.RIGHT))>.9999 and absf(frame.origin.y-31.5)<.001,"future road input reuses the actual shared zoning board at the perpendicular arm")
 print("RESULT %d/%d shared road grid checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
