extends RefCounted
## Reuses the transport chooser and viewport: ordered stops, first stop again to close.
var view
var stops:Array=[]
var kind:=""
var mode:=""
func _init(owner_view):view=owner_view
func cancel():stops.clear();kind=""
func handle_input(event:InputEvent)->bool:
 if view.mode not in ["transit_line","freight_line","remove_line"]:cancel();mode="";return false
 if mode!=view.mode:cancel();mode=view.mode
 if (event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE) or (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT):
  cancel();view.mode="select";view.refresh();return true
 if not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT:return false
 if not event.pressed:return true
 var point:Vector2=view.world(event.position);var lot:Dictionary={}
 for record:Dictionary in view.city.public_facilities.lots:
  if record.public_asset_id not in ["bus-stop-01","train-station-01","subway-entrance-01"]:continue
  if Geometry2D.is_point_in_polygon(point,record.polygon):lot=record;break
 if lot.is_empty():return true
 if view.mode=="remove_line":
  for line:Dictionary in view.city.transit_lines:
   if lot.id in line.stops:
    view.city.remove_transit_line(line.id);view.message="";view.refresh();return true
  return true
 var selected_kind:String={"bus-stop-01":"bus","train-station-01":"rail","subway-entrance-01":"metro"}[lot.public_asset_id]
 if view.mode=="freight_line":
  if selected_kind!="rail":return true
  selected_kind="freight"
 if stops.is_empty():kind=selected_kind;stops.append(lot.id)
 elif selected_kind!=kind:view.message="종류가 같은 정류장을 선택하세요"
 elif lot.id==stops[0] and stops.size()>=2:
  var result:Dictionary=view.city.create_transit_line(kind,stops)
  view.message="" if result.get("ok",false) or result.get("queued",false) else result.reason
  if result.get("ok",false) or result.get("queued",false):cancel();view.mode="select"
 elif not lot.id in stops:stops.append(lot.id)
 view.refresh();return true
func draw_preview():
 if view.mode not in ["transit_line","freight_line"] or stops.is_empty():return
 var points:=PackedVector2Array()
 for id:int in stops:
  for lot:Dictionary in view.city.public_facilities.lots:
   if lot.id==id:points.append(view.screen(lot.position))
 for p:Vector2 in points:view.draw_arc(p,9,0,TAU,24,Color("36b7ff"),2,true)
 # Selection order, not a fabricated running path; real routing is validated on closure.
