extends SceneTree
var checks:=0
var failed:=0
func _initialize():run.call_deferred()
func verify(value: bool,detail: String):
 checks+=1
 if value:print("PASS "+detail)
 else:failed+=1;push_error("FAIL "+detail)
func run():
 root.size=Vector2i(1280,820)
 root.gui_embed_subwindows=true
 var game=load("res://main.tscn").instantiate()
 root.add_child(game);current_scene=game
 await process_frame
 game.paused=true
 verify(game.chosen.is_empty() and game.categories.all(func(button):return button.get_theme_stylebox("normal").border_color!=game.BLUE),"startup has no blue selected category")
 game.select_category("police")
 var cards: Array=game.drawer_box.get_children().filter(func(n):return n is Button and n.has_meta("thumbnail_asset_id"))
 verify(cards.size()==4,"approved C cards exist for all four police assets")
 if cards.size()==4:await check_cards(game)
 await check_focus_and_pause(game)
 game.queue_free()
 await process_frame
 print("RESULT %d/%d thumbnail HUD checks passed" % [checks-failed,checks])
 quit(1 if failed else 0)
func check_cards(game):
 var expected: Dictionary={"fire":3,"police":4,"health":4,"education":4,"park":8}
 var total:=0
 var before: String=JSON.stringify(game.city.buildings)+str(game.city.funds)
 for key in expected:
  game.select_category(key)
  await process_frame
  var cards: Array=game.drawer_box.get_children().filter(func(n):return n is Button and n.has_meta("thumbnail_asset_id"))
  verify(cards.size()==expected[key],key+" has every PNG-backed building/park/parking card")
  for card in cards:
   total+=1
   var image=card.get_node_or_null("AssetThumbnail")
   var band=card.get_node_or_null("NameBand")
   var caption=card.get_node_or_null("NameBand/AssetName")
   verify(image is TextureRect and image.texture!=null and image.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_COVERED,str(card.name)+" real image covers the whole button without distortion")
   verify(card.size.x>=128 and card.size.y>=96,str(card.name)+" C card minimum size")
   verify(band is Panel and caption is Label and caption.text==card.get_meta("asset_name") and caption.get_theme_font_size("font_size")>=18,str(card.name)+" bottom name band and readable real name")
   if band is Panel:verify(band.get_theme_stylebox("panel").bg_color.a>.5 and band.get_theme_stylebox("panel").bg_color.a<1,str(card.name)+" dark translucent name band")
   card.pressed.emit()
   await process_frame
   var windows: Array=game.find_children("ServiceAssetPreview","Window",true,false)
   verify(windows.size()==1 and not windows[0].find_children("*","MeshInstance3D",true,false).is_empty(),str(card.name)+" opens only its real geometry inspector")
   for window in windows:window.close_requested.emit()
   await process_frame
 verify(total==23,"all 23 existing PNG-backed facilities use C cards")
 verify(before==JSON.stringify(game.city.buildings)+str(game.city.funds),"thumbnail inspection never builds or charges")

func check_focus_and_pause(game):
 game.categories[0].grab_focus()
 game.categories[-1].pressed.emit()
 await process_frame
 verify(root.gui_get_focus_owner()==game.categories[-1],"category activation moves keyboard focus to clicked category")
 verify(game.categories.filter(func(button):return button.get_theme_stylebox("normal").border_color==game.BLUE).size()==1,"exactly one blue selection outline")
 var focus=game.categories[0].get_theme_stylebox("focus")
 verify(focus is StyleBoxTexture and focus.resource_name=="KeyboardFocusDashed","keyboard focus has a distinct bright dashed shape, not the blue selected outline")
 if focus is StyleBoxTexture:
  var image: Image=focus.texture.get_image()
  var transitions:=0
  var previous:=false
  for x in range(8,120):
   var lit:=image.get_pixel(x,3).a>.2
   if lit!=previous:transitions+=1
   previous=lit
  verify(transitions>=8,"focus texture contains real dashed gaps")
 verify(game.pause_button.icon_alignment==HORIZONTAL_ALIGNMENT_CENTER and game.pause_button.text.is_empty(),"pause icon is centered like the speed caption")
 var target: Button=game.categories[7]
 var click:=InputEventMouseButton.new()
 click.position=target.get_global_rect().get_center()
 click.global_position=click.position
 click.button_index=MOUSE_BUTTON_LEFT
 click.pressed=true;root.push_input(click)
 click.pressed=false;root.push_input(click)
 await process_frame
 verify(game.chosen=="health" and root.gui_get_focus_owner()==target,"actual mouse press/release selects health and transfers keyboard focus")
 var card: Button=game.drawer_box.get_children().filter(func(n):return n is Button and n.has_meta("thumbnail_asset_id"))[0]
 card.disabled=true
 card.pressed.emit()
 await process_frame
 verify(game.find_children("ServiceAssetPreview","Window",true,false).is_empty(),"disabled thumbnail cannot be forced into activation")
 card.disabled=false
 for size_value in [Vector2i(1920,1080),Vector2i(1280,820),Vector2i(960,640)]:
  root.size=size_value
  await process_frame
  await process_frame
  game.select_category("police")
  await process_frame
  var view:=root.get_visible_rect()
  for button in game.drawer_box.get_children().filter(func(n):return n is Button and n.has_meta("thumbnail_asset_id")):
   verify(view.encloses(button.get_global_rect()),str(button.name)+" complete card fits "+str(size_value))
