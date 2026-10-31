extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
var checks = 0
var failures = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func _initialize() -> void:
	var sim = Sim.new()
	sim.reset()
	sim.add_player(1)
	sim.add_player(2)
	sim.running = true
	sim.next_wave = 99999
	var food = 0
	var gold = 0
	for r in sim.resources.values():
		food += int(r.kind == "food")
		gold += int(r.kind == "gold")
		check(not Sim.Terrain.blocked(r.p, 2), "resource outside cliffs")
	check(food == 24 and gold == 18, "six farm and six mine clusters")
	check(Sim.MAP_HALF == 59, "expanded map")
	check(not sim.valid_site("tower", Vector2(-26, -14)), "no construction on cliffs")
	var worker = sim.spawn_unit("worker", Vector2(-35, -14), 1)
	sim.command(1, "move", [worker], Vector2(-16, -14))
	var crossed = false
	for i in range(650):
		sim.step(0.05)
		crossed = crossed or Sim.Terrain.blocked(sim.units[worker].p)
	check(not crossed, "cliff collision rejects every step")
	check(sim.units[worker].p.distance_to(Vector2(-16, -14)) < 2, "worker routes around cliff")
	check(sim.command(1, "skill", [], Vector2.ZERO, "power") != "", "cannot acquire free skill")
	sim.wave = 1
	sim.step(0.05)
	check(sim.players[1].skill_points == 1 and sim.players[2].skill_points == 1, "one reward for each peer")
	sim.step(0.05)
	check(sim.players[1].skill_points == 1, "reward cannot repeat")
	check(sim.command(1, "skill", [], Vector2.ZERO, "power") == "", "valid skill acquired")
	check(sim.command(1, "skill", [], Vector2.ZERO, "vitality") != "", "double spend rejected")
	check(sim.players[2].skill_points == 1 and sim.players[2].skills.power == 0, "choice does not spend ally reward")
	sim.command(2, "skill", [], Vector2.ZERO, "vitality")
	var soldier = sim.spawn_unit("soldier", Vector2(-5, -5), 2)
	check(is_equal_approx(sim.units[soldier].max_hp, 150), "future troops inherit HP skill")
	var copy = Sim.new()
	copy.apply_snapshot(sim.snapshot())
	check(copy.players[1].skills.power == 1 and copy.players[2].skills.vitality == 1, "skills survive snapshot and save")
	sim.wave = 2
	sim.step(0.05)
	sim.command(1, "skill", [], Vector2.ZERO, "power")
	check(sim.players[1].skills.power == 2, "stacked skill levels")
	sim.add_player(3)
	check(sim.players[3].skill_points == 2, "late join receives earned choices")
	var attacker = sim.spawn_unit("soldier", Vector2(-8, -8), 1)
	var victim = sim.spawn_unit("raider", Vector2(-7, -8), 0)
	var hp: float = sim.units[victim].hp
	sim._strike(sim.units[attacker], sim.units[victim], 0.05)
	check(is_equal_approx(hp - sim.units[victim].hp, 18 * 1.30), "two power levels add thirty percent damage")
	sim.players[1].skill_points = 1
	sim.command(1, "skill", [], Vector2.ZERO, "harvest")
	var resource = {}
	for r in sim.resources.values():
		if r.kind == "food":
			resource = r
			break
	sim.units[worker].p = resource.p
	sim.command(1, "gather", [worker], resource.p, str(resource.id))
	var before: int = sim.stock.food
	for i in range(4):
		sim._step_ally(sim.units[worker], 1.0)
	check(sim.stock.food - before == 25, "harvest skill adds exact twenty five percent over four ticks")
	print("TERRAIN_SKILL_TEST ", checks - failures.size(), "/", checks, " PASS ", failures)
	quit(0 if failures.is_empty() else 1)
