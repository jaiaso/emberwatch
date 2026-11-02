extends SceneTree
const Layout=preload("res://scripts/window_layout.gd")
var checks=0
var failures=[]
var game
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		push_error(label)
func key_f11() -> void:
	var event=InputEventKey.new()
	event.keycode=KEY_F11
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await process_frame
func click(point: Vector2) -> void:
	var event=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.position=root.get_final_transform()*point
	event.global_position=event.position
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await process_frame
func run() -> void:
	for usable in [Rect2i(0,0,1920,1040),Rect2i(0,0,1366,728),Rect2i(0,0,1280,680),Rect2i(0,0,1024,728),Rect2i(0,0,800,560),Rect2i(-1920,0,1920,1040),Rect2i(1920,-300,1080,1880)]:
		for frame in [Vector2i(16,39),Vector2i(24,60)]:
			var offset=Vector2i(frame.x/2,frame.y-8)
			var fitted=Layout.fitted_rect(usable,frame,offset)
			check(usable.encloses(Rect2i(fitted.position-offset,fitted.size+frame)),"decorated window fits desktop")
			check(absf(float(fitted.size.x)/fitted.size.y-1.6)<0.005,"fitted window preserves aspect")
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var session=root.get_node("Session")
	session.allow_autosave=false
	session.solo()
	check(root.content_scale_aspect==Window.CONTENT_SCALE_ASPECT_KEEP,"keep aspect enabled")
	if DisplayServer.get_name()!="headless":
		var usable=DisplayServer.screen_get_usable_rect(root.current_screen)
		check(usable.encloses(Rect2i(DisplayServer.window_get_position_with_decorations(),DisplayServer.window_get_size_with_decorations())),"actual launch fits usable desktop")
	for dimensions in [Vector2i(1152,720),Vector2i(1024,640),Vector2i(800,600),Vector2i(1280,720),Vector2i(640,480)]:
		if DisplayServer.get_name()!="headless":
			root.size=dimensions
			await create_timer(0.15).timeout
		for i in range(4):
			await process_frame
		var bounds=Rect2(Vector2.ZERO,Vector2(root.size)).grow(1)
		var transform=root.get_final_transform()
		for control in [game.hud.menu,game.hud.audio_button,game.hud.minimap,game.hud.buttons.cavalry,game.hud.buttons.save,game.hud.help_panel]:
			check(bounds.encloses(transform*control.get_global_rect()),"top/bottom controls fit viewport")
		if DisplayServer.get_name()!="headless":
			await click(Vector2(650,625))
			check(session.sim.queued_population()==1,"bottom cavalry button works after resize %s queued=%d" % [dimensions,session.sim.queued_population()])
			await click(Vector2(280,681))
			check(session.sim.queued_population()==0,"bottom cancel button works after resize")
	if DisplayServer.get_name()!="headless":
		await key_f11()
		check(root.mode==Window.MODE_FULLSCREEN,"F11 enters fullscreen")
		await key_f11()
		for i in range(5):
			await process_frame
		check(root.mode==Window.MODE_WINDOWED,"F11 restores window")
		var usable=DisplayServer.screen_get_usable_rect(root.current_screen)
		check(usable.encloses(Rect2i(DisplayServer.window_get_position_with_decorations(),DisplayServer.window_get_size_with_decorations())),"fullscreen exit stays inside desktop")
	if not OS.get_cmdline_user_args().is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	print("WINDOW_TEST ",checks-failures.size(),"/",checks," PASS ",failures," size=",root.size)
	game._graceful_quit()
