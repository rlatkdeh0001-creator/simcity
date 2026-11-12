extends Label
## Object replacement token reserves an image slot; it is never drawn as a glyph.
const ICON_PATH:="res://assets/ui/currency-icon-A.svg"
const ICON_COLOR:=Color("36b7ff")
const TOKEN:="\uFFFC"
var currency_texture: Texture2D=preload("res://assets/ui/currency-icon-A.svg")
func _init():visible_characters=0;mouse_filter=Control.MOUSE_FILTER_IGNORE;add_theme_font_size_override("font_size",18);add_theme_color_override("font_color",Color("edf4f5"))
func icon_ready() -> bool:return currency_texture!=null and currency_texture.get_width()>0
func _ready():
 minimum_size_changed.connect(sync_minimum)
 sync_minimum()
func sync_minimum():
 var measured:=measured_minimum_size()
 if custom_minimum_size!=measured:custom_minimum_size=measured
func line_width(line: String,font: Font,pixels: int) -> float:
 var pieces:=line.split(TOKEN);var width:=float(maxi(0,pieces.size()-1)*pixels)
 for piece in pieces:width+=font.get_string_size(piece,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x
 return width
func measured_minimum_size() -> Vector2:
 var font:=get_theme_font("font");var pixels:=get_theme_font_size("font_size");var width:=0.0
 var lines:=text.split("\n")
 for line in lines:width=maxf(width,line_width(line,font,pixels))
 return Vector2(ceilf(width),ceilf((font.get_height(pixels)+get_theme_constant("line_spacing"))*lines.size()-get_theme_constant("line_spacing")))
func _draw():
 sync_minimum()
 var font:=get_theme_font("font");var pixels:=get_theme_font_size("font_size")
 var lines:=text.split("\n");var advance:=font.get_height(pixels)+get_theme_constant("line_spacing")
 var total: float=advance*lines.size()-get_theme_constant("line_spacing")
 var y:=font.get_ascent(pixels)
 if vertical_alignment==VERTICAL_ALIGNMENT_CENTER:y+=(size.y-total)/2
 elif vertical_alignment==VERTICAL_ALIGNMENT_BOTTOM:y+=size.y-total
 for line in lines:
  var width:=line_width(line,font,pixels);var x:=0.0
  if horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER:x=(size.x-width)/2
  elif horizontal_alignment==HORIZONTAL_ALIGNMENT_RIGHT:x=size.x-width
  var pieces:=line.split(TOKEN)
  for i in range(pieces.size()):
   font.draw_string(get_canvas_item(),Vector2(x,y),pieces[i],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,get_theme_color("font_color"))
   x+=font.get_string_size(pieces[i],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x
   if i<pieces.size()-1:
    draw_texture_rect(currency_texture,Rect2(Vector2(x,y-font.get_ascent(pixels)+(font.get_height(pixels)-pixels)/2),Vector2(pixels,pixels)),false)
    x+=pixels
  y+=advance
