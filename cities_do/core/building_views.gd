extends Node
## Render real 3D models once per facade direction; share the resulting image across lots.
signal changed
const CANVAS := 640
const CACHE_LIMIT := 64
var cache := {}
var pending := {}
var queue: Array[Dictionary] = []
var busy := false

func view(asset: Dictionary, facing: Vector2) -> Dictionary:
	if DisplayServer.get_name()=="headless" or not asset.has("model"):return {}
	var key := "%s:%.10f:%.10f" % [asset.id,facing.x,facing.y]
	if cache.has(key):return cache[key]
	if not pending.has(key):
		pending[key]=true
		queue.append({"key":key,"asset":asset,"facing":facing})
		_start_next.call_deferred()
	return {}

func _start_next():
	if busy or queue.is_empty():return
	busy=true
	var request: Dictionary=queue.pop_front()
	var asset: Dictionary=request.asset
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(CANVAS,CANVAS)
	viewport.transparent_bg=true
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var stage:=Node3D.new()
	viewport.add_child(stage)
	var model=load(asset.model).instantiate()
	stage.add_child(model)
	model.rotation.y=atan2(request.facing.x,request.facing.y)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("d9e4f0")
	environment.environment.ambient_light_energy=.75
	stage.add_child(environment)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-55,-35,0)
	light.light_energy=1.1
	stage.add_child(light)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	var lot: float=asset.footprint[0]*4.0
	var height: float=asset.height_m
	camera.size=maxf(lot*sqrt(2.0)+1,height*cos(PI/6)+lot/sqrt(2.0)+1)*1.08
	var target:=Vector3(0,height/2,0)
	stage.add_child(camera)
	camera.position=target+Vector3(60,60*sqrt(2.0)*tan(PI/6),60)
	camera.look_at(target)
	camera.current=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	# Child viewports may be scheduled after their parent's first frame.
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image:=viewport.get_texture().get_image()
	var ppm:=CANVAS/camera.size
	if cache.size()>=CACHE_LIMIT:cache.erase(cache.keys()[0])
	cache[request.key]={"texture":ImageTexture.create_from_image(image),"image":image,
		"ppm":ppm,"anchor":Vector2(CANVAS/2.0,CANVAS/2.0+height/2*cos(PI/6)*ppm)}
	pending.erase(request.key)
	viewport.queue_free()
	busy=false
	changed.emit()
	_start_next.call_deferred()
