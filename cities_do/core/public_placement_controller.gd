extends Node2D
## Existing C cards and world only: no controls, labels or panels are created here.
var view
var asset_id:=""
var turns:=0
var last_result: Dictionary={}
var assets: Dictionary={}
func begin(id: String) -> bool:
 if not view.city.public_facilities.entries.has(id):return false
 view.cancel_zoning_drag();view.drawing=false;view.stroke.clear()
 if view.power_overlay!=null:view.power_overlay.drawing=false;view.power_overlay.stroke.clear()
 if view.water_overlay!=null:view.water_overlay.drawing=false;view.water_overlay.stroke.clear()
 asset_id=id;turns=0;view.mode="public_placement"
 var drawer=view.get("drawer")
 if drawer!=null:drawer.hide()
 queue_redraw();view.queue_redraw()
 return true
func cancel():
 asset_id=""
 if view.mode=="public_placement":view.mode="select"
 queue_redraw()
func preview() -> Dictionary:
 return view.city.public_facilities.preview(asset_id,view.pointer,turns,true) if not asset_id.is_empty() else {"ok":false}
func ghost_color() -> Color:
 return Color(.25,1,.45,.55) if preview().ok else Color(1,.2,.15,.55)
func _process(_delta: float):
 if view.mode!="public_placement":
  if not asset_id.is_empty():asset_id="";queue_redraw()
  return
 queue_redraw()
func _unhandled_input(event):
 if view.mode!="public_placement" or asset_id.is_empty():return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_R:turns=posmod(turns+1,4);queue_redraw();get_viewport().set_input_as_handled()
  elif event.keycode==KEY_ESCAPE:cancel();get_viewport().set_input_as_handled()
 elif event is InputEventMouseMotion:
  view.pointer=view.world(event.position);queue_redraw()
 elif event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_RIGHT:cancel();get_viewport().set_input_as_handled()
  elif event.button_index==MOUSE_BUTTON_LEFT:
   view.pointer=view.world(event.position)
   last_result=view.city.public_facilities.place(asset_id,view.pointer,turns,true)
   if not last_result.ok:print("PUBLIC_PLACEMENT_REJECT "+JSON.stringify({"asset":asset_id,"code":last_result.code,"reason":last_result.get("reason","")}))
   view.refresh();queue_redraw();get_viewport().set_input_as_handled()
func asset(id: String) -> Dictionary:
 if assets.has(id):return assets[id]
 var entry: Dictionary=(view.city.public_facilities.subway_platform if id=="subway-platform-silhouette-01" else view.city.public_facilities.entries[id]).duplicate(true)
 if id=="subway-platform-silhouette-01":entry.render_height_offset_m=12.7
 entry.footprint=[maxi(int(entry.width),int(entry.depth)),maxi(int(entry.width),int(entry.depth))]
 if not entry.has("height_m"):
  var model=load(entry.model).instantiate();var bounds:=AABB();var first:=true
  for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
   var transform_value: Transform3D=mesh.transform
   var parent=mesh.get_parent()
   while parent is Node3D:transform_value=parent.transform*transform_value;parent=parent.get_parent()
   var box: AABB=transform_value*mesh.get_aabb();bounds=box if first else bounds.merge(box);first=false
  entry.height_m=bounds.size.y
  model.free()
 assets[id]=entry
 return entry
func visual(record: Dictionary,part:String="") -> Dictionary:
 var entry:=asset(record.public_asset_id)
 var rendered: Dictionary=view.building_views.view(entry,record.front_direction,part)
 if rendered.is_empty():return {}
 var factor: float=view.tile.x/4*sqrt(2.0)*view.map_zoom/rendered.ppm
 var origin:Vector2=record.position
 if entry.get("origin","")=="centre of road-contact edge, ground z=0":origin+=Vector2(record.front_direction)*float(entry.depth)/2
 var ground:Vector2=view.screen(origin)
 if record.has("render_depth_m"):ground=view.origin+view.transit_view.project_point(origin,float(record.render_depth_m))*view.map_zoom
 return {"texture":rendered.texture,"image":rendered.image,"rect":Rect2(ground-rendered.anchor*factor,Vector2(rendered.image.get_size())*factor)}
func target(position: Vector2) -> Dictionary:
 var ordered: Array=view.building_draw_order().filter(func(record):return record.has("public_asset_id"))
 ordered.reverse()
 for record: Dictionary in ordered:
  var rendered:=visual(record)
  if not rendered.is_empty() and rendered.rect.has_point(position):
   var pixel: Vector2i=Vector2i((position-rendered.rect.position)/rendered.rect.size*Vector2(rendered.image.get_size()))
   if rendered.image.get_pixelv(pixel).a>.1:return record
  if Geometry2D.is_point_in_polygon(view.world(position),record.polygon):return record
 return {}
func _draw():
 if view==null or asset_id.is_empty() or view.mode!="public_placement" or get_viewport().gui_get_hovered_control()!=null:return
 var result:=preview()
 if not result.has("record"):return
 var tint:=ghost_color();var rendered:=visual(result.record)
 if not rendered.is_empty():draw_texture_rect(rendered.texture,rendered.rect,false,tint)
 var outline:=PackedVector2Array()
 for p in result.record.polygon:outline.append(view.screen(p))
 draw_colored_polygon(outline,Color(tint.r,tint.g,tint.b,.2))
 outline.append(outline[0]);draw_polyline(outline,Color(tint.r,tint.g,tint.b,.9),2,true)
