extends RefCounted
## Ordered creation only. The overlay owns picks and existing-line edits.
var view
var stops:Array=[]
var kind:=""
func _init(owner_view):view=owner_view
func cancel():stops.clear();kind=""
func choose_stop(id:int):
 if id<0 or kind.is_empty():return
 if stops.size()>=2 and id==stops[0]:
  var result:Dictionary=view.city.create_transit_line(kind,stops)
  var accepted:bool=result.get("ok",false) or result.get("queued",false)
  view.message="" if accepted else result.reason
  if accepted:cancel()
  view.refresh()
 elif id not in stops:stops.append(id)
