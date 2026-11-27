extends RefCounted
## Approved click modes; original main.gd drag path remains opt-in as hidden "legacy".
const Network=preload("res://core/traffic_network.gd")
const AngleSnap=preload("res://core/road_angle_snap.gd")
const LengthUnits=preload("res://core/road_length_units.gd")
const Grid=preload("res://core/road_grid_snap.gd")
const Construction=preload("res://core/road_construction.gd")
const Height=preload("res://core/road_height.gd")
const Geometry=preload("res://core/road_geometry.gd")
var grid_frame: Dictionary={}
var travel_dir:=0
var center_tool:=false
var target_height_m:=0.0
var start_height_m:=0.0
var pending:Dictionary={}
var warning_panel:PanelContainer
func clear_warning():
 pending.clear()
 if is_instance_valid(warning_panel):warning_panel.hide();warning_panel.queue_free()
 warning_panel=null
 if view.world_renderer!=null:
  for sprite in view.world_renderer.buildings.values():sprite.modulate=Color.WHITE
func confirm_pending():
 if pending.is_empty():return
 var approved:Dictionary=pending.duplicate(true)
 if approved.city_id!=view.city.get_instance_id():cancel();return
 var plan:=_submit_path(approved,false)
 if not plan.ok or plan.get("demolish_ids",[])!=approved.demolish_ids:cancel();return
 clear_warning()
 commit_path(approved,true)
func set_height(value:float):
 if center_tool:
  if value not in [0.0,10.0]:return
  target_height_m=value
 else:target_height_m=0.0 if travel_dir!=0 else roundf(value/5)*5
 if target_height_m<0:target_height_m=minf(target_height_m,Height.SHALLOWEST_ROAD_TUNNEL_M)
 _preview_signature=null
 var controls=view.find_child("RoadHeightControls",true,false)
 if controls!=null:controls.synchronize()
 sync_underground_view()
 view.queue_redraw()
## A target below ground shows the underground view (covered roads, metro).
func sync_underground_view():
 var transit=view.get("transit_view")
 if transit==null or view.get("mode")!="road":return
 var below:=target_height_m< -Height.EPS
 if transit.underground!=below:transit.underground=below;transit.sync_visibility()
var owner_reference: WeakRef
var view:
 get:return owner_reference.get_ref()
var kind:="straight"
var anchors: Array[Vector2]=[]
var start_tangent:=Vector2.ZERO
var last_result: Dictionary={}
var cursor_armed:=false
var measurement_boxes: Array[Dictionary]=[]
var preview_computations:=0
var _preview_signature=null
var _preview_cache:Dictionary={}
var _legacy_signature=null
var _legacy_valid:=false
func _init(owner):owner_reference=weakref(owner)
func cancel():
 clear_warning()
 grid_frame.clear()
 cursor_armed=false
 anchors.clear();start_tangent=Vector2.ZERO
 view.drawing=false;view.stroke.clear();view.queue_redraw()
func set_kind(value: String):
 if value not in ["straight","curve","free","legacy"]:return
 if value=="legacy" and (travel_dir!=0 or center_tool):return
 if value!=kind:cancel()
 kind=value;view.mode="road"
 arm_cursor()
 if view.has_method("update_road_modes"):view.update_road_modes()
 view.queue_redraw()
func grid_on() -> bool:return view.road_grid_enabled and kind!="legacy"
func layer_roads_at(point:Vector2,height:float) -> Array:
 return view.city.roads.filter(func(road):return absf(Height.height_at(road,point)-height)<Height.EPS)
func layer_roads() -> Array:return layer_roads_at(view.pointer,target_height_m)
func layer_city(point:Vector2,height:float) -> Dictionary:
 var selected:Array=layer_roads_at(point,height);var lattices:Array=[]
 if view.city.zoning_lattices.size()==view.city.roads.size():
  for road:Dictionary in selected:lattices.append(view.city.zoning_lattices[view.city.roads.find(road)])
 return {"roads":selected,"zoning_lattices":lattices,"width":view.city.width,"height":view.city.height}
func grid_reference(point: Vector2) -> Dictionary:return grid_frame if not grid_frame.is_empty() else Grid.frame_near(layer_city(point,target_height_m),point)
func width() -> float:return view.city.RoadProfile.width_for("local",view.road_lanes,view.city.config.road_width,travel_dir)
func selected_profile() -> Dictionary:
 var result:={"kind":"local","lanes":view.road_lanes,"width":width()}
 if travel_dir!=0:result.travel_dir=travel_dir
 else:result.major_side=view.road_major_side
 return result
func snap(point: Vector2) -> Vector2:
 return Grid.start(layer_city(point,target_height_m),point,width(),grid_reference(point)) if grid_on() else view.city.RoadJunctions.snap_point(point,layer_roads_at(point,target_height_m))
func arm_cursor():cursor_armed=true;view.queue_redraw()
func cursor_preview() -> Dictionary:
 if not cursor_armed or view.mode!="road" or kind=="legacy" or not anchors.is_empty() or not view.pointer.is_finite():return {}
 var center:=snap(view.pointer)
 var width:=width()
 var valid: bool=center.x>=0 and center.y>=0 and center.x<=view.city.width and center.y<=view.city.height
 var probe:={"points":PackedVector2Array([center,center]),"width":width}
 var occupied: Array=[]
 for b in view.city.buildings:occupied.append(view.city.footprint(b))
 for b in view.city.public_facilities.lots:occupied.append(b.polygon)
 for b in view.city.power.plants+view.city.water.facilities:occupied.append(view.city.power_plant_footprint(b))
 for shape in occupied:
  if view.city._polygon_road_distance(shape,probe)<-.0005:valid=false;break
 return {"center":center,"radius":width/2,"ok":valid,"snapped":not AngleSnap.connection(center,layer_roads()).is_empty()}
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
 var result: Vector2=view.city.RoadJunctions.snap_point(point,layer_roads())
 # The one-cell snap radius must not collapse an intentional four-metre extension.
 return point if result.distance_to(first)<LengthUnits.EPS and point.distance_to(first)>=LengthUnits.CONNECT/2 else result
func tangent_at(point: Vector2,height:float=NAN) -> Vector2:
 var roads: Array=layer_roads_at(point,target_height_m if is_nan(height) else height);roads.reverse()
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
 var mixed_height:=absf(start_height_m-target_height_m)>Height.EPS
 if grid_on():
  if kind=="curve" and anchors.size()<2:last=view.pointer
  else:
   var assisted:=AngleSnap.apply(PackedVector2Array([first,last]),layer_roads(),true) if kind=="straight" or (kind=="free" and start_tangent==Vector2.ZERO) else PackedVector2Array([first,last])
   var ends:=Grid.ends(layer_city(last,target_height_m),first if mixed_height else assisted[0],assisted[-1],width(),grid_reference(first),mixed_height)
   first=ends[0];last=ends[-1]
 if kind=="curve" and anchors.size()<2:return PackedVector2Array([first,AngleSnap.constrain_point(first,last,layer_roads())])
 if kind=="straight" or (kind=="free" and start_tangent==Vector2.ZERO):
  var ends:=PackedVector2Array([first,last])
  if grid_on() or (mixed_height and not AngleSnap.connection(last,layer_roads()).is_empty()):return ends
  ends=AngleSnap.apply(ends,layer_roads(),true)
  if mixed_height:ends[0]=first
  return ends
 var control: Vector2=anchors[1] if kind=="curve" else first+start_tangent*first.distance_to(last)/2
 if kind=="free":
  var assisted:=AngleSnap.axis(last-first,AngleSnap.connection(first,layer_roads()))
  if assisted!=Vector2.ZERO and absf(assisted.dot(start_tangent))<.5:control=first+assisted*first.distance_to(last)/2
 var steps:=clampi(ceili((first.distance_to(control)+control.distance_to(last))*2),8,128)
 var points:=PackedVector2Array()
 for i in range(steps+1):
  var t:=float(i)/steps;var u:=1-t
  points.append(first*u*u+control*2*u*t+last*t*t)
 if not grid_on() and not mixed_height:points=view.city.RoadJunctions.snap_path(points,layer_roads())
 points[-1]=last
 points=AngleSnap.apply(points,layer_roads())
 if grid_on():
  points[0]=first;points[-1]=last
  points[1]=AngleSnap.constrain_point(first,points[1],layer_roads())
  points[-2]=AngleSnap.constrain_point(last,points[-2],layer_roads())
 return points
func resolved_path() -> Dictionary:
 var points:=raw_path()
 if grid_on():
  if kind=="curve" and anchors.size()<2:return {"ok":points.size()>=2,"points":points,"reason":""}
  return Grid.fit(points,layer_roads())
 # Control handles are not destination contacts; follow the start road's build step.
 if kind=="curve" and anchors.size()<2:return LengthUnits.fit(points,[],LengthUnits.build_step(PackedVector2Array([anchors[0],anchors[0]]),layer_roads()) if not anchors.is_empty() else LengthUnits.BUILD)
 var roads:=layer_roads()
 # Destination-layer snap cannot see the already accepted start on its own layer.
 # Use the existing fixed-contact fit policy, not the free-start reversal or flat overlay fit.
 if points.size()>=2 and absf(start_height_m-target_height_m)>Height.EPS and not AngleSnap.connection(points[-1],roads).is_empty():
  return LengthUnits.fit(points,roads,LengthUnits.CONNECT,true)
 if center_tool and (start_height_m!=0 or target_height_m!=0):return LengthUnits.fit(points,roads)
 var overdraw:=Construction.fit_overlay(points,roads,selected_profile())
 if not overdraw.is_empty():return overdraw
 return LengthUnits.fit(points,roads)
func path() -> PackedVector2Array:return resolved_path().points
func joins_routable(network,points: PackedVector2Array,road_id: int=-1) -> bool:
 # Surface the existing traffic graph's no-U-turn rule, rather than showing a
 # green road whose snapped endpoint cannot enter any new outgoing lane.
 var new_id: int=view.city.roads.size() if road_id<0 else road_id
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
 return _preview_plan().duplicate(true)
func _preview_plan() -> Dictionary:
 if not pending.is_empty():return pending
 # Cache world-space admission, never camera-space drawing. Geometry changes also invalidate.
 var obstacles:Array=[]
 for building in view.city.buildings:obstacles.append(view.city.footprint(building))
 for lot in view.city.public_facilities.lots:obstacles.append(lot.polygon)
 var transit_generation:int=view.transit_view.generation if view.transit_view!=null else 0
 var signature:=hash([target_height_m,start_height_m,kind,anchors,start_tangent,view.pointer,view.road_lanes,view.road_major_side,travel_dir,center_tool,grid_on(),grid_frame,view.city.get_instance_id(),view.city.width,view.city.height,view.city.roads,transit_generation,view.city.config.road_width,obstacles,view.city.power.plants,view.city.water.facilities])
 if signature!=_preview_signature:
  _preview_signature=signature;preview_computations+=1;_preview_cache=_compute_preview()
 return _preview_cache
func legacy_preview(points:PackedVector2Array)->bool:
 var obstacles:Array=[]
 for building in view.city.buildings:obstacles.append(view.city.footprint(building))
 for lot in view.city.public_facilities.lots:obstacles.append(lot.polygon)
 var transit_generation:int=view.transit_view.generation if view.transit_view!=null else 0
 var signature:=hash([points,view.road_lanes,view.city.get_instance_id(),view.city.roads,transit_generation,view.city.config.road_width,obstacles,view.city.power.plants,view.city.water.facilities])
 if signature!=_legacy_signature:
  _legacy_signature=signature;preview_computations+=1
  _legacy_valid=view.city.add_road(points,"local",false,view.road_lanes).ok
 return _legacy_valid
func _compute_preview() -> Dictionary:
 var resolved:=resolved_path()
 var profile:=height_profile(resolved.points)
 var points: PackedVector2Array=profile.points
 var frame:=grid_reference(points[0]).duplicate(true) if grid_on() and points.size()>0 else {}
 var candidate:=selected_profile()
 candidate.points=points
 var intent:={"points":points,"heights_m":profile.heights_m,"grid_frame":frame,"lanes":view.road_lanes,"major_side":view.road_major_side,"travel_dir":travel_dir,"center_tool":center_tool}
 var result:=_submit_path(intent,false)
 result.merge(intent,true)
 result.width=candidate.width
 if not resolved.ok:result.ok=false;result.reason=resolved.reason
 if result.ok and (not center_tool or (start_height_m==0 and target_height_m==0)):
  var network=Network.new()
  var additions: Array=result.get("new_roads",[candidate])
  if not network.build(view.city.roads+additions):result.ok=false;result.reason=network.errors[0] if not network.errors.is_empty() else "도로 경로를 확인해 주세요"
  else:
   for i in range(additions.size()):
    if not joins_routable(network,additions[i].points,view.city.roads.size()+i):result.ok=false;result.reason="급격한 되돌림 도로는 주행할 수 없습니다";break
 if points.size()>=2:
  if center_tool and (start_height_m!=0 or target_height_m!=0):
   result.center_preview=_center_preview(result.get("new_roads",result.get("preview_roads",[])))
  if result.get("center_preview",[]).is_empty():
   result.ribbon_polygons=preview_polygons(points,result.width)
   result.arrow_polygons=preview_arrow_polygons(result)
 return result
func height_profile(points:PackedVector2Array)->Dictionary:
 var result:=points.duplicate();var heights:=PackedFloat64Array()
 if points.size()<2:return {"points":result,"heights_m":heights}
 if center_tool:
  # This API receives level intent, not the legacy road's baked ramp samples.
  # The model inserts the split, the ramp, and then the deck on this resolved spine.
  heights.resize(points.size());heights.fill(start_height_m);heights[-1]=target_height_m
  return {"points":result,"heights_m":heights}
 var length:=Height.length_cells(points)
 var ramp:=Height.minimum_ramp_m(target_height_m-start_height_m,"local")/4
 if ramp>0 and ramp<length:
  result=LengthUnits.Paths.slice(points,0,ramp)
  var rest:=LengthUnits.Paths.slice(points,ramp,length)
  result.append_array(rest.slice(1))
 var distance:=0.0
 for i in range(result.size()):
  if i>0:distance+=result[i-1].distance_to(result[i])
  heights.append(target_height_m if ramp==0 else lerpf(start_height_m,target_height_m,clampf(distance/maxf(Height.EPS,minf(ramp,length)),0,1)))
 return {"points":result,"heights_m":heights}
func pointer_world(screen_position:Vector2)->Vector2:
 return view.world(screen_position+Vector2(0,target_height_m*view.tile.x/4*sqrt(1.5)*view.map_zoom))
func click(point: Vector2):
 view.pointer=point
 sync_underground_view()
 if anchors.is_empty():
  start_height_m=target_height_m
  if grid_on():grid_frame=Grid.frame_near(layer_city(point,target_height_m),point).duplicate(true)
  anchors.append(snap(point));start_tangent=tangent_at(anchors[0]);view.queue_redraw();return
 if kind=="curve" and anchors.size()==1:
  var guide:=resolved_path()
  if guide.ok:anchors.append(guide.points[-1])
  view.queue_redraw();return
 last_result=preview()
 if not last_result.ok:view.queue_redraw();return
 last_result.city_id=view.city.get_instance_id()
 if last_result.get("warning",false):
  pending=last_result.duplicate(true)
  warning_panel=preload("res://core/road_demolition_warning.gd").new()
  view.drawer.get_parent().add_child(warning_panel)
  var endpoint:Vector2=view.screen(last_result.points[-1])-Vector2(0,target_height_m*view.tile.x/4*sqrt(1.5)*view.map_zoom)
  warning_panel.setup(self,endpoint,pending.demolish_ids.size())
  for id in pending.demolish_ids:
   var sprite=view.world_renderer.buildings.get(id)
   if sprite!=null:sprite.modulate=Color(1.25,1.12,.35)
  view.queue_redraw();return
 commit_path(last_result,false)
func commit_path(plan:Dictionary,confirmed:bool):
 last_result=plan
 var points: PackedVector2Array=last_result.points
 var heights:PackedFloat64Array=plan.heights_m
 var committed_grid: Dictionary=plan.grid_frame
 last_result=_submit_path(plan,true,confirmed)
 if last_result.ok or last_result.get("queued",false):
  view.message=""
  cancel()
  arm_cursor()
  start_height_m=heights[-1]
  if kind=="straight":anchors.append(points[-1]);start_tangent=tangent_at(points[-1],start_height_m)
  if kind=="straight" and grid_on():
   var endpoint_layer:=layer_city(points[-1],start_height_m)
   grid_frame=committed_grid.duplicate(true) if endpoint_layer.roads.is_empty() else Grid.frame_near(endpoint_layer,points[-1]).duplicate(true)
  view.refresh()
func _submit_path(plan:Dictionary,commit:bool,confirmed:bool=false)->Dictionary:
 var approved:Variant=plan.demolish_ids if confirmed else null
 if plan.get("center_tool",false):
  if not view.city.has_method("add_center_flyover"):return {"ok":false,"reason":"중앙 도로를 놓을 수 없습니다"}
  return view.city.add_center_flyover(plan.points,plan.heights_m,commit,plan.lanes,confirmed,plan.major_side,plan.grid_frame,approved)
 return view.city.add_elevated_road(plan.points,plan.heights_m,"local",commit,plan.lanes,confirmed,plan.major_side,plan.grid_frame,approved,plan.travel_dir)
func handle_input(event: InputEvent) -> bool:
 if view.mode!="road" or kind=="legacy":return false
 if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_PAGEUP,KEY_PAGEDOWN]:
  if travel_dir!=0:return true
  if center_tool:
   set_height(10.0 if event.keycode==KEY_PAGEUP else 0.0);return true
  var step:=5 if event.keycode==KEY_PAGEUP else -5
  var height:=target_height_m+step
  if height<0 and height>Height.SHALLOWEST_ROAD_TUNNEL_M:height+=step
  set_height(height);return true
 if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:cancel();return true
 if not pending.is_empty():
  if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:cancel()
  return true
 if event is InputEventMouseMotion:
  if view.panning:return false
  view.pointer=pointer_world(event.position);view.queue_redraw();return true
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_RIGHT:
   if event.pressed:cancel()
   return true
  if event.button_index==MOUSE_BUTTON_LEFT:
   if event.pressed:click(pointer_world(event.position))
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
  var radius:=maxf(.6,float(result.width)*.8)
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
func preview_colors(valid: bool,warning:bool=false) -> Dictionary:
 if valid and warning:return {"fill":Color(1,.82,.15,.55),"outline":Color("e6c442")}
 return {"fill":Color(.3,.9,.5,.55) if valid else Color(.95,.3,.25,.55),"outline":Color("3ddc84") if valid else Color("ef5350")}
func preview_polygons(points: PackedVector2Array,width: float) -> Array[PackedVector2Array]:
 var result: Array[PackedVector2Array]=[]
 if points.is_empty() or width<=0:return result
 var shapes: Array[PackedVector2Array]=[]
 if LengthUnits.Paths.length_of(points)<.00001:
  var disc:=PackedVector2Array()
  for i in range(64):disc.append(points[0]+Vector2.from_angle(TAU*i/64.0)*width/2)
  shapes.append(disc)
 else:
  # Clipper's absolute arc tolerance is too coarse in 4m world cells: scale only the presentation mesh.
  const DETAIL_SCALE:=64.0
  var detailed:=PackedVector2Array()
  for p in points:detailed.append(p*DETAIL_SCALE)
  for shape in Geometry2D.offset_polyline(detailed,width*DETAIL_SCALE/2,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND):
   for i in range(shape.size()):shape[i]/=DETAIL_SCALE
   shapes.append(shape)
 var bounds:=Vector2(view.city.width,view.city.height)
 var border:=PackedVector2Array([Vector2.ZERO,Vector2(bounds.x,0),bounds,Vector2(0,bounds.y)])
 for shape in shapes:
  for clipped in Geometry2D.intersect_polygons(shape,border):
   for i in range(clipped.size()):clipped[i]=clipped[i].clamp(Vector2.ZERO,bounds)
   result.append(clipped)
 return result
func preview_arrow_polygons(result: Dictionary) -> Array[PackedVector2Array]:
 if result.has("arrow_polygons"):return result.arrow_polygons
 if not result.get("ok",false) or result.get("travel_dir",0)==0:return []
 return Geometry.direction_arrows({"kind":"local","points":result.points,"width":result.width,"lanes":result.lanes,"travel_dir":result.travel_dir})

func _center_preview(roads:Array)->Array[Dictionary]:
 var result:Array[Dictionary]=[]
 var bounds:=Vector2(view.city.width,view.city.height)
 for road:Dictionary in roads:
  # Use the model's proposed records, not independent offset/snap plans.
  var shapes:=Geometry.clip_to_map(Geometry.pavement_ribbons(road.merged({"flat_start":true,"flat_end":true})),bounds)
  result.append({"road":road,"ribbon_polygons":shapes,"arrow_polygons":Geometry.direction_arrows(road) if road.get("travel_dir",0)!=0 else []})
 result.sort_custom(func(a,b):return not Height.raised(a.road) and Height.raised(b.road))
 return result

func draw_preview():
 measurement_boxes.clear()
 if view.mode!="road" or kind=="legacy" or (view.get_viewport().gui_get_hovered_control()!=null and pending.is_empty()):return
 if anchors.is_empty():draw_cursor(cursor_preview());return
 var result:=_preview_plan()
 if result.points.size()<2:return
 var colors:=preview_colors(result.ok,result.get("warning",false))
 var members:Array=result.get("center_preview",[])
 var compound:=not members.is_empty()
 if not compound:members=[{"road":result,"ribbon_polygons":result.ribbon_polygons,"arrow_polygons":result.arrow_polygons}]
 for member:Dictionary in members:
  var road:Dictionary=member.road
  var shadow:=Height.off_ground(road) if compound else not is_zero_approx(target_height_m) or not is_zero_approx(start_height_m)
  for shape in member.ribbon_polygons:
   var projected:=PackedVector2Array()
   var ground:=PackedVector2Array()
   for point in shape:
    var p:Vector2=view.screen(point)
    ground.append(p)
    projected.append(p-Vector2(0,Height.height_at(road,point)*view.tile.x/4*sqrt(1.5)*view.map_zoom))
   if shadow:view.draw_colored_polygon(ground,Color(0,0,0,.18))
   view.draw_colored_polygon(projected,colors.fill)
   projected.append(projected[0]);view.draw_polyline(projected,colors.outline,2,true)
  for shape in member.arrow_polygons:
   var projected:=PackedVector2Array()
   for point in shape:projected.append(view.screen(point))
   view.draw_colored_polygon(projected,Color("e8e7dc"))
 for index in [0,result.points.size()-1]:
  var point:Vector2=result.points[index];var height:float=Height.height_at(result,point)
  if not is_finite(height) or absf(height)<=Height.EPS:continue
  var ground:Vector2=view.screen(point);var top:=ground-Vector2(0,height*view.tile.x/4*sqrt(1.5)*view.map_zoom)
  view.draw_dashed_line(ground,top,Color("edf4f5"),1,5);view.draw_arc(ground,5,0,TAU,24,Color("edf4f5"),1,true)
 for station:Dictionary in result.get("piers",[]):
  for point:Vector2 in station.positions:
   var ground:Vector2=view.screen(point)
   view.draw_line(ground,ground-Vector2(0,(float(station.height_m)-2)*view.tile.x/4*sqrt(1.5)*view.map_zoom),colors.outline,2,true)
 draw_measurements(result)
