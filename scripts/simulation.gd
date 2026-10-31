extends RefCounted
## The host alone advances this simulation. Clients only submit intents.

const MAP_HALF = 39.0
const WAVE_COUNT = 6
const WAVE_INTERVAL = 70.0
const UNIT_DATA = {
	"worker": {"hp": 55.0, "speed": 3.0, "range": 1.4, "damage": 4.0, "cost": {"food": 45}},
	"soldier": {"hp": 125.0, "speed": 2.8, "range": 1.6, "damage": 18.0, "cost": {"food": 55, "gold": 20}},
	"archer": {"hp": 65.0, "speed": 3.1, "range": 8.0, "damage": 12.0, "cost": {"wood": 45, "gold": 25}},
	"raider": {"hp": 85.0, "speed": 2.3, "range": 1.7, "damage": 10.0, "cost": {}},
	"brute": {"hp": 270.0, "speed": 1.6, "range": 2.2, "damage": 23.0, "cost": {}},
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

func reset() -> void:
	units.clear()
	buildings.clear()
	resources.clear()
	players.clear()
	stock = {"food": 280, "wood": 320, "gold": 180}
	elapsed = 0.0
	wave = 0
	next_wave = WAVE_INTERVAL
	running = false
	result = ""
	next_id = 1
	tick = 0
	event_serial = 0
	event_text = "森を拓き、夜明けまで砦を守れ。"
	rng.seed = 1989
	_spawn_building("hall", Vector2.ZERO, 0, true)
	_spawn_building("barracks", Vector2(7, 3), 0, true)
	for cluster in [Vector2(-13, -8), Vector2(15, -13), Vector2(-18, 13), Vector2(20, 14)]:
		for i in range(12):
			_add_resource("wood", cluster + Vector2(rng.randf_range(-5, 5), rng.randf_range(-5, 5)), 160)
	for cluster in [Vector2(-9, 5), Vector2(10, -7)]:
		for i in range(5):
			_add_resource("food", cluster + Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-2.5, 2.5)), 150)
	for cluster in [Vector2(3, 12), Vector2(-15, -18)]:
		for i in range(4):
			_add_resource("gold", cluster + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2)), 240)

func _id() -> int:
	var value = next_id
	next_id += 1
	return value

func _add_resource(kind: String, pos: Vector2, amount: int) -> void:
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
	players[peer_id] = {"slot": slot, "name": "盟友 %d" % (slot + 1)}
	var base = Vector2(-3, -4).rotated(float(slot) * TAU / 4.0)
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
	announce("盟友が離脱。部隊の指揮をホストに移譲しました。")

func spawn_unit(kind: String, pos: Vector2, owner: int) -> int:
	var id = _id()
	var data: Dictionary = UNIT_DATA[kind]
	units[id] = {"id": id, "kind": kind, "owner": owner, "p": pos, "hp": data.hp,
		"max_hp": data.hp, "target": pos, "order": "idle", "resource": -1,
		"enemy": -1, "cool": 0.0, "gather": 0.0, "anim": 0.0}
	return id

func _spawn_building(kind: String, pos: Vector2, owner: int, complete: bool) -> int:
	var id = _id()
	var data: Dictionary = BUILD_DATA[kind]
	buildings[id] = {"id": id, "kind": kind, "owner": owner, "p": pos,
		"hp": data.hp, "max_hp": data.hp, "progress": 1.0 if complete else 0.01, "cool": 0.0}
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
				if action == "gather" and u.kind != "worker":
					continue
				u.order = action if action != "stop" else "idle"
				u.resource = target_id if action == "gather" else -1
				u.enemy = target_id if action == "attack" else -1
				u.gather = 0.0
				var offset = Vector2(index % 5 - mini(owned.size() - 1, 4) * 0.5, index / 5) * 1.25
				u.target = Vector2(clampf(pos.x + offset.x, -37, 37), clampf(pos.y + offset.y, -37, 37))
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
			if population() >= capacity():
				return "人口上限です。家を建ててください。"
			var producer = {}
			for b in buildings.values():
				if b.kind == ("hall" if extra == "worker" else "barracks") and b.progress >= 1.0:
					producer = b
					break
			if producer.is_empty():
				return "完成した生産施設が必要です。"
			if float(producer.cool) > 0.0:
				return "施設は準備中です。少し待ってください。"
			if not can_afford(UNIT_DATA[extra].cost):
				return "共有資源が足りません。"
			_spend(UNIT_DATA[extra].cost)
			spawn_unit(extra, producer.p + Vector2(0, 3.7) + Vector2(rng.randf_range(-1, 1), 0), sender)
			producer.cool = 1.5
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

func step(delta: float) -> void:
	if not running or result != "":
		return
	tick += 1
	elapsed += delta
	if wave < WAVE_COUNT and elapsed >= next_wave:
		_spawn_wave()
	for b in buildings.values():
		b.cool = maxf(0.0, b.cool - delta)
		if b.kind == "tower" and b.progress >= 1.0 and b.cool <= 0.0:
			var victim = _nearest_enemy(b.p, 11.0, true)
			if victim != -1:
				units[victim].hp -= 27.0
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
			if units[id].owner == 0:
				stock.gold += 4 if units[id].kind == "raider" else 15
			units.erase(id)
	for id in buildings.keys():
		if buildings[id].hp <= 0:
			buildings.erase(id)
	if not buildings.has(1):
		result = "defeat"
		running = false
		announce("中央砦が陥落した。火は、また灯せる。")
	elif wave == WAVE_COUNT and enemies_left() == 0:
		result = "victory"
		running = false
		announce("夜明けだ。砦は守られた。")

func _spawn_wave() -> void:
	wave += 1
	next_wave = elapsed + WAVE_INTERVAL
	var side = (wave - 1) % 4
	var origin: Vector2 = [Vector2(-34, -29), Vector2(33, -28), Vector2(31, 33), Vector2(-32, 30)][side]
	var count = (5 + wave * 3) * maxi(1, players.size())
	count = mini(count, 80)
	for i in range(count):
		var kind = "brute" if wave >= 3 and i % 7 == 0 else "raider"
		spawn_unit(kind, origin + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)), 0)
	announce("第 %d 波 ／ %sから敵襲！" % [wave, ["北西", "北東", "南東", "南西"][side]])

func _nearest_enemy(pos: Vector2, radius: float, hostile: bool) -> int:
	var nearest = -1
	var distance = radius
	for other in units.values():
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
		target.hp -= float(UNIT_DATA[u.kind].damage)
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
				var amount = mini(5, resource.amount)
				resource.amount -= amount
				stock[resource.kind] += amount
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
	var dir = diff.normalized()
	# Local separation and circular building avoidance suit this open-field map.
	var repel = Vector2.ZERO
	for other in units.values():
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
	u.p += dir * minf(diff.length(), float(UNIT_DATA[u.kind].speed) * delta)
	u.p = Vector2(clampf(u.p.x, -37.5, 37.5), clampf(u.p.y, -37.5, 37.5))
	return false

func snapshot() -> Dictionary:
	return {"units": units.duplicate(true), "buildings": buildings.duplicate(true),
		"resources": resources.duplicate(true), "players": players.duplicate(true),
		"stock": stock.duplicate(), "elapsed": elapsed, "wave": wave,
		"next_wave": next_wave, "running": running, "result": result,
		"event_text": event_text, "event_serial": event_serial, "tick": tick}

func apply_snapshot(state: Dictionary) -> void:
	units = state.units
	buildings = state.buildings
	resources = state.resources
	players = state.players
	stock = state.stock
	elapsed = state.elapsed
	wave = state.wave
	next_wave = state.next_wave
	running = state.running
	result = state.result
	event_text = state.event_text
	event_serial = state.event_serial
	tick = state.tick
