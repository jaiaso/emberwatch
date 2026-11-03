extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Heroes=preload("res://scripts/heroes.gd")
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
	sim.running=true
	sim.next_wave=99999
	return sim
func sample(kind: String,owner: int=1) -> Dictionary:
	return {"kind":kind,"owner":owner}
func run() -> void:
	for key in Heroes.DATA:
		var sim=fresh()
		sim.hero_selection_required=true
		sim.step(1)
		check(sim.elapsed==0,"no preparation time lost before selecting")
		check(sim.command(1,"train",[],Vector2.ZERO,"soldier")!="","commands require hero")
		check(sim.command(1,"hero",[],Vector2.ZERO,key)=="","select "+key)
		var hero_id=int(sim.players[1].hero_unit)
		check(sim.units.has(hero_id) and sim.units[hero_id].kind==key and sim.units[hero_id].owner==1,"one hero exists at start")
		check(sim.population()==6,"hero does not consume ordinary population")
		check(sim.command(1,"hero",[],Vector2.ZERO,key)!="","cannot select twice")
		sim.add_player(2)
		check(sim.command(2,"hero",[],Vector2.ZERO,key)!="" and sim.players[2].hero=="","duplicate atomically rejected")
		check(sim.command(999,"hero",[],Vector2.ZERO,key)!="","unknown peer cannot choose")
		check(sim.command(2,"hero",[],Vector2.ZERO,"fake")!="","unknown hero rejected")
		var other="joan" if key!="joan" else "arthur"
		check(sim.choose_hero(2,other)=="" and sim.heroes_ready(),"distinct heroes accepted")
		var enemy=sim.spawn_unit("brute",Vector2(15,0),0)
		sim.units[enemy].guard=true
		sim.deal_damage(sim.units[enemy],99999,1)
		check(sim.players[1].hero_xp==45 and sim.players[2].hero_xp==0,"guard kill grants XP only to killer army owner")
		sim.deal_damage(sim.units[enemy],99999,1)
		check(sim.players[1].hero_xp==45,"dead enemy cannot grant XP twice")
		sim._award_hero_xp(1,15)
		check(sim.players[1].hero_level==2 and sim.players[1].hero_xp==60,"level threshold")
		check(sim.units[hero_id].max_hp>Sim.UNIT_DATA[key].hp,"level raises hero HP")
		sim._award_hero_xp(1,9999)
		check(sim.players[1].hero_level==6 and sim.players[1].hero_xp==700,"level and XP cap")
		var copied=Sim.new()
		copied.apply_snapshot(sim.snapshot())
		check(copied.players[1].hero==key and copied.players[1].hero_level==6 and copied.units[hero_id].max_hp==sim.units[hero_id].max_hp,"snapshot includes hero and growth")
		# Death during a preparation/guard expedition waits for the coming wave.
		sim.units[hero_id].hp=0
		sim.step(0.05)
		check(sim.players[1].hero_unit==-1 and sim.players[1].revive_wave==1 and not sim.units.has(hero_id),"hero death waits for wave one")
		sim.step(1)
		check(sim.players[1].hero_unit==-1,"no immediate resurrection during preparation")
		sim.wave=1
		sim.step(0.05)
		var revived=int(sim.players[1].hero_unit)
		check(revived!=hero_id and sim.units.has(revived) and sim.units[revived].hp==sim.units[revived].max_hp and sim.players[1].hero_level==6,"wave clear resurrects at full HP with growth")
		sim.players[1].skill_points=0
		sim.wave=2
		var last=sim.spawn_unit("raider",Vector2(50,50),0)
		sim.units[last].hp=0
		sim.units[revived].hp=0
		sim.step(0.05)
		check(sim.units.has(sim.players[1].hero_unit) and sim.players[1].revive_wave==-1,"hero dying on last-enemy tick revives same wave")
		sim.remove_player(1)
		check(sim.hero_owner(key)==-1 and sim.units.values().filter(func(u): return u.kind==key).is_empty(),"disconnect removes hero and releases unique choice")
	var sim=fresh()
	sim.choose_hero(1,"arthur")
	check(is_equal_approx(sim.unit_stats(sample("soldier")).damage,12) and sim.unit_stats(sample("soldier",2)).damage==10,"Arthur own swords only")
	sim._award_hero_xp(1,480)
	check(sim.unit_stats(sample("soldier")).armor>Sim.UNIT_DATA.soldier.armor,"Arthur level five defense unlock")
	var h: Dictionary=sim.units[sim.players[1].hero_unit]
	h.hp=100
	var e=sim.spawn_unit("brute",h.p+Vector2(1,0),0)
	sim._strike(h,sim.units[e],0.1)
	check(h.hp>100,"Arthur life steal")
	sim=fresh()
	sim.choose_hero(1,"joan")
	check(sim.unit_stats(sample("soldier")).armor>Sim.UNIT_DATA.soldier.armor and sim.unit_stats(sample("soldier",2)).armor==Sim.UNIT_DATA.soldier.armor,"Joan owner defense")
	h=sim.units[sim.players[1].hero_unit]
	var ally=sim.spawn_unit("soldier",h.p+Vector2(2,0),2)
	var far=sim.spawn_unit("soldier",Vector2(40,0),1)
	e=sim.spawn_unit("raider",h.p+Vector2(1,0),0)
	sim.units[ally].hp=50
	sim.units[far].hp=50
	sim.units[e].hp=50
	sim._heal_hero_auras(1)
	check(sim.units[ally].hp==52 and sim.units[far].hp==50 and sim.units[e].hp==50,"Joan heals nearby allies, not far units or enemies")
	sim._award_hero_xp(1,480)
	sim._heal_hero_auras(1)
	check(sim.units[far].hp==51,"Joan level five distant swords regen")
	h.hp=0
	var before: float=sim.units[ally].hp
	sim._heal_hero_auras(1)
	check(sim.units[ally].hp==before,"dead Joan aura stops")
	sim=fresh()
	sim.choose_hero(1,"iskandar")
	var id=sim.spawn_unit("cavalry",Vector2(10,0),1)
	var heavy=sim.unit_stats(sim.units[id])
	check(sim.units[id].kind=="heavy_cavalry" and heavy.damage>Sim.UNIT_DATA.cavalry.damage and heavy.armor>Sim.UNIT_DATA.cavalry.armor and heavy.speed<Sim.UNIT_DATA.cavalry.speed,"Iskandar heavy cavalry conversion and tradeoff")
	check(sim.spawn_unit("cavalry",Vector2(12,0),2)>0 and sim.production_kind(2,"cavalry")=="cavalry","conversion only own player")
	var stock: Dictionary=sim.stock.duplicate()
	sim.command(1,"train",[],Vector2.ZERO,"cavalry")
	sim.command(1,"cancel_train",[],Vector2.ZERO)
	check(sim.stock==stock,"converted cavalry cancellation refunds cost")
	sim.command(1,"train",[],Vector2.ZERO,"cavalry")
	sim.buildings[2].queue[0].left=0
	sim.step(0.05)
	check(sim.units.values().filter(func(u): return u.kind=="heavy_cavalry").size()==2,"actual training produces heavy cavalry")
	sim=fresh()
	sim.choose_hero(1,"kenshin")
	var cav=sim.unit_stats(sample("cavalry"))
	check(cav.damage>17 and cav.speed>4.5 and Sim.UNIT_DATA.kenshin.speed>cav.speed,"Kenshin speed and attack passive")
	sim._award_hero_xp(1,480)
	check(sim.unit_stats(sample("cavalry")).armor>0.22,"Kenshin defense unlock")
	sim=fresh()
	sim.choose_hero(1,"yoichi")
	check(sim.unit_stats(sample("archer")).range==10 and sim.unit_stats(sample("archer",2)).range==8,"Yoichi only own archer range")
	h=sim.units[sim.players[1].hero_unit]
	e=sim.spawn_unit("raider",h.p+Vector2(12,0),0)
	sim._strike(h,sim.units[e],0.1)
	check(sim.units[e].hp<85,"Yoichi actually attacks beyond normal archer range")
	sim=fresh()
	sim.choose_hero(1,"himiko")
	check(sim.units.values().filter(func(u): return u.kind=="mage" and u.owner==1).size()==1,"Himiko converts starting archer")
	var mage=sim.spawn_unit("archer",Vector2(20,0),1)
	check(sim.units[mage].kind=="mage" and Sim.UNIT_DATA.mage.damage>15 and Sim.UNIT_DATA.mage.speed<2.5 and Sim.UNIT_DATA.mage.armor<0.05,"mage conversion and tradeoffs")
	sim._award_hero_xp(1,480)
	h=sim.units[sim.players[1].hero_unit]
	e=sim.spawn_unit("raider",h.p+Vector2(4,0),0)
	var splash=sim.spawn_unit("raider",h.p+Vector2(4,1),0)
	sim._strike(h,sim.units[e],0.1)
	check(sim.units[splash].hp<85 and sim.events[-1].kind=="fire","Himiko flame and splash unlock")
	e=sim.spawn_unit("raider",Vector2(24,0),0)
	splash=sim.spawn_unit("raider",Vector2(24,1),0)
	sim._strike(sim.units[mage],sim.units[e],0.1)
	check(sim.units[splash].hp<85,"level five mage splash")
	var copy=Sim.new()
	copy.apply_snapshot(sim.snapshot())
	check(copy.production_kind(1,"archer")=="mage" and copy.players[1].hero_xp==480,"conversion persists across snapshot")
	# Corner cases around queues, final-wave resurrection and faction effects.
	sim=fresh()
	sim.command(1,"train",[],Vector2.ZERO,"archer")
	sim.choose_hero(1,"himiko")
	sim.buildings[2].queue[0].left=0
	sim.step(0.05)
	check(sim.units.values().filter(func(u): return u.kind=="mage").size()==2,"hero choice also converts jobs queued earlier")
	check(sim.command(1,"train",[],Vector2.ZERO,"himiko")!="","hero cannot be mass produced")
	sim=fresh()
	sim.choose_hero(1,"kenshin")
	sim._award_hero_xp(1,160)
	h=sim.units[sim.players[1].hero_unit]
	e=sim.spawn_unit("brute",h.p+Vector2(1,0),0)
	sim._strike(h,sim.units[e],0.05)
	check(is_equal_approx(h.cool,0.65),"Kenshin level three actual attack interval")
	sim=fresh()
	sim.choose_hero(1,"arthur")
	h=sim.units[sim.players[1].hero_unit]
	sim.wave=6
	sim.cleared_wave=5
	h.hp=0
	sim.step(0.05)
	check(sim.result=="victory" and sim.units.has(sim.players[1].hero_unit),"final-wave clear also revives hero before victory")
	sim=fresh()
	sim.choose_hero(1,"arthur")
	sim.wave=1
	sim.units[sim.players[1].hero_unit].hp=0
	sim.buildings[1].hp=0
	sim.step(0.05)
	check(sim.result=="defeat" and sim.players[1].hero_unit==-1,"fallen hall prevents resurrection")
	sim=fresh()
	sim.choose_hero(1,"joan")
	sim.hero_selection_required=true
	sim.add_player(2)
	var before_time: float=sim.elapsed
	sim.step(0.05)
	check(sim.elapsed>before_time and sim.command(2,"train",[],Vector2.ZERO,"worker")!="","late unselected player does not freeze allies but must choose before orders")
	var shield=sim.spawn_unit("soldier",Vector2(40,0),1)
	var armor: float=sim.unit_stats(sim.units[shield]).armor
	sim.units[sim.players[1].hero_unit].hp=0
	sim.step(0.05)
	check(sim.unit_stats(sim.units[shield]).armor==armor,"army passive remains while hero awaits resurrection")
	sim=fresh()
	sim.choose_hero(1,"joan")
	h=sim.units[sim.players[1].hero_unit]
	ally=sim.spawn_unit("soldier",h.p+Vector2(2,0),2)
	sim.units[ally].hp=50
	sim.paused=true
	sim.step(1)
	check(sim.units[ally].hp==50,"pause stops hero healing aura")
	sim=fresh()
	sim.choose_hero(1,"yoichi")
	sim.units[sim.players[1].hero_unit].hp=0
	sim.wave=1
	sim.cleared_wave=1
	sim.step(0.05)
	check(sim.players[1].revive_wave==2,"death between waves waits for next clear")
	sim._award_hero_xp(1,160)
	check(sim.players[1].hero_level==3,"army can earn experience while hero is dead")
	sim.wave=2
	sim.step(0.05)
	check(sim.units[sim.players[1].hero_unit].max_hp>Sim.UNIT_DATA.yoichi.hp,"revival applies levels earned while dead")
	print("HEROES_TEST ",checks-failures.size(),"/",checks," PASS ",failures)
	quit(0 if failures.is_empty() else 1)
