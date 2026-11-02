extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var sim=Sim.new()
	sim.reset()
	sim.add_player(1)
	check(sim.next_wave==300 and sim.camps.size()==20,"five minute start and twenty resource camps")
	var totals={1:{},2:{},3:{}}
	for camp in sim.camps.values():
		check(sim.camp_amount(camp.id)>0,"nonempty camp")
		check((sim.camp_guards(camp.id)==0)==(camp.tier==1),"near camps safe and distant camps guarded")
		var count=0
		for res in sim.resources.values():
			if res.camp==camp.id:
				count+=1
				check(not Sim.Terrain.blocked(res.p,2.0) and absf(res.p.x)<=55 and absf(res.p.y)<=55,"resource inside playable free terrain")
		totals[camp.tier][camp.kind]=maxi(totals[camp.tier].get(camp.kind,0),count)
	for kind in ["wood","food","gold"]:
		check(totals[3].get(kind,0)>totals[1].get(kind,0) and (not totals[2].has(kind) or totals[2][kind]>totals[1][kind]),"distant camps occupy larger areas")
		var amount={}
		for res in sim.resources.values():
			if res.kind==kind:
				amount[res.tier]=res.max_amount
		check(amount[3]>amount[1] and (not amount.has(2) or (amount[3]>amount[2] and amount[2]>amount[1])),"distant deposits richer per node")
	sim.running=true
	check(sim.enemies_left()==0 and not sim.incoming_attack().is_empty(),"guards do not block preparation preview")
	var guard={}
	for u in sim.units.values():
		if u.get("guard",false):
			guard=u
			break
	var hall_hp: float=sim.buildings[1].hp
	for i in range(300):
		sim.step(0.05)
	check(sim.buildings[1].hp==hall_hp and guard.p.distance_to(guard.home)<12,"idle guards stay at camps and never raid hall")
	var attacker=sim.spawn_unit("soldier",guard.p+Vector2(0.5,0),1)
	sim.units[attacker].hp=10000
	var hp: float=sim.units[attacker].hp
	sim.spatial.clear()
	sim._step_guard(guard,0.05)
	check(sim.units[attacker].hp<hp,"guard attacks intruder")
	sim.units[attacker].p=guard.home+Vector2(19,0)
	guard.p=guard.home+Vector2(13,0)
	sim.navigation.rebuild(sim.buildings,Sim.BUILD_DATA)
	sim.spatial.clear()
	var before: float=guard.p.distance_to(guard.home)
	sim._step_guard(guard,0.1)
	check(guard.p.distance_to(guard.home)<before,"guard returns home instead of chasing indefinitely")
	var copy=Sim.new()
	copy.apply_snapshot(sim.snapshot())
	check(copy.camps==sim.camps and copy.units[guard.id].home==guard.home,"camp and guard state survives snapshot/save")
	# Isolate the countdown boundary without waiting five real minutes.
	sim=Sim.new()
	sim.reset()
	sim.add_player(1)
	sim.running=true
	sim.elapsed=299.90
	sim.step(0.05)
	check(sim.wave==0,"wave never starts before five minutes")
	sim.step(0.06)
	check(sim.wave==1 and sim.enemies_left()==16,"first wave starts at five minutes despite living guards")
	for id in sim.units.keys():
		if sim.units[id].owner==0 and not sim.units[id].get("guard",false):
			sim.units.erase(id)
	sim.step(0.05)
	check(is_equal_approx(sim.next_wave-sim.elapsed,300),"full five minutes begins after clearance")
	check(sim.players[1].skill_points==1 and sim.cleared_wave==1,"living guards do not block wave rewards")
	sim.command(1,"skill",[],Vector2.ZERO,"power")
	sim.elapsed=sim.next_wave-0.1
	sim.step(0.05)
	check(sim.wave==1,"intermission lasts five minutes")
	sim.step(0.06)
	check(sim.wave==2,"second wave starts at end of intermission")
	sim.units=sim.units.duplicate(true)
	for id in sim.units.keys():
		if sim.units[id].owner==0 and not sim.units[id].get("guard",false):
			sim.units.erase(id)
	sim.wave=6
	sim.step(0.05)
	check(sim.result=="victory" and sim.units.values().any(func(u): return u.get("guard",false)),"victory ignores surviving resource guards")
	var session=root.get_node("Session")
	for level in range(3):
		session.solo(level)
		check(session.sim.next_wave==300,"all difficulties start with five minute preparation")
		var first_guard={}
		for unit in session.sim.units.values():
			if unit.get("guard",false):
				first_guard=unit
				break
		check(is_equal_approx(first_guard.max_hp,Sim.UNIT_DATA[first_guard.kind].hp*[0.78,1.0,1.25][level]),"new camp guards use chosen difficulty")
	session.rematch()
	check(session.sim.next_wave==300,"rematch resets five minute timer")
	print("EXPEDITION_TEST ",checks-failures.size(),"/",checks," PASS ",failures)
	quit(0 if failures.is_empty() else 1)
