extends Control

signal navigated(pos: Vector2)
var sim
var camera_center = Vector2.ZERO

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "クリックで視点を移動"

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		navigated.emit((event.position / size - Vector2.ONE * 0.5) * 80.0)
		accept_event()

func _point(pos: Vector2) -> Vector2:
	return (pos / 80.0 + Vector2.ONE * 0.5) * size

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("283c33"))
	for i in range(1, 4):
		draw_line(Vector2(size.x * i / 4, 0), Vector2(size.x * i / 4, size.y), Color("34473b"))
		draw_line(Vector2(0, size.y * i / 4), Vector2(size.x, size.y * i / 4), Color("34473b"))
	if sim == null:
		return
	for res in sim.resources.values():
		if res.amount <= 0:
			continue
		var color = Color("6f8b55") if res.kind == "wood" else Color("d0b779") if res.kind == "gold" else Color("b47f57")
		draw_circle(_point(res.p), 1.5, color)
	for b in sim.buildings.values():
		draw_rect(Rect2(_point(b.p) - Vector2(3, 3), Vector2(6, 6)), Color("d8c89d"))
	for u in sim.units.values():
		var color = Color("df765e") if u.owner == 0 else Color("94cfb6")
		draw_circle(_point(u.p), 1.5 if u.owner else 2.0, color)
	var center = _point(camera_center)
	var points = PackedVector2Array([center + Vector2(0, -21), center + Vector2(31, 0), center + Vector2(0, 21), center + Vector2(-31, 0), center + Vector2(0, -21)])
	draw_polyline(points, Color("e8d6a6"), 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color("73836b"), false, 1.0)
