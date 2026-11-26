extends SceneTree

var checks := 0
var failures := 0

func _initialize():
 run.call_deferred()

func check(ok:bool, title:String):
 checks+=1
 if not ok:
  failures+=1
  push_error("FAIL "+title)

func click(button:Control):
 var p:=button.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new()
 motion.position=p
 root.push_input(motion,true)
 for down in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT
  event.pressed=down
  event.position=p
  root.push_input(event,true)

func approved_transport_icons() -> Dictionary:
 var path:=ProjectSettings.globalize_path("res://").path_join("../docs/concepts/transit-icons-20261119/icons-B.txt").simplify_path()
 var images:Dictionary={}
 for line in FileAccess.get_file_as_string(path).split("\n"):
  if not line.strip_edges().begins_with('"'):continue
  var image:=Image.new()
  var svg:='<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24"><g fill="#e4eef1">%s</g></svg>'%line.get_slice("'",1)
  if image.load_svg_from_string(svg)==OK:images[line.get_slice('"',1)]=image.get_data()
 check(images.size()==5,"all five approved B reference glyphs rasterize")
 return images

func check_transport_icon(row:HBoxContainer,tool:String,approved:Dictionary):
 var card:=row.get_node_or_null("Tool_"+tool)
 var pictures:=card.find_children("*","TextureRect",true,false) if card!=null else []
 var glyph:TextureRect=pictures[0] if pictures.size()==1 else null
 check(glyph!=null and glyph.custom_minimum_size==Vector2(38,38) and glyph.texture!=null and glyph.texture.get_image().get_data()==approved.get(tool),"transport card shows its approved B glyph: "+tool)

func run():
 root.size=Vector2i(1280,720)
 var game=load("res://main.tscn").instantiate()
 root.add_child(game)
 game.paused=true
 game.select_category("transport")
 await process_frame
 var tabs:Control=game.get_node_or_null("HUD/TransportTabs")
 if tabs==null:
  var matches:Array=game.find_children("TransportTabs","HBoxContainer",true,false)
  if not matches.is_empty():tabs=matches[0]
 check(tabs!=null,"transport has a dedicated tab row")
 if tabs!=null:
  var approved:=approved_transport_icons()
  # Freight creation and route removal moved to the overlay. Exercise the shared
  # tray-card builder for their approved glyphs without adding controls to the UI.
  var icon_probe:=HBoxContainer.new()
  for tool in ["freight_line","remove_line"]:
   game.add_drawer_tool(icon_probe,"transport",[tool,tool])
   check_transport_icon(icon_probe,tool,approved)
  icon_probe.free()
  var expected:=[
   ["Facility_bus-stop-01","Facility_bus-station-01","Tool_transit_line"],
   ["Tool_metro","Facility_subway-entrance-01","Tool_transit_line"],
   ["Tool_rail","RailHeightControls","Facility_train-station-01","Tool_transit_line"]]
  check(game.transport_tab==0,"first transport tab is bus")
  for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
   root.size=resolution
   await process_frame
   await process_frame
   var width:float=game.drawer.size.x
   var tab_pos:=tabs.global_position
   var bottom:float=game.drawer.get_global_rect().end.y
   for i in range(3):
    game.activate_tool("rail")
    click(tabs.get_child(i))
    await process_frame
    await process_frame
    check(game.transport_tab==i and game.mode=="select","viewport click selects tab and clears tool: %s %d"%[resolution,i])
    var names:Array=[]
    for child in game.drawer_box.get_children().slice(1,-1):names.append(str(child.name))
    check(names==expected[i],"exact card order: %s %d: %s"%[resolution,i,names])
    if resolution==Vector2i(1920,1080):
     check_transport_icon(game.drawer_box,"transit_line",approved)
     if i>0:check_transport_icon(game.drawer_box,["metro","rail"][i-1],approved)
    var route:Control=game.drawer_box.get_node("Tool_transit_line")
    check(route.get_global_rect().end.x<=game.drawer.get_global_rect().end.x-12,"last card is fully inside the tray: %s %d"%[resolution,i])
    check(game.drawer.size.x==width and tabs.global_position==tab_pos,"tray and tabs stay fixed: %s %d"%[resolution,i])
    check(root.get_visible_rect().encloses(tabs.get_global_rect()) and not tabs.get_global_rect().intersects(game.drawer.get_global_rect()) and not game.drawer.get_global_rect().intersects(game.dock.get_global_rect()),"HUD regions do not overlap: %s %d"%[resolution,i])
    var tag:="%s tab %d"%[resolution,i]
    var tab:Button=tabs.get_child(i)
    var face:=tab.get_theme_stylebox("normal") as StyleBoxFlat
    check(face.corner_radius_top_left==12 and face.corner_radius_top_right==12 and face.corner_radius_bottom_left==0 and face.corner_radius_bottom_right==0 and face.border_width_bottom==0 and tab.get_theme_font_size("font_size")==18 and face.bg_color==Color("36b7ff") and tab.get_theme_color("font_color")==Color("142b37"),"folder shape, joined bottom and selected palette: "+tag)
    check(tab.size.y>=30 and tab.size.y<=34,"folder tab is about 30px tall after theme layout: %s (%.1fpx)"%[tag,tab.size.y])
    check(tab.has_focus() and not tab.has_focus(true),"pointer selection does not paint dotted focus: "+tag)
    var scroll:ScrollContainer=game.drawer_scroll
    var close:Button=game.drawer_box.get_child(-1)
    var viewport:=scroll.get_global_rect()
    var drawer_rect:Rect2=game.drawer.get_global_rect()
    var border:StyleBox=game.drawer.get_theme_stylebox("panel")
    check(not scroll.get_h_scroll_bar().visible and not scroll.get_v_scroll_bar().visible and scroll.scroll_horizontal==0,"no visible tray scroll or scroll displacement: "+tag)
    check(viewport.encloses(close.get_global_rect()) and close.get_global_rect().end.x<=drawer_rect.end.x-border.get_margin(SIDE_RIGHT) and close.get_global_rect().end.y<=drawer_rect.end.y-border.get_margin(SIDE_BOTTOM),"actual chevron is inside the tray clip and frame: %s %s %s"%[tag,viewport,close.get_global_rect()])
    check(is_equal_approx(drawer_rect.end.y,bottom),"tray bottom edge is invariant: "+tag)
    click(close)
    check(not game.drawer.visible and not tabs.visible,"actual chevron closes the transport tray: "+tag)
    game.select_category("transport")
    await process_frame
    await process_frame
   var keyboard_tab:Button=tabs.get_child(1)
   keyboard_tab.grab_focus()
   for down in [true,false]:
    var accept:=InputEventAction.new();accept.action="ui_accept";accept.pressed=down;root.push_input(accept,true)
   check(game.transport_tab==1 and keyboard_tab.has_focus(true),"keyboard activation keeps visible focus")
   click(keyboard_tab)
   check(keyboard_tab.has_focus() and not keyboard_tab.has_focus(true),"click on the already keyboard-focused tab hides the outline")
   click(tabs.get_child(2))
  game.select_category("road")
  check(not tabs.visible,"other categories hide the transport tab row")
  game.select_category("transport")
  check(game.transport_tab==2,"transport remembers the last viewed tab")
 print("Transport tabs: %d passed, %d failed"%[checks-failures,failures])
 quit(1 if failures else 0)
