extends CanvasLayer

const MiniMap = preload("res://scripts/minimap.gd")
const Sim = preload("res://scripts/simulation.gd")
const CREAM = Color("e4d8b7")
const MUTED = Color("91a296")
const GOLD = Color("e0b973")
const NAMES = {"worker": "村人", "soldier": "剣士", "archer": "弓兵"}
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
var difficulty: OptionButton
var continue_button: Button
var tabs: Array = []
var tab_buttons: Array = []
var active_tab = 0
var queue_label: Label
var queue_bar: ProgressBar
var hp_bar: ProgressBar
var tutorial: Label
var tutorial_panel: Panel
var paused_label: Label
var boss_panel: Panel
var boss_label: Label
var boss_bar: ProgressBar
var rematch_button: Button
var bonus_panel: Panel
var bonus_title: Label
var bonus_summary: Label
var paused_by_help = false

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
	theme.set_color("font_disabled_color", "Button", Color("64786a"))
	for entry in [["normal", "243c35", "5a7160"], ["hover", "355148", "e0b973"], ["pressed", "526952", "e0b973"], ["disabled", "1b2c27", "34493d"]]:
		theme.set_stylebox(entry[0], "Button", _style(Color(entry[1]), Color(entry[2])))
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
	_make_bonus()
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

func _bar(parent: Node, rect: Rect2, color: Color) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.position = rect.position
	bar.size = rect.size
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.add_theme_font_size_override("font_size", 1)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background = _style(Color("24382b"), Color("4a6049"))
	var fill = _style(color, color)
	for style in [background, fill]:
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		style.content_margin_left = 0
		style.content_margin_right = 0
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	bar.size = rect.size
	return bar

func _make_title() -> void:
	menu = _panel(root, Rect2(42, 48, 428, 624), Color(0.055, 0.12, 0.105, 0.98))
	_label(menu, "A  C O O P E R A T I V E  S U R V I V A L  R T S", Vector2(28, 25), 11, GOLD)
	_label(menu, "EMBERWATCH", Vector2(25, 52), 39)
	_label(menu, "灰 の 砦", Vector2(29, 109), 23, GOLD)
	_label(menu, "火を絶やすな。仲間と夜明けを迎えろ。", Vector2(29, 159), 15)
	_label(menu, "村を築き、部隊を率い、6回の襲撃を防ぐ。\n最後の夜には、敵の指揮官が待ち受ける。", Vector2(29, 198), 13, MUTED)
	_label(menu, "難易度", Vector2(29, 250), 13, GOLD)
	difficulty = OptionButton.new()
	difficulty.position = Vector2(120, 241)
	difficulty.size = Vector2(280, 37)
	difficulty.focus_mode = Control.FOCUS_NONE
	for name in Sim.DIFFICULTIES:
		difficulty.add_item(name)
	difficulty.select(1)
	menu.add_child(difficulty)
	_button(menu, "ひとりで出陣", Rect2(28, 294, 232, 44), func(): Session.solo(difficulty.selected), true)
	continue_button = _button(menu, "続きから", Rect2(272, 294, 128, 44), func(): Session.continue_game())
	continue_button.tooltip_text = "ソロのセーブを再開。襲撃の撃退後に自動保存します。"
	_button(menu, "協力プレイの部屋を作る", Rect2(28, 352, 372, 42), func(): Session.host(difficulty.selected))
	address = LineEdit.new()
	address.text = "127.0.0.1"
	address.placeholder_text = "ホストのIPアドレス"
	address.position = Vector2(28, 408)
	address.size = Vector2(225, 40)
	menu.add_child(address)
	_button(menu, "部屋に参加", Rect2(263, 408, 137, 40), func(): Session.join(address.text))
	menu_status = _label(menu, "", Vector2(28, 465), 12, GOLD)
	menu_status.size = Vector2(373, 56)
	menu_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(menu, "1–4 PLAYERS    /    SHARED RESOURCES", Vector2(29, 546), 11, MUTED)
	_label(menu, "VERSION 1.1.0     —     峡谷と実り", Vector2(29, 577), 12, GOLD)

func _make_play_ui() -> void:
	play_ui = Control.new()
	play_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(play_ui)
	_panel(play_ui, Rect2(0, 0, 1152, 64), Color("11261f"))
	_label(play_ui, "EMBERWATCH", Vector2(22, 9), 21)
	_label(play_ui, "灰の砦  /  VERSION 1.1.0", Vector2(24, 39), 10, MUTED)
	resources_label = _label(play_ui, "", Vector2(279, 20), 17)
	_button(play_ui, "操作 [H]", Rect2(1000, 14, 128, 35), toggle_help)
	var objective_bg = _panel(play_ui, Rect2(13, 77, 324, 65), Color(0.05, 0.12, 0.10, 0.90))
	objective_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(play_ui, "共同目標", Vector2(24, 87), 11, GOLD)
	_label(play_ui, "中央砦を守り、6回の襲撃を撃退", Vector2(24, 109), 16)
	var wave_bg = _panel(play_ui, Rect2(882, 77, 246, 65), Color(0.05, 0.12, 0.10, 0.90))
	wave_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_label = _label(play_ui, "", Vector2(896, 85), 17, GOLD)
	time_label = _label(play_ui, "", Vector2(896, 113), 11, MUTED)
	tutorial_panel = _panel(play_ui, Rect2(13, 153, 302, 99), Color(0.05, 0.12, 0.10, 0.84))
	tutorial_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial = _label(tutorial_panel, "", Vector2(11, 9), 12, CREAM)
	boss_panel = _panel(play_ui, Rect2(386, 77, 374, 65), Color(0.16, 0.10, 0.08, 0.94))
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_label = _label(boss_panel, "", Vector2(12, 7), 14, GOLD)
	boss_bar = _bar(boss_panel, Rect2(12, 39, 350, 10), Color("b56748"))
	toast_label = _label(play_ui, "", Vector2(320, 465), 15, GOLD)
	toast_label.size = Vector2(650, 30)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_stylebox_override("normal", _style(Color(0.05, 0.12, 0.10, 0.93), Color("6d7a59")))
	mode_label = _label(play_ui, "", Vector2(325, 432), 14, GOLD)
	paused_label = _label(play_ui, "一時停止中  —  [P] で再開", Vector2(405, 260), 21, GOLD)
	paused_label.add_theme_stylebox_override("normal", _style(Color("142a24"), GOLD))
	_panel(play_ui, Rect2(0, 504, 1152, 216), Color("11261f"))
	_label(play_ui, "戦場図 / クリックで移動", Vector2(19, 513), 10, MUTED)
	minimap = MiniMap.new()
	minimap.position = Vector2(18, 537)
	minimap.size = Vector2(164, 164)
	minimap.sim = Session.sim
	minimap.navigated.connect(func(pos): game.camera_center = pos)
	play_ui.add_child(minimap)
	selection_label = _label(play_ui, "部隊を選択", Vector2(207, 512), 17)
	task_label = _label(play_ui, "", Vector2(208, 537), 10, MUTED)
	for i in range(3):
		var tab = Control.new()
		tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		play_ui.add_child(tab)
		tabs.append(tab)
		var index = i
		tab_buttons.append(_button(play_ui, ["部隊を生産", "村を建設", "全軍を強化"][i], Rect2(207 + i * 174, 562, 164, 29), func(): _select_tab(index)))
	var train = [["worker", "[1] 村人\n食料45 · 3秒"], ["soldier", "[2] 剣士\n食料55 / 金20 · 4秒"], ["archer", "[3] 弓兵\n木45 / 金25 · 5秒"]]
	for i in range(train.size()):
		var key: String = train[i][0]
		buttons[key] = _button(tabs[0], train[i][1], Rect2(207 + i * 174, 601, 164, 49), func(): Session.issue("train", [], Vector2.ZERO, key))
		buttons[key].add_theme_font_size_override("font_size", 12)
	queue_label = _label(tabs[0], "", Vector2(383, 663), 11, MUTED)
	queue_bar = _bar(tabs[0], Rect2(383, 689, 338, 6), Color("a3b67b"))
	_button(tabs[0], "[C] 自分の予約を取消", Rect2(207, 666, 164, 31), func(): Session.issue("cancel_train"))
	var builds = [["house", "[B] 家 · 人口+10\n木70"], ["barracks", "[N] 兵舎\n木150 / 金30"], ["tower", "[T] 監視塔\n木110 / 金60"]]
	for i in range(builds.size()):
		var key: String = builds[i][0]
		buttons[key] = _button(tabs[1], builds[i][1], Rect2(207 + i * 174, 601, 164, 49), func(): game.set_build_mode(key))
		buttons[key].add_theme_font_size_override("font_size", 12)
	_label(tabs[1], "村人を選択 → 建物を選ぶ → 緑色の位置をクリック\n複数の村人で工事が早く進みます。", Vector2(208, 664), 11, MUTED)
	buttons.weapons = _button(tabs[2], "[U] 鋼の武器\n食料120 / 金100", Rect2(207, 601, 251, 49), func(): Session.issue("research", [], Vector2.ZERO, "weapons"))
	buttons.masonry = _button(tabs[2], "[L] 石造の砦\n木180 / 金100", Rect2(468, 601, 251, 49), func(): Session.issue("research", [], Vector2.ZERO, "masonry"))
	_label(tabs[2], "鋼の武器：全軍・塔の攻撃力 +25%\n石造の砦：中央砦の耐久 +500 / 他の建物 +150", Vector2(208, 664), 11, MUTED)
	_panel(play_ui, Rect2(745, 517, 1, 184), Color("4d6652"))
	hp_label = _label(play_ui, "", Vector2(767, 513), 16, GOLD)
	hp_bar = _bar(play_ui, Rect2(768, 545, 360, 8), Color("a0b878"))
	_button(play_ui, "[R] 砦を修復 · 木60", Rect2(767, 568, 174, 35), func(): Session.issue("repair"))
	_button(play_ui, "[Y] 集合地点", Rect2(953, 568, 175, 35), func(): game.cancel_mode(); game.rally_mode = true)
	buttons.pause = _button(play_ui, "[P] 一時停止", Rect2(767, 613, 174, 33), func(): Session.issue("pause"))
	buttons.save = _button(play_ui, "[F9] セーブ", Rect2(953, 613, 175, 33), func(): Session.issue("save"))
	_label(play_ui, "F 全兵士 / V 全村人 / Z 待機村人\nE 進軍攻撃 / X 停止 / Ctrl+6〜9 部隊登録", Vector2(767, 661), 11, MUTED)
	_select_tab(0)

func _select_tab(index: int) -> void:
	active_tab = index
	for i in range(tabs.size()):
		tabs[i].visible = i == index
		tab_buttons[i].modulate = Color("f2cf8c") if i == index else Color.WHITE

func _make_lobby() -> void:
	lobby = _panel(root, Rect2(338, 165, 476, 332), Color(0.05, 0.12, 0.10, 0.99))
	_label(lobby, "集 結 の 時", Vector2(28, 24), 25, GOLD)
	_label(lobby, "最大4人で、ひとつの砦を守る。", Vector2(28, 77), 15)
	lobby_status = _label(lobby, "", Vector2(28, 116), 13, MUTED)
	lobby_status.size = Vector2(420, 100)
	lobby_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_button = _button(lobby, "全員で出陣", Rect2(28, 240, 270, 43), func(): Session.start(), true)
	_button(lobby, "タイトルへ", Rect2(311, 240, 137, 43), func(): Session.back_to_menu())
	_label(lobby, "UDP 27840 · 途中参加可能 · 全員 v1.1.0", Vector2(28, 298), 11, MUTED)

func _make_help() -> void:
	help_panel = _panel(root, Rect2(230, 87, 692, 535), Color(0.05, 0.12, 0.10, 0.99))
	_label(help_panel, "指 揮 官 の 手 引 き", Vector2(28, 23), 24, GOLD)
	_label(help_panel, "左クリック / ドラッグ     自分の部隊を選択（Shiftで追加）\nダブルクリック                画面内の同じ兵種をまとめて選択\n右クリック                        移動 / 敵を攻撃 / 村人で資源を採集\nWASD / 矢印 / 中ボタン     カメラ移動\nホイール / Space              拡大縮小 / 中央砦へ戻る\n1 / 2 / 3 / C                         村人 / 剣士 / 弓兵を予約 / 予約取消\nB / N / T                              家 / 兵舎 / 監視塔を設置\nE / X / Y                               進軍攻撃 / 停止 / 新兵の集合地点\nF / V / Z                               全兵士 / 全村人 / 待機村人\nU / L / R                               武器強化 / 建物強化 / 砦の修復\nCtrl+6〜9 → 6〜9                部隊グループ登録 → 呼び出し\nP / F9 / M                            一時停止 / セーブ（ソロ） / 消音", Vector2(29, 80), 13)
	_label(help_panel, "最初はVで村人を選び、木・畑・金鉱を右クリック。\n6波目の敵と指揮官を倒せば勝利。中央砦が壊れると全員敗北。\nソロはこの画面で一時停止。オンライン中は時間が進みます。", Vector2(29, 397), 12, MUTED)
	_button(help_panel, "戦場へ戻る", Rect2(29, 477, 307, 38), toggle_help, true)
	_button(help_panel, "タイトルへ戻る（退出）", Rect2(350, 477, 313, 38), func(): help_panel.hide(); paused_by_help = false; Session.back_to_menu())
	help_panel.hide()

func _make_outcome() -> void:
	outcome = _panel(root, Rect2(311, 156, 530, 365), Color(0.05, 0.12, 0.10, 0.99))
	outcome_title = _label(outcome, "", Vector2(32, 24), 30, GOLD)
	outcome_body = _label(outcome, "", Vector2(32, 89), 14)
	rematch_button = _button(outcome, "もう一度、出陣", Rect2(32, 292, 227, 43), func(): Session.rematch(), true)
	_button(outcome, "タイトルへ戻る", Rect2(271, 292, 227, 43), func(): Session.back_to_menu())
	outcome.hide()

func toggle_help() -> void:
	help_panel.visible = not help_panel.visible
	if Session.mode == "solo":
		if help_panel.visible and not Session.sim.paused:
			Session.sim.paused = true
			paused_by_help = true
		elif not help_panel.visible and paused_by_help:
			Session.sim.paused = false
			paused_by_help = false
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
	continue_button.disabled = not Session.has_save() or Session.mode != "menu"
	play_ui.visible = active
	lobby.visible = Session.mode in ["host", "client"] and not Session.sim.running and Session.sim.result == ""
	start_button.visible = Session.mode == "host"
	outcome.visible = active and Session.sim.result != ""
	if not active or outcome.visible:
		help_panel.hide()
		paused_by_help = false
		last_event = -1
	if outcome.visible:
		var sim = Session.sim
		outcome_title.text = "夜明けの勝利" if sim.result == "victory" else "砦、陥落"
		outcome_body.text = "%s\n\n%s  ·  %d分%02d秒\n撃破 %d  /  失った部隊 %d\n採集 %d  /  生産 %d  /  建築 %d" % [sim.event_text, Sim.DIFFICULTIES[sim.difficulty], int(sim.elapsed) / 60, int(sim.elapsed) % 60, sim.stats.kills, sim.stats.lost, sim.stats.gathered, sim.stats.trained, sim.stats.built]
		rematch_button.disabled = Session.mode == "client"

func toast(text: String) -> void:
	toast_label.text = text
	toast_left = 4.5

func _process(delta: float) -> void:
	if game == null:
		return
	var sim = Session.sim
	var player: Dictionary = sim.players.get(Session.local_id, {})
	var points = player.get("skill_points", 0)
	bonus_panel.visible = sim.running and points > 0 and Session.mode in ["solo", "host", "client"] and not help_panel.visible
	bonus_title.text = "撃退ボーナス — スキルを1つ選択（残り%d）" % points
	var skills: Dictionary = player.get("skills", {})
	bonus_summary.text = "取得済み：豊穣 %d / 勇士 %d / 不屈 %d" % [skills.get("harvest", 0), skills.get("power", 0), skills.get("vitality", 0)] + ("　・ソロは選択まで待機" if Session.mode == "solo" else "　・オンライン中は時間が進みます")
	audio_button.text = "消音 [M]" if game.sound.muted else "音 [M]"
	if sim.result != "" and not outcome.visible:
		refresh_mode()
	resources_label.text = "食料 %d    木 %d    金 %d    人口 %d+%d/%d" % [sim.stock.food, sim.stock.wood, sim.stock.gold, sim.population(), sim.queued_population(), sim.capacity()]
	wave_label.text = "襲撃  %02d / 06" % sim.wave
	var remain = int(maxf(0, sim.next_wave - sim.elapsed))
	time_label.text = "敵 %d  ·  次まで %02d:%02d" % [sim.enemies_left(), remain / 60, remain % 60] if sim.wave < 6 else "敵残り %d  ·  最後の夜" % sim.enemies_left()
	var hall: Dictionary = sim.buildings.get(1, {})
	hp_label.text = "中央砦  %d / %d" % [int(maxf(0, hall.get("hp", 0))), int(hall.get("max_hp", 1500))]
	hp_bar.value = hall.get("hp", 0) / hall.get("max_hp", 1500.0)
	var counts = {"worker": 0, "soldier": 0, "archer": 0}
	for id in game.selected:
		if sim.units.has(id):
			counts[sim.units[id].kind] += 1
	selection_label.text = "部隊を選択" if game.selected.is_empty() else "%d部隊  ·  村人%d / 剣士%d / 弓兵%d" % [game.selected.size(), counts.worker, counts.soldier, counts.archer]
	task_label.text = "%s  ·  %d人で防衛  ·  %s  ·  待機村人 %d" % [sim.players.get(Session.local_id, {}).get("name", "接続中"), sim.players.size(), Sim.DIFFICULTIES[sim.difficulty], sim.worker_count(true, Session.local_id)]
	for key in ["house", "barracks", "tower"]:
		buttons[key].disabled = counts.worker == 0 or not sim.running or not sim.can_afford(Sim.BUILD_DATA[key].cost)
	for key in ["worker", "soldier", "archer"]:
		buttons[key].disabled = not sim.running or not sim.can_afford(Sim.UNIT_DATA[key].cost) or sim.population() + sim.queued_population() >= sim.capacity()
	for key in ["weapons", "masonry"]:
		buttons[key].disabled = sim.upgrades[key] or not sim.can_afford(Sim.RESEARCH[key].cost)
		buttons[key].tooltip_text = "研究済み・味方全員に適用" if sim.upgrades[key] else "共有資源を消費。味方全員に適用します。"
	var first = {}
	var queued = 0
	for b in sim.buildings.values():
		for job in b.queue:
			if job.owner == Session.local_id:
				queued += 1
				if first.is_empty():
					first = job
	queue_label.text = "生産予約なし · ボタンで最大5人まで予約" if first.is_empty() else "%s  あと%.1f秒 · 自分の予約 %d" % [NAMES[first.kind], maxf(0, first.left), queued]
	queue_bar.value = 0.0 if first.is_empty() else 1.0 - first.left / first.total
	buttons.pause.disabled = Session.mode != "solo"
	buttons.save.disabled = Session.mode != "solo"
	buttons.pause.text = "[P] 再開する" if sim.paused else "[P] 一時停止"
	paused_label.visible = sim.paused and not help_panel.visible
	tutorial_panel.visible = sim.elapsed < 150 and (sim.stats.gathered == 0 or sim.stats.trained == 0 or sim.stats.built == 0)
	tutorial.text = "%s Vで村人を選択 → 資源を右クリック\n%s 1 / 2 / 3 で村人・兵士を予約\n%s 村人を選択 → Bで家を建てる" % ["✓" if sim.stats.gathered > 0 else "1.", "✓" if sim.stats.trained > 0 else "2.", "✓" if sim.stats.built > 0 else "3."]
	boss_panel.hide()
	for u in sim.units.values():
		if u.kind == "warlord":
			boss_panel.show()
			boss_label.text = "襲撃指揮官  ·  %d / %d" % [int(maxf(0, u.hp)), int(u.max_hp)]
			boss_bar.value = u.hp / u.max_hp
			break
	minimap.camera_center = game.camera_center
	minimap.queue_redraw()
	lobby_status.text = "%d / 4 人が集結  ·  %s\n%s" % [sim.players.size(), Sim.DIFFICULTIES[sim.difficulty], Session.status]
	if Session.mode == "host":
		lobby_status.text += "\n招待用IP：" + host_ips
	mode_label.text = ""
	if game.build_mode != "":
		mode_label.text = "建築位置をクリック  /  右クリック・Escで取消"
	elif game.rally_mode:
		mode_label.text = "新しい部隊の集合地点をクリック"
	elif game.attack_mode:
		mode_label.text = "進軍先をクリック  /  敵を迎撃しながら移動"
	if sim.event_serial != last_event and sim.running:
		last_event = sim.event_serial
		toast(sim.event_text)
	toast_left = maxf(0.0, toast_left - delta)
	toast_label.modulate.a = minf(1, toast_left)

func _make_bonus() -> void:
	bonus_panel = _panel(root, Rect2(176, 188, 800, 245), Color(0.045, 0.10, 0.085, 0.99))
	bonus_title = _label(bonus_panel, "撃退ボーナス — スキルを1つ選択", Vector2(24, 18), 23, GOLD)
	_label(bonus_panel, "自分の部隊に適用。重ねて取得でき、次のウェーブにも持ち越します。", Vector2(24, 58), 13, MUTED)
	var index = 0
	for key in Sim.SKILLS:
		var skill_key = key
		var card = _button(bonus_panel, Sim.SKILLS[key].name + "\n" + Sim.SKILLS[key].detail, Rect2(24 + index * 253, 96, 243, 80), func(): Session.issue("skill", [], Vector2.ZERO, skill_key), true)
		card.add_theme_font_size_override("font_size", 13)
		index += 1
	bonus_summary = _label(bonus_panel, "", Vector2(24, 197), 13, MUTED)
	bonus_panel.hide()
