extends SceneTree
var game
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game._showcase()
	for i in range(90):
		await process_frame
	var samples=[]
	for i in range(180):
		samples.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		await process_frame
	samples.sort()
	var total=0.0
	for sample in samples:
		total+=sample
	print("RENDER_MEASURE size=",root.size," frames=",samples.size()," average_process_ms=",total/samples.size()," p95_process_ms=",samples[170]," engine_fps=",Performance.get_monitor(Performance.TIME_FPS)," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var path=OS.get_cmdline_user_args()[0]
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	game._graceful_quit()
