extends SceneTree
## Review fix 3-2 (user rule 2026-11-19, ASSET_REQUEST_RAIL_PARK_KO.md 5절 12번) in the actual main scene
## with its simulation worker, real clicks and keys. An edit that changes the route of a rail, metro or
## freight line with a consist first shows "수정사항이 있는 모든 열차가 초기화됩니다!" and is applied only on
## 확인 (or Enter); 취소 (or Esc) leaves tracks, stops and consists exactly as they were. Stop edits
## (노선 수정 tool), bulldozing a line's track or station and rebuilding a cut track warn; a branch, a
## schedule-only edit, a line without a consist and a bus line do not. Capture is explicit
## (--review-capture=) and native only.
const City=preload("res://core/city_model.gd")
const Operations=preload("res://core/transit_operations.gd")
const Planner=preload("res://core/transit_line_planner.gd")
const TEXT:="수정사항이 있는 모든 열차가 초기화됩니다!"
const LIMIT:=400
var checks:=0
var failures:=0
var game
var capture:=""
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if ok:print("PASS ",label)
	else:failures+=1;printerr("FAIL ",label)
func settle():
	for i in range(4):await process_frame
## Real input through the viewport: GUI first, then the scene's _input/_unhandled_input.
func click(position:Vector2):
	var motion:=InputEventMouseMotion.new();motion.position=position;motion.global_position=position
	root.push_input(motion,true);await process_frame
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=position;event.global_position=position
		root.push_input(event,true);await process_frame
	await settle()
func key(code:int):
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.pressed=pressed;root.push_input(event,true)
		await settle()
func press(control:Control):await click(control.get_global_rect().get_center())
## One worker development step (the lift scene's barrier): queued edits replay, consists advance, publish.
func step(count:int=1):
	var city=game.city
	for i in range(count):
		city.simulation.resume();city.advance_society(city.config.development_interval_seconds);city.simulation.validation_publish()
	city.simulation.resume()
	await process_frame
func shown()->bool:return game.route_warning_open()
func state(city)->PackedByteArray:return var_to_bytes([city.transit_routes,city.transit_lines,city.transit_state,city.public_facilities.lots,city.next_transit_route_id])
func line_of(city,id:int)->Dictionary:
	for line:Dictionary in city.transit_lines:
		if int(line.id)==id:return line
	return {}
func train(city,id:int)->Dictionary:return city.transit_state.trains.get(id,{})
func status(city,id:int)->String:return str(city.transit_state.lines.get(id,{}).get("status",""))
func plan_of(city,id:int)->Dictionary:return Planner.new().rail_plan(city,line_of(city,id))
func describe(t:Dictionary)->String:
	return "none" if t.is_empty() else "stops=%s distance=%.1f departures=%d drawn=%d"%[str(t.plan.stops.map(func(s):return s.id)),float(t.distance),int(t.departures),t.visible.size()]
func lot(city,id:int)->Dictionary:
	for record:Dictionary in city.public_facilities.lots:
		if int(record.id)==id:return record
	return {}
func centroid(polygon:PackedVector2Array)->Vector2:
	var sum:=Vector2.ZERO
	for p:Vector2 in polygon:sum+=p
	return sum/maxi(polygon.size(),1)
func station_click(city,id:int)->Vector2:return game.screen(centroid(lot(city,id).polygon))
## The consist sits on the line's current plan at its first stop and is drawn there.
func at_start(city,id:int)->bool:
	var t:Dictionary=train(city,id);var plan:Dictionary=plan_of(city,id)
	if t.is_empty() or t.visible.is_empty() or t.plan!=plan or float(t.distance)!=0.0 or int(t.next_stop)!=1:return false
	var first:PackedVector2Array=lot(city,int(plan.stops[0].id)).internal_points
	var sum:=Vector2.ZERO
	for pose:Dictionary in t.visible:sum+=pose.position
	return (sum/t.visible.size()).distance_to((first[0]+first[-1])*2.0)<8.0
func run_until(city,id:int,done:Callable)->int:
	for i in range(LIMIT):
		await step()
		if done.call(train(city,id)):return i+1
	return -1
func running(t:Dictionary)->bool:return not t.is_empty() and float(t.distance)>5.0 and int(t.departures)>=1 and not t.visible.is_empty()
func choose(tool:String):
	game.select_category("transport");await settle()
	var card:Control=game.find_child("Tool_"+tool,true,false)
	if card!=null:await press(card)
## Three real stations in a row (A-B-C) joined by ground track (the regen fixture).
func row_city()->Dictionary:
	var city=City.new(160,90,42)
	city.population_enabled=false;city.happiness_enabled=false;city.funds=1000000
	city.add_road(PackedVector2Array([Vector2(2,40),Vector2(150,40)]),"local",true,4)
	for x:float in [30.0,70.0,110.0]:
		if not city.public_facilities.place("train-station-01",Vector2(x,33.0),0,true).ok:return {}
	var tracks:Array=[]
	for record:Dictionary in city.public_facilities.lots:
		var p:PackedVector2Array=record.internal_points
		if p[0].x>p[-1].x:p.reverse()
		tracks.append(p)
	var joins:Array=[]
	for i in range(2):
		var join:=PackedVector2Array([tracks[i][-1],tracks[i+1][0]])
		if not city.add_transit_route(join).ok:return {}
		joins.append(join)
	return {"city":city,"ids":city.public_facilities.lots.map(func(record):return record.id),"joins":joins}
func run():
	Engine.max_fps=30
	root.size=Vector2i(1920,1080)
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--review-capture="):capture=arg.trim_prefix("--review-capture=")
	if not capture.is_empty() and (DisplayServer.get_name()=="headless" or FileAccess.file_exists(capture)):
		check(false,"native capture requires a real display and a new destination");finish();return
	var built:=row_city()
	check(not built.is_empty(),"fixture: three real stations A-B-C joined in a row")
	if built.is_empty():finish();return
	var city=built.city;var ids:Array=built.ids
	var made:Dictionary=city.create_transit_line("rail",ids,{"dwell_seconds":4.0,"headway_seconds":20.0})
	check(made.ok,"rail line A-B-C: "+str(made.get("reason","")))
	if not made.ok:finish();return
	var id:int=int(made.line.id)
	game=load("res://main.tscn").instantiate();game.city=city;root.add_child(game);current_scene=game
	await settle()
	game.paused=true;city.simulation.worker.Suspend()
	game.map_zoom=1.0
	var span:float=absf((game.world_renderer.iso(Vector2(118,36))-game.world_renderer.iso(Vector2(22,36))).x)
	game.map_zoom=clampf(1250.0/maxf(span,1.0),.3,1.5)
	game.origin=Vector2(960,430)-game.world_renderer.iso(Vector2(70,36))*game.map_zoom
	game.world_renderer.synchronize();game.refresh();await settle()
	print("development step %.2fs zoom %.2f A=%s C=%s"%[city.config.development_interval_seconds,game.map_zoom,str(station_click(city,ids[0])),str(station_click(city,ids[2]))])
	# A line without a consist yet: its stop edit applies without a warning.
	check(train(city,id).is_empty(),"no consist runs before the first development step")
	await choose("edit_line")
	check(game.mode=="edit_line","the 노선 수정 card selects the stop edit tool")
	for stop:int in [ids[0],ids[0],ids[2],ids[0]]:await click(station_click(city,stop))
	check(not shown(),"a stop edit of a line without a consist shows no warning")
	await step()
	check(line_of(city,id).stops==[ids[0],ids[2]],"it applies at once: stops %s"%str(line_of(city,id).stops))
	var took:=await run_until(city,id,running)
	check(took>0,"the consist of the A-C line runs: %s"%describe(train(city,id)))
	await schedule_only(city,id,ids)
	await stop_edits(city,id,ids)
	await track_edits(city,id,ids,built.joins)
	await bus_edit()
	finish()
func finish():
	if game!=null and game.city!=null and game.city.simulation!=null:game.city.simulation.shutdown()
	print("REVIEW_FIX_DIALOG checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
func schedule_only(city,id:int,ids:Array):
	var before:Dictionary=train(city,id).duplicate(true)
	var waiting:bool=game.edit_transit_line(id,[ids[0],ids[2]],{"dwell_seconds":6.0})
	check(not waiting and not shown(),"a dwell-only edit shows no warning")
	await step()
	var t:Dictionary=train(city,id)
	check(float(line_of(city,id).dwell_seconds)==6.0 and t.plan==before.plan and int(t.departures)>=int(before.departures) and (float(t.distance)>=float(before.distance) or int(t.departures)>int(before.departures)),"it applies and the consist keeps running: %s was %s"%[describe(t),describe(before)])
## The warning's look: one line, 확인 then 취소, economy-window palette, 18px or more, centred.
func look():
	var w=game.route_warning
	var texts:Array=[]
	for node:Node in w.find_children("*","Control",true,false):
		if (node is Label or node is Button) and node.is_visible_in_tree():texts.append(node.text)
	check(texts==[TEXT,"확인","취소"],"the warning shows only the line and two buttons: %s"%str(texts))
	var box:StyleBoxFlat=w.panel.get_theme_stylebox("panel")
	var ok:StyleBoxFlat=w.confirm_button.get_theme_stylebox("normal")
	var no:StyleBoxFlat=w.cancel_button.get_theme_stylebox("normal")
	check(box.bg_color==Color("142b37") and box.border_color==Color("38515e") and w.message.get_theme_color("font_color")==Color("edf4f5") and ok.bg_color==Color("36b7ff") and no.bg_color==Color("38515e"),"palette: panel #142b37, border #38515e, text #edf4f5, 확인 #36b7ff")
	var sizes:Array=[w.message,w.confirm_button,w.cancel_button].map(func(c):return c.get_theme_font_size("font_size"))
	check(sizes.all(func(s):return s>=18),"font sizes are 18px or more: %s"%str(sizes))
	var centre:Vector2=w.panel.get_global_rect().get_center()
	check(centre.distance_to(Vector2(root.size)/2)<2.0 and w.get_global_rect().size==Vector2(root.size),"a modal panel centred on screen: %s"%str(centre))
func stop_edits(city,id:int,ids:Array):
	# Add stop B back with real clicks: the warning opens before anything changes.
	var before:=state(city)
	await choose("edit_line")
	for stop:int in [ids[0],ids[0],ids[1],ids[2],ids[0]]:await click(station_click(city,stop))
	check(shown() and game.route_warning.message.text==TEXT,"adding stop B with 노선 수정 shows the warning: %s"%str(game.route_warning.message.text if game.route_warning!=null else "none"))
	if not shown():return
	look()
	check(state(city)==before,"while it is open nothing has changed")
	var zoom:float=game.map_zoom;var origin:Vector2=game.origin
	var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true;wheel.position=Vector2(960,540);wheel.global_position=wheel.position
	root.push_input(wheel,true);await settle()
	for code:int in [KEY_W,KEY_LEFT,KEY_PAGEDOWN,KEY_DELETE]:await key(code)
	await click(station_click(city,ids[2]))
	check(shown() and game.map_zoom==zoom and game.origin==origin and state(city)==before,"other input (wheel, camera keys, map clicks) is blocked while it is open")
	if not capture.is_empty():
		game.world_renderer.synchronize();game.refresh();await settle()
		await RenderingServer.frame_post_draw
		var image:=root.get_texture().get_image()
		check(image.get_size()==Vector2i(1920,1080),"native capture is 1920x1080")
		check(image.save_png(capture)==OK,"warning capture saved")
		print("REVIEW_CAPTURE ",capture," display=",DisplayServer.get_name())
	await key(KEY_ESCAPE)
	check(not shown() and state(city)==before,"Esc (취소) closes it; tracks, stops and consists are byte-identical")
	var held:Dictionary=train(city,id).duplicate(true)
	await step()
	check(line_of(city,id).stops==[ids[0],ids[2]] and train(city,id).plan==held.plan and int(train(city,id).departures)>=int(held.departures) and not at_start(city,id),"after 취소 the consist keeps running its route: %s"%describe(train(city,id)))
	# The same edit confirmed with a click on 확인.
	await choose("edit_line")
	for stop:int in [ids[0],ids[0],ids[1],ids[2],ids[0]]:await click(station_click(city,stop))
	check(shown(),"the same edit warns again")
	if not shown():return
	var count:=int(train(city,id).departures)
	await press(game.route_warning.confirm_button)
	check(not shown(),"a click on 확인 closes it")
	await step()
	check(line_of(city,id).stops==ids and at_start(city,id) and int(train(city,id).departures)==count,"확인 applies stops A-B-C and the same consist is moved to the first stop: %s"%describe(train(city,id)))
	var took:=await run_until(city,id,running)
	check(took>0,"it runs the A-B-C route again: %s"%describe(train(city,id)))
	# Remove B again, confirmed with Enter.
	await choose("edit_line")
	for stop:int in [ids[0],ids[0],ids[2],ids[0]]:await click(station_click(city,stop))
	check(shown(),"removing stop B warns")
	await key(KEY_ENTER)
	check(not shown(),"Enter (확인) closes it")
	await step()
	check(line_of(city,id).stops==[ids[0],ids[2]] and at_start(city,id),"Enter applies the edit and moves the consist to the first stop: %s"%describe(train(city,id)))
	took=await run_until(city,id,func(t):return running(t) and float(t.distance)>200.0)
	check(took>0,"it runs past B again: %s"%describe(train(city,id)))
func track_edits(city,id:int,ids:Array,joins:Array):
	var gap:int=-1
	for route:Dictionary in city.transit_routes:
		if route.points==joins[1]:gap=int(route.id)
	await press(game.bulldozer)
	check(game.mode=="demolish","the bulldozer button selects the bulldozer")
	# Station B carries the line's track: bulldozing it warns; Esc keeps everything.
	var b:Dictionary=lot(city,ids[1])
	var front:=Vector2.ZERO;var bottom:=-INF
	for p:Vector2 in b.polygon:bottom=maxf(bottom,p.y)
	front=Vector2(centroid(b.polygon).x,bottom-1.5)
	var before:=state(city)
	await click(game.screen(front))
	check(shown() and state(city)==before,"bulldozing station B under the running line warns first: %s"%game.message)
	if shown():await key(KEY_ESCAPE)
	await step()
	check(not lot(city,ids[1]).is_empty() and not shown(),"Esc keeps station B")
	# Its B-C track: the warning; Enter stops the consist where it is.
	if game.mode!="demolish":await press(game.bulldozer)
	before=state(city)
	await click(game.screen((joins[1][0]+joins[1][1])/2))
	check(shown() and state(city)==before,"bulldozing the B-C track the line runs on warns first")
	var held:Dictionary=train(city,id).duplicate(true)
	await key(KEY_ENTER)
	await step(3)
	var t:Dictionary=train(city,id)
	check(not city.transit_routes.any(func(r):return int(r.id)==gap) and status(city,id)=="blocked" and t.visible==held.visible and float(t.distance)==float(held.distance),"Enter removes it and the consist stops where it is: %s %s"%[status(city,id),describe(t)])
	# Rebuilt with the rail tool: one warning at the confirming click, none while drawing.
	await key(KEY_ESCAPE)
	await choose("rail")
	game.set_route_drawing_kind("straight");await settle()
	check(game.mode=="rail","the rail card selects the rail tool")
	await click(game.screen(joins[1][0]))
	var motion:=InputEventMouseMotion.new();motion.position=game.screen(joins[1][1]);motion.global_position=motion.position;root.push_input(motion,true);await settle()
	check(not shown(),"no warning while the track is drawn (preview)")
	await click(game.screen(joins[1][1]))
	check(shown(),"rebuilding the B-C track warns at the confirming click")
	if not shown():return
	await press(game.route_warning.confirm_button)
	await step()
	check(city.transit_routes.any(func(r):return r.points.size()==2 and r.points[0].distance_to(joins[1][0])<.01 and r.points[1].distance_to(joins[1][1])<.01) and at_start(city,id),"확인 rebuilds it and the consist restarts from the first stop: %s"%describe(train(city,id)))
	var took:=await run_until(city,id,func(t):return running(t) and float(t.distance)>60.0)
	check(took>0,"it runs again from the start: %s"%describe(train(city,id)))
	# A branch laid on the line's track (the rail tool's confirm step): no warning, it keeps running.
	var at:Vector2=(joins[0][0]+joins[0][1])/2;var branch:=PackedVector2Array()
	for i in range(29):branch.append(at+Vector2(14*float(i)/28.0,-4*pow(float(i)/28.0,2)))
	var routes:int=city.transit_routes.size()
	var pending:Dictionary=train(city,id).duplicate(true)
	game.transit_view.commit({"points":branch,"heights_m":PackedFloat64Array()},false)
	check(not shown(),"laying a branch on the line's track shows no warning")
	await step()
	t=train(city,id)
	check(city.transit_routes.size()==routes+1 and t.plan==plan_of(city,id) and int(t.departures)==int(pending.departures) and float(t.distance)>=float(pending.distance) and not at_start(city,id),"the branch is built and the consist keeps running where it was: %s was %s"%[describe(t),describe(pending)])
func bus_edit():
	game.city.simulation.shutdown()
	var city=load("res://tests/test_scheduled_buses.gd").fixture(4)
	var stops:Array=city.public_facilities.lots.map(func(record):return record.id)
	var made:Dictionary=city.create_transit_line("bus",stops,{"dwell_seconds":1.0})
	check(made.ok,"bus line operates: "+str(made.get("reason","")))
	if not made.ok:return
	game.city=city;city.enable_simulation_worker();city.simulation.worker.Suspend()
	await step(5)
	check(city.transit_state.bus.get("vehicles",[]).size()==1,"a bus runs before the edit")
	var waiting:bool=game.edit_transit_line(int(made.line.id),[stops[1],stops[0]])
	check(not waiting and not shown(),"a bus line stop edit shows no warning")
	await step()
	check(line_of(city,int(made.line.id)).stops==[stops[1],stops[0]],"it applies at once")
