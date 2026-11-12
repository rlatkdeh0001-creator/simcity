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
 verify(game.money.text=="50,000 \uFFFC","approved currency symbol replaces player-facing doth without changing funds")
 game.city.funds=1000;game.select_category("power")
 for frame in range(5):await process_frame
 var cards: Array=game.drawer_box.get_children().filter(func(b):return b is Button and b.get_meta("thumbnail_asset_id","")=="power-wind")
 verify(cards.size()==1,"existing wind C-card is present")
 if cards.size()==1:
  var card: Button=cards[0];game.drawer_scroll.ensure_control_visible(card)
  for frame in range(5):await process_frame
  verify(card.get_meta("unaffordable",false) and not card.disabled,"unaffordable card is dim but still receives rejection clicks")
  for down in [true,false]:
   var event:=InputEventMouseButton.new();event.position=card.get_global_rect().get_center();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await process_frame
  verify(game.mode!="public_placement" and game.public_controller.asset_id.is_empty() and game.city.funds==1000,"real poor-card click cannot open any placement ghost or debit funds")
  verify(game.get("money_toast")!=null,"approved card-anchored insufficient-funds bubble exists")
  if game.get("money_toast")!=null:
   verify(game.money_toast.visible and game.money_toast.get_meta("message","")=="잔고가 부족합니다.","exact approved bubble copy appears")
   verify(card.get_theme_stylebox("normal").border_color==Color("ff5a5a"),"rejected card has a red outline")
   verify(game.money_toast.get_global_rect().end.y<=card.get_global_rect().position.y,"bubble is directly above the actual scrolled card")
   await create_timer(2.2).timeout
   verify(not game.money_toast.visible and card.get_theme_stylebox("normal").border_color!=Color("ff5a5a"),"real-time two-second expiry removes bubble and red border")
  game.city.funds=15000
  verify(not card.get_meta("unaffordable",true),"funds-change event undims card exactly at approved CSV price")
  game.city.power.pending_doth=-.25;game.refresh_status()
  verify(card.get_meta("unaffordable",false) and not game.select_public_asset("power-wind"),"fractional pending utility charge uses same available balance as real construction")
  game.city.power.pending_doth=0;game.refresh_status()
  verify(game.select_public_asset("power-wind") and game.mode=="public_placement" and game.city.funds==15000,"affordable selection opens ghost without charging or changing price")
  game.public_controller.cancel()
  verify(game.city.Economy.format_fraction(-12345.125,6)=="−12,345.125000 \uFFFC","fractional utility money keeps decimal precision and thousand grouping")
  game.set_monthly_balance(1200);verify(game.balance_label.text=="+1,200 \uFFFC/월","monthly HUD keeps positive sign and official icon")
  game.set_monthly_balance(-200);verify(game.balance_label.text=="−200 \uFFFC/월","monthly HUD keeps negative sign and official icon")
 game.queue_free();await process_frame
 print("RESULT %d/%d money UI checks passed" % [checks-failures,checks]);quit(1 if failures else 0)
