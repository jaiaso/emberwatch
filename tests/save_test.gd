extends SceneTree
var checks = 0
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func run() -> void:
	var session = root.get_node("Session")
	session.allow_autosave = false
	var path: String = session.SAVE_PATH
	var original = PackedByteArray()
	var existed = FileAccess.file_exists(path)
	if existed:
		original = FileAccess.get_file_as_bytes(path)
	session.solo(2)
	session.sim.stock.food = 432
	session.sim.elapsed = 121.5
	session.sim.wave = 2
	session.sim.command(1, "train", [], Vector2.ZERO, "worker")
	var next_id: int = session.sim.next_id
	check(session.save_game(false), "save succeeds")
	session.back_to_menu()
	check(session.continue_game(), "saved game resumes")
	check(session.mode == "solo" and session.sim.difficulty == 2 and session.sim.stock.food == 387, "save retains mode, difficulty and resources")
	check(session.sim.elapsed == 121.5 and session.sim.next_id == next_id and session.sim.queued_population() == 1, "save retains time, unique IDs and queue")
	for i in range(70):
		session.sim.step(0.05)
	check(session.sim.population() == 7, "saved queue finishes after resuming")
	session.sim.paused = true
	session.save_game(false)
	session.back_to_menu()
	session.continue_game()
	check(not session.sim.paused, "resumed game starts unpaused")
	var bytes = FileAccess.get_file_as_bytes(path)
	bytes[bytes.size() - 1] = bytes[bytes.size() - 1] ^ 1
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	session.back_to_menu()
	check(not session.continue_game(), "checksum rejects corrupted data")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("not a save")
	file.close()
	check(not session.continue_game(), "invalid save header rejected")
	if existed:
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(original)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("SAVE_TEST ", checks - failures.size(), "/", checks, " PASS ", failures)
	quit(0 if failures.is_empty() else 1)
