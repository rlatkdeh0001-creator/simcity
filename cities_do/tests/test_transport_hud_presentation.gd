extends SceneTree

const BusFixture=preload("res://tests/test_scheduled_buses.gd")
const PAPER:=Color("142b37")
const INK:=Color("edf4f5")
const BUILDING_TEXT:="#901 · 4×4 · 레벨 3\n성장 수치 0 / %d\n%s · %s · 지상 %d층"
const BUTTON_INK:=["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]
var game
var checks:=0
var failures:=0
var output:=""
var route_frame:Image
var building_frame:Image

func _initialize():
 run.call_deferred()

func check(ok:bool, description:String):
 checks+=1
 if not ok:
  failures+=1
  printerr("FAIL ",description)

func settle():
 await process_frame
 await process_frame
 await process_frame

func move_pointer(position:Vector2):
 var motion:=InputEventMouseMotion.new();motion.position=position
 root.push_input(motion,true)

func click(position:Vector2):
 move_pointer(position)
 for down in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=position
  root.push_input(event,true)
 await settle()

func click_control(control:Control):
 await click(control.get_global_rect().get_center())

func luminance(srgb:Color)->float:
 var c:=srgb.srgb_to_linear()
 return .2126*c.r+.7152*c.g+.0722*c.b

func contrast(fg:Color,bg:Color)->float:
 return (luminance(fg)+.05)/(luminance(bg)+.05)

func paper(stylebox:StyleBox)->bool:
 return stylebox is StyleBoxFlat and stylebox.bg_color.is_equal_approx(PAPER)

func themed_ink(button:Button,color:Color)->bool:
 return BUTTON_INK.all(func(key):return button.get_theme_color(key).is_equal_approx(color))

func check_tabs(tag:String):
 for tab:Button in game.transport_tabs.get_children():
  var active:bool=game.transport_tab==tab.get_index()
  check(themed_ink(tab,PAPER if active else INK),tag+": active/inactive tab ink through normal, hover, press and focus: "+tab.text)

func check_info(tag:String):
 var info:Label=game.info
 var box:=info.get_theme_stylebox("normal")
 var bounds:=info.get_global_rect()
 check(info.is_visible_in_tree(),tag+": valid selection shows a lower-right info label")
 check(paper(box),tag+": selected info has opaque approved backplate #142b37")
 check(info.get_theme_font_size("font_size")>=18,tag+": selected info is at least 18px")
 check(box is StyleBoxFlat and contrast(info.get_theme_color("font_color"),box.bg_color)>=4.5,tag+": selected info contrast >=4.5:1")
 check(root.get_visible_rect().encloses(bounds) and bounds.position.x>root.size.x/2.0,tag+": info stays inside the viewport on the right")
 for panel:Control in [game.dock,game.drawer,game.transport_tabs,game.route_overlay.panel,game.road_modes,game.labor_panel]:
  check(not panel.is_visible_in_tree() or not panel.get_global_rect().intersects(bounds),tag+": selected info does not overlap "+str(panel.name))
 move_pointer(bounds.get_center())
 check(info.mouse_filter==Control.MOUSE_FILTER_IGNORE and info.focus_mode==Control.FOCUS_NONE and root.gui_get_hovered_control()==null,tag+": backplate passes the mouse through and never takes focus")

func frame()->Image:
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()

func run():
 Engine.max_fps=60
 var native:=DisplayServer.get_name()!="headless"
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--e4a-output="):output=arg.trim_prefix("--e4a-output=")
 if not output.is_empty():
  if not native or FileAccess.file_exists(output.path_join("a-route-list-1920.png")) or FileAccess.file_exists(output.path_join("a-selected-building-1920.png")):
   check(false,"capture requires native GL and fresh output files");finish();return
 if not native:root.size=Vector2i(1280,720)
 else:
  check(root.size==Vector2i(1920,1080) and RenderingServer.get_current_rendering_method()=="gl_compatibility","native window is actual 1920x1080 GL Compatibility")
 game=load("res://main.tscn").instantiate()
 game.paused=true
 root.add_child(game)
 game.city.simulation.shutdown()
 game.city=BusFixture.fixture(4)
 var city=game.city
 var stops:Array=city.public_facilities.lots.map(func(lot):return lot.id)
 check(city.create_transit_line("bus",stops).ok,"fixture creates an authoritative scheduled bus route")
 city.buildings.append({"id":901,"x":40,"y":44,"size":4,"level":3,"zone":"residential","asset_id":"mansion-a-4x4-4f","score":0.0})
 var asset:Dictionary=city.catalog.get_asset("mansion-a-4x4-4f")
 game.map_zoom=.9 if native else .58
 game.origin=Vector2(root.size.x*.58,root.size.y*.44)-game.world_renderer.iso(Vector2(50,50))*game.map_zoom
 game.refresh()
 await settle()
 check(not game.info.visible,"no selection has no info")
 await click_control(game.categories[6])
 check(game.drawer.visible and game.transport_tabs.visible and game.transport_tab==0,"transport opens at bus from the actual bottom bar")
 check_tabs("bus")
 await click_control(game.transport_tabs.get_child(1))
 check(game.transport_tab==1 and game.transport_tabs.get_child(1).has_focus() and not game.transport_tabs.get_child(1).has_focus(true),"transport tab click retains pointer focus behavior")
 check_tabs("metro")
 await click_control(game.transport_tabs.get_child(0))
 await click_control(game.drawer_box.get_node("Tool_transit_line"))
 var overlay=game.route_overlay
 check(overlay.visible and overlay.mode=="bus" and overlay.rows.get_child_count()==1,"viewport click opens real bus list")
 if not overlay.visible or overlay.rows.get_child_count()!=1:finish();return
 var row:Control=overlay.rows.get_child(0)
 var title:Label=row.get_child(1)
 check(paper(overlay.panel.get_theme_stylebox("panel")),"route list panel keeps #142b37")
 check(title.text=="버스 1" and title.get_theme_color("font_color").is_equal_approx(INK),"real route title keeps wording and uses #edf4f5")
 for button:Button in [row.get_node("DeleteRoute"),overlay.create_buttons["bus"]]:
  check(paper(button.get_theme_stylebox("normal")),"route list button uses #142b37: "+button.name)
  check(themed_ink(button,INK),"route list button uses #edf4f5 through interactive states: "+button.name)
 check(not overlay.paths.is_empty() and not overlay.arrow_primitives.is_empty(),"route geometry and arrows still present")
 check(root.get_visible_rect().encloses(overlay.panel.get_global_rect()) and not overlay.panel.get_global_rect().intersects(game.transport_tabs.get_global_rect()),"real route list fits without overlapping tray tabs")
 move_pointer(Vector2(root.size.x-50,60));await settle()
 if not output.is_empty():route_frame=await frame()
 await click_control(game.drawer_box.get_child(-1))
 check(not overlay.visible and not game.drawer.visible and not game.transport_tabs.visible,"actual chevron closes the tray and route overlay")
 var b:Dictionary=city.find_building(901)
 var visual:Dictionary=game.building_visual(b)
 var target:Vector2=visual.rect.get_center() if not visual.is_empty() else game.screen(Vector2(42,46))-Vector2(0,game.visual_lift(b)*game.map_zoom)
 check(game.pick_rendered_building(target).get("id",-1)==901,"fixture click targets actual rendered building 901")
 await click(target)
 check(game.selected==901,"real viewport click selects building 901")
 check(game.info.text==BUILDING_TEXT%[city.config.score_threshold,asset.category_name,asset.name,asset.storeys],"selected building retains exact full text: "+str(game.info.text))
 var sizes:=[root.size] if native else [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]
 for size_value:Vector2i in sizes:
  if root.size!=size_value:root.size=size_value
  await settle()
  check(root.size==size_value,"expected viewport: "+str(size_value))
  check_info(str(size_value))
 if not output.is_empty():
  move_pointer(Vector2(root.size.x-50,60));await settle()
  building_frame=await frame()
  var pixel:=Vector2i(game.info.get_global_rect().position+Vector2(9,7))
  check(building_frame.get_size()==Vector2i(1920,1080) and building_frame.get_pixelv(pixel).is_equal_approx(PAPER),"native framebuffer has actual #142b37 plate under the building info")
 await click_control(game.categories[6])
 check(game.selected==901 and not game.info.visible,"tray hides selected info without changing the selection")
 await click_control(game.drawer_box.get_child(-1))
 check(game.info.visible,"closing the tray restores the selected info")
 game.open_budget();await settle()
 check(game.budget_window.visible and not game.info.visible,"modal budget hides selected info without stealing its selection")
 game.budget_window.close();await settle()
 check(game.selected==901 and game.info.visible,"closing modal restores the same selected info")
 await click(Vector2(root.size.x-50,60))
 check(game.selected==-1 and not game.info.visible,"empty map click deselects and hides the plate")
 if not output.is_empty() and failures==0:
  check(route_frame.get_size()==Vector2i(1920,1080),"route capture has native framebuffer dimensions")
  if failures==0:
   check(route_frame.save_png(output.path_join("a-route-list-1920.png"))==OK,"route capture saved")
   check(building_frame.save_png(output.path_join("a-selected-building-1920.png"))==OK,"building capture saved")
 finish()

func finish():
 print("Part A HUD: %d passed, %d failed"%[checks-failures, failures])
 if game!=null:
  game.free();game=null
 quit(1 if failures else 0)
