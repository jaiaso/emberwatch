extends Control

signal navigated(pos: Vector2)
var sim
var camera_center = Vector2.ZERO

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "クリックで視点を移動"

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		navigated.emit((event.position / size - Vector2.ONE * 0.5) * 120.0)
		accept_event()

func _point(pos: Vector2) -> Vector2:
	return (pos / 120.0 + Vector2.ONE * 0.5) * size

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("283c33"))
	for i in range(1, 4):
		draw_line(Vector2(size.x * i / 4, 0), Vector2(size.x * i / 4, size.y), Color("34473b"))
		draw_line(Vector2(0, size.y * i / 4), Vector2(size.x, size.y * i / 4), Color("34473b"))
	if sim == null:
		return
	for cliff in sim.Terrain.CLIFFS:
		draw_rect(Rect2(_point(cliff.position), cliff.size / 120.0 * size), Color("a2a096"))
	for res in sim.resources.values():
		if res.amount <= 0:
			continue
		var color = Color("6f8b55") if res.kind == "wood" else Color("ffdc38") if res.kind == "gold" else Color("e7cc66")
		draw_circle(_point(res.p), 1.5, color)
	for b in sim.buildings.values():
		draw_rect(Rect2(_point(b.p) - Vector2(3, 3), Vector2(6, 6)), Color("d8c89d"))
	for u in sim.units.values():
		var color = Color("df765e") if u.owner == 0 else Color("94cfb6")
		draw_circle(_point(u.p), 1.5 if u.owner else 2.0, color)
	var incoming: Dictionary = sim.incoming_attack()
	if not incoming.is_empty():
		var source = _point(incoming.origin)
		var heading = (_point(Vector2.ZERO) - source).normalized()
		var tip = source + heading * 16.0
		var wing = heading.orthogonal() * 4.5
		var pulse = 0.65 + 0.35 * sin(Time.get_ticks_msec() / 260.0)
		var warning = Color(1.0, 0.71, 0.28, pulse)
		draw_circle(source, 7.0, Color(0.07, 0.10, 0.08, 0.95))
		draw_arc(source, 7.0, 0, TAU, 28, warning, 2.0)
		draw_line(source, tip, warning, 2.5)
		draw_colored_polygon(PackedVector2Array([tip, tip - heading * 7 + wing, tip - heading * 7 - wing]), warning)
		var label_pos = (source + Vector2(9, -8)).clamp(Vector2(2, 13), size - Vector2(36, 3))
		draw_string(get_theme_default_font(), label_pos, incoming.direction, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ffe0a0"))
	var center = _point(camera_center)
	var points = PackedVector2Array([center + Vector2(0, -21), center + Vector2(31, 0), center + Vector2(0, 21), center + Vector2(-31, 0), center + Vector2(0, -21)])
	draw_polyline(points, Color("e8d6a6"), 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color("73836b"), false, 1.0)
