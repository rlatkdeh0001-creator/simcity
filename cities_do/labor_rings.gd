extends Control
var work := {}
const LABELS := ["미취학","초등교육","고등교육","전문대학","대학"]
const COLORS := [Color("8bbaa0"),Color("5baac4"),Color("dfb65d"),Color("b78bd0"),Color("e28f77")]
func _init():custom_minimum_size=Vector2(460,100)
func _draw():
 for stage in range(5):
  var center := Vector2(46+stage*92,34)
  var capacity: int=work.get("slots",[0,0,0,0,0])[stage]
  var filled: int=work.get("filled",[0,0,0,0,0])[stage]
  draw_arc(center,23,0,TAU,48,Color("344c59"),6,true)
  if capacity>0 and filled>0:draw_arc(center,23,-PI/2,-PI/2+TAU*float(filled)/capacity,48,COLORS[stage],6,true)
  draw_string(ThemeDB.fallback_font,center+Vector2(-17,5),"%d/%d" % [filled,capacity],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
  draw_string(ThemeDB.fallback_font,Vector2(stage*92+10,82),LABELS[stage],HORIZONTAL_ALIGNMENT_LEFT,-1,14,COLORS[stage])
