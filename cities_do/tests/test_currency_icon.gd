extends SceneTree
var checks:=0
var failures:=0
func verify(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);await process_frame
 verify(not "₫" in game.money.text and not "doth" in game.money.text,"rejected currency glyph and internal unit are absent from HUD text")
 verify(game.money.get("currency_texture")!=null,"treasury uses an actual approved SVG image instead of a currency font glyph")
 game.set_monthly_balance(1200);await process_frame;await process_frame
 var drawn_width: float=game.money.line_width(game.money.text,game.money.get_theme_font("font"),game.money.get_theme_font_size("font_size"))
 verify(game.money.size.x+.01>=drawn_width and game.money.global_position.x+drawn_width<=game.balance_label.global_position.x,"native treasury image/text reserves enough layout width and never overlaps monthly balance")
 game.select_category("power")
 for frame in range(5):await process_frame
 var card=game.drawer_box.get_children().filter(func(n):return n is Button and n.get_meta("thumbnail_asset_id","")=="power-wind")[0]
 game.drawer_scroll.ensure_control_visible(card)
 for frame in range(5):await process_frame
 game.show_asset_info(card);await process_frame;await process_frame
 var numbers: Array=game.asset_info.find_children("InfoNumber_*","Label",true,false)
 var units: Array=game.asset_info.find_children("InfoUnit_*","Label",true,false)
 verify(numbers.size()==4 and units.size()==4,"approved wind hover is a genuine three-column table with separate number and unit controls")
 if numbers.size()==4:
  var right: float=numbers[0].get_global_rect().end.x
  verify(numbers.all(func(n):return n.horizontal_alignment==HORIZONTAL_ALIGNMENT_RIGHT and absf(n.get_global_rect().end.x-right)<1),"all numeric last digits share the same right-aligned column edge")
  var font: Font=numbers[0].get_theme_font("font");var pixels: int=numbers[0].get_theme_font_size("font_size")
  var widths: Array=[]
  for digit in "0123456789":widths.append(font.get_string_size(digit,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x)
  verify(numbers.all(func(n):return n.get_theme_font("font")==game.money.get_theme_font("font") and not n.has_theme_font_override("font")),"numeric cells inherit the same existing HUD font without a separate monospace override")
  print("HOVER_NUMERIC_FONT "+font.get_font_name()+" digit_advances="+str(widths))
  verify(numbers.map(func(n):return n.text)==["15,000","−200","1,000","2,000"],"only alignment and icon presentation change, not CSV values")
 if units.size()==4:verify(units.all(func(n):return n.horizontal_alignment==HORIZONTAL_ALIGNMENT_LEFT),"unit column is independently left aligned")
 for size_value in [Vector2i(1280,820),Vector2i(960,640)]:
  root.size=size_value;await process_frame;await process_frame;await process_frame
  var viewport_rect:=root.get_visible_rect()
  verify(viewport_rect.encloses(game.money.get_global_rect()) and viewport_rect.encloses(game.balance_label.get_global_rect()),"currency image HUD fits "+str(size_value))
  var width: float=game.money.line_width(game.money.text,game.money.get_theme_font("font"),game.money.get_theme_font_size("font_size"))
  verify(game.money.global_position.x+width<=game.balance_label.global_position.x and game.money.get_parent().get_global_rect().position.x>=game.status_left.get_global_rect().end.x,"positive monthly balance remains separated from cash and left instruments at "+str(size_value))
 game.queue_free();await process_frame
 print("RESULT %d/%d custom currency icon checks passed" % [checks-failures,checks]);quit(1 if failures else 0)
