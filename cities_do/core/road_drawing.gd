extends RefCounted
## Approved click modes; original main.gd drag path remains opt-in as hidden "legacy".
const Network=preload("res://core/traffic_network.gd")
const AngleSnap=preload("res://core/road_angle_snap.gd")
const LengthUnits=preload("res://core/road_length_units.gd")
var owner_reference: WeakRef
var view:
 get:return owner_reference.get_ref()
var kind:="straight"
var anchors: Array[Vector2]=[]
var start_tangent:=Vector2.ZERO
var last_result: Dictionary={}
func _init(owner):owner_reference=weakref(owner)
func cancel():
 anchors.clear();start_tangent=Vector2.ZERO
 view.drawing=false;view.stroke.clear();view.queue_redraw()
func set_kind(value: String):
 if value not in ["straight","curve","free","legacy"]:return
 if value!=kind:cancel()
 kind=value;view.mode="road"
 if view.has_method("update_road_modes"):view.update_road_modes()
 view.queue_redraw()
func snap(point: Vector2) -> Vector2:return view.city.RoadJunctions.snap_point(point,view.city.roads)
func tangent_at(point: Vector2) -> Vector2:
 var roads: Array=view.city.roads.duplicate();roads.reverse()
 for road in roads:
  var p: PackedVector2Array=road.points
  if point.distance_to(p[-1])<.0002:return (p[-1]-p[-2]).normalized()
  if point.distance_to(p[0])<.0002:return (p[0]-p[1]).normalized()
 for road in roads:
  for i in range(road.points.size()-1):
   if point.distance_to(Geometry2D.get_closest_point_to_segment(point,road.points[i],road.points[i+1]))<.0002:return (road.points[i+1]-road.points[i]).normalized()
 return Vector2.ZERO
func raw_path() -> PackedVector2Array:
 if anchors.is_empty():return PackedVector2Array()
 var first:=anchors[0];var last:=snap(view.pointer)
 if kind=="curve" and anchors.size()<2:return PackedVector2Array([first,AngleSnap.constrain_point(first,last,view.city.roads)])
 if kind=="straight" or (kind=="free" and start_tangent==Vector2.ZERO):return AngleSnap.apply(PackedVector2Array([first,last]),view.city.roads)
 var control: Vector2=anchors[1] if kind=="curve" else first+start_tangent*first.distance_to(last)/2
 if kind=="free":
  var assisted:=AngleSnap.axis(last-first,AngleSnap.connection(first,view.city.roads))
  if assisted!=Vector2.ZERO and absf(assisted.dot(start_tangent))<.5:control=first+assisted*first.distance_to(last)/2
 var steps:=clampi(ceili((first.distance_to(control)+control.distance_to(last))*2),8,128)
 var points:=PackedVector2Array()
 for i in range(steps+1):
  var t:=float(i)/steps;var u:=1-t
  points.append(first*u*u+control*2*u*t+last*t*t)
 return AngleSnap.apply(view.city.RoadJunctions.snap_path(points,view.city.roads),view.city.roads)
func resolved_path() -> Dictionary:
 var points:=raw_path()
 # A control handle is not a road contact. Its guide still uses eight-metre steps.
 if kind=="curve" and anchors.size()<2:return LengthUnits.fit(points,[])
 return LengthUnits.fit(points,view.city.roads)
func path() -> PackedVector2Array:return resolved_path().points
func joins_routable(network,points: PackedVector2Array) -> bool:
 # Surface the existing traffic graph's no-U-turn rule, rather than showing a
 # green road whose snapped endpoint cannot enter any new outgoing lane.
 var new_id: int=view.city.roads.size()
 for point in [points[0],points[-1]]:
  var existing:=false;var connected:=false
  for outgoing: Dictionary in network.lanes:
   if outgoing.road!=new_id or outgoing.start.distance_to(point*4)>.001:continue
   for incoming: Dictionary in network.lanes:
    if incoming.road<0 or incoming.road>=new_id or incoming.end_node!=outgoing.start_node:continue
    existing=true
    for next_id: int in incoming.next:
     if next_id==outgoing.id or network.lanes[next_id].get("to",-1)==outgoing.id:connected=true
  if existing and not connected:return false
 return true
func preview() -> Dictionary:
 var resolved:=resolved_path()
 var points: PackedVector2Array=resolved.points
 var complete: bool=kind!="curve" or anchors.size()>=2
 var result: Dictionary=view.city.add_road(points,"local",false,view.road_lanes,false,complete)
 result.points=points
 if not resolved.ok:result.ok=false;result.reason=resolved.reason
 if result.ok:
  var candidate:={"points":points,"kind":"local","lanes":view.road_lanes,"width":view.city.config.road_width*view.road_lanes/2.0}
  var network=Network.new()
  if not network.build(view.city.roads+[candidate]):result.ok=false;result.reason=network.errors[0] if not network.errors.is_empty() else "도로 경로를 확인해 주세요"
  elif not joins_routable(network,points):result.ok=false;result.reason="급격한 되돌림 도로는 주행할 수 없습니다"
 return result
func click(point: Vector2):
 view.pointer=point
 if anchors.is_empty():
  anchors.append(snap(point));start_tangent=tangent_at(anchors[0]);view.queue_redraw();return
 if kind=="curve" and anchors.size()==1:
  var guide:=resolved_path()
  if guide.ok:anchors.append(guide.points[-1])
  view.queue_redraw();return
 last_result=preview()
 if not last_result.ok:view.queue_redraw();return
 var points: PackedVector2Array=last_result.points
 last_result=view.city.add_road(points,"local",true,view.road_lanes,false,true)
 if last_result.ok:
  view.stop_traffic();cancel()
  if kind=="straight":anchors.append(points[-1]);start_tangent=tangent_at(points[-1])
  view.refresh()
func handle_input(event: InputEvent) -> bool:
 if view.mode!="road" or kind=="legacy":return false
 if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:cancel();return true
 if event is InputEventMouseMotion:
  if view.panning:return false
  view.pointer=view.world(event.position);view.queue_redraw();return true
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_RIGHT:
   if event.pressed:cancel()
   return true
  if event.button_index==MOUSE_BUTTON_LEFT:
   if event.pressed:click(view.world(event.position))
   return true
 return false
func draw_preview():
 if view.mode!="road" or kind=="legacy" or anchors.is_empty() or view.get_viewport().gui_get_hovered_control()!=null:return
 var result:=preview()
 if result.points.size()<2:return
 view.draw_ribbon(result.points,view.road_lanes,Color(.3,.9,.5,.55) if result.ok else Color(.95,.3,.25,.55))
