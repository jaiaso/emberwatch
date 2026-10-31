extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
var checks = 0
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)

func fresh():
	var sim = Sim.new()
	sim.reset()
	sim.add_player(1)
	sim.running = true
	sim.next_wave = 99999.0
	return sim

func advance(sim, seconds: float) -> void:
	for i in range(int(seconds * 20)):
		sim.step(0.05)

func run() -> void:
	var font: FontFile = load("res://assets/NotoSansJP.ttf")
	print("FONT_AXES ", font.get_supported_variation_list())
	var sim = fresh()
	check(sim.units.size() == 6 and sim.population() == 6, "initial army")
	check(sim.buildings.has(1) and sim.resources.size() == 66, "deterministic settlement")
	var worker = -1
	for u in sim.units.values():
		if u.kind == "worker":
			worker = u.id
			break
	sim.add_player(2)
	check(sim.players.size() == 2 and sim.units.size() == 12, "second player joins")
	var before: Vector2 = sim.units[worker].target
	check(sim.command(2, "move", [worker], Vector2(20, 20)) != "", "cannot command ally units")
	check(sim.units[worker].target == before, "rejected command does not mutate unit")
	check(sim.command(1, "move", [worker], Vector2(NAN, 1)) != "", "reject non-finite coordinates")
	var amount: int = sim.stock.food
	check(sim.command(1, "train", [], Vector2.ZERO, "raider") != "" and sim.stock.food == amount, "reject enemy production atomically")
	var res = -1
	for resource in sim.resources.values():
		if resource.kind == "food":
			res = resource.id
			break
	sim.units[worker].p = sim.resources[res].p + Vector2(1, 0)
	amount = sim.stock.food
	check(sim.command(1, "gather", [worker], sim.resources[res].p, str(res)) == "", "accept gather command")
	advance(sim, 2.2)
	check(sim.stock.food >= amount + 10, "gather increments shared stock")
	check(sim.resources[res].amount <= 140, "gather depletes resource")
	sim.units[worker].p = Vector2(-4, 5)
	var site = Vector2(-3, 6)
	var cap: int = sim.capacity()
	var wood: int = sim.stock.wood
	check(sim.valid_site("house", site), "unoccupied valid build site")
	check(not sim.valid_site("house", Vector2.ZERO), "reject overlapping build")
	check(sim.command(1, "build", [worker], site, "house") == "", "accept construction")
	check(sim.stock.wood == wood - 70, "building spends exact cost")
	advance(sim, 15)
	check(sim.capacity() == cap + 10, "worker completes house and increases capacity")
	sim.stock.food = 0
	var population: int = sim.population()
	check(sim.command(1, "train", [], Vector2.ZERO, "worker") != "" and sim.population() == population, "insufficient resources do not spawn")
	sim.stock.food = 100
	check(sim.command(1, "train", [], Vector2.ZERO, "worker") == "" and sim.stock.food == 55, "successful production spends shared resource")
	check(sim.population() == population and sim.queued_population() == 1, "production reserves population before completion")
	advance(sim, 3.5)
	check(sim.population() == population + 1 and sim.queued_population() == 0, "queued unit finishes after training time")
	sim.buildings[1].hp = 900.0
	sim.stock.wood = 100
	check(sim.command(2, "repair", [], Vector2.ZERO) == "" and sim.buildings[1].hp == 1120 and sim.stock.wood == 40, "ally repairs shared hall")
	var snap: Dictionary = sim.snapshot()
	var client = Sim.new()
	client.apply_snapshot(snap)
	check(client.stock == sim.stock and client.units.size() == sim.units.size(), "complete snapshot restoration")
	client.stock.food = -999
	check(sim.stock.food != -999, "snapshot does not alias host state")
	sim.remove_player(2)
	check(sim.units.values().all(func(u): return u.owner == 1), "disconnect transfers army to host")
	sim = fresh()
	sim.units.clear()
	sim._spawn_building("tower", Vector2(8, -4), 1, true)
	var enemy: int = sim.spawn_unit("raider", Vector2(12, -4), 0)
	advance(sim, 5)
	check(not sim.units.has(enemy), "tower kills nearby raider")
	sim = fresh()
	sim.units.clear()
	var soldier: int = sim.spawn_unit("soldier", Vector2(-8, 0), 1)
	enemy = sim.spawn_unit("raider", Vector2(-9, 0), 0)
	advance(sim, 8)
	check(not sim.units.has(enemy) and sim.units.has(soldier), "melee fight resolves")
	sim = fresh()
	sim.next_wave = 0
	sim.step(0.05)
	check(sim.wave == 1 and sim.enemies_left() == 8, "wave spawns expected raiders")
	sim = fresh()
	sim.add_player(2)
	sim.next_wave = 0
	sim.step(0.05)
	check(sim.enemies_left() == 16, "waves scale with players")
	sim = fresh()
	sim.units.clear()
	enemy = sim.spawn_unit("raider", Vector2(-30, -25), 0)
	var start_distance: float = sim.units[enemy].p.length()
	advance(sim, 6)
	check(sim.units[enemy].p.length() < start_distance - 8, "raider approaches settlement")
	sim = fresh()
	sim.buildings[1].hp = 0.0
	sim.step(0.05)
	check(sim.result == "defeat" and not sim.running, "hall destruction ends match")
	sim = fresh()
	sim.wave = 6
	sim.step(0.05)
	check(sim.result == "victory" and not sim.running, "final wave clearance wins match")
	sim = fresh()
	sim.stock = {"food": 1000, "wood": 1000, "gold": 1000}
	check(sim.command(1, "train", [], Vector2.ZERO, "soldier") == "", "soldier can be queued")
	var food_before: int = sim.stock.food
	check(sim.command(2, "cancel_train", [], Vector2.ZERO) != "", "outsider cannot cancel queue")
	check(sim.command(1, "cancel_train", [], Vector2.ZERO) == "" and sim.stock.food == food_before + 55, "own queue cancellation refunds cost")
	check(sim.command(1, "research", [], Vector2.ZERO, "weapons") == "" and sim.upgrades.weapons, "weapons research succeeds")
	food_before = sim.stock.food
	check(sim.command(1, "research", [], Vector2.ZERO, "weapons") != "" and sim.stock.food == food_before, "research cannot be purchased twice")
	check(sim.command(1, "research", [], Vector2.ZERO, "masonry") == "" and sim.buildings[1].max_hp == 2000, "masonry improves existing hall")
	var house: int = sim._spawn_building("house", Vector2(-5, 5), 1, true)
	check(sim.buildings[house].max_hp == 470, "masonry applies to future buildings")
	sim.command(1, "rally", [], Vector2(-10, -6))
	check(sim.rally == Vector2(-10, -6), "rally point is shared state")
	sim = fresh()
	sim.units.clear()
	var mover: int = sim.spawn_unit("worker", Vector2(-12, 0), 1)
	sim.command(1, "move", [mover], Vector2(12, 0))
	advance(sim, 18)
	check(sim.units[mover].p.distance_to(Vector2(12, 0)) < 2.0, "A* routes unit around central hall")
	sim = fresh()
	sim.paused = true
	advance(sim, 5)
	check(sim.elapsed == 0, "pause freezes simulation time")
	sim = fresh()
	sim.difficulty = 0
	var easy_enemy: int = sim.spawn_unit("raider", Vector2(20, 20), 0)
	check(sim.units[easy_enemy].max_hp < 85, "easy difficulty reduces enemy health")
	sim.wave = 5
	sim.next_wave = 0
	sim.step(0.05)
	check(sim.units.values().any(func(u): return u.kind == "warlord"), "final wave includes a boss")
	var restored = Sim.new()
	restored.apply_snapshot(sim.snapshot())
	check(restored.next_id == sim.next_id and restored.rng.state == sim.rng.state and restored.difficulty == 0, "save snapshot retains IDs, random state and difficulty")
	var queue_sim = fresh()
	queue_sim.stock = {"food": 10000, "wood": 10000, "gold": 10000}
	for i in range(5):
		queue_sim.command(1, "train", [], Vector2.ZERO, "worker")
	check(queue_sim.queued_population() == 5, "facility accepts five queued units")
	var stock_before: int = queue_sim.stock.food
	check(queue_sim.command(1, "train", [], Vector2.ZERO, "worker") != "" and queue_sim.stock.food == stock_before, "full facility rejects further training without spending")
	for i in range(12):
		queue_sim.spawn_unit("soldier", Vector2(25 + i % 3, 20), 1)
	check(queue_sim.command(1, "train", [], Vector2.ZERO, "archer") != "", "population reservation prevents over-recruitment")
	var combat = fresh()
	combat.stock = {"food": 1000, "wood": 1000, "gold": 1000}
	combat.command(1, "research", [], Vector2.ZERO, "weapons")
	combat.units.clear()
	var fighter: int = combat.spawn_unit("soldier", Vector2(15, 15), 1)
	var victim: int = combat.spawn_unit("raider", Vector2(16, 15), 0)
	combat.step(0.05)
	check(is_equal_approx(combat.units[victim].hp, 62.5), "weapon upgrade increases actual damage by 25 percent")
	var session = root.get_node("Session")
	session.mode = "client"
	session.sim.match_id = sim.match_id
	sim.tick = 42
	var compressed = var_to_bytes(sim.snapshot()).compress(FileAccess.COMPRESSION_GZIP)
	var count = int(ceil(float(compressed.size()) / 900.0))
	for i in range(count - 1, -1, -1):
		session._state_part(10, i, count, compressed.slice(i * 900, mini((i + 1) * 900, compressed.size())))
	check(session.sim.tick == 42 and session.receive_serial == 10, "out-of-order UDP chunks reassemble")
	var tick_before: int = session.sim.tick
	session._state_part(9, 0, 1, compressed)
	check(session.sim.tick == tick_before and session.receive_serial == 10, "stale snapshot ignored")
	session._state_part(11, 0, count + 1, compressed.slice(0, 900))
	check(session.sim.tick == tick_before and session.receive_serial == 10, "lost chunk leaves current state intact")
	session._state_part(12, 0, 1, compressed + compressed)
	check(session.sim.tick == tick_before and session.receive_serial == 10, "oversized UDP chunk rejected")
	var stale_state: Dictionary = sim.snapshot()
	stale_state.tick += 100
	stale_state.match_id += 1
	session._receive_state(stale_state)
	check(session.sim.tick == tick_before, "previous match snapshot cannot overwrite current match")
	session._welcome({"protocol": "0.1.0"})
	check(session.mode == "menu" and "バージョン" in session.status, "incompatible welcome returns an explicit version message")
	print("SIMULATION_TEST ", checks - failures.size(), "/", checks, " PASS; failures=", failures)
	quit(0 if failures.is_empty() else 1)
