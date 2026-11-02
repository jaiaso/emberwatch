extends RefCounted
## Client rectangle fitted inside the usable desktop, including OS decorations.
const BASE = Vector2i(1152,720)
const MARGIN = 12

static func fitted_rect(usable: Rect2i, decorations: Vector2i, client_offset: Vector2i) -> Rect2i:
	var available = usable.size - decorations - Vector2i.ONE * MARGIN * 2
	var scale_value = minf(1.0,minf(float(maxi(1,available.x))/BASE.x,float(maxi(1,available.y))/BASE.y))
	var client = Vector2i(maxi(1,floori(BASE.x*scale_value)),maxi(1,floori(BASE.y*scale_value)))
	var outer = client + decorations
	return Rect2i(usable.position + (usable.size-outer)/2 + client_offset,client)

static func fit(window: Window) -> void:
	if DisplayServer.get_name()=="headless" or window.mode!=Window.MODE_WINDOWED:
		return
	var usable = DisplayServer.screen_get_usable_rect(window.current_screen)
	if usable.size.x<=0 or usable.size.y<=0:
		return
	var frame_size = DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
	frame_size = Vector2i(maxi(0,frame_size.x),maxi(0,frame_size.y))
	var offset = DisplayServer.window_get_position() - DisplayServer.window_get_position_with_decorations()
	var rect = fitted_rect(usable,frame_size,offset)
	window.min_size = Vector2i(mini(576,rect.size.x),mini(360,rect.size.y))
	window.size = rect.size
	window.position = rect.position
