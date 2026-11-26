extends SceneTree
## Item 5: real main scene and production renderer, with no simulation advance.
## --fixture-check never reads the framebuffer; --catenary-capture=<new PNG> opts in.
const City=preload("res://core/city_model.gd")
const SIZE:=Vector2i(1920,1080)
const CENTER:=Vector2(48,42)
const RADIUS:=8.5
const ANGLE:=PI/4
var checks:=0
var failures:=0

func _initialize():run.call_deferred()

func check(ok:bool,label:String)->bool:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;printerr("FAIL ",label)
 return ok

func finish():
 print("SECOND_FIX_CATENARY checks=%d failed=%d"%[checks,failures])
 quit(1 if failures else 0)

func run():
 var args:=OS.get_cmdline_user_args()
 var headless:=DisplayServer.get_name()=="headless"
 var check_only:=args.has("--fixture-check")
 var path:=""
 for arg in args:
  if arg.begins_with("--catenary-capture="):path=arg.trim_prefix("--catenary-capture=")
 if headless:root.size=SIZE
 elif not check(root.size==SIZE and DisplayServer.window_get_size()==SIZE,"native window and viewport are exactly 1920x1080"):
  finish();return
 var city=City.new(96,96,20261126)
 city.population_enabled=false;city.happiness_enabled=false;city.funds=1000000
 var radial:=Vector2.from_angle(ANGLE)
 var crossing:=CENTER+radial*RADIUS
 # Oblique eight-lane ribbon; both edges of this real crossing fall on the turn.
 var road_axis:=radial.rotated(deg_to_rad(12.0))
 var road:Dictionary=city.add_road(PackedVector2Array([crossing-road_axis*14,crossing+road_axis*14]),"local",true,8)
 var points:=PackedVector2Array()
 for i in range(-2,16):points.append(CENTER+Vector2.from_angle(PI*.5*i/12)*RADIUS)
 var track:Dictionary=city.add_transit_route(points,"rail")
 if not check(road.ok and track.ok,"real road and rail construction: %s / %s"%[road.get("reason","OK"),track.get("reason","OK")]):
  finish();return
 var game=load("res://main.tscn").instantiate()
 game.city=city;game.paused=true
 root.add_child(game);current_scene=game
 game.map_zoom=2.75
 game.origin=Vector2(960,490)-game.world_renderer.iso(crossing)*game.map_zoom
 game.refresh()
 for i in range(4):await process_frame
 var renderer=game.world_renderer
 var commands:Array=game.transit_view.geometry.catenary
 var footprint:Rect2=game.dock.get_global_rect()
 var projection_ok:=true
 var visible_contacts:=0
 for node in renderer.catenary_nodes:
  for command:Dictionary in node.commands:
   if command.kind not in ["contact","pole"]:continue
   if command.kind=="contact" and node.is_visible_in_tree():visible_contacts+=1
   for point:Vector2 in [command.projected_a,command.projected_b]:
    var screen:Vector2=game.origin+point*game.map_zoom
    projection_ok=projection_ok and Rect2(32,32,1856,1016).has_point(screen) and not footprint.grow(16).has_point(screen)
 check(projection_ok and visible_contacts>0,"real retained poles and contact wires framed clear of the HUD")
 check(not game.drawer.visible and not game.transit_view.underground,"normal ground view with the drawer closed")
 check_spans(commands,city.road_pavement,radial.orthogonal())
 if not check_only and not path.is_empty() and failures==0:
  if check(not headless and path.get_extension().to_lower()=="png" and not FileAccess.file_exists(path),"capture needs a native display and a new PNG destination"):
   await RenderingServer.frame_post_draw
   var image:=root.get_texture().get_image()
   if check(image.get_size()==SIZE,"direct native framebuffer is 1920x1080"):
    var directory:=ProjectSettings.globalize_path(path).get_base_dir()
    if check(DirAccess.make_dir_recursive_absolute(directory)==OK,"capture destination ready"):
     if check(image.save_png(path)==OK,"one raw framebuffer saved"):
      print("SECOND_FIX_CATENARY_CAPTURE ",ProjectSettings.globalize_path(path))
 finish()

func check_spans(commands:Array,pavement:Array,tangent:Vector2):
 var supports:Array=commands.filter(func(c):return c.kind=="pull")
 var total:=0;var crossing:=0
 var longest_crossing:=0.0;var longest_clear:=0.0
 var start:=Vector2.ZERO
 var attached:=true;var clearance:=true
 for pole in commands.filter(func(c):return c.kind=="pole"):
  for polygon:PackedVector2Array in pavement:
   var distance:=INF
   for i in range(polygon.size()):
    distance=minf(distance,pole.a.distance_to(Geometry2D.get_closest_point_to_segment(pole.a,polygon[i],polygon[(i+1)%polygon.size()])))
   clearance=clearance and not Geometry2D.is_point_in_polygon(pole.a,polygon) and distance>=.2499
 for wire:Dictionary in commands:
  if wire.kind!="messenger":continue
  if is_equal_approx(wire.a_height,4.8):start=wire.a
  if not is_equal_approx(wire.b_height,4.8):continue
  var end:Vector2=wire.b
  attached=attached and supports.any(func(p):return p.a.is_equal_approx(start)) and supports.any(func(p):return p.a.is_equal_approx(end))
  # Conservative arc-length bound for this regular polygon inscribed in a 34m circle.
  var length:=absf((start-CENTER).angle_to(end-CENTER))*RADIUS*4
  total+=1
  if (start-CENTER).dot(tangent)*(end-CENTER).dot(tangent)<0:
   crossing+=1;longest_crossing=maxf(longest_crossing,length)
  else:longest_clear=maxf(longest_clear,length)
 check(clearance and attached and total>2,"physical supports carry every span and clear the sidewalk by 1m")
 check(crossing==2 and longest_crossing<=48 and longest_crossing>8,"both road spans stay within 48m (%.3fm)"%longest_crossing)
 check(longest_clear>0 and longest_clear<=8.05,"ordinary curve spans keep 8m pitch (%.3fm)"%longest_clear)
