extends SceneTree
const Model=preload("res://core/city_model.gd")
var checks:=0
var failed:=0
func _initialize():run.call_deferred()
func verify(ok: bool,detail: String):
 checks+=1
 if ok:print("PASS "+detail)
 else:failed+=1;push_error("FAIL "+detail)
func run():
 for diagonal in [false,true]:
  var city=Model.new(60,60,42);city.population_enabled=false
  city.add_road(PackedVector2Array([Vector2(10,30),Vector2(42,42) if diagonal else Vector2(42,30)]))
  var frame: Dictionary=city.zoning_grid.frames.values()[0]
  var square: PackedVector2Array=city.Parcels.polygon(frame,0,0,2)
  verify(city.paint_zones(square,"residential").changed==4,"initial free designation fills four cells diagonal="+str(diagonal))
  var before: Dictionary=city.zone_designations.duplicate()
  for other in ["commercial","industrial","residential"]:
   verify(city.paint_zones(square,other).changed==0 and city.zone_designations==before,"occupied cells never change on brush "+other)
  var wide: PackedVector2Array=city.Parcels.polygon(frame,0,0,4)
  verify(city.paint_zones(wide,"commercial").changed==12,"mixed drag skips four existing cells and paints twelve empty cells")
  verify(before.keys().all(func(id):return city.zone_designations[id]=="residential"),"original residential patch is preserved inside commercial drag")
  verify(city.paint_zones(wide,"industrial").changed==0,"fully zoned mixed range rejects all different-zone repaint")
  verify(city.paint_zones(square,"").changed==4,"existing eraser explicitly clears chosen four cells")
  verify(city.paint_zones(square,"industrial").changed==4,"erase then repaint allows intended zone change")
  verify(city.paint_zones(wide,"").changed==16 and city.zone_designations.is_empty(),"erase clears mixed types without changing other city data")
  verify(city.funds==50000 and city.buildings.is_empty(),"painting never charges or constructs")
 print("RESULT %d/%d non-overpaint checks passed"%[checks-failed,checks]);quit(1 if failed else 0)
