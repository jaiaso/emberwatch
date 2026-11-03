extends SceneTree
const Heroes=preload("res://scripts/heroes.gd")
var game
var session
var checks=0
var failures=[]
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		push_error(label)
func click(point: Vector2) -> void:
	var event=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.position=root.get_final_transform()*point
	event.global_position=event.position
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await process_frame
func run() -> void:
	session=root.get_node("Session")
	session.allow_autosave=false
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await click(Vector2(200,363))
	for i in range(6): await process_frame
	check(game.hud.hero_picker.visible and session.sim.elapsed==0,"solo displays six hero choices before timer")
	check(game.hud.hero_cards.size()==6,"all six choices visible")
	for key in Heroes.DATA:
		var card=game.hud.hero_cards[key]
		check(root.get_visible_rect().encloses(card.get_global_rect()),"hero card fits logical screen")
	if not OS.get_cmdline_user_args().is_empty() and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]+"-selection.png")
	await click(game.hud.hero_cards.arthur.get_global_rect().get_center())
	for i in range(5): await process_frame
	check(session.sim.players[1].hero=="arthur" and not game.hud.hero_picker.visible,"real card click confirms Arthur")
	var hero_id=int(session.sim.players[1].hero_unit)
	check(game.entities.has(hero_id) and game.entities[hero_id].has_node("HeroRing"),"hero special model and gold ring rendered")
	await click(game.hud.hero_status.get_global_rect().get_center())
	check(game.selected==[hero_id],"hero HUD selects commander")
	await process_frame
	await process_frame
	check("アーサー王" in game.hud.selection_label.text and "XP" in game.hud.hero_status.text,"name and experience visible")
	session.sim._award_hero_xp(1,480)
	await process_frame
	await process_frame
	check("Lv5" in game.hud.hero_status.text,"HUD reflects leveling")
	# Render the two transformed troop types and their normal animation path.
	var heavy=session.sim.spawn_unit("heavy_cavalry",Vector2(-2,6),1)
	var mage=session.sim.spawn_unit("mage",Vector2(0,6),1)
	for i in range(5): await process_frame
	check(game.entities.has(heavy) and game.entities[heavy].has_node("Mount/HorseLeg3"),"heavy cavalry model and horse animation")
	check(game.entities.has(mage) and game.entities[mage].has_node("Body/ArmR"),"mage model and cast animation")
	session.sim.effect("fire",Vector2(0,6),Vector2(3,6),false,28)
	for i in range(3): await process_frame
	check(game.effects.any(func(e): return e.kind=="fire"),"fireball renders through effect path")
	if not OS.get_cmdline_user_args().is_empty() and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]+"-battle.png")
	if DisplayServer.get_name()!="headless":
		print("HERO_UI_NATIVE ",checks-failures.size(),"/",checks," PASS ",failures)
		game._graceful_quit(0 if failures.is_empty() else 1)
		return
	var path: String=session.SAVE_PATH
	var existed=FileAccess.file_exists(path)
	var original=FileAccess.get_file_as_bytes(path) if existed else PackedByteArray()
	for key in Heroes.DATA:
		session.solo()
		session.issue("hero",[],Vector2.ZERO,key)
		await process_frame
		await process_frame
		var id=int(session.sim.players[1].hero_unit)
		check(game.entities.has(id) and game.entities[id].get_meta("hero","")==key,"correct unique model "+key)
		if Heroes.mounted(key):
			check(game.entities[id].has_node("Mount/HorseLeg3"),"mounted hero articulated horse")
		if key=="himiko":
			check("魔法使い" in game.hud.buttons.archer.text,"mage production button renamed")
		if key=="iskandar":
			check("重装騎兵" in game.hud.buttons.cavalry.text,"heavy production button renamed")
		# Each choice gets a save/continue round trip, including a dead hero.
		session.sim.wave=1
		session.sim.units[id].hp=0
		session.sim._spawn_wave()
		session.sim.step(0.05)
		check(session.save_game(false),"hero save writes")
		session.back_to_menu()
		check(session.continue_game() and session.sim.players[1].hero==key and session.sim.players[1].hero_unit==-1 and session.sim.players[1].revive_wave==2,"save restores dead hero and resurrection wave")
		await process_frame
		await process_frame
		check("復活" in game.hud.hero_status.text,"HUD explains resurrection wait")
	session.back_to_menu()
	if existed:
		var file=FileAccess.open(path,FileAccess.WRITE)
		file.store_buffer(original)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("HERO_UI_TEST ",checks-failures.size(),"/",checks," PASS ",failures)
	game._graceful_quit(0 if failures.is_empty() else 1)
