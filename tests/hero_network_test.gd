extends SceneTree
var session
var role="host"
var clock=0.0
var phase=0
var phase_at=0.0
var duplicate_rejected=false
var saw_growth=false
var saw_dead=false
var saw_revived=false
var original_hero=-1
var sentinel=-1
var done=false
var initial_match=-1
var saw_rematch=false
var acknowledged=0
var choices={"host":"arthur","c1":"joan","c2":"iskandar","c3":"himiko"}
func _initialize() -> void:
	role=OS.get_cmdline_user_args()[0]
	call_deferred("begin")
func begin() -> void:
	session=root.get_node("Session")
	session.allow_autosave=false
	session.changed.connect(func(): print("NET_STATE ",role," ",session.mode," ",session.status," players=",session.sim.players.size()))
	session.message.connect(func(text):
		if "選択済み" in text: duplicate_rejected=true)
	if role=="host":
		session.host()
		session.issue("hero",[],Vector2.ZERO,"arthur")
	else:
		session.join("127.0.0.1")
func finish(ok: bool) -> void:
	print("HERO_NETWORK ",role," duplicate=",duplicate_rejected," growth=",saw_growth," dead=",saw_dead," revived=",saw_revived," rematch=",saw_rematch," state=",session.mode,"/",session.sim.running,"/",session.sim.tick," player=",session.sim.players.get(session.local_id,{})," PASS=",ok)
	session.back_to_menu()
	quit(0 if ok else 1)
func _process(delta: float) -> bool:
	clock+=delta
	if session==null: return false
	if clock>45:
		finish(false)
		return false
	var sim=session.sim
	if done and session.mode=="menu":
		finish(true)
		return false
	if role=="host":
		if phase==0 and sim.players.size()==4:
			session.start()
			if sim.running:
				finish(false)
				return false
			phase=1
		if phase==1 and sim.heroes_ready():
			session.start()
			initial_match=sim.match_id
			sim.next_wave=99999
			sim.wave=1
			sentinel=sim.spawn_unit("raider",Vector2(55,55),0)
			for owner in sim.players:
				sim.players[owner].skill_points=3
				for i in range(4):
					var enemy=sim.spawn_unit("brute",Vector2(50,50),0)
					sim.units[enemy].guard=true
					sim.deal_damage(sim.units[enemy],99999,owner)
			phase=2
			phase_at=clock
			sim.players[1].skills.power=1
		if phase==2 and sim.players.values().all(func(p): return p.skills.power>=1):
			for player in sim.players.values():
				sim.units[player.hero_unit].hp=0
			sim.players[1].skills.power=2
			phase=3
			phase_at=clock
		if phase==3 and sim.players.values().all(func(p): return p.skills.power>=2):
			sim.units[sentinel].hp=0
			phase=4
			phase_at=clock
			sim.players[1].skills.power=3
		if phase==4 and sim.players.values().all(func(p): return p.skills.power>=3):
			var passed=sim.players.size()==4 and sim.cleared_wave==1
			var selected=[]
			for player in sim.players.values():
				passed=passed and player.hero_level==3 and player.hero_xp==180 and sim.units.has(player.hero_unit) and player.hero not in selected
				selected.append(player.hero)
			print("HERO_NETWORK_HOST unique_growth_revive PASS=",passed)
			if not passed:
				finish(false)
				return false
			sim.result="victory"
			sim.running=false
			session.rematch()
			session.issue("hero",[],Vector2.ZERO,"arthur")
			phase=5
			phase_at=clock
		if phase==5 and sim.heroes_ready():
			for player in sim.players.values(): player.skill_points=1
			sim.players[1].skills.harvest=1
			session.start()
			phase=6
			phase_at=clock
		if phase==6 and sim.players.values().all(func(p): return p.skills.harvest==1) and clock-phase_at>1:
			var passed=sim.players.size()==4 and sim.running and sim.match_id!=initial_match
			for player in sim.players.values():
				passed=passed and player.hero_level==1 and player.hero_xp==0 and sim.units.has(player.hero_unit)
			finish(passed)
	else:
		if session.mode!="client" or not session.welcomed or not sim.players.has(session.local_id): return false
		var player: Dictionary=sim.players[session.local_id]
		if phase==0:
			session.issue("hero",[],Vector2.ZERO,"arthur")
			phase=1
		if phase==1 and duplicate_rejected:
			session.issue("hero",[],Vector2.ZERO,choices[role])
			phase=2
		if initial_match==-1 and player.get("hero","")!="":
			initial_match=sim.match_id
			original_hero=player.hero_unit
		if player.get("hero_level",1)==3 and player.get("hero_xp",0)==180:
			saw_growth=true
			if acknowledged==0:
				session.issue("skill",[],Vector2.ZERO,"power")
				acknowledged=1
		if saw_growth and player.get("hero_unit",-2)==-1 and player.get("revive_wave",-1)==1:
			saw_dead=true
			if acknowledged==1:
				session.issue("skill",[],Vector2.ZERO,"power")
				acknowledged=2
		if saw_dead and player.get("hero_unit",-1)>0 and player.hero_unit!=original_hero and sim.cleared_wave==1:
			saw_revived=true
			if acknowledged==2:
				session.issue("skill",[],Vector2.ZERO,"power")
				acknowledged=3
		if initial_match!=-1 and sim.match_id!=initial_match and not saw_rematch:
			saw_rematch=true
			session.issue("hero",[],Vector2.ZERO,choices[role])
		if saw_rematch and sim.running and not done:
			var passed=duplicate_rejected and saw_growth and saw_dead and saw_revived and player.hero==choices[role] and player.hero_level==1
			print("HERO_NETWORK_CLIENT ",role," PASS=",passed)
			if not passed:
				finish(false)
				return false
			done=true
			session.issue("skill",[],Vector2.ZERO,"harvest")
			phase_at=clock
		# Keep the connection alive until the host finishes its own assertions.
		if done and clock-phase_at>8:
			finish(true)
	return false
