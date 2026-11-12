extends RefCounted
## Approved click modes; original main.gd drag path remains opt-in as hidden "legacy".
const Network=preload("res://core/traffic_network.gd")
const AngleSnap=preload("res://core/road_angle_snap.gd")
const LengthUnits=preload("res://core/road_length_units.gd")
const Grid=preload("res://core/road_grid_snap.gd")
var grid_frame: Dictionary={}
var owner_reference: WeakRef
var view:
 get:return owner_reference.get_ref()
var kind:="straight"
var anchors: Array[Vector2]=[]
var start_tangent:=Vector2.ZERO
var last_result: Dictionary={}
var cursor_armed:=false
var measurement_boxes: Array[Dictionary]=[]
func _init(owner):owner_reference=weakref(owner)
func cancel():
 grid_frame.clear()
 cursor_armed=false
 anchors.clear();start_tangent=Vector2.ZERO
 view.drawing=false;view.stroke.clear();view.queue_redraw()
func set_kind(value: String):
 if value not in ["straight","curve","free","legacy"]:return
 if value!=kind:cancel()
 kind=value;view.mode="road"
 arm_cursor()
 if view.has_method("update_road_modes"):view.update_road_modes()
 view.queue_redraw()
func grid_on() -> bool:return view.road_grid_enabled and kind!="legacy"
func grid_reference(point: Vector2) -> Dictionary:return grid_frame if not grid_frame.is_empty() else Grid.frame_near(view.city,point)
func snap(point: Vector2) -> Vector2:
 return Grid.start(view.city,point,view.city.config.road_width*view.road_lanes/2.0,grid_reference(point)) if grid_on() else view.city.RoadJunctions.snap_point(point,view.city.roads)
func arm_cursor():cursor_armed=true;view.queue_redraw()
func cursor_preview() -> Dictionary:
 if not cursor_armed or view.mode!="road" or kind=="legacy" or not anchors.is_empty() or not view.pointer.is_finite():return {}
 var center:=snap(view.pointer)
 var width: float=view.city.config.road_width*view.road_lanes/2.0
 var valid: bool=center.x>=0 and center.y>=0 and center.x<=view.city.width and center.y<=view.city.height
 var probe:={"points":PackedVector2Array([center,center]),"width":width}
 var occupied: Array=[]
 for b in view.city.buildings:occupied.append(view.city.footprint(b))
 for b in view.city.public_facilities.lots:occupied.append(b.polygon)
 for b in view.city.power.plants+view.city.water.facilities:occupied.append(view.city.power_plant_footprint(b))
 for shape in occupied:
  if view.city._polygon_road_distance(shape,probe)<-.0005:valid=false;break
 return {"center":center,"radius":width/2,"ok":valid,"snapped":not AngleSnap.connection(center,view.city.roads).is_empty()}
func cursor_ring(center: Vector2,radius: float) -> PackedVector2Array:
 var points:=PackedVector2Array()
 for i in range(65):points.append(view.screen(center+Vector2.from_angle(TAU*i/64.0)*radius))
 return points
func draw_cursor(state: Dictionary):
 if state.is_empty():return
 var edge:=Color("3ddc84") if state.ok else Color("ef5350")
 var fill:=edge;fill.a=.35
 var disc:=cursor_ring(state.center,state.radius)
 view.draw_colored_polygon(disc,fill);view.draw_polyline(disc,edge,2,true)
 if state.snapped:
  var ring:=cursor_ring(state.center,state.radius*1.33)
  for i in range(0,64,4):view.draw_polyline(ring.slice(i,i+3),Color("36b7ff"),2,true)
func destination(point: Vector2,first: Vector2) -> Vector2:
 var result: Vector2=view.city.RoadJunctions.snap_point(point,view.city.roads)
 # The one-cell snap radius must not collapse an intentional four-metre extension.
 return point if result.distance_to(first)<LengthUnits.EPS and point.distance_to(first)>=LengthUnits.CONNECT/2 else result
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
 var first:=anchors[0];var last:=destination(view.pointer,first)
 if grid_on():
  if kind=="curve" and anchors.size()<2:last=view.pointer
  else:
   var assisted:=AngleSnap.apply(PackedVector2Array([first,last]),view.city.roads) if kind=="straight" or (kind=="free" and start_tangent==Vector2.ZERO) else PackedVector2Array([first,last])
   var ends:=Grid.ends(view.city,assisted[0],assisted[-1],view.city.config.road_width*view.road_lanes/2.0,grid_reference(first))
   first=ends[0];last=ends[-1]
 if kind=="curve" and anchors.size()<2:return PackedVector2Array([first,AngleSnap.constrain_point(first,last,view.city.roads)])
 if kind=="straight" or (kind=="free" and start_tangent==Vector2.ZERO):return PackedVector2Array([first,last]) if grid_on() else AngleSnap.apply(PackedVector2Array([first,last]),view.city.roads)
 var control: Vector2=anchors[1] if kind=="curve" else first+start_tangent*first.distance_to(last)/2
 if kind=="free":
  var assisted:=AngleSnap.axis(last-first,AngleSnap.connection(first,view.city.roads))
  if assisted!=Vector2.ZERO and absf(assisted.dot(start_tangent))<.5:control=first+assisted*first.distance_to(last)/2
 var steps:=clampi(ceili((first.distance_to(control)+control.distance_to(last))*2),8,128)
 var points:=PackedVector2Array()
 for i in range(steps+1):
  var t:=float(i)/steps;var u:=1-t
  points.append(first*u*u+control*2*u*t+last*t*t)
 if not grid_on():points=view.city.RoadJunctions.snap_path(points,view.city.roads)
 points[-1]=last
 points=AngleSnap.apply(points,view.city.roads)
 if grid_on():
  points[0]=first;points[-1]=last
  points[1]=AngleSnap.constrain_point(first,points[1],view.city.roads)
  points[-2]=AngleSnap.constrain_point(last,points[-2],view.city.roads)
 return points
func resolved_path() -> Dictionary:
 var points:=raw_path()
 if grid_on():
  if kind=="curve" and anchors.size()<2:return {"ok":points.size()>=2,"points":points,"reason":""}
  return Grid.fit(points,view.city.roads)
 # Control handles are not destination contacts; follow the start road's build step.
 if kind=="curve" and anchors.size()<2:return LengthUnits.fit(points,[],LengthUnits.build_step(PackedVector2Array([anchors[0],anchors[0]]),view.city.roads) if not anchors.is_empty() else LengthUnits.BUILD)
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
 var result: Dictionary=view.city.add_road(points,"local",false,view.road_lanes,false,complete,view.road_major_side,grid_reference(points[0]) if grid_on() and points.size()>0 else {})
 result.points=points
 if not resolved.ok:result.ok=false;result.reason=resolved.reason
 if result.ok:
  var candidate:={"points":points,"kind":"local","lanes":view.road_lanes,"width":view.city.config.road_width*view.road_lanes/2.0,"major_side":view.road_major_side}
  var network=Network.new()
  if not network.build(view.city.roads+[candidate]):result.ok=false;result.reason=network.errors[0] if not network.errors.is_empty() else "도로 경로를 확인해 주세요"
  elif not joins_routable(network,points):result.ok=false;result.reason="급격한 되돌림 도로는 주행할 수 없습니다"
 return result
func click(point: Vector2):
 view.pointer=point
 if anchors.is_empty():
  if grid_on():grid_frame=Grid.frame_near(view.city,point).duplicate(true)
  anchors.append(snap(point));start_tangent=tangent_at(anchors[0]);view.queue_redraw();return
 if kind=="curve" and anchors.size()==1:
  var guide:=resolved_path()
  if guide.ok:anchors.append(guide.points[-1])
  view.queue_redraw();return
 last_result=preview()
 if not last_result.ok:view.queue_redraw();return
 var points: PackedVector2Array=last_result.points
 var committed_grid: Dictionary=grid_reference(points[0]).duplicate(true) if grid_on() else {}
 last_result=view.city.add_road(points,"local",true,view.road_lanes,false,true,view.road_major_side,committed_grid)
 if last_result.ok:
  view.stop_traffic();cancel()
  arm_cursor()
  if kind=="straight":anchors.append(points[-1]);start_tangent=tangent_at(points[-1])
  if kind=="straight":grid_frame=Grid.frame_near(view.city,points[-1]).duplicate(true) if grid_on() else {}
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
func measurements(result: Dictionary={}) -> Dictionary:
 if view.mode!="road" or kind=="legacy" or anchors.is_empty():return {}
 if result.is_empty():result=preview()
 var points: PackedVector2Array=result.points
 if points.size()<2:return {}
 var length:=LengthUnits.Paths.length_of(points)
 if length<.0001:return {}
 var text: String="%d m"%roundi(length*4) if absf(length*4-roundf(length*4))<.01 else "%.1f m"%(length*4)
 var data:={"length_m":length*4,"length_text":text,"midpoint":LengthUnits.Paths.sample(points,length/2),"angles":[]}
 for pair in [[0,1],[points.size()-1,points.size()-2]]:
  var center: Vector2=points[pair[0]]
  var host:=AngleSnap.connection(center,view.city.roads)
  if host.is_empty():continue
  var ray: Vector2=(points[pair[1]]-center).normalized()
  if ray==Vector2.ZERO:continue
  var base: Vector2=-host.outward if host.endpoint else host.tangent
  if not host.endpoint and base.dot(ray)<0:base=-base
  var turn:=base.angle_to(ray)
  var degrees:=absf(rad_to_deg(turn))
  var radius: float=maxf(.6,view.city.config.road_width*view.road_lanes/2.0*.8)
  var arc:=PackedVector2Array()
  for i in range(25):arc.append(view.screen(center+Vector2.from_angle(base.angle()+turn*i/24.0)*radius))
  data.angles.append({"center":center,"degrees":degrees,"text":"%d°"%roundi(degrees),"arc":arc})
 return data
func draw_measure_badge(text: String,center: Vector2,color: Color):
 var font: Font=view.money.get_theme_font("font")
 var size:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,20)+Vector2(20,12)
 var screen_size: Vector2=view.get_viewport_rect().size
 var bottom: float=(view.drawer.global_position.y if view.drawer.visible else view.dock.global_position.y)-8
 var rect:=Rect2(center-size/2,size)
 rect.position.x=clampf(rect.position.x,8,maxf(8,screen_size.x-size.x-8))
 rect.position.y=clampf(rect.position.y,8,maxf(8,bottom-size.y))
 for prior in measurement_boxes:
  if rect.intersects(prior.rect):rect.position.y=maxf(8,prior.rect.position.y-size.y-6)
 var box:=StyleBoxFlat.new();box.bg_color=Color("142b37");box.set_corner_radius_all(6)
 box.draw(view.get_canvas_item(),rect)
 view.draw_string(font,rect.position+Vector2(10,6+font.get_ascent(20)),text,HORIZONTAL_ALIGNMENT_LEFT,-1,20,color)
 measurement_boxes.append({"text":text,"rect":rect,"font_size":20})
func draw_measurements(result: Dictionary):
 var data:=measurements(result)
 if data.is_empty():return
 draw_measure_badge(data.length_text,view.screen(data.midpoint)+Vector2(0,-32),Color("edf4f5"))
 for angle in data.angles:
  if angle.degrees>.001:view.draw_polyline(angle.arc,Color("36b7ff"),2,true)
  draw_measure_badge(angle.text,angle.arc[12]+Vector2(0,-28),Color("36b7ff"))
func draw_preview():
 measurement_boxes.clear()
 if view.mode!="road" or kind=="legacy" or view.get_viewport().gui_get_hovered_control()!=null:return
 if anchors.is_empty():draw_cursor(cursor_preview());return
 var result:=preview()
 if result.points.size()<2:return
 view.draw_ribbon(result.points,view.road_lanes,Color(.3,.9,.5,.55) if result.ok else Color(.95,.3,.25,.55))
 draw_measurements(result)
