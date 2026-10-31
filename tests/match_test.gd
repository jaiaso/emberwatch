extends SceneTree
const Sim = preload("res://scripts/simulation.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sim = Sim.new()
	sim.reset()
	sim.add_player(1)
	sim.running = true
	var start = Time.get_ticks_msec()
	var sites = [["tower", Vector2(-6, -5)], ["tower", Vector2(6, -5)], ["house", Vector2(-4, 6)], ["house", Vector2(10, 8)], ["tower", Vector2(1, 7)]]
	var site_index = 0
	for tick in range(18000):
		if tick % 10 == 0:
			if sim.players[1].skill_points > 0:
				sim.command(1, "skill", [], Vector2.ZERO, "power")
			var workers: Array = []
			for u in sim.units.values():
				if u.owner == 1 and u.kind == "worker":
					workers.append(u.id)
					if u.order == "idle":
						var kind: String = ["wood", "food", "gold"][workers.size() % 3]
						var nearest = -1
						var distance = INF
						for res in sim.resources.values():
							if res.kind == kind and res.amount > 0 and u.p.distance_to(res.p) < distance:
								distance = u.p.distance_to(res.p)
								nearest = res.id
						if nearest != -1:
							sim.command(1, "gather", [u.id], sim.resources[nearest].p, str(nearest))
			var army: Array = []
			var target = Vector2.ZERO
			for u in sim.units.values():
				if u.owner == 1 and u.kind != "worker":
					army.append(u.id)
				elif u.owner == 0:
					target = u.p
			if sim.enemies_left() > 0:
				sim.command(1, "attack_move", army, target)
			if workers.size() + sim.buildings[1].queue.size() < 8:
				sim.command(1, "train", [], Vector2.ZERO, "worker")
			sim.command(1, "train", [], Vector2.ZERO, "archer" if tick % 30 == 0 else "soldier")
			if site_index < sites.size() and not workers.is_empty():
				var site: Array = sites[site_index]
				var close: Array = workers.filter(func(id): return sim.units[id].order != "construct" and sim.units[id].p.distance_to(site[1]) < 14)
				if not close.is_empty() and sim.command(1, "build", [close[0]], site[1], site[0]) == "":
					site_index += 1
			if sim.wave >= 2:
				sim.command(1, "research", [], Vector2.ZERO, "weapons")
			if sim.wave >= 3:
				sim.command(1, "research", [], Vector2.ZERO, "masonry")
			if sim.buildings.has(1) and sim.buildings[1].hp < sim.buildings[1].max_hp - 220:
				sim.command(1, "repair", [], Vector2.ZERO)
		sim.step(0.05)
		if sim.result != "":
			break
	print("MATCH_TEST result=", sim.result, " waves=", sim.wave, " kills=", sim.stats.kills, " elapsed=", sim.elapsed, " army=", sim.population(), " enemies=", sim.enemies_left(), " wall_ms=", Time.get_ticks_msec() - start)
	quit(0 if sim.result == "victory" else 1)
