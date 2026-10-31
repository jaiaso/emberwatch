extends SceneTree

var session
var role = "host"
var clock = 0.0
var sent = false
var own = -1
var host_unit = -1
var host_target = Vector2.ZERO
var client_moves = 0
var client_baseline = {}
var disconnect_seen = false
var done = false

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	if not args.is_empty():
		role = args[0]
	call_deferred("begin")

func begin() -> void:
	session = root.get_node("Session")
	session.changed.connect(func(): print("NETWORK_STATUS ", role, " ", session.mode, " ", session.status, " peers=", session.sim.players.size()))
	if role == "host":
		session.host()
		if session.mode != "host":
			push_error("NETWORK_HOST_BIND_FAILED")
			quit(1)
	else:
		session.join("127.0.0.1")

func _process(delta: float) -> bool:
	clock += delta
	if session == null:
		return false
	if done:
		if clock > 11.0:
			quit(0)
		return false
	if clock > 18.0:
		push_error("NETWORK_TIMEOUT role=" + role)
		quit(1)
		return false
	if role == "host":
		if not sent and session.sim.players.size() == 4:
			for u in session.sim.units.values():
				if u.owner == 1:
					host_unit = u.id
					host_target = u.target
				for id in session.sim.players:
					if id != 1 and not client_baseline.has(id) and u.owner == id:
						client_baseline[id] = u.p
			for player in session.sim.players.values():
				player.skill_points = 1
			session.start()
			# Exercise multi-packet snapshots with a full late-game enemy wave.
			session.sim.wave = 5
			session.sim.next_wave = 0.0
			sent = true
		if sent and clock > 9.0:
			var owners: Array = []
			for u in session.sim.units.values():
				if u.owner != 1 and u.order == "move" and not owners.has(u.owner):
					owners.append(u.owner)
			var skilled = 0
			for id in session.sim.players:
				if id != 1 and session.sim.players[id].skills.power == 1 and session.sim.players[id].skill_points == 0:
					skilled += 1
			var passed = skilled == 3 and owners.size() == 3 and session.sim.units[host_unit].target == host_target and session.sim.tick > 60
			print("NETWORK_HOST four_peers=", session.sim.players.size(), " authorized_clients=", owners.size(), " ownership_protected=", session.sim.units[host_unit].target == host_target, " enemies=", session.sim.enemies_left(), " tick=", session.sim.tick, " PASS=", passed)
			quit(0 if passed else 1)
	else:
		if not sent and session.mode == "client" and session.sim.running and session.sim.players.size() == 4:
			for u in session.sim.units.values():
				if u.owner == session.local_id:
					own = u.id
					break
			for u in session.sim.units.values():
				if u.owner == 1:
					host_unit = u.id
					host_target = u.target
					break
			# The server must reject this forged attempt to control the host's unit.
			session.issue("move", [host_unit], Vector2(-29, 25))
			session.issue("move", [own], Vector2(25, 20))
			session.issue("skill", [], Vector2.ZERO, "power")
			sent = true
		if sent and clock > 7.0:
			var passed = session.sim.players[session.local_id].skills.power == 1 and session.sim.players[session.local_id].skill_points == 0 and session.sim.tick > 50 and session.sim.units[own].order == "move" and session.sim.units[host_unit].target == host_target and session.sim.units[own].p.distance_to(Vector2(25, 20)) < 30.0
			print("NETWORK_CLIENT ", role, " peer=", session.local_id, " tick=", session.sim.tick, " own_order=", session.sim.units[own].order, " PASS=", passed)
			# Remain connected until the host has checked all three owners.
			if not passed:
				quit(1)
			done = true
	return false
