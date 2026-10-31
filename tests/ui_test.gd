extends SceneTree

var failures: Array = []
var checks = 0
var game
var session

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)

func key(code: Key, ctrl: bool = false) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.ctrl_pressed = ctrl
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func click(point: Vector2) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = root.get_final_transform() * point
	event.global_position = event.position
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	session = root.get_node("Session")
	session.allow_autosave = false
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	print("UI_GEOMETRY ", root.size, " transform=", root.get_final_transform(), " root_rect=", game.hud.root.get_global_rect())
	check(game.hud.menu.visible and not game.hud.play_ui.visible, "title visible on launch")
	# Click the actual title button, then operate the normal input path.
	await click(Vector2(200, 363))
	check(session.mode == "solo" and session.sim.running and game.hud.play_ui.visible, "title button starts solo game")
	if session.mode != "solo":
		quit(1)
		return
	await key(KEY_V)
	check(game.selected.size() == 3, "V selects all three own workers")
	await key(KEY_B)
	check(game.build_mode == "house" and is_instance_valid(game.ghost), "B opens building placement")
	await key(KEY_ESCAPE)
	check(game.build_mode == "" and not game.hud.help_panel.visible, "Escape cancels placement")
	await key(KEY_F)
	check(game.selected.size() == 3, "F selects starting combat army")
	await key(KEY_E)
	check(game.attack_mode, "E activates attack-move")
	var destination = Vector2(10, -5)
	var screen = game.camera.unproject_position(Vector3(destination.x, 0, destination.y))
	await click(screen)
	check(not game.attack_mode and session.sim.units[game.selected[0]].order == "attack_move", "terrain click submits attack-move")
	await key(KEY_H)
	check(game.hud.help_panel.visible, "H opens controls")
	await key(KEY_H)
	check(not game.hud.help_panel.visible, "H returns to battlefield")
	await key(KEY_M)
	check(game.sound.muted, "M mutes music and sound")
	await key(KEY_1)
	check(session.sim.population() == 6 and session.sim.queued_population() == 1, "1 queues worker through input")
	for i in range(70):
		session.sim.step(0.05)
	check(session.sim.population() == 7, "worker finishes training")
	await key(KEY_6, true)
	game.selected.clear()
	await key(KEY_6)
	check(game.selected.size() == 3, "control group restores army selection")
	await key(KEY_P)
	var before: float = session.sim.elapsed
	session.sim.step(1)
	check(session.sim.paused and session.sim.elapsed == before, "P pauses solo simulation")
	await key(KEY_P)
	check(not session.sim.paused, "P resumes solo simulation")
	await click(Vector2(450, 576))
	check(game.hud.active_tab == 1 and game.hud.tabs[1].visible, "building tab opens")
	await click(Vector2(620, 576))
	check(game.hud.active_tab == 2 and game.hud.tabs[2].visible, "upgrade tab opens")
	await key(KEY_Y)
	check(game.rally_mode, "Y enables rally placement")
	await key(KEY_ESCAPE)
	check(not game.rally_mode and not game.hud.help_panel.visible, "Escape cancels rally placement")
	session.sim.players[1].skill_points = 1
	await process_frame
	await process_frame
	check(game.hud.bonus_panel.visible, "wave reward shows three skill cards")
	await click(Vector2(320, 315))
	await process_frame
	check(session.sim.players[1].skills.harvest == 1 and session.sim.players[1].skill_points == 0, "card click spends own reward")
	check(not game.hud.bonus_panel.visible, "bonus closes after choice")
	print("UI_TEST ", checks - failures.size(), "/", checks, " PASS; failures=", failures)
	game.queue_free()
	await process_frame
	await process_frame
	quit.call_deferred(0 if failures.is_empty() else 1)
