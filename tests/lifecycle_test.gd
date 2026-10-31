extends SceneTree
var session
var role = "host"
var clock = 0.0
var phase = 0
var initial_match = -1
var saw_rematch = false
var saw_live_state = false
var departing_id = -1
var passed = false

func _initialize() -> void:
	role = OS.get_cmdline_user_args()[0]
	call_deferred("begin")

func begin() -> void:
	session = root.get_node("Session")
	session.allow_autosave = false
	if role == "host":
		session.host()
	else:
		session.join("127.0.0.1")

func _process(delta: float) -> bool:
	clock += delta
	if session == null:
		return false
	if clock > 16:
		push_error("LIFECYCLE_TIMEOUT " + role)
		quit(1)
		return false
	if role == "host":
		if phase == 0 and session.sim.players.size() >= 2:
			session.start()
			session.sim.buildings[1].hp = 1200
			phase = 1
		if phase == 1 and session.sim.players.size() == 3:
			session.sim.stock.wood = 777
			for id in session.sim.players:
				if id != 1:
					departing_id = id
		if phase == 1 and clock > 5 and session.sim.players.size() == 3:
			session.sim.result = "victory"
			session.sim.running = false
			session.rematch()
			phase = 2
		if phase == 2 and clock > 9:
			passed = session.sim.players.size() == 2 and session.sim.running
			for u in session.sim.units.values():
				passed = passed and session.sim.players.has(u.owner)
			for b in session.sim.buildings.values():
				for job in b.queue:
					passed = passed and session.sim.players.has(job.owner)
			print("LIFECYCLE_HOST peers=", session.sim.players.size(), " transfer=", passed, " PASS=", passed)
			quit(0 if passed else 1)
	else:
		if session.mode == "client" and session.sim.running:
			if initial_match == -1:
				initial_match = session.sim.match_id
			if session.sim.buildings[1].hp == 1200:
				saw_live_state = true
			if session.sim.match_id != initial_match:
				saw_rematch = true
				if role == "late" and phase == 0:
					session.issue("train", [], Vector2.ZERO, "worker")
					phase = 1
			if role == "late" and saw_rematch and clock > 4.5:
				passed = saw_live_state and session.sim.population() >= 18
				print("LIFECYCLE_LATE running_join=", saw_live_state, " rematch=", saw_rematch, " PASS=", passed)
				session.back_to_menu()
				quit(0 if passed else 1)
		if role == "early" and clock > 8 and phase == 0:
			passed = saw_live_state and saw_rematch and session.mode == "client" and session.sim.running
			print("LIFECYCLE_EARLY rematch=", saw_rematch, " PASS=", passed)
			phase = 1
		if role == "early" and phase == 1 and clock > 9.5:
			quit(0 if passed else 1)
	return false
