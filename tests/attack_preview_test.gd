extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var count=0
var failures=[]
func check(ok: bool,label: String) -> void:
	count+=1
	if not ok:
		failures.append(label)
		push_error(label)
func _initialize() -> void:
	var sim=Sim.new()
	sim.reset()
	sim.add_player(1)
	check(sim.incoming_attack().is_empty(),"no preview in lobby")
	sim.running=true
	for number in range(1,7):
		sim.wave=number-1
		sim.units.clear()
		var preview: Dictionary=sim.incoming_attack()
		check(preview.wave==number and preview.direction==["北西","北東","南東","南西","北西","北東"][number-1],"correct wave direction")
		var client=Sim.new()
		client.apply_snapshot(sim.snapshot())
		check(client.incoming_attack()==preview,"same preview after synchronization/save")
		sim._spawn_wave()
		check(sim.units.values().all(func(u): return absf(u.p.x-preview.origin.x)<=3.001 and absf(u.p.y-preview.origin.y)<=3.001),"spawn matches preview origin")
		check(sim.incoming_attack().is_empty(),"no preview while enemies remain")
		sim.units.clear()
	sim.wave=6
	check(sim.incoming_attack().is_empty(),"no seventh wave")
	sim.wave=1
	sim.paused=true
	check(sim.incoming_attack().direction=="北東","preview stays visible while paused")
	sim.result="defeat"
	check(sim.incoming_attack().is_empty(),"no preview after defeat")
	print("ATTACK_PREVIEW_TEST ",count-failures.size(),"/",count," PASS ",failures)
	quit(0 if failures.is_empty() else 1)
