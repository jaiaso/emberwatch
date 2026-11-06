extends RefCounted
## Shared collision, rendering and minimap geometry. Gaps remain traversable.
const HALF = 59.0
const CLIFFS = [Rect2(-30, -23, 8, 18), Rect2(22, 5, 8, 18),
	Rect2(-16, 28, 22, 7), Rect2(-6, -35, 22, 7)]

static func blocked(pos: Vector2, margin: float = 0.55) -> bool:
	for cliff in CLIFFS:
		if cliff.grow(margin).has_point(pos):
			return true
	return false

static func crosses(a: Vector2, b: Vector2) -> bool:
	var min_x = minf(a.x, b.x)
	var max_x = maxf(a.x, b.x)
	var min_y = minf(a.y, b.y)
	var max_y = maxf(a.y, b.y)
	for cliff in CLIFFS:
		var rect: Rect2 = cliff.grow(0.55)
		if max_x < rect.position.x or min_x > rect.end.x or max_y < rect.position.y or min_y > rect.end.y:
			continue
		if rect.has_point(a) or rect.has_point(b):
			return true
		var corners = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		for i in range(4):
			if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null:
				return true
	return false
