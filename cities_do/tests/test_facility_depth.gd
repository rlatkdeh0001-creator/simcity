extends SceneTree
var checks:=0
var failed:=0
func _initialize():run.call_deferred()
func verify(ok: bool,detail: String):
 checks+=1
 if ok:print("PASS "+detail)
 else:failed+=1;push_error("FAIL "+detail)
func run():
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);await process_frame
 var public=game.city.public_facilities
 for pair in [["park-garden-2x2",Vector2(33,35)],["power-solar",Vector2(30,36)]]:
  var record: Dictionary=public.preview(pair[0],pair[1]).record;record.id=game.city.next_id;game.city.next_id+=1;public.lots.append(record)
 verify(game.building_depth(public.lots[0])==game.building_depth(public.lots[1]),"repro solar and foreground garden have equal old far-corner sort key")
 verify(game.has_method("building_draw_order"),"shared geometry-aware painter order exists")
 if game.has_method("building_draw_order"):
  var ordered: Array=game.building_draw_order()
  verify(ordered[0].public_asset_id=="power-solar" and ordered[1].public_asset_id=="park-garden-2x2","rear solar drawn before actual foreground garden independent of tied old depth")
  public.lots.reverse();verify(game.building_draw_order().map(func(n):return n.public_asset_id)==["power-solar","park-garden-2x2"],"creation order cannot flip front and rear")
  for id in ["power-wind","parking-large-4x8","park-play-4x4"]:
   public.lots.clear()
   var rear: Dictionary=public.preview(id,Vector2(30,36)).record;rear.id=1
   var bounds: Rect2=game.city.Parcels.bounds(rear.polygon)
   var front: Dictionary=public.preview("park-garden-2x2",Vector2(bounds.end.x+1,bounds.position.y+1)).record;front.id=2
   public.lots.append_array([front,rear])
   verify(game.building_draw_order()[0].id==1,id+" uses shared footprint occlusion, not oversized forward corner")
   public.lots.reverse();verify(game.building_draw_order()[0].id==1,id+" remains stable after inventory reorder")
  var snapshot: String=JSON.stringify(public.lots);game.building_draw_order();verify(JSON.stringify(public.lots)==snapshot,"render sorting never mutates placement inventory or original geometry")
  var replaced: Dictionary=public.lots[0].duplicate(true);replaced.render_test_tag=true;public.lots[0]=replaced
  verify(game.building_draw_order().any(func(n):return n.get("render_test_tag",false)),"cached indices resolve replacement city records instead of stale dictionary references")
  for angle in [.2,PI/4,PI/2]:
   public.lots.clear()
   var rear: Dictionary=public.preview("power-solar",Vector2(30,36)).record;rear.id=1
   var front: Dictionary=public.preview("park-garden-2x2",Vector2(33,35)).record;front.id=2
   for record in [rear,front]:
    var rotated:=PackedVector2Array()
    for p in record.polygon:rotated.append((p-Vector2(30,36)).rotated(angle)+Vector2(30,36))
    record.polygon=rotated
   public.lots.append_array([front,rear]);verify(game.building_draw_order()[0].id==1,"ray ordering supports rotated convex lots angle="+str(angle))
 game.queue_free();await process_frame
 print("RESULT %d/%d facility depth checks passed"%[checks-failed,checks]);quit(1 if failed else 0)
