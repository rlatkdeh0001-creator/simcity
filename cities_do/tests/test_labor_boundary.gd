extends SceneTree
var checks:=0
var failed:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failed+=1;printerr("FAIL "+label)
func _initialize():run.call_deferred()
func place(city,lower_y:float,upper_y:float)->Dictionary:
 for parcel:Dictionary in city.zoning_grid.parcels.values():
  if parcel.center.y<lower_y or parcel.center.y>upper_y:continue
  var result:Dictionary=city.add_building_at(parcel.center,"industrial")
  if result.ok:return result.building
 return {}
func run():
 var c=load("res://core/city_model.gd").new(100,100)
 check(c.population.core.has_method("GetLaborBoundaryDistances"),"worker computes proven boundary-road distances")
 if not c.population.core.has_method("GetLaborBoundaryDistances"):finish();return
 c.add_road(PackedVector2Array([Vector2(0,30),Vector2(60,30)]))
 var first:Dictionary=place(c,20,40)
 c.add_road(PackedVector2Array([Vector2(20,70),Vector2(40,70)]))
 var second:Dictionary=place(c,60,80)
 check(not first.is_empty() and not second.is_empty(),"actual native lots exist beside both road components")
 c.population.sync(c.buildings)
 var distances:Dictionary=c.population.core.GetLaborBoundaryDistances(c.roads[0].parcel_id,Vector2(0,30))
 check(distances.has(first.id) and distances[first.id]>0,"connected native frontage reachable from true boundary")
 check(not distances.has(second.id),"isolated road is not a fabricated commute route")
 check(c.population.core.GetLaborBoundaryDistances(999999,Vector2.ZERO).is_empty(),"unknown boundary road grants no route")
 finish()
func finish():print("LABOR_BOUNDARY checks=%d failed=%d"%[checks,failed]);quit(1 if failed else 0)
