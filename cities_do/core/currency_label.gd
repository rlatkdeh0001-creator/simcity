extends Label
## Native Label retains text/minimum size/accessibility; draw only the currency glyph blue.
const ICON_COLOR:=Color("36b7ff")
func _init():visible_characters=0;mouse_filter=Control.MOUSE_FILTER_IGNORE;add_theme_font_size_override("font_size",18);add_theme_color_override("font_color",Color("edf4f5"))
func _ready():
 if not glyph_supported():
  var fallback:=SystemFont.new();fallback.font_names=PackedStringArray(["Segoe UI","Arial","Noto Sans"])
  if fallback.has_char(0x20ab):add_theme_font_override("font",fallback)
func glyph_supported() -> bool:return get_theme_font("font").has_char(0x20ab)
func _draw():
 var font:=get_theme_font("font");var pixels:=get_theme_font_size("font_size")
 var lines:=text.split("\n");var advance:=font.get_height(pixels)+get_theme_constant("line_spacing")
 var total: float=advance*lines.size()-get_theme_constant("line_spacing")
 var y:=font.get_ascent(pixels)
 if vertical_alignment==VERTICAL_ALIGNMENT_CENTER:y+=(size.y-total)/2
 elif vertical_alignment==VERTICAL_ALIGNMENT_BOTTOM:y+=size.y-total
 for line in lines:
  var width:=font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x
  var x:=0.0
  if horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER:x=(size.x-width)/2
  elif horizontal_alignment==HORIZONTAL_ALIGNMENT_RIGHT:x=size.x-width
  var pieces:=line.split("₫")
  for i in range(pieces.size()):
   font.draw_string(get_canvas_item(),Vector2(x,y),pieces[i],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,get_theme_color("font_color"))
   x+=font.get_string_size(pieces[i],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x
   if i<pieces.size()-1:
    font.draw_string(get_canvas_item(),Vector2(x,y),"₫",HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,ICON_COLOR)
    x+=font.get_string_size("₫",HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x
  y+=advance
