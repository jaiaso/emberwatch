extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var sim=Sim.new()
	sim.reset()
	sim.add_player(1)
	sim.running=true
	var start=Time.get_ticks_msec()
	var report=0
	for tick in range(66000):
		if tick%20==0:
			if sim.players[1].skill_points>0:
				sim.command(1,"skill",[],Vector2.ZERO,"power" if sim.players[1].skills.power<3 else "vitality")
			var workers=[]
			var army=[]
			for u in sim.units.values():
				if u.owner==1:
					if u.kind=="worker":
						workers.append(u.id)
					else:
						army.append(u.id)
			var safe={}
			for camp in sim.camps.values():
				safe[camp.id]=sim.camp_guards(camp.id)==0
			for index in range(workers.size()):
				var u: Dictionary=sim.units[workers[index]]
				if u.order=="idle":
					var kind=["food","wood","gold","food"][index%4]
					var nearest={}
					var distance=INF
					for res in sim.resources.values():
						if res.amount>0 and res.kind==kind and safe[res.camp] and u.p.distance_to(res.p)<distance:
							distance=u.p.distance_to(res.p)
							nearest=res
					if not nearest.is_empty():
						sim.command(1,"gather",[u.id],nearest.p,str(nearest.id))
			if workers.size()+sim.buildings[1].queue.size()<10:
				sim.command(1,"train",[],Vector2.ZERO,"worker")
			sim.command(1,"train",[],Vector2.ZERO,"archer" if tick%60==0 else "soldier")
			var houses=0
			var towers=0
			var barracks=0
			for b in sim.buildings.values():
				houses+=int(b.kind=="house")
				towers+=int(b.kind=="tower")
				barracks+=int(b.kind=="barracks")
			var build="house" if houses<6 and sim.population()+sim.queued_population()>sim.capacity()-6 else "barracks" if sim.wave>=1 and barracks<2 else "tower" if towers<4 else ""
			if build!="" and sim.can_afford(Sim.BUILD_DATA[build].cost):
				var placed=false
				for x in [-7,7,-12,12,-17,17]:
					for y in [-7,7,0,-12,12]:
						var pos=Vector2(x,y)
						if placed or not sim.valid_site(build,pos):
							continue
						for id in workers:
							if sim.units[id].order!="construct" and sim.units[id].p.distance_to(pos)<14:
								placed=sim.command(1,"build",[id],pos,build)==""
								break
			if army.size()>8:
				sim.command(1,"research",[],Vector2.ZERO,"weapons")
			if sim.wave>=1:
				sim.command(1,"research",[],Vector2.ZERO,"masonry")
			var target=-1
			var distance=INF
			for u in sim.units.values():
				if u.owner==0 and not u.get("guard",false) and u.p.length()<distance:
					distance=u.p.length()
					target=u.id
			if target==-1 and army.size()>=8 and sim.next_wave-sim.elapsed>65:
				var kind="food" if sim.stock.food<700 else "gold" if sim.stock.gold<500 else "wood"
				for u in sim.units.values():
					if u.get("guard",false) and sim.camps[u.camp].kind==kind and u.p.length()<distance:
						distance=u.p.length()
						target=u.id
			if target!=-1:
				sim.command(1,"attack",army,sim.units[target].p,str(target))
			elif sim.next_wave-sim.elapsed<65:
				sim.command(1,"attack_move",army,Vector2.ZERO)
			if sim.buildings[1].hp<sim.buildings[1].max_hp-220:
				sim.command(1,"repair",[],Vector2.ZERO)
		sim.step(0.05)
		if sim.wave>report:
			report=sim.wave
			print("MATCH_WAVE ",report," time=",sim.elapsed," army=",sim.population()," stock=",sim.stock," kills=",sim.stats.kills)
		if sim.result!="":
			break
	print("MATCH_TEST result=",sim.result," waves=",sim.wave," kills=",sim.stats.kills," elapsed=",sim.elapsed," army=",sim.population()," enemies=",sim.enemies_left()," wall_ms=",Time.get_ticks_msec()-start)
	quit(0 if sim.result=="victory" else 1)
