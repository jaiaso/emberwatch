extends CanvasLayer

const MiniMap = preload("res://scripts/minimap.gd")
const CREAM = Color("e4d8b7")
const MUTED = Color("91a296")
const GOLD = Color("e0b973")
var game
var root: Control
var menu: Panel
var play_ui: Control
var lobby: Panel
var help_panel: Panel
var outcome: Panel
var menu_status: Label
var lobby_status: Label
var start_button: Button
var address: LineEdit
var resources_label: Label
var wave_label: Label
var time_label: Label
var selection_label: Label
var task_label: Label
var hp_label: Label
var toast_label: Label
var mode_label: Label
var minimap
var outcome_title: Label
var outcome_body: Label
var toast_left = 0.0
var last_event = -1
var buttons: Dictionary = {}
var audio_button: Button
var host_ips = "127.0.0.1"

func setup(controller) -> void:
	game = controller
	layer = 3
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme = Theme.new()
	var font = FontVariation.new()
	font.base_font = load("res://assets/NotoSansJP.ttf")
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 550.0}
	theme.default_font = font
	theme.default_font_size = 14
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_hover_color", "Button", Color("fff0c7"))
	theme.set_color("font_disabled_color", "Button", Color("617367"))
	theme.set_stylebox("normal", "Button", _style(Color("243c35"), Color("5a7160")))
	theme.set_stylebox("hover", "Button", _style(Color("355148"), GOLD))
	theme.set_stylebox("pressed", "Button", _style(Color("526952"), GOLD))
	theme.set_stylebox("disabled", "Button", _style(Color("1b2c27"), Color("34493d")))
	theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), GOLD))
	theme.set_stylebox("normal", "LineEdit", _style(Color("10251f"), Color("687f68")))
	theme.set_color("font_color", "LineEdit", CREAM)
	theme.set_color("caret_color", "LineEdit", GOLD)
	root.theme = theme
	add_child(root)
	_make_title()
	_make_play_ui()
	_make_lobby()
	_make_help()
	_make_outcome()
	audio_button = _button(root, "音 [M]", Rect2(908, 14, 80, 35), func(): game.sound.toggle())
	Session.changed.connect(refresh_mode)
	Session.message.connect(toast)
	refresh_mode()

func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _panel(parent: Node, rect: Rect2, color: Color = Color("142a24")) -> Panel:
	var p = Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", _style(color, Color("63735c")))
	parent.add_child(p)
	return p

func _label(parent: Node, text: String, pos: Vector2, font_size: int = 14, color: Color = CREAM) -> Label:
	var label = Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var button = Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	if primary:
		button.add_theme_stylebox_override("normal", _style(Color("9b7447"), Color("d9b17a")))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _make_title() -> void:
	menu = _panel(root, Rect2(42, 86, 428, 572), Color(0.055, 0.12, 0.105, 0.97))
	_label(menu, "A  C O O P E R A T I V E  S U R V I V A L  R T S", Vector2(28, 25), 11, GOLD)
	_label(menu, "EMBERWATCH", Vector2(25, 54), 39)
	_label(menu, "灰 の 砦", Vector2(29, 112), 23, GOLD)
	_label(menu, "火を絶やすな。仲間と夜明けを迎えろ。", Vector2(29, 168), 15)
	_label(menu, "資源を集め、村を築き、部隊を率いる。\n6回の襲撃から、ひとつの砦を守り抜く。", Vector2(29, 208), 14, MUTED)
	_button(menu, "ひとりで出陣", Rect2(28, 282, 372, 46), func(): Session.solo(), true)
	_button(menu, "協力プレイの部屋を作る", Rect2(28, 340, 372, 42), func(): Session.host())
	address = LineEdit.new()
	address.text = "127.0.0.1"
	address.placeholder_text = "ホストのIPアドレス"
	address.position = Vector2(28, 394)
	address.size = Vector2(225, 40)
	menu.add_child(address)
	_button(menu, "部屋に参加", Rect2(263, 394, 137, 40), func(): Session.join(address.text))
	menu_status = _label(menu, "", Vector2(28, 449), 12, GOLD)
	menu_status.size.x = 373
	menu_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(menu, "1–4 PLAYERS     /     LAN & DIRECT IP", Vector2(29, 509), 12, MUTED)
	_label(menu, "LOW POLY · SHARED RESOURCES · ONE LAST STAND", Vector2(29, 535), 10, MUTED)
	_label(menu, "", Vector2.ZERO)

func _make_play_ui() -> void:
	play_ui = Control.new()
	play_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(play_ui)
	_panel(play_ui, Rect2(0, 0, 1152, 64), Color("11261f"))
	_label(play_ui, "EMBERWATCH", Vector2(22, 9), 21)
	_label(play_ui, "灰の砦  /  CO-OP DEFENSE", Vector2(24, 39), 10, MUTED)
	resources_label = _label(play_ui, "", Vector2(302, 20), 18)
	_button(play_ui, "操作 [H]", Rect2(1000, 14, 128, 35), toggle_help)
	var objective_bg = _panel(play_ui, Rect2(13, 77, 324, 65), Color(0.05, 0.12, 0.10, 0.87))
	objective_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(play_ui, "共同目標", Vector2(24, 87), 11, GOLD)
	_label(play_ui, "中央砦を守り、6回の襲撃を撃退", Vector2(24, 109), 16)
	var wave_bg = _panel(play_ui, Rect2(882, 77, 246, 65), Color(0.05, 0.12, 0.10, 0.87))
	wave_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_label = _label(play_ui, "", Vector2(896, 85), 17, GOLD)
	time_label = _label(play_ui, "", Vector2(896, 113), 12, MUTED)
	toast_label = _label(play_ui, "", Vector2(320, 484), 15, GOLD)
	toast_label.size = Vector2(650, 32)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_stylebox_override("normal", _style(Color(0.05, 0.12, 0.10, 0.91), Color("6d7a59")))
	mode_label = _label(play_ui, "", Vector2(325, 450), 15, GOLD)
	_panel(play_ui, Rect2(0, 530, 1152, 190), Color("11261f"))
	minimap = MiniMap.new()
	minimap.position = Vector2(20, 542)
	minimap.size = Vector2(164, 164)
	minimap.sim = Session.sim
	minimap.navigated.connect(func(pos): game.camera_center = pos)
	play_ui.add_child(minimap)
	selection_label = _label(play_ui, "部隊を選択", Vector2(207, 542), 18)
	task_label = _label(play_ui, "ドラッグで複数選択 / 右クリックで指示", Vector2(208, 574), 11, MUTED)
	var train = [["worker", "[1] 村人", "食料45"], ["soldier", "[2] 剣士", "食料55 / 金20"], ["archer", "[3] 弓兵", "木45 / 金25"]]
	for i in range(train.size()):
		var entry: Array = train[i]
		var key: String = entry[0]
		buttons[key] = _button(play_ui, entry[1], Rect2(207 + i * 156, 602, 146, 38), func(): Session.issue("train", [], Vector2.ZERO, key))
		buttons[key].tooltip_text = entry[2] + " / 自分の部隊として生産（共有施設）"
	var builds = [["house", "[B] 家 +10", "木70 / 人口上限+10"], ["barracks", "[N] 兵舎", "木150 / 金30 / 兵士の生産施設"], ["tower", "[T] 監視塔", "木110 / 金60 / 周囲の敵を自動攻撃"]]
	for i in range(builds.size()):
		var entry: Array = builds[i]
		var key: String = entry[0]
		buttons[key] = _button(play_ui, entry[1], Rect2(207 + i * 156, 653, 146, 38), func(): game.set_build_mode(key))
		buttons[key].tooltip_text = entry[2] + " / 村人を選択して設置"
	_panel(play_ui, Rect2(696, 544, 1, 160), Color("4d6652"))
	hp_label = _label(play_ui, "", Vector2(718, 545), 16, GOLD)
	_button(play_ui, "[R] 砦を修復 · 木60", Rect2(719, 578, 216, 34), func(): Session.issue("repair"))
	_label(play_ui, "[E] 進軍攻撃  [X] 停止\n[F] 全兵士  [V] 全村人\n[Space] 砦へ  [G] 合図", Vector2(718, 624), 12, MUTED)
	_label(play_ui, "THE LAST LIGHT", Vector2(973, 552), 12, GOLD)
	_label(play_ui, "村人を資源へ右クリック\n採集した資源は全員で共有\n家で人口を増やし、増兵\n塔を建てて迎え撃とう", Vector2(973, 583), 11, MUTED)
	_label(play_ui, "WASD 移動 / ホイール 拡縮", Vector2(973, 686), 10, MUTED)

func _make_lobby() -> void:
	lobby = _panel(root, Rect2(350, 183, 452, 301), Color(0.05, 0.12, 0.10, 0.98))
	_label(lobby, "集 結 の 時", Vector2(28, 24), 25, GOLD)
	_label(lobby, "最大4人で、ひとつの砦を守る。", Vector2(28, 77), 15)
	lobby_status = _label(lobby, "", Vector2(28, 115), 13, MUTED)
	lobby_status.size = Vector2(398, 70)
	lobby_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_button = _button(lobby, "全員で出陣", Rect2(28, 208, 248, 43), func(): Session.start(), true)
	_button(lobby, "タイトルへ", Rect2(290, 208, 135, 43), func(): Session.back_to_menu())
	_label(lobby, "UDP 27840 · 途中参加可能 · 資源と砦は共有", Vector2(28, 268), 11, MUTED)

func _make_help() -> void:
	help_panel = _panel(root, Rect2(263, 102, 626, 507), Color(0.05, 0.12, 0.10, 0.99))
	_label(help_panel, "指 揮 官 の 手 引 き", Vector2(28, 23), 24, GOLD)
	_label(help_panel, "左クリック / ドラッグ      自分の部隊を選択（Shiftで追加）\n右クリック                        移動 / 敵を攻撃 / 村人で資源を採集\nWASD / 矢印                     カメラ移動\nホイール / Space             拡大縮小 / 中央砦に戻る\n1 / 2 / 3                             村人 / 剣士 / 弓兵を生産\nB / N / T                             家 / 兵舎 / 監視塔を設置\nE → 地面をクリック        敵を迎撃しながら進軍\nX / F / V                              停止 / 全兵士選択 / 全村人選択\nR / G                                   砦を修復 / カーソル位置に合図\nEsc                                       建築取消 / メニューを閉じる", Vector2(29, 87), 14)
	_label(help_panel, "最初の一手：Vで村人を選び、木や果実を右クリック。\n6波目の敵を倒せば勝利。中央砦が壊れると全員敗北。\nオンライン中も時間は進みます。", Vector2(29, 354), 12, MUTED)
	_button(help_panel, "戦場へ戻る", Rect2(29, 444, 273, 38), toggle_help, true)
	_button(help_panel, "タイトルへ戻る（退出）", Rect2(318, 444, 279, 38), func(): help_panel.hide(); Session.back_to_menu())
	help_panel.hide()

func _make_outcome() -> void:
	outcome = _panel(root, Rect2(326, 185, 500, 296), Color(0.05, 0.12, 0.10, 0.98))
	outcome_title = _label(outcome, "", Vector2(32, 24), 30, GOLD)
	outcome_body = _label(outcome, "", Vector2(32, 95), 15)
	_button(outcome, "タイトルへ戻る", Rect2(32, 220, 436, 43), func(): Session.back_to_menu(), true)
	outcome.hide()

func toggle_help() -> void:
	help_panel.visible = not help_panel.visible
	game.cancel_mode()

func refresh_mode() -> void:
	if Session.mode == "host":
		var ips: Array = []
		for ip in IP.get_local_addresses():
			if ":" not in ip and not ip.begins_with("127.") and not ip.begins_with("169.254."):
				ips.append(ip)
		host_ips = ", ".join(ips) if not ips.is_empty() else "127.0.0.1"
	var active = Session.mode in ["solo", "host", "client"]
	menu.visible = Session.mode in ["menu", "connecting"]
	menu_status.text = Session.status
	play_ui.visible = active
	lobby.visible = Session.mode in ["host", "client"] and not Session.sim.running and Session.sim.result == ""
	start_button.visible = Session.mode == "host"
	outcome.visible = active and Session.sim.result != ""
	if not active:
		help_panel.hide()
		last_event = -1
	if outcome.visible:
		outcome_title.text = "夜明けの勝利" if Session.sim.result == "victory" else "砦、陥落"
		outcome_body.text = "%s\n\n撃退した襲撃：%d / 6    経過時間：%d分%02d秒" % [Session.sim.event_text, Session.sim.wave, int(Session.sim.elapsed) / 60, int(Session.sim.elapsed) % 60]
	game.clear_selection()

func toast(text: String) -> void:
	toast_label.text = text
	toast_left = 4.5

func _process(delta: float) -> void:
	if game == null:
		return
	var sim = Session.sim
	audio_button.text = "消音 [M]" if game.sound.muted else "音 [M]"
	if sim.result != "" and not outcome.visible:
		refresh_mode()
	resources_label.text = "食料 %d     木材 %d     金 %d     人口 %d/%d" % [sim.stock.get("food", 0), sim.stock.get("wood", 0), sim.stock.get("gold", 0), sim.population(), sim.capacity()]
	wave_label.text = "襲撃  %02d / 06" % sim.wave
	time_label.text = "次の襲撃まで %02d:%02d" % [int(maxf(0, sim.next_wave - sim.elapsed)) / 60, int(maxf(0, sim.next_wave - sim.elapsed)) % 60] if sim.wave < 6 else "最後の敵を撃退せよ"
	var hall: Dictionary = sim.buildings.get(1, {})
	hp_label.text = "中央砦  %d / 1500" % int(maxf(0, hall.get("hp", 0)))
	var counts = {"worker": 0, "soldier": 0, "archer": 0}
	for id in game.selected:
		if sim.units.has(id):
			var kind: String = sim.units[id].kind
			counts[kind] = int(counts.get(kind, 0)) + 1
	selection_label.text = "部隊を選択" if game.selected.is_empty() else "%d 部隊  /  村人%d  剣士%d  弓兵%d" % [game.selected.size(), counts.worker, counts.soldier, counts.archer]
	task_label.text = "自軍：%s  /  %d人で防衛中  /  共有資源" % [sim.players.get(Session.local_id, {}).get("name", "接続中"), sim.players.size()]
	for key in ["house", "barracks", "tower"]:
		buttons[key].disabled = counts.worker == 0 or not sim.running
	minimap.camera_center = game.camera_center
	minimap.queue_redraw()
	lobby_status.text = "%d / 4 人が集結\n%s" % [sim.players.size(), Session.status]
	if Session.mode == "host":
		lobby_status.text += "\n招待用IP：" + host_ips
	mode_label.text = ""
	if game.build_mode != "":
		mode_label.text = "建築位置をクリック  /  右クリック・Escで取消"
	elif game.attack_mode:
		mode_label.text = "進軍先をクリック  /  敵を迎撃しながら移動"
	if sim.event_serial != last_event and sim.running:
		last_event = sim.event_serial
		toast(sim.event_text)
	toast_left = maxf(0.0, toast_left - delta)
	toast_label.modulate.a = minf(1, toast_left)
