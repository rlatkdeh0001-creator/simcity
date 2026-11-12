extends SceneTree
var checks:=0
var failures:=0
func verify(value: bool,label: String):
 checks+=1
 if value:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);await process_frame
 verify(game.has_method("asset_info_rows"),"asset hover exposes real CSV rows rather than hardcoded mockup values")
 if game.has_method("asset_info_rows"):
  var rows: Array=game.asset_info_rows("power-wind")
  verify(rows.any(func(r):return r.id=="construction" and r.text=="15,000 \uFFFC"),"wind construction row uses existing approved CSV value")
  verify(rows.any(func(r):return r.id=="upkeep" and r.text=="−200 \uFFFC/월"),"upkeep preserves minus and monthly unit")
  verify(rows.any(func(r):return r.id=="average_output_kw" and r.value==1000) and rows.any(func(r):return r.id=="rated_output_kw" and r.value==2000),"actual average and rated wind output are distinctly labeled, no fake generation")
  verify(game.asset_info_rows("unknown-asset").is_empty(),"missing data produces no invented price or capacity rows")
  game.select_category("power")
  for frame in range(5):await process_frame
  var card=game.drawer_box.get_children().filter(func(b):return b is Button and b.get_meta("thumbnail_asset_id","")=="power-wind")[0]
  game.drawer_scroll.ensure_control_visible(card)
  for frame in range(5):await process_frame
  var event:=InputEventMouseMotion.new();event.position=card.get_global_rect().get_center();root.push_input(event,true);await process_frame;await process_frame
  verify(game.get("asset_info")!=null and game.asset_info.visible,"actual mouse hover opens approved preview bubble")
  if game.get("asset_info")!=null:
   verify(game.asset_info.find_children("*","TextureRect",true,false).any(func(n):return n.texture!=null),"bubble uses actual registered asset preview image")
   verify(root.get_visible_rect().encloses(game.asset_info.get_global_rect()),"hover bubble is wholly inside viewport")
  verify(game.money.icon_ready(),"approved currency SVG texture is available independently of font glyphs")
  for size_value in [Vector2i(1280,820),Vector2i(960,640)]:
   root.size=size_value;await process_frame;await process_frame
   game.show_asset_info(card);await process_frame;await process_frame
   verify(root.get_visible_rect().encloses(game.asset_info.get_global_rect()),"approved hover bubble remains wholly inside "+str(size_value))
  for id in ["medical-hospital","elementary-school","prison-8x8","water-intake","water-sewage-treatment","water-water-tower","waste-recycling-center"]:
   var info: Array=game.asset_info_rows(id)
   verify(info.size()>=3 and info.all(func(r):return is_finite(r.value) and not "doth" in r.text),id+" exposes only existing finite CSV capacities and official money display")
  print("CURRENCY_IMAGE "+game.money.ICON_PATH+" ready="+str(game.money.icon_ready()))
  game.select_category("power");game.power_overlay.refresh()
  verify(game.city.Economy.CURRENCY_SYMBOL in game.power_overlay.summary.text and not "doth" in game.power_overlay.summary.text and not "₫" in game.power_overlay.summary.text,"existing electricity settings use image slots without changing metering")
  game.select_category("water");game.water_overlay.refresh()
  verify(game.city.Economy.CURRENCY_SYMBOL in game.water_overlay.summary.text and not "doth" in game.water_overlay.summary.text and not "₫" in game.water_overlay.summary.text,"existing water settings use image slots without changing tariffs")
 game.queue_free();await process_frame
 print("RESULT %d/%d asset money info checks passed" % [checks-failures,checks]);quit(1 if failures else 0)
