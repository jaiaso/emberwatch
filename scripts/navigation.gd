extends RefCounted
## Static building obstacles use A*. Moving armies use local separation.
var grid = AStarGrid2D.new()
var signature = ""
var version = 0

func rebuild(buildings: Dictionary, definitions: Dictionary) -> void:
	var next_signature = str(buildings.keys())
	if next_signature == signature:
		return
	signature = next_signature
	version += 1
	grid.region = Rect2i(-19, -19, 38, 38)
	grid.cell_size = Vector2(2, 2)
	grid.offset = Vector2(1, 1)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	grid.fill_solid_region(grid.region, false)
	for b in buildings.values():
		var radius: float = definitions[b.kind].radius + 0.8
		for x in range(-19, 19):
			for y in range(-19, 19):
				var cell = Vector2i(x, y)
				if grid.get_point_position(cell).distance_to(b.p) < radius:
					grid.set_point_solid(cell, true)

func _cell(pos: Vector2) -> Vector2i:
	var candidate = Vector2i(floori(pos.x / 2), floori(pos.y / 2)).clamp(Vector2i(-19, -19), Vector2i(18, 18))
	if not grid.is_point_solid(candidate):
		return candidate
	var best = candidate
	var distance = INF
	for x in range(candidate.x - 4, candidate.x + 5):
		for y in range(candidate.y - 4, candidate.y + 5):
			var point = Vector2i(x, y)
			if not grid.is_in_boundsv(point) or grid.is_point_solid(point):
				continue
			var d = grid.get_point_position(point).distance_squared_to(pos)
			if d < distance:
				distance = d
				best = point
	return best

func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	return grid.get_point_path(_cell(from), _cell(to), false)
