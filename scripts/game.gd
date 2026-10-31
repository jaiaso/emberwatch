extends Node3D

const Visuals = preload("res://scripts/visuals.gd")
const HUD = preload("res://scripts/hud.gd")
const Sound = preload("res://scripts/sound.gd")
const TEAM = Visuals.TEAM
var art = Visuals.new()
var camera: Camera3D
var camera_center = Vector2(-5, -2)
var zoom = 29.0
var entities: Dictionary = {}
var resource_nodes: Dictionary = {}
var selected: Array = []
var build_mode = ""
var attack_mode = false
var ghost: Node3D
var dragging = false
var drag_start = Vector2.ZERO
var drag_end = Vector2.ZERO
var hud
var overlay: Control
var markers: Array = []
var menu_time = 0.0
var capture_path = ""
var capture_frames = 0
var previous_mode = "menu"
var sound
var groups: Dictionary = {}
var effects: Array = []
var last_effect = 0
var last_match = -1
var rally_mode = false
var double_select = false
var closing = false

func _ready() -> void:
	_setup_world()
	sound = Sound.new()
	add_child(sound)
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(_graceful_quit)
	var retro_layer = CanvasLayer.new()
	retro_layer.layer = 1
	add_child(retro_layer)
	var screen = ColorRect.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material = ShaderMaterial.new()
	material.shader = load("res://shaders/retro.gdshader")
	screen.material = material
	retro_layer.add_child(screen)
	var layer = CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	layer.add_child(overlay)
	hud = HUD.new()
	add_child(hud)
	hud.setup(self)
	Session.pinged.connect(func(pos): markers.append({"p": pos, "life": 4.0, "color": Color("efbd70")}))
	Session.changed.connect(_session_changed)
	var args = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--capture" and i + 1 < args.size():
			capture_path = args[i + 1]
		if args[i] == "--solo":
			Session.solo()
		if args[i] == "--showcase":
			_showcase()
	if "--landscape" in args:
		Session.solo()
		Session.allow_autosave = false
		Session.sim.elapsed = 151
		Session.sim.next_wave = 221
		camera_center = Vector2(-11, -5)
		zoom = 46
	if "--units-preview" in args:
		Session.solo()
		Session.allow_autosave = false
		Session.sim.elapsed = 151
		Session.sim.next_wave = 221
		Session.sim.units.clear()
		for i in range(3):
			Session.sim.spawn_unit(["worker", "soldier", "archer"][i], Vector2(-8 + i * 3, 8), 1)
		camera_center = Vector2(-5, 8)
		zoom = 17
	if "--bonus-preview" in args:
		Session.solo()
		Session.allow_autosave = false
		Session.sim.players[1].skill_points = 1
	_update_camera()

func _setup_world() -> void:
	add_child(art.terrain())
	var world = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("293f36")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("bac2a2")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_light_color = Color("516756")
	environment.fog_density = 0.005
	world.environment = environment
	add_child(world)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -32, 0)
	sun.light_color = Color("ffddb0")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = zoom
	camera.far = 180
	camera.current = true
	add_child(camera)

func _session_changed() -> void:
	if Session.mode != previous_mode or last_match != Session.sim.match_id:
		for node in entities.values():
			node.queue_free()
		entities.clear()
		for node in resource_nodes.values():
			node.queue_free()
		resource_nodes.clear()
		camera_center = Vector2.ZERO if Session.mode != "menu" else Vector2(-5, -2)
		previous_mode = Session.mode
		last_match = Session.sim.match_id
		last_effect = Session.sim.effect_serial
		effects.clear()
		groups.clear()
		clear_selection()
	cancel_mode()

func clear_selection() -> void:
	selected.clear()
	dragging = false

func cancel_mode() -> void:
	build_mode = ""
	attack_mode = false
	rally_mode = false
	if is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null

func set_build_mode(kind: String) -> void:
	if not Session.sim.running:
		return
	var has_worker = false
	for id in selected:
		if Session.sim.units.has(id) and Session.sim.units[id].kind == "worker":
			has_worker = true
	if not has_worker:
		hud.toast("村人を選択してから建築してください。")
		return
	cancel_mode()
	build_mode = kind
	sound.cue("build")
	ghost = art.make_building(kind, TEAM[0])
	add_child(ghost)

func _process(delta: float) -> void:
	if Session.mode == "menu":
		menu_time += delta
	else:
		if not hud.help_panel.visible and not hud.address.has_focus():
			var horizontal = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
			var vertical = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
			camera_center += (Vector2(0.768, -0.64) * horizontal + Vector2(0.64, 0.768) * vertical) * zoom * 0.6 * delta
			camera_center = camera_center.clamp(Vector2(-52, -52), Vector2(52, 52))
	_update_camera()
	_sync_models(delta)
	for event in Session.sim.events:
		if event.id > last_effect:
			var visual: Dictionary = event.duplicate()
			visual.life = 0.8 if event.kind != "arrow" else 0.45
			visual.total = visual.life
			effects.append(visual)
			last_effect = event.id
	for visual in effects:
		visual.life -= delta
	effects = effects.filter(func(e): return e.life > 0)
	if is_instance_valid(ghost):
		var point = ground_point(get_viewport().get_mouse_position())
		ghost.position = Vector3(point.x, 0, point.y)
		var valid: bool = can_build_at(point)
		var color = Color(0.55, 0.9, 0.68, 0.45) if valid else Color(0.9, 0.25, 0.2, 0.45)
		for child in ghost.get_children():
			if child is MeshInstance3D:
				child.material_override = art.mat(color, true)
	for marker in markers:
		marker.life -= delta
	markers = markers.filter(func(m): return m.life > 0)
	selected = selected.filter(func(id): return Session.sim.units.has(id) and Session.sim.units[id].owner == Session.local_id)
	overlay.queue_redraw()
	if capture_path != "":
		capture_frames += 1
		if capture_frames == 40:
			_capture.call_deferred()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var error = get_viewport().get_texture().get_image().save_png(capture_path)
	print("CAPTURE_RESULT ", error, " ", capture_path)
	await _graceful_quit(error)

func _graceful_quit(code: int = 0) -> void:
	if closing:
		return
	closing = true
	sound.shutdown()
	await get_tree().create_timer(0.12).timeout
	get_tree().quit(code)

func _update_camera() -> void:
	camera.size = zoom
	var center = Vector3(camera_center.x, 0, camera_center.y)
	camera.position = center + Vector3(30, 38, 36)
	camera.look_at(center)

func _team(owner: int) -> Color:
	if owner == 0:
		return Color("9b5142")
	return TEAM[int(Session.sim.players.get(owner, {}).get("slot", 0)) % TEAM.size()]

func _sync_models(delta: float) -> void:
	var sim = Session.sim
	for id in entities.keys():
		if not sim.units.has(id) and not sim.buildings.has(id):
			entities[id].queue_free()
			entities.erase(id)
	for unit in sim.units.values():
		var model: Node3D
		if not entities.has(unit.id):
			model = art.make_unit(unit.kind, _team(unit.owner))
			add_child(model)
			model.position = Vector3(unit.p.x, 0, unit.p.y)
			entities[unit.id] = model
			model.set_meta("owner", unit.owner)
		else:
			model = entities[unit.id]
			if model.get_meta("owner", -1) != unit.owner:
				model.queue_free()
				entities.erase(unit.id)
				continue
		var goal = Vector3(unit.p.x, 0, unit.p.y)
		var moved = model.position.distance_to(goal)
		var old = model.position
		model.position = model.position.lerp(goal, minf(1.0, delta * 18.0))
		if moved > 0.01:
			var direction = goal - old
			model.rotation.y = lerp_angle(model.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 12.0))
		var body: Node3D = model.get_node("Body")
		body.position.y = absf(sin(float(unit.anim) * 9.0)) * 0.07 if moved > 0.02 else 0.0
		body.rotation.z = sin(float(unit.anim) * 16.0) * 0.12 if unit.order in ["gather", "construct"] and moved < 0.03 else 0.0
		var swing: float = clampf((sim.elapsed - unit.get("attack_at", -10.0)) / 0.3, 0, 1)
		body.rotation.x = sin(swing * PI) * 0.4
		model.get_node("Selection").visible = unit.id in selected
	for building in sim.buildings.values():
		if not entities.has(building.id):
			var model = art.make_building(building.kind, _team(1 if building.owner == 0 else building.owner))
			model.position = Vector3(building.p.x, 0, building.p.y)
			add_child(model)
			entities[building.id] = model
		entities[building.id].scale.y = maxf(0.08, building.progress)
	for resource in sim.resources.values():
		if not resource_nodes.has(resource.id):
			var model = art.make_resource(resource.kind, resource.id)
			model.position = Vector3(resource.p.x, 0, resource.p.y)
			add_child(model)
			resource_nodes[resource.id] = model
		resource_nodes[resource.id].visible = resource.amount > 0

func ground_point(screen: Vector2) -> Vector2:
	var intersect = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	if intersect == null:
		return Vector2.ZERO
	return Vector2(intersect.x, intersect.z)

func _pick_unit(screen: Vector2, enemy: bool = false) -> int:
	var best = -1
	var distance = 20.0
	for u in Session.sim.units.values():
		if enemy and u.owner != 0:
			continue
		if not enemy and u.owner != Session.local_id:
			continue
		var pos = camera.unproject_position(Vector3(u.p.x, 0.9, u.p.y))
		var d = pos.distance_to(screen)
		if d < distance:
			distance = d
			best = u.id
	return best

func _pick_resource(screen: Vector2) -> int:
	var best = -1
	var distance = 27.0
	for res in Session.sim.resources.values():
		if res.amount <= 0:
			continue
		var height = 1.8 if res.kind == "wood" else 0.5
		var projected = camera.unproject_position(Vector3(res.p.x, height, res.p.y))
		var d = projected.distance_to(screen)
		if d < distance:
			distance = d
			best = res.id
	return best

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE and Session.mode != "menu":
		camera_center -= (Vector2(0.768, -0.64) * event.relative.x + Vector2(0.64, 0.768) * event.relative.y) * zoom / 720.0
	if event is InputEventMouseMotion and dragging:
		drag_end = event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and dragging:
		drag_end = event.position
		dragging = false
		_select_rectangle(Input.is_physical_key_pressed(KEY_SHIFT))
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		sound.toggle()
		return
	if not Session.sim.running or Session.mode == "menu":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_H]:
			if build_mode != "" or attack_mode or rally_mode:
				cancel_mode()
			else:
				hud.toggle_help()
			return
	if hud.help_panel.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		var point = ground_point(event.position)
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				zoom = maxf(17, zoom - 2)
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom = minf(48, zoom + 2)
			MOUSE_BUTTON_LEFT:
				if build_mode != "":
					if can_build_at(point):
						Session.issue("build", selected, point, build_mode)
						cancel_mode()
					else:
						hud.toast("建物・資源から離し、村人の近くに設置してください。資源も確認。")
				elif rally_mode:
					Session.issue("rally", [], point)
					cancel_mode()
				elif attack_mode:
					Session.issue("attack_move", selected, point)
					markers.append({"p": point, "life": 0.8, "color": Color("e9ad73")})
					cancel_mode()
				else:
					dragging = true
					drag_start = event.position
					drag_end = event.position
					double_select = event.double_click
			MOUSE_BUTTON_RIGHT:
				if build_mode != "" or attack_mode or rally_mode:
					cancel_mode()
				else:
					_context_order(event.position, point)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_6 and event.keycode <= KEY_9:
			var slot = int(event.keycode - KEY_6)
			if event.ctrl_pressed:
				groups[slot] = selected.duplicate()
				hud.toast("部隊 %d を登録しました。" % (slot + 6))
			else:
				selected = groups.get(slot, []).filter(func(id): return Session.sim.units.has(id) and Session.sim.units[id].owner == Session.local_id)
			return
		match event.keycode:
			KEY_1: Session.issue("train", [], Vector2.ZERO, "worker")
			KEY_2: Session.issue("train", [], Vector2.ZERO, "soldier")
			KEY_3: Session.issue("train", [], Vector2.ZERO, "archer")
			KEY_B: set_build_mode("house")
			KEY_N: set_build_mode("barracks")
			KEY_T: set_build_mode("tower")
			KEY_R: Session.issue("repair")
			KEY_C: Session.issue("cancel_train")
			KEY_U: Session.issue("research", [], Vector2.ZERO, "weapons")
			KEY_L: Session.issue("research", [], Vector2.ZERO, "masonry")
			KEY_P: Session.issue("pause")
			KEY_F9: Session.issue("save")
			KEY_Y:
				cancel_mode()
				rally_mode = true
			KEY_Z:
				selected.clear()
				for u in Session.sim.units.values():
					if u.kind == "worker" and u.owner == Session.local_id and u.order == "idle":
						selected.append(u.id)
						camera_center = u.p
						break
			KEY_X: Session.issue("stop", selected)
			KEY_F: _select_kind(false)
			KEY_V: _select_kind(true)
			KEY_E:
				if not selected.is_empty():
					cancel_mode()
					attack_mode = true
			KEY_SPACE: camera_center = Vector2.ZERO
			KEY_G: Session.issue("ping", [], ground_point(get_viewport().get_mouse_position()))

func _select_rectangle(additive: bool) -> void:
	sound.cue("select")
	if not additive:
		selected.clear()
	if drag_start.distance_to(drag_end) < 6:
		var id = _pick_unit(drag_end)
		if id != -1:
			if double_select:
				for u in Session.sim.units.values():
					var screen = camera.unproject_position(Vector3(u.p.x, 1, u.p.y))
					if u.owner == Session.local_id and u.kind == Session.sim.units[id].kind and Rect2(0, 64, 1152, 440).has_point(screen) and u.id not in selected:
						selected.append(u.id)
			if additive and id in selected:
				selected.erase(id)
			elif id not in selected:
				selected.append(id)
		return
	var rect = Rect2(drag_start, drag_end - drag_start).abs()
	for u in Session.sim.units.values():
		if u.owner != Session.local_id:
			continue
		if rect.has_point(camera.unproject_position(Vector3(u.p.x, 0.7, u.p.y))) and u.id not in selected:
			selected.append(u.id)

func _select_kind(workers: bool) -> void:
	sound.cue("select")
	selected.clear()
	for u in Session.sim.units.values():
		if u.owner == Session.local_id and (u.kind == "worker") == workers:
			selected.append(u.id)

func _context_order(screen: Vector2, pos: Vector2) -> void:
	sound.cue("order")
	var target = _pick_unit(screen, true)
	if target != -1:
		Session.issue("attack", selected, pos, str(target))
	else:
		var resource = _pick_resource(screen)
		var has_worker = false
		for id in selected:
			if Session.sim.units.has(id) and Session.sim.units[id].kind == "worker":
				has_worker = true
		if resource != -1 and has_worker:
			Session.issue("gather", selected, pos, str(resource))
		else:
			Session.issue("move", selected, pos)
	markers.append({"p": pos, "life": 0.8, "color": Color("a3d0ac")})

func _draw_overlay() -> void:
	if Session.mode in ["menu", "connecting"]:
		return
	if dragging and drag_start.distance_to(drag_end) >= 6:
		var rect = Rect2(drag_start, drag_end - drag_start).abs()
		overlay.draw_rect(rect, Color(0.6, 0.85, 0.7, 0.12))
		overlay.draw_rect(rect, Color("a8d4b6"), false, 1.0)
	for visual in effects:
		var from: Vector2 = visual.from
		var to: Vector2 = visual.to
		var progress: float = 1.0 - visual.life / visual.total
		var start = camera.unproject_position(Vector3(from.x, 1.5, from.y))
		var end = camera.unproject_position(Vector3(to.x, 0.9, to.y))
		if end.y < 65 or end.y > 500:
			continue
		var color = Color("ef9c72") if visual.hostile else Color("f4df9b")
		color.a = minf(1, visual.life * 4)
		if visual.kind == "arrow":
			var point = start.lerp(end, minf(progress * 1.5, 1)) + Vector2(0, -sin(minf(progress * 1.5, 1) * PI) * 20)
			overlay.draw_line(point, point - (end - start).normalized() * 8, color, 2)
		elif visual.kind == "hit":
			if progress < 0.35:
				overlay.draw_line(end + Vector2(-4, -4), end + Vector2(4, 4), color, 1)
				overlay.draw_line(end + Vector2(4, -4), end + Vector2(-4, 4), color, 1)
		elif visual.kind == "death":
			overlay.draw_arc(end, 8 + progress * 12, 0, TAU, 12, color, 1)
		else:
			overlay.draw_arc(end, 6 + progress * 18, 0, TAU, 20, Color(0.5, 0.9, 0.7, color.a), 1)
		if visual.amount > 0 and progress > 0.2:
			overlay.draw_string(hud.root.get_theme_default_font(), end + Vector2(-6, -8 - progress * 28), str(int(visual.amount)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	var rally_point: Vector2 = Session.sim.rally
	var rally_screen = camera.unproject_position(Vector3(rally_point.x, 0.2, rally_point.y))
	if rally_screen.y > 64 and rally_screen.y < 500:
		overlay.draw_line(rally_screen, rally_screen + Vector2(0, -22), Color("e5ba74"), 1)
		overlay.draw_colored_polygon(PackedVector2Array([rally_screen + Vector2(0, -22), rally_screen + Vector2(12, -18), rally_screen + Vector2(0, -14)]), Color("e5ba74"))
	for res in Session.sim.resources.values():
		if res.amount <= 0 or res.kind == "wood":
			continue
		var rp = camera.unproject_position(Vector3(res.p.x, 2.4, res.p.y))
		if Rect2(0, 145, 1152, 350).has_point(rp):
			overlay.draw_style_box(hud._style(Color("142a24"), Color("b5a765")), Rect2(rp - Vector2(17, 14), Vector2(42, 19)))
			overlay.draw_string(hud.root.get_theme_default_font(), rp + Vector2(-12, 0), "畑" if res.kind == "food" else "金鉱", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ffe092"))
	for u in Session.sim.units.values():
		if u.owner != 0:
			var marker = camera.unproject_position(Vector3(u.p.x, 2.2, u.p.y))
			if Rect2(0, 145, 1152, 350).has_point(marker):
				overlay.draw_string(hud.root.get_theme_default_font(), marker + Vector2(-5, -3), {"worker": "農", "soldier": "剣", "archer": "弓"}.get(u.kind, ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, {"worker": Color("ffe092"), "soldier": Color("e7f2ff"), "archer": Color("a2edb1")}.get(u.kind, Color.WHITE))
		if u.id not in selected and u.hp >= u.max_hp:
			continue
		var pos = camera.unproject_position(Vector3(u.p.x, 1.9 if u.kind != "brute" else 2.7, u.p.y))
		_bar(pos, u.hp / u.max_hp, 25.0, Color("bacc88") if u.owner != 0 else Color("d47b61"))
	for b in Session.sim.buildings.values():
		if b.hp >= b.max_hp and b.progress >= 1.0 and b.kind != "hall":
			continue
		var pos = camera.unproject_position(Vector3(b.p.x, 5.8 if b.kind == "hall" else 4.9, b.p.y))
		_bar(pos, b.progress if b.progress < 1.0 else b.hp / b.max_hp, 56, Color("e0bd7b"))
	for marker in markers:
		var p: Vector2 = marker.p
		var pos = camera.unproject_position(Vector3(p.x, 0.1, p.y))
		var radius = 9.0 + sin(marker.life * 9.0) * 3.0
		overlay.draw_arc(pos, radius, 0, TAU, 20, marker.color, 1.5)
		overlay.draw_line(pos + Vector2(-5, 0), pos + Vector2(5, 0), marker.color)
		overlay.draw_line(pos + Vector2(0, -5), pos + Vector2(0, 5), marker.color)

func _bar(pos: Vector2, ratio: float, width: float, color: Color) -> void:
	if pos.y < 70 or pos.y > 500:
		return
	var rect = Rect2(pos - Vector2(width / 2, 0), Vector2(width, 4))
	overlay.draw_rect(rect.grow(1), Color("172c25"))
	overlay.draw_rect(Rect2(rect.position, Vector2(width * clampf(ratio, 0, 1), 4)), color)

func can_build_at(point: Vector2) -> bool:
	if build_mode == "" or not Session.sim.valid_site(build_mode, point) or not Session.sim.can_afford(Session.sim.BUILD_DATA[build_mode].cost):
		return false
	for id in selected:
		if Session.sim.units.has(id) and Session.sim.units[id].kind == "worker" and Session.sim.units[id].p.distance_to(point) < 14.0:
			return true
	return false

func _showcase() -> void:
	# A reproducible screenshot scene; normal matches always start with the standard economy.
	Session.solo()
	Session.allow_autosave = false
	var sim = Session.sim
	sim._spawn_building("house", Vector2(-4, 6), 1, true)
	sim._spawn_building("tower", Vector2(-6, -5), 1, true)
	sim._spawn_building("house", Vector2(9, 8), 1, true)
	sim._spawn_building("tower", Vector2(6, -5), 1, true)
	for i in range(5):
		sim.spawn_unit("soldier", Vector2(-4 + i * 1.5, -8), 1)
	for i in range(4):
		sim.spawn_unit("archer", Vector2(-3 + i * 1.5, -5), 1)
	for i in range(6):
		sim.spawn_unit("raider", Vector2(-7 + i * 1.5, -15), 0)
	sim.spawn_unit("slinger", Vector2(-3, -16), 0)
	sim.spawn_unit("warlord", Vector2(3, -15), 0)
	sim.upgrades.weapons = true
	sim.command(1, "train", [], Vector2.ZERO, "soldier")
	sim.command(1, "train", [], Vector2.ZERO, "archer")
	sim.wave = 6
	sim.elapsed = 422
	sim.next_wave = 99999
	sim.stats.gathered = 245
	sim.stats.trained = 8
	sim.stats.built = 4
	_select_kind(false)
	camera_center = Vector2(0, -1)
	zoom = 30
