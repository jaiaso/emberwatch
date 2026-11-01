extends RefCounted
## The host alone advances this simulation. Clients only submit intents.

const Terrain = preload("res://scripts/terrain_data.gd")
const MAP_HALF = Terrain.HALF
const WAVE_COUNT = 6
const WAVE_INTERVAL = 70.0
const WAVE_DIRECTIONS = ["北西", "北東", "南東", "南西"]
const WAVE_ORIGINS = [Vector2(-50, -45), Vector2(49, -44), Vector2(47, 49), Vector2(-48, 46)]
const Navigation = preload("res://scripts/navigation.gd")
const DIFFICULTIES = ["穏やかな夜", "標準の夜", "苛烈な夜"]
const TRAIN_TIME = {"worker": 3.0, "soldier": 4.0, "archer": 5.0}
const RESEARCH = {
	"weapons": {"name": "鋼の武器", "cost": {"food": 120, "gold": 100}},
	"masonry": {"name": "石造の砦", "cost": {"wood": 180, "gold": 100}},
}
const SKILLS = {
	"harvest": {"name": "豊穣の手", "detail": "自分の村人の採集量 +25%"},
	"power": {"name": "勇士の誓い", "detail": "自分の部隊の攻撃力 +15%"},
	"vitality": {"name": "不屈の命", "detail": "自分の部隊の最大HP +20%・回復"},
}
const UNIT_DATA = {
	"worker": {"hp": 55.0, "speed": 3.0, "range": 1.4, "damage": 4.0, "cost": {"food": 45}},
	"soldier": {"hp": 125.0, "speed": 2.8, "range": 1.6, "damage": 18.0, "cost": {"food": 55, "gold": 20}},
	"archer": {"hp": 65.0, "speed": 3.1, "range": 8.0, "damage": 12.0, "cost": {"wood": 45, "gold": 25}},
	"raider": {"hp": 85.0, "speed": 2.3, "range": 1.7, "damage": 10.0, "cost": {}},
	"brute": {"hp": 270.0, "speed": 1.6, "range": 2.2, "damage": 23.0, "cost": {}},
	"slinger": {"hp": 60.0, "speed": 2.1, "range": 6.0, "damage": 9.0, "cost": {}},
	"warlord": {"hp": 650.0, "speed": 1.9, "range": 2.8, "damage": 29.0, "cost": {}},
}
const BUILD_DATA = {
	"hall": {"hp": 1500.0, "radius": 2.7, "time": 0.0, "cost": {}},
	"house": {"hp": 320.0, "radius": 1.5, "time": 9.0, "cost": {"wood": 70}},
	"barracks": {"hp": 650.0, "radius": 2.0, "time": 15.0, "cost": {"wood": 150, "gold": 30}},
	"tower": {"hp": 500.0, "radius": 1.3, "time": 12.0, "cost": {"wood": 110, "gold": 60}},
}

var units: Dictionary = {}
var buildings: Dictionary = {}
var resources: Dictionary = {}
var players: Dictionary = {}
var stock: Dictionary = {}
var elapsed = 0.0
var wave = 0
var next_wave = WAVE_INTERVAL
var running = false
var result = ""
var next_id = 1
var event_text = "森を拓き、夜明けまで砦を守れ。"
var event_serial = 0
var tick = 0
var rng = RandomNumberGenerator.new()
var difficulty = 1
var paused = false
var upgrades = {"weapons": false, "masonry": false}
var stats = {"kills": 0, "lost": 0, "gathered": 0, "trained": 0, "built": 0}
var events: Array = []
var effect_serial = 0
var cleared_wave = 0
var rally = Vector2(0, -7)
var navigation = Navigation.new()
var paths: Dictionary = {}
var spatial: Dictionary = {}
var match_id = 0

func reset() -> void:
	match_id = Time.get_ticks_usec()
	units.clear()
	buildings.clear()
	resources.clear()
	players.clear()
	stock = {"food": 280, "wood": 320, "gold": 180}
	elapsed = 0.0
	wave = 0
	next_wave = WAVE_INTERVAL
	running = false
	paused = false
	upgrades = {"weapons": false, "masonry": false}
	stats = {"kills": 0, "lost": 0, "gathered": 0, "trained": 0, "built": 0}
	events.clear()
	effect_serial = 0
	cleared_wave = 0
	rally = Vector2(0, -7)
	paths.clear()
	spatial.clear()
	navigation.signature = ""
	result = ""
	next_id = 1
	tick = 0
	event_serial = 0
	event_text = "森を拓き、夜明けまで砦を守れ。"
	rng.seed = 1989
	_spawn_building("hall", Vector2.ZERO, 0, true)
	_spawn_building("barracks", Vector2(7, 3), 0, true)
	for cluster in [Vector2(-13, -8), Vector2(15, -13), Vector2(-18, 13), Vector2(20, 14), Vector2(-43, 32), Vector2(40, -35), Vector2(-42, -39), Vector2(40, 38)]:
		for i in range(12):
			_add_resource("wood", cluster + Vector2(rng.randf_range(-5, 5), rng.randf_range(-5, 5)), 160)
	for cluster in [Vector2(-11, 6), Vector2(11, -9), Vector2(-41, 10), Vector2(36, -13), Vector2(12, 42), Vector2(-13, -45)]:
		for i in range(4):
			_add_resource("food", cluster + Vector2(i % 2, i / 2) * 3.2, 150)
	for cluster in [Vector2(3, 13), Vector2(-15, -18), Vector2(-43, -5), Vector2(39, 12), Vector2(-28, 43), Vector2(29, -43)]:
		for i in range(3):
			_add_resource("gold", cluster + Vector2(i * 2.5, 0), 300)

func _id() -> int:
	var value = next_id
	next_id += 1
	return value

func _add_resource(kind: String, pos: Vector2, amount: int) -> void:
	if Terrain.blocked(pos, 2.0):
		return
	var id = _id()
	resources[id] = {"id": id, "kind": kind, "p": pos, "amount": amount}

func add_player(peer_id: int) -> void:
	if players.has(peer_id):
		return
	var slot = 0
	var occupied: Array = []
	for player in players.values():
		occupied.append(player.slot)
	while slot in occupied:
		slot += 1
	players[peer_id] = {"slot": slot, "name": "盟友 %d" % (slot + 1), "skill_points": cleared_wave, "skills": {"harvest": 0, "power": 0, "vitality": 0}}
	var base = Vector2(-5, 6).rotated(float(slot) * TAU / 4.0)
	for i in range(3):
		spawn_unit("worker", base + Vector2(i * 1.3, 0), peer_id)
	spawn_unit("soldier", base + Vector2(0, 2), peer_id)
	spawn_unit("soldier", base + Vector2(1.5, 2), peer_id)
	spawn_unit("archer", base + Vector2(3, 2), peer_id)
	if players.size() > 1:
		stock.food += 130
		stock.wood += 150
		stock.gold += 90

func remove_player(peer_id: int) -> void:
	players.erase(peer_id)
	# Transfer an absent ally's army to the host so the shared defense can continue.
	for unit in units.values():
		if unit.owner == peer_id:
			unit.owner = 1
	for building in buildings.values():
		if building.owner == peer_id:
			building.owner = 1
		for job in building.get("queue", []):
			if job.owner == peer_id:
				job.owner = 1
	announce("盟友が離脱。部隊の指揮をホストに移譲しました。")

func spawn_unit(kind: String, pos: Vector2, owner: int) -> int:
	var id = _id()
	var data: Dictionary = UNIT_DATA[kind]
	var hp: float = data.hp * ([0.78, 1.0, 1.25][difficulty] if owner == 0 else 1.0)
	if owner != 0:
		hp *= 1.0 + 0.2 * players.get(owner, {}).get("skills", {}).get("vitality", 0)
	units[id] = {"id": id, "kind": kind, "owner": owner, "p": pos, "hp": hp,
		"max_hp": hp, "target": pos, "order": "idle", "resource": -1,
		"enemy": -1, "cool": 0.0, "gather": 0.0, "anim": 0.0, "attack_at": -10.0}
	return id

func _spawn_building(kind: String, pos: Vector2, owner: int, complete: bool) -> int:
	var id = _id()
	var data: Dictionary = BUILD_DATA[kind]
	var hp: float = data.hp + (500.0 if kind == "hall" else 150.0) * float(upgrades.masonry)
	buildings[id] = {"id": id, "kind": kind, "owner": owner, "p": pos,
		"hp": hp, "max_hp": hp, "progress": 1.0 if complete else 0.01, "cool": 0.0, "queue": []}
	return id

func population() -> int:
	var count = 0
	for unit in units.values():
		if unit.owner != 0:
			count += 1
	return count

func capacity() -> int:
	var cap = 18 * maxi(1, players.size())
	for building in buildings.values():
		if building.kind == "house" and building.progress >= 1.0:
			cap += 10
	return mini(cap, 120)

func queued_population() -> int:
	var count = 0
	for b in buildings.values():
		count += b.queue.size()
	return count

func worker_count(idle_only: bool = false, owner: int = -1) -> int:
	var count = 0
	for u in units.values():
		if u.kind == "worker" and (owner == -1 or u.owner == owner) and (not idle_only or u.order == "idle"):
			count += 1
	return count

func enemies_left() -> int:
	var count = 0
	for unit in units.values():
		if unit.owner == 0:
			count += 1
	return count

func can_afford(cost: Dictionary) -> bool:
	for key in cost:
		if stock.get(key, 0) < cost[key]:
			return false
	return true

func _spend(cost: Dictionary) -> void:
	for key in cost:
		stock[key] -= cost[key]

func valid_site(kind: String, pos: Vector2) -> bool:
	if not BUILD_DATA.has(kind) or kind == "hall" or not pos.is_finite():
		return false
	if absf(pos.x) > MAP_HALF - 4 or absf(pos.y) > MAP_HALF - 4:
		return false
	var radius: float = BUILD_DATA[kind].radius
	if Terrain.blocked(pos, radius + 0.8):
		return false
	for b in buildings.values():
		if pos.distance_to(b.p) < radius + float(BUILD_DATA[b.kind].radius) + 0.8:
			return false
	for res in resources.values():
		if res.amount > 0 and pos.distance_to(res.p) < radius + 0.65:
			return false
	return true

func command(sender: int, action: String, ids: Array, pos: Vector2, extra: String = "") -> String:
	if not running or result != "" or not players.has(sender):
		return "戦闘が始まっていません。"
	if not pos.is_finite() or ids.size() > 120:
		return "無効な指令です。"
	var owned: Array = []
	for id in ids:
		if typeof(id) == TYPE_INT and units.has(id) and units[id].owner == sender and not owned.has(id):
			owned.append(id)
	match action:
		"move", "attack_move", "gather", "attack", "stop":
			if owned.is_empty():
				return "自分の部隊を選択してください。"
			var target_id = int(extra) if extra.is_valid_int() else -1
			if action == "gather" and not resources.has(target_id):
				return "資源が見つかりません。"
			if action == "attack" and (not units.has(target_id) or units[target_id].owner != 0):
				return "敵が見つかりません。"
			var index = 0
			for id in owned:
				var u: Dictionary = units[id]
				paths.erase(id)
				if action == "gather" and u.kind != "worker":
					continue
				u.order = action if action != "stop" else "idle"
				u.resource = target_id if action == "gather" else -1
				u.enemy = target_id if action == "attack" else -1
				u.gather = 0.0
				var offset = Vector2(index % 5 - mini(owned.size() - 1, 4) * 0.5, index / 5) * 1.25
				u.target = Vector2(clampf(pos.x + offset.x, -57, 57), clampf(pos.y + offset.y, -57, 57))
				index += 1
		"build":
			if not BUILD_DATA.has(extra) or extra == "hall":
				return "無効な建物です。"
			var workers: Array = owned.filter(func(id): return units[id].kind == "worker")
			if workers.is_empty():
				return "建築には自分の村人を選択してください。"
			var close = false
			for id in workers:
				if units[id].p.distance_to(pos) < 14.0:
					close = true
			if not close:
				return "村人から14マス以内に建ててください。"
			if buildings.size() >= 40 or not valid_site(extra, pos):
				return "ここには建築できません。"
			if not can_afford(BUILD_DATA[extra].cost):
				return "共有資源が足りません。"
			_spend(BUILD_DATA[extra].cost)
			var build_id = _spawn_building(extra, pos, sender, false)
			for id in workers:
				units[id].order = "construct"
				units[id].resource = build_id
				units[id].enemy = -1
		"train":
			if extra not in ["worker", "soldier", "archer"]:
				return "無効な兵種です。"
			if population() + queued_population() >= capacity():
				return "人口上限です。家を建ててください。"
			var producer = {}
			for b in buildings.values():
				if b.kind == ("hall" if extra == "worker" else "barracks") and b.progress >= 1.0 and b.queue.size() < 5:
					if producer.is_empty() or b.queue.size() < producer.queue.size():
						producer = b
			if producer.is_empty():
				return "完成した生産施設が必要です。"
			if not can_afford(UNIT_DATA[extra].cost):
				return "共有資源が足りません。"
			_spend(UNIT_DATA[extra].cost)
			producer.queue.append({"id": _id(), "kind": extra, "owner": sender, "left": TRAIN_TIME[extra], "total": TRAIN_TIME[extra]})
		"cancel_train":
			var last_job = -1
			var producer_id = -1
			var job_index = -1
			for b in buildings.values():
				for i in range(b.queue.size()):
					var job: Dictionary = b.queue[i]
					if job.owner == sender and job.id > last_job:
						last_job = job.id
						producer_id = b.id
						job_index = i
			if last_job == -1:
				return "取り消せる自分の生産予約がありません。"
			var job: Dictionary = buildings[producer_id].queue[job_index]
			for key in UNIT_DATA[job.kind].cost:
				stock[key] += UNIT_DATA[job.kind].cost[key]
			buildings[producer_id].queue.remove_at(job_index)
		"skill":
			if not SKILLS.has(extra) or players[sender].get("skill_points", 0) <= 0:
				return "選択できるボーナスがありません。"
			players[sender].skill_points -= 1
			players[sender].skills[extra] += 1
			if extra == "vitality":
				for u in units.values():
					if u.owner == sender:
						var bonus = float(UNIT_DATA[u.kind].hp) * 0.2
						u.max_hp += bonus
						u.hp = minf(u.max_hp, u.hp + bonus)
			announce(players[sender].name + "：" + SKILLS[extra].name + "を獲得！")
		"research":
			if not RESEARCH.has(extra) or upgrades[extra]:
				return "この強化は研究済みです。"
			if not can_afford(RESEARCH[extra].cost):
				return "共有資源が足りません。"
			_spend(RESEARCH[extra].cost)
			upgrades[extra] = true
			if extra == "masonry":
				for b in buildings.values():
					var bonus = 500.0 if b.kind == "hall" else 150.0
					b.max_hp += bonus
					b.hp += bonus
			announce(RESEARCH[extra].name + "が完成。全員の防衛力が向上！")
		"rally":
			rally = pos.clamp(Vector2(-57, -57), Vector2(57, 57))
			announce("新しい部隊の集合地点を更新しました。")
		"repair":
			if not buildings.has(1) or buildings[1].hp >= buildings[1].max_hp:
				return "中央砦は損傷していません。"
			if stock.wood < 60:
				return "修復には木材60が必要です。"
			stock.wood -= 60
			buildings[1].hp = minf(buildings[1].max_hp, buildings[1].hp + 220.0)
		"ping":
			announce("盟友 %d の合図：マップの光を確認！" % (int(players[sender].slot) + 1))
		_:
			return "無効な指令です。"
	return ""

func announce(message: String) -> void:
	event_text = message
	event_serial += 1

func effect(kind: String, from: Vector2, to: Vector2, hostile: bool = false, amount: float = 0.0) -> void:
	effect_serial += 1
	events.append({"id": effect_serial, "kind": kind, "from": from, "to": to, "hostile": hostile, "amount": amount})
	if events.size() > 48:
		events.pop_front()

func step(delta: float) -> void:
	if not running or paused or result != "":
		return
	if players.size() == 1 and wave < WAVE_COUNT and enemies_left() == 0 and players.values()[0].get("skill_points", 0) > 0:
		return
	tick += 1
	elapsed += delta
	navigation.rebuild(buildings, BUILD_DATA)
	spatial.clear()
	for u in units.values():
		var cell = Vector2i(floori(u.p.x / 4.0), floori(u.p.y / 4.0))
		if not spatial.has(cell):
			spatial[cell] = []
		spatial[cell].append(u.id)
	if wave < WAVE_COUNT and elapsed >= next_wave and enemies_left() == 0:
		_spawn_wave()
	for b in buildings.values():
		b.cool = maxf(0.0, b.cool - delta)
		if b.progress >= 1.0 and not b.queue.is_empty():
			var job: Dictionary = b.queue[0]
			job.left -= delta
			if job.left <= 0.0 and population() < capacity():
				var spawned = spawn_unit(job.kind, b.p + Vector2(0, float(BUILD_DATA[b.kind].radius) + 1.4), job.owner)
				units[spawned].order = "attack_move" if job.kind != "worker" else "move"
				units[spawned].target = rally + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1, 1))
				b.queue.pop_front()
				stats.trained += 1
				effect("spawn", b.p, units[spawned].p)
		if b.kind == "tower" and b.progress >= 1.0 and b.cool <= 0.0:
			var victim = _nearest_enemy(b.p, 11.0, true)
			if victim != -1:
				var damage = 27.0 * (1.25 if upgrades.weapons else 1.0)
				units[victim].hp -= damage
				effect("arrow", b.p, units[victim].p, false, damage)
				b.cool = 1.1
	var unit_ids = units.keys()
	for id in unit_ids:
		if not units.has(id):
			continue
		var u: Dictionary = units[id]
		if u.hp <= 0:
			continue
		u.cool = maxf(0.0, u.cool - delta)
		u.anim += delta
		if u.owner == 0:
			_step_enemy(u, delta)
		else:
			_step_ally(u, delta)
	for id in unit_ids:
		if units.has(id) and units[id].hp <= 0:
			effect("death", units[id].p, units[id].p, units[id].owner == 0)
			if units[id].owner == 0:
				stock.gold += 4 if units[id].kind in ["raider", "slinger"] else 15
				stats.kills += 1
			else:
				stats.lost += 1
			units.erase(id)
			paths.erase(id)
	for id in buildings.keys():
		if buildings[id].hp <= 0:
			for job in buildings[id].queue:
				for key in UNIT_DATA[job.kind].cost:
					stock[key] += UNIT_DATA[job.kind].cost[key]
			effect("death", buildings[id].p, buildings[id].p)
			buildings.erase(id)
	if wave > cleared_wave and enemies_left() == 0:
		var rewards = wave - cleared_wave
		cleared_wave = wave
		next_wave = maxf(next_wave, elapsed + 22.0)
		for player in players.values():
			player.skill_points = player.get("skill_points", 0) + rewards
		if wave < WAVE_COUNT:
			stock.food += 45 * maxi(1, players.size())
			stock.wood += 35 * maxi(1, players.size())
			announce("第%d波を撃退。補給とボーナススキルを獲得！" % wave)
	if not buildings.has(1):
		result = "defeat"
		running = false
		announce("中央砦が陥落した。火は、また灯せる。")
	elif wave == WAVE_COUNT and enemies_left() == 0:
		result = "victory"
		running = false
		announce("夜明けだ。砦は守られた。")

func approach_for_wave(number: int) -> Dictionary:
	if number < 1 or number > WAVE_COUNT:
		return {}
	var side = (number - 1) % WAVE_DIRECTIONS.size()
	return {"wave": number, "direction": WAVE_DIRECTIONS[side], "origin": WAVE_ORIGINS[side]}

func incoming_attack() -> Dictionary:
	if not running or result != "" or enemies_left() > 0:
		return {}
	return approach_for_wave(wave + 1)

func _spawn_wave() -> void:
	wave += 1
	next_wave = elapsed + [85.0, WAVE_INTERVAL, 60.0][difficulty]
	var approach = approach_for_wave(wave)
	var origin: Vector2 = approach.origin
	var count = (5 + wave * 3) * maxi(1, players.size())
	count = mini(int(ceil(count * [0.75, 1.0, 1.15][difficulty])), 100)
	for i in range(count):
		var kind = "brute" if wave >= 3 and i % 7 == 0 else "raider"
		if wave >= 2 and i % 6 == 2:
			kind = "slinger"
		spawn_unit(kind, origin + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)), 0)
	if wave == WAVE_COUNT:
		var boss = spawn_unit("warlord", origin + Vector2(0, 3), 0)
		units[boss].hp *= 1.0 + 0.45 * (players.size() - 1)
		units[boss].max_hp = units[boss].hp
	announce("第 %d 波 ／ %sから敵襲！" % [wave, approach.direction])

func _nearest_enemy(pos: Vector2, radius: float, hostile: bool) -> int:
	var nearest = -1
	var distance = radius
	for other in _nearby(pos, radius):
		if (other.owner == 0) != hostile or other.hp <= 0:
			continue
		var d = pos.distance_to(other.p)
		if d < distance:
			distance = d
			nearest = other.id
	return nearest

func _strike(u: Dictionary, target: Dictionary, delta: float, building: bool = false) -> void:
	var reach: float = UNIT_DATA[u.kind].range
	if building:
		reach += float(BUILD_DATA[target.kind].radius)
	if u.p.distance_to(target.p) > reach:
		_move(u, target.p, delta)
	elif u.cool <= 0.0:
		var damage = float(UNIT_DATA[u.kind].damage) * (1.25 if u.owner != 0 and upgrades.weapons else 1.0)
		damage *= 1.0 + 0.15 * players.get(u.owner, {}).get("skills", {}).get("power", 0)
		target.hp -= damage
		u.attack_at = elapsed
		effect("arrow" if u.kind in ["archer", "slinger"] else "hit", u.p, target.p, u.owner == 0, damage)
		u.cool = 0.85 if u.kind != "brute" else 1.4

func _step_enemy(u: Dictionary, delta: float) -> void:
	var victim = _nearest_enemy(u.p, 9.0, false)
	if victim != -1:
		_strike(u, units[victim], delta)
		return
	var target = {}
	var distance = INF
	for b in buildings.values():
		var d = u.p.distance_to(b.p)
		if d < distance:
			distance = d
			target = b
	if not target.is_empty():
		_strike(u, target, delta, true)

func _step_ally(u: Dictionary, delta: float) -> void:
	if u.order == "gather":
		var resource: Dictionary = resources.get(u.resource, {})
		if resource.is_empty() or resource.amount <= 0:
			var next_res = -1
			var distance = 18.0
			for res in resources.values():
				if res.amount > 0 and res.kind == resource.get("kind", "wood"):
					var d = u.p.distance_to(res.p)
					if d < distance:
						distance = d
						next_res = res.id
			if next_res == -1:
				u.order = "idle"
				return
			u.resource = next_res
			resource = resources[next_res]
		if u.p.distance_to(resource.p) > 1.4:
			_move(u, resource.p, delta)
		else:
			u.gather += delta
			if u.gather >= 1.0:
				var bonus = players.get(u.owner, {}).get("skills", {}).get("harvest", 0)
				u.harvest_credit = u.get("harvest_credit", 0.0) + 5.0 * 0.25 * bonus
				var earned = floori(u.harvest_credit)
				u.harvest_credit -= earned
				var amount = mini(5 + earned, resource.amount)
				resource.amount -= amount
				stock[resource.kind] += amount
				stats.gathered += amount
				u.gather = 0.0
		return
	if u.order == "construct":
		var b: Dictionary = buildings.get(u.resource, {})
		if b.is_empty() or b.progress >= 1.0:
			u.order = "idle"
		elif u.p.distance_to(b.p) > float(BUILD_DATA[b.kind].radius) + 1.2:
			_move(u, b.p, delta)
		else:
			b.progress = minf(1.0, b.progress + delta / float(BUILD_DATA[b.kind].time))
			if b.progress >= 1.0:
				stats.built += 1
				effect("spawn", b.p, b.p)
		return
	if u.order == "move":
		if _move(u, u.target, delta):
			u.order = "idle"
		return
	if u.order == "attack" and units.has(u.enemy) and units[u.enemy].hp > 0:
		_strike(u, units[u.enemy], delta)
		return
	var radius = 10.0 if u.kind != "worker" else 2.5
	var victim = _nearest_enemy(u.p, radius, true)
	if victim != -1:
		_strike(u, units[victim], delta)
	elif u.order == "attack_move":
		if _move(u, u.target, delta):
			u.order = "idle"
	elif u.order == "attack":
		u.order = "idle"

func _move(u: Dictionary, target: Vector2, delta: float) -> bool:
	var diff: Vector2 = target - u.p
	if diff.length() < 0.4:
		return true
	var destination = target
	var blocked = Terrain.crosses(u.p, target)
	for b in buildings.values():
		if Geometry2D.get_closest_point_to_segment(b.p, u.p, target).distance_to(b.p) < float(BUILD_DATA[b.kind].radius) + 0.6:
			blocked = true
			break
	if blocked:
		var route: Dictionary = paths.get(u.id, {})
		if route.is_empty() or route.version != navigation.version or route.target.distance_to(target) > 2.0:
			route = {"points": navigation.route(u.p, target), "target": target, "version": navigation.version, "index": 0}
			paths[u.id] = route
		if route.points.is_empty():
			return false
		if route.index < route.points.size():
			if u.p.distance_to(route.points[route.index]) < 0.65:
				route.index += 1
			if route.index < route.points.size():
				destination = route.points[route.index]
	else:
		paths.erase(u.id)
	var dir: Vector2 = (destination - u.p).normalized()
	# Local separation and circular building avoidance suit this open-field map.
	var repel = Vector2.ZERO
	for other in _nearby(u.p, 1.5):
		if other.id == u.id:
			continue
		var away: Vector2 = u.p - other.p
		var dist = away.length()
		if dist > 0.01 and dist < 0.9:
			repel += away / dist * (0.9 - dist) * 2.0
	for b in buildings.values():
		var away: Vector2 = u.p - b.p
		var dist = away.length()
		var radius: float = BUILD_DATA[b.kind].radius + 0.45
		if dist < radius + 0.9 and dist > 0.01:
			var normal = away / dist
			var tangent = Vector2(-normal.y, normal.x)
			if tangent.dot(dir) < 0:
				tangent = -tangent
			repel += normal * maxf(0, radius - dist) * 3.0 + tangent * (1.0 - maxf(0, normal.dot(dir)))
	dir = (dir + repel).normalized()
	var proposed: Vector2 = u.p + dir * minf(diff.length(), float(UNIT_DATA[u.kind].speed) * delta)
	if not Terrain.crosses(u.p, proposed):
		u.p = proposed
	u.p = Vector2(clampf(u.p.x, -57.5, 57.5), clampf(u.p.y, -57.5, 57.5))
	return false

func _nearby(pos: Vector2, radius: float) -> Array:
	if spatial.is_empty():
		return units.values()
	var result_units: Array = []
	var center = Vector2i(floori(pos.x / 4.0), floori(pos.y / 4.0))
	var extent = ceili(radius / 4.0)
	for x in range(center.x - extent, center.x + extent + 1):
		for y in range(center.y - extent, center.y + extent + 1):
			for id in spatial.get(Vector2i(x, y), []):
				if units.has(id):
					result_units.append(units[id])
	return result_units

func snapshot() -> Dictionary:
	return {"units": units.duplicate(true), "buildings": buildings.duplicate(true),
		"resources": resources.duplicate(true), "players": players.duplicate(true),
		"stock": stock.duplicate(), "elapsed": elapsed, "wave": wave,
		"next_wave": next_wave, "running": running, "result": result,
		"event_text": event_text, "event_serial": event_serial, "tick": tick,
		"difficulty": difficulty, "paused": paused, "upgrades": upgrades.duplicate(),
		"stats": stats.duplicate(), "events": events.duplicate(true), "effect_serial": effect_serial,
		"cleared_wave": cleared_wave, "rally": rally, "next_id": next_id, "rng_state": rng.state, "match_id": match_id}

func apply_snapshot(state: Dictionary) -> void:
	units = state.units
	buildings = state.buildings
	resources = state.resources
	players = state.players
	for player in players.values():
		if not player.has("skills"):
			player.skills = {"harvest": 0, "power": 0, "vitality": 0}
			player.skill_points = 0
	stock = state.stock
	elapsed = state.elapsed
	wave = state.wave
	next_wave = state.next_wave
	running = state.running
	result = state.result
	event_text = state.event_text
	event_serial = state.event_serial
	tick = state.tick
	match_id = state.get("match_id", 0)
	difficulty = state.get("difficulty", 1)
	paused = state.get("paused", false)
	upgrades = state.get("upgrades", {"weapons": false, "masonry": false})
	stats = state.get("stats", {"kills": 0, "lost": 0, "gathered": 0, "trained": 0, "built": 0})
	events = state.get("events", [])
	effect_serial = state.get("effect_serial", 0)
	cleared_wave = state.get("cleared_wave", 0)
	rally = state.get("rally", Vector2(0, -7))
	next_id = state.get("next_id", 1000)
	rng.state = state.get("rng_state", rng.state)
	paths.clear()
	spatial.clear()
	navigation.signature = ""
