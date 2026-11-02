extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=[]
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		push_error(label)
func fresh():
	var sim=Sim.new()
	sim.reset()
	sim.add_player(1)
	sim.units.clear()
	sim.running=true
	sim.next_wave=99999
	return sim
func run() -> void:
	var data=Sim.UNIT_DATA
	check(data.soldier.armor>data.cavalry.armor and data.cavalry.armor>data.archer.armor,"shield has highest armor, cavalry balanced")
	check(data.soldier.damage<data.cavalry.damage and data.soldier.damage<data.archer.damage,"shield sacrifices damage")
	check(data.cavalry.speed>data.soldier.speed and data.soldier.speed>data.archer.speed,"cavalry fast and archer slower than shield")
	check(data.archer.range>data.cavalry.range and data.archer.range>data.soldier.range,"archer has ranged advantage")
	check(data.cavalry.cost.food>data.soldier.cost.food and data.cavalry.cost.gold>data.soldier.cost.gold and Sim.TRAIN_TIME.cavalry>Sim.TRAIN_TIME.soldier,"mounted unit pays higher cost and training time")
	var sim=fresh()
	for kind in ["worker","soldier","archer","cavalry"]:
		var id=sim.spawn_unit(kind,Vector2(5,0),1)
		var u: Dictionary=sim.units[id]
		var hp: float=u.hp
		var actual: float=sim.deal_damage(u,20)
		check(is_equal_approx(actual,20*(1-data[kind].get("armor",0))),"armor affects actual damage")
		check(is_equal_approx(hp-u.hp,actual) and u.last_hit_at==sim.elapsed,"damage records health and combat timer")
		var damaged: float=u.hp
		sim._heal_near_hall(u,1.0)
		check(u.hp==damaged,"healing blocked immediately after a hit")
		sim.elapsed+=5
		sim._heal_near_hall(u,1.0)
		check(is_equal_approx(u.hp,minf(u.max_hp,damaged+4)),"four HP recovered after delay inside base")
		u.hp=u.max_hp-1
		sim._heal_near_hall(u,1.0)
		check(u.hp==u.max_hp,"healing capped at max HP")
		u.hp=u.max_hp-20
		u.p=Vector2(8.1,0)
		sim._heal_near_hall(u,1.0)
		check(u.hp==u.max_hp-20,"outside healing radius")
		u.p=Vector2(5,0)
		u.hp=0
		sim._heal_near_hall(u,1.0)
		check(u.hp==0,"healing never resurrects dead units")
	var enemy=sim.spawn_unit("raider",Vector2(5,0),0)
	sim.units[enemy].hp=10
	sim._heal_near_hall(sim.units[enemy],1)
	check(sim.units[enemy].hp==10,"base does not heal enemies")
	sim=fresh()
	var cavalry=sim.spawn_unit("cavalry",Vector2(5,0),1)
	var u: Dictionary=sim.units[cavalry]
	u.hp=50
	sim.buildings[1].progress=0.5
	sim._heal_near_hall(u,1)
	check(u.hp==50,"unfinished hall does not heal")
	sim.buildings[1].progress=1
	sim.buildings[1].hp=0
	sim._heal_near_hall(u,1)
	check(u.hp==50,"destroyed hall does not heal")
	sim.buildings[1].hp=1000
	sim.paused=true
	sim.step(1)
	check(u.hp==50,"pause stops healing")
	sim.paused=false
	sim.add_player(2)
	var ally=sim.spawn_unit("soldier",Vector2(-5,0),2)
	sim.units[ally].hp=50
	sim._heal_near_hall(sim.units[ally],1)
	check(sim.units[ally].hp==54,"base heals ally players too")
	var money: Dictionary=sim.stock.duplicate()
	check(sim.command(1,"train",[],Vector2.ZERO,"cavalry")=="","mounted production accepted")
	check(sim.stock.food==money.food-110 and sim.stock.gold==money.gold-70 and sim.queued_population()==1,"mounted production pays cost and reserves population")
	sim.command(1,"cancel_train",[],Vector2.ZERO)
	check(sim.stock==money and sim.queued_population()==0,"cancel cavalry refunds exact cost")
	sim.stock.food=109
	var before=sim.stock.duplicate()
	check(sim.command(1,"train",[],Vector2.ZERO,"cavalry")!="" and sim.stock==before,"insufficient cavalry cost rejected atomically")
	var copy=Sim.new()
	copy.apply_snapshot(sim.snapshot())
	check(copy.units[cavalry].hp==u.hp and copy.units[cavalry].last_hit_at==u.last_hit_at,"mounted healing state survives synchronization")
	# Exercise actual enemy attack through armor, including wave scaling.
	sim=fresh()
	var shield=sim.spawn_unit("soldier",Vector2(12,0),1)
	enemy=sim.spawn_unit("raider",Vector2(13,0),0)
	sim.units[enemy].wave_power=1.35
	var hp: float=sim.units[shield].hp
	sim._strike(sim.units[enemy],sim.units[shield],0.05)
	check(is_equal_approx(hp-sim.units[shield].hp,10*1.35*0.55),"enemy wave damage respects shield armor")
	var travelled={}
	for kind in ["soldier","archer","cavalry"]:
		var movement=fresh()
		var id=movement.spawn_unit(kind,Vector2(12,-10),1)
		movement.navigation.rebuild(movement.buildings,Sim.BUILD_DATA)
		movement._move(movement.units[id],Vector2(20,-10),1.0)
		travelled[kind]=movement.units[id].p.distance_to(Vector2(12,-10))
	check(travelled.cavalry>travelled.soldier and travelled.soldier>travelled.archer,"actual movement speeds follow roles")
	sim=fresh()
	var archer=sim.spawn_unit("archer",Vector2(12,-10),1)
	enemy=sim.spawn_unit("raider",Vector2(18,-10),0)
	sim._strike(sim.units[archer],sim.units[enemy],0.05)
	check(sim.units[enemy].hp==70 and sim.units[archer].p==Vector2(12,-10),"archer attacks at range without advancing")
	print("ROLES_HEAL_TEST ",checks-failures.size(),"/",checks," PASS ",failures)
	quit(0 if failures.is_empty() else 1)
