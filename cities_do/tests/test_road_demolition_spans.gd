extends SceneTree
const Paths=preload("res://core/road_junctions.gd")
var checks:=0
var failed:=0
var helper: GDScript
func _initialize():run.call_deferred()
func verify(value: bool,label: String):
 checks+=1
 if value:print("PASS "+label)
 else:
  failed+=1
  push_error("FAIL "+label)
func road(id: int,points: Array,width: float=2.0,lanes: int=2) -> Dictionary:
 return {"parcel_id":id,"points":PackedVector2Array(points),"width":width,"lanes":lanes}
func select(roads: Array,id: int,point: Vector2,drag: Variant=null) -> Dictionary:
 return helper.selection(roads,id,point,drag)
func cut(result: Dictionary,id: int,first: float,last: float) -> bool:
 for item in result.get("cuts",[]):
  if item.id==id and absf(item.first-first)<.0005 and absf(item.last-last)<.0005:
   return absf(Paths.length_of(item.points)-(last-first))<.0005
 return false
func run():
 verify(ResourceLoader.exists("res://core/road_demolition.gd"),"pure selection helper exists")
 if failed:quit(1);return
 helper=load("res://core/road_demolition.gd")
 var roads: Array=[road(17,[Vector2(0,0),Vector2(20,0)])]
 var result:=select(roads,17,Vector2(7.3,.4))
 verify(result.ok and result.cuts.size()==1 and cut(result,17,0,20),"click selects free-end to free-end span")
 var joined: Array=[road(8,[Vector2(0,0),Vector2(5,0)]),road(31,[Vector2(10,0),Vector2(5,0)],4,4),road(99,[Vector2(10,0),Vector2(15,0)])]
 result=select(joined,31,Vector2(7,0))
 verify(result.ok and result.cuts.size()==3 and cut(result,8,0,5) and cut(result,31,0,5) and cut(result,99,0,5),"click traverses reversed authored straight joins and width transitions")
 var bent:Array=[road(8,[Vector2(0,0),Vector2(5,0)]),road(31,[Vector2(5,5),Vector2(5,0)],4,4),road(99,[Vector2(5,5),Vector2(10,5)])]
 result=select(bent,31,Vector2(5,2))
 verify(result.cuts.size()==1 and cut(result,31,0,5),"click stops at both two-arm corners instead of deleting neighbouring roads")
 result=select(bent,8,Vector2(4,0),Vector2(5,4))
 verify(result.cuts.size()==1 and cut(result,8,4,5),"forward drag clamps at first bent connection")
 result=select(bent,99,Vector2(6,5),Vector2(5,1))
 verify(result.cuts.size()==1 and cut(result,99,0,1),"reverse drag clamps at second bent connection")
 verify(not select(bent,8,Vector2(5,0),Vector2(5,1)).ok,"drag from selected road's corner cannot enter perpendicular road")
 var branched: Array=[road(17,[Vector2(0,0),Vector2(20,0)]),road(4,[Vector2(6,0),Vector2(6,5)]),road(7,[Vector2(14,-5),Vector2(14,5)])]
 result=select(branched,17,Vector2(10,0))
 verify(result.ok and result.cuts.size()==1 and cut(result,17,6,14),"mid-record T and cross clip click to junction-to-junction")
 result=select(branched,17,Vector2(2,0))
 verify(cut(result,17,0,6),"click does not pass a true T junction")
 result=select(branched,4,Vector2(6,2))
 verify(result.cuts.size()==1 and cut(result,4,0,5),"branch click stops at T without deleting trunk")
 result=select(roads,17,Vector2(7.3,.4),Vector2(7.4,0))
 verify(cut(result,17,7.3,9.3),"forward drag starts at exact projected press and grows first eight metres")
 result=select(roads,17,Vector2(7.3,.4),Vector2(3.1,0))
 verify(cut(result,17,1.3,7.3),"backward drag grows in eight-metre ceiling increments")
 result=select(roads,17,Vector2(7.3,0),Vector2(11.3,0))
 verify(cut(result,17,7.3,11.3),"exact eight-metre multiples do not add another increment")
 result=select(joined,8,Vector2(4,0),Vector2(6.4,0))
 verify(result.cuts.size()==2 and cut(result,8,4,5) and cut(result,31,2,5),"directional drag spans authored join and reversed record with shared arc budget")
 result=select(joined,99,Vector2(11,0),Vector2(8.6,0))
 verify(result.cuts.size()==2 and cut(result,99,0,1) and cut(result,31,0,3),"reverse directional drag spans multi-record straight join")
 result=select(branched,17,Vector2(10.3,0),Vector2(30,0))
 verify(result.cuts.size()==1 and cut(result,17,10.3,14),"forward drag clamps at cross even for distant cursor")
 result=select(branched,17,Vector2(10.3,0),Vector2(-10,0))
 verify(result.cuts.size()==1 and cut(result,17,6,10.3),"backward drag clamps at T even for distant cursor")
 var curved: Array=[road(42,[Vector2(0,0),Vector2(3,4),Vector2(6,4),Vector2(6,10)])]
 curved[0].source_start=100.0
 var frozen:=var_to_bytes(curved)
 result=select(curved,42,Paths.sample(curved[0].points,4.3),Paths.sample(curved[0].points,8.6))
 verify(cut(result,42,4.3,10.3) and result.cuts[0].points.size()==4,"sampled curve uses arc length and retains interior vertices, not chord or source offset")
 result.cuts[0].points[0]=Vector2(999,999)
 result=select(curved,42,Paths.sample(curved[0].points,9.3),Paths.sample(curved[0].points,5.2))
 verify(cut(result,42,3.3,9.3),"curved reverse drag uses sampled arc length")
 verify(var_to_bytes(curved)==frozen,"repeated preview and modifying returned geometry cannot mutate input roads")
 result=select(roads,17,Vector2(0,0))
 verify(cut(result,17,0,20),"click at exact first endpoint selects span")
 result=select(roads,17,Vector2(20,0))
 verify(cut(result,17,0,20),"click at exact last endpoint selects span")
 result=select(roads,17,Vector2(19.7,0),Vector2(50,0))
 verify(cut(result,17,19.7,20),"terminal remainder shorter than eight metres is clamped, never snapped backwards")
 result=select(roads,17,Vector2(0,0),Vector2(-3,0))
 verify(not result.ok and result.cuts.is_empty(),"outward drag from first free endpoint selects nothing")
 result=select(roads,17,Vector2(20,0),Vector2(23,0))
 verify(not result.ok and result.cuts.is_empty(),"outward drag from last free endpoint selects nothing")
 result=select(branched,17,Vector2(6,0),Vector2(4,0))
 verify(result.cuts.size()==1 and cut(result,17,4,6),"drag starting exactly at junction chooses pressed road arm in drag direction")
 result=select(branched,17,Vector2(6,0),Vector2(8,0))
 verify(result.cuts.size()==1 and cut(result,17,6,8),"junction-boundary forward drag cannot delete opposite arm")
 verify(not select(roads,999,Vector2.ZERO).ok,"missing stable ID is safely rejected")
 verify(not select(roads,17,Vector2(7,10)).ok,"press beyond selected road width is safely rejected")
 verify(not select(roads,17,Vector2(INF,0)).ok,"nonfinite press is safely rejected")
 verify(not select(roads,17,Vector2(7,0),Vector2(NAN,0)).ok,"nonfinite drag is safely rejected")
 verify(not select([],17,Vector2.ZERO).ok,"empty input is safely rejected")
 result=select(joined,8,Vector2(4,0),Vector2(14.5,0))
 verify(result.cuts.size()==3 and cut(result,8,4,5) and cut(result,31,0,5) and cut(result,99,0,5),"long drag crosses three authored records and clamps at final free endpoint")
 result=select(joined,8,Vector2(5,0),Vector2(6,0))
 verify(result.cuts.size()==1 and cut(result,31,3,5),"drag from exact two-arm seam enters next reversed record")
 result=select(joined,31,Vector2(5,0),Vector2(4,0))
 verify(result.cuts.size()==1 and cut(result,8,3,5),"drag from exact two-arm seam enters previous record")
 result=select(branched,17,Vector2(6,0))
 verify(result.cuts.size()==1 and cut(result,17,6,14),"exact junction click deterministically chooses forward span, never both sides")
 var junction_join: Array=joined.duplicate(true)
 junction_join.append(road(108,[Vector2(10,0),Vector2(10,4)]))
 result=select(junction_join,8,Vector2(4,0),Vector2(15,0))
 verify(result.cuts.size()==2 and cut(result,8,4,5) and cut(result,31,0,5),"multi-record drag stops at three-arm authored junction")
 verify(not select(roads,17,Vector2(7,0),Vector2(7,0)).ok,"zero-motion explicit drag has no direction; click must pass null")
 var curve_branch: Array=curved.duplicate(true)
 curve_branch.append(road(73,[Vector2(4.5,4),Vector2(4.5,8)]))
 result=select(curve_branch,42,Paths.sample(curve_branch[0].points,4.3),Vector2(6,10))
 verify(result.cuts.size()==1 and cut(result,42,4.3,6.5),"sampled curved record drag clips at a mid-road T by local arc distance")
 print("RESULT %d/%d road demolition span checks passed" % [checks-failed,checks])
 quit(1 if failed else 0)
