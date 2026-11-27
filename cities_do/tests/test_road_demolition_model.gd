extends SceneTree
const City=preload("res://core/city_model.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func fixture():
 var city=City.new(100,100)
 city.add_road(PackedVector2Array([Vector2(10,30),Vector2(90,30)]))
 city.add_road(PackedVector2Array([Vector2(40,10),Vector2(40,50)]))
 city.add_road(PackedVector2Array([Vector2(10,80),Vector2(90,80)]))
 return city
func run():
 var city=fixture()
 verify(city.has_method("road_demolition_selection") and city.has_method("demolish_road_selection"),"player selection and transactional mutation APIs exist")
 if failures:quit(1);return
 var original:=var_to_bytes(city.roads)
 var selected: Dictionary=city.road_demolition_selection(0,Vector2(25.3,30))
 verify(selected.ok and selected.cuts.size()==1 and selected.cuts[0].first==0 and selected.cuts[0].last==30,"model click selects whole free-end to actual junction span")
 verify(var_to_bytes(city.roads)==original,"model preview never mutates roads")
 var far:={}
 for parcel in city.zoning_grid.parcels.values():
  if parcel.frame.road_index==2:far[parcel.id]=var_to_bytes(parcel)
 for id in far:city.zone_designations[id]="commercial"
 var result: Dictionary=city.demolish_road_selection(selected)
 verify(result.ok and is_equal_approx(result.removed_cells,30),"transaction deletes exactly selected click arc length")
 verify(city.roads[0].parcel_id==0 and city.roads[0].points[0]==Vector2(40,30) and city.roads[0].source_start==30,"survivor retains original ID and source offset")
 var preserved:=not far.is_empty()
 for id in far:preserved=preserved and city.zoning_grid.parcels.has(id) and var_to_bytes(city.zoning_grid.parcels.get(id))==far[id] and city.zone_designations.get(id)=="commercial"
 verify(preserved,"far parcel records and painted zoning remain unchanged")
 verify(not city.demolish_road_selection(selected).ok,"stale selection cannot delete a different interval")
 city=fixture()
 selected=city.road_demolition_selection(0,Vector2(25.3,30),Vector2(70,30))
 verify(is_equal_approx(selected.cuts[0].first,15.3) and selected.cuts[0].last==30,"model drag uses exact press and clamps at junction")
 result=city.demolish_road_selection(selected)
 verify(result.ok and is_equal_approx(result.removed_cells,14.7) and city.roads[0].points[-1].is_equal_approx(Vector2(25.3,30)) and city.roads[1].points[0]==Vector2(40,30),"drag mutation is exactly preview with original plus unique fragment IDs")
 verify(city.roads[0].parcel_id==0 and city.roads[1].parcel_id==3 and city.roads[1].zoning_source_id==0 and city.roads[1].source_start==30,"new fragment preserves source identity and does not reuse IDs")
 city=City.new(100,100)
 city.add_road(PackedVector2Array([Vector2(10,30),Vector2(90,30)]))
 var cuts: Array=[]
 for interval in [Vector2(10,20),Vector2(15,25),Vector2(25,30),Vector2(50,60),Vector2(10,20)]:
  cuts.append({"id":0,"first":interval.x,"last":interval.y,"points":City.RoadJunctions.slice(city.roads[0].points,interval.x,interval.y)})
 result=city.demolish_road_selection({"ok":true,"cuts":cuts})
 verify(result.ok and is_equal_approx(result.removed_cells,30) and city.roads.size()==3,"overlapping duplicated touching and disjoint cuts consolidate once per original record")
 verify(city.roads[0].points==PackedVector2Array([Vector2(10,30),Vector2(20,30)]) and city.roads[1].points==PackedVector2Array([Vector2(40,30),Vector2(60,30)]) and city.roads[2].points==PackedVector2Array([Vector2(70,30),Vector2(90,30)]),"consolidation keeps exact surviving original-coordinate intervals")
 verify(city.roads[0].parcel_id==0 and city.roads[1].parcel_id==1 and city.roads[2].parcel_id==2 and city.roads[2].source_start==60,"multiple fragments keep stable source offsets and monotonic IDs")
 original=var_to_bytes(city.roads)
 verify(not city.demolish_road_selection({"ok":true,"cuts":[{"id":0,"first":0.0,"last":1.0,"points":PackedVector2Array([Vector2(10,30),Vector2(11,30)])},{"id":999,"first":0.0,"last":1.0}]}).ok and var_to_bytes(city.roads)==original,"mixed valid and missing IDs fail atomically")
 city=City.new(100,100)
 city.add_road(PackedVector2Array([Vector2(10,30),Vector2(20,30)]))
 city.add_road(PackedVector2Array([Vector2(20,30),Vector2(30,30)]))
 selected=city.road_demolition_selection(0,Vector2(15,30))
 verify(selected.cuts.size()==2,"click traverses authored two-arm seam")
 result=city.demolish_road_selection(selected)
 verify(result.ok and city.roads.is_empty() and city.zoning_grid.count()==0,"multi-record click deletes whole selected span and no phantom parcels")
 city=fixture()
 result=city.demolish_road_unit(0,Vector2(25.3,30))
 verify(result.ok and result.removed_cells==1,"legacy four-metre internal API remains unchanged")
 city=City.new(100,100)
 var horizontal:=PackedVector2Array([Vector2(20,40),Vector2(40,40)])
 city.add_road(horizontal);city.add_road(PackedVector2Array([Vector2(40,40),Vector2(40,60)]));city.add_road(PackedVector2Array([Vector2(40,40),Vector2(60,40)]))
 verify(city.junctions.size()==1 and city.junctions[0].arms.size()==3,"separately built horizontal and vertical roads form a true T")
 verify(city.demolish_road_selection(city.road_demolition_selection(2,Vector2(50,40))).ok and city.roads.size()==2 and city.junctions.is_empty(),"remove one T arm and retain an ordinary L-shaped connection")
 original=var_to_bytes(city.roads)
 selected=city.road_demolition_selection(1,Vector2(40,50),Vector2(20,40))
 verify(selected.cuts.size()==1 and selected.cuts[0].id==1 and selected.cuts[0].first==0,"drag toward horizontal road stops at L corner")
 selected=city.road_demolition_selection(1,Vector2(40,50))
 verify(selected.cuts.size()==1 and selected.cuts[0].id==1 and var_to_bytes(city.roads)==original,"vertical whole-span preview excludes horizontal road and does not mutate")
 result=city.demolish_road_selection(selected)
 verify(result.ok and city.roads.size()==1 and city.roads[0].parcel_id==0 and city.roads[0].points==horizontal,"T then arm removal then vertical removal leaves original horizontal road only")
 var flat:bool=city.roads.size()==1 and city.road_visuals.size()==1 and city.road_visuals[0].flat_end
 for polygon in city.road_pavement:
  for point in polygon:flat=flat and point.x<=40.0001 and point.x>=19.9999
 verify(flat,"surviving horizontal corner end has a flat butt cap with no painted extension")
 print("RESULT %d/%d road demolition model checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
