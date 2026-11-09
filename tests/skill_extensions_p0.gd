extends RefCounted

const SkillManagerScript = preload("res://scripts/skill_manager.gd")
const SkillData = preload("res://scripts/skill_data.gd")
var t: SceneTree

func run(runner: SceneTree) -> void:
	t = runner
	validate_tables()
	await dash()
	await stealth()
	await fear()
	await common()

func check(ok: bool, label: String) -> void:
	t.check(ok,label)

func fixture(locked: bool = false) -> Dictionary:
	var f: Dictionary = t._xp_fixture(300,2)
	f.player.configure_combat(100,{})
	f.manager._offscreen_relocate_seconds = 1000.0
	f.manager._random.seed = 7
	var records: Dictionary = t._s5_records()
	for id in records:
		records[id].Initially_unlocked = true
		if locked and id!="skill_rapid_slash":
			records[id].Initially_unlocked = false
	var manager := SkillManagerScript.new()
	var extra := {
		"skill_dash":{"d":{"Id":"d","Level":1,"Distance":80.0,"Duration_sec":0.2,"Cooldown_sec":5.0}},
		"skill_stealth":{"s":{"Id":"s","Level":1,"Duration_sec":1.0,"Cooldown_sec":4.0}},
		"skill_dragon_fear":{"f":{"Id":"f","Level":1,"Range":100.0,"Duration_sec":1.0,"Cooldown_sec":5.0}}}
	for id in extra:
		var next: Dictionary = extra[id].values()[0].duplicate(true)
		next.Level = 2
		next.Id = "next"
		extra[id]["next"] = next
	manager.configure(f.player,f.manager,records,t._s5_levels(),extra,
		{"Wander_radius":30.0})
	f.host.add_child(manager)
	manager.set_physics_process(false)
	f.skills = manager
	return f

func release() -> void:
	for action in ["move_up","move_down","move_left","move_right"]:
		Input.action_release(action)

func close(f: Dictionary) -> void:
	release()
	t.paused = false
	f.host.queue_free()
	await t.process_frame

func advance(f: Dictionary, delta: float, move_enemies: bool = false) -> void:
	f.player._physics_process(delta)
	f.skills._physics_process(delta)
	f.manager._elapsed_seconds += delta
	if move_enemies:
		f.manager._update_active_enemies(delta)

func press(f: Dictionary, id: String) -> void:
	t._s5_press(f,id)

func dash() -> void:
	for actions in [[],["move_up"],["move_right","move_down"]]:
		var f := fixture()
		for action in actions:
			Input.action_press(action)
		press(f,"skill_dash")
		var direction: Vector2 = f.player.movement_input() if not actions.is_empty() else Vector2.RIGHT
		release()
		Input.action_press("move_left")
		advance(f,0.1)
		advance(f,0.1)
		check(f.player.position.distance_to(direction*80.0)<0.2,"DASH-01 fixed normalized direction and exact distance despite opposite input: "+str(actions))
		check(not f.skills.skills.skill_dash.active and is_equal_approx(f.skills.skills.skill_dash.completed_at,0.2) and is_equal_approx(f.skills.skills.skill_dash.cooldown_until,5.2),"DASH-02 duration completion starts cooldown")
		await close(f)
	var f := fixture()
	Input.action_press("move_up")
	f.player._physics_process(0.1)
	release()
	f.player.position = Vector2.ZERO
	press(f,"skill_dash")
	advance(f,0.2)
	check(f.player.position.distance_to(Vector2(0,-80))<0.2,"DASH-01 no input uses last movement direction")
	await close(f)
	for diagonal in [false,true]:
		f = fixture()
		var map = t.MapScene.instantiate()
		f.host.add_child(map)
		f.player.position = Vector2(1268,0)
		await t.physics_frame
		Input.action_press("move_right")
		if diagonal: Input.action_press("move_down")
		press(f,"skill_dash")
		release()
		advance(f,0.2)
		check(f.player.position.x<=1272.2 and absf(f.player.position.y-(80.0/sqrt(2.0) if diagonal else 0.0))<0.2 and not f.skills.skills.skill_dash.active,"DASH-03 wall component blocked tangent retained duration still ends: "+str(diagonal))
		await close(f)
	f = fixture()
	var enemy: EnemyActor = t._spawn(f,Vector2(40,0))
	var other: EnemyActor = t._spawn(f,Vector2(200,0))
	press(f,"skill_dash")
	advance(f,0.1)
	f.manager._resolve_contact_pushes()
	check(f.player.position.distance_to(Vector2(40,0))<0.2 and enemy.position==Vector2(40,0),"DASH-04 player passes enemy without contact push")
	f.manager._update_contact_damage()
	f.manager._update_contact_damage()
	check(f.player.hp==95,"DASH-05 contact damage remains with per-enemy rehit restriction")
	other.position = enemy.position+Vector2(10,0)
	f.manager._resolve_contact_pushes()
	check(enemy.position.distance_to(other.position)>=15.99,"DASH-04 enemy-enemy pushes continue during dash")
	advance(f,0.1)
	enemy.position = f.player.position
	other.position = Vector2(400,0)
	f.manager._resolve_contact_pushes()
	check(enemy.position==f.player.position,"DASH-06 finishing frame still passes through")
	advance(f,0.0)
	f.manager._resolve_contact_pushes()
	check(enemy.position.distance_to(f.player.position)>15.9,"DASH-06 push resumes next frame after dash")
	await close(f)
	f = fixture()
	enemy = t._spawn(f,Vector2(50,0))
	f.player.configure_combat(100,t._attack())
	press(f,"skill_dash")
	press(f,"skill_rapid_slash")
	f.player.update_basic_attack(0.0,f.manager.get_living_enemies())
	f.player.update_basic_attack(0.15,f.manager.get_living_enemies())
	check(enemy.hp==72 and f.skills.skills.skill_dash.active and f.skills.skills.skill_rapid_slash.active,"DASH-07 slash and basic attacks coexist with dash and dash adds no damage")
	await close(f)
	f = fixture()
	var shot = t._new_projectile(f,t._projectile(),Vector2(100,0),Vector2.ZERO)
	press(f,"skill_dash")
	shot.advance(1.0)
	check(f.player.hp==92 and f.player.dash_remaining>0.0,"DASH-05 existing projectile damages player during dash")
	await close(f)

func stealth() -> void:
	var f := fixture()
	var enemy: EnemyActor = t._spawn(f,Vector2(200,100))
	enemy.move_speed = 20.0
	press(f,"skill_stealth")
	check(f.player.is_stealthed() and not f.skills.skills.skill_stealth.active and f.skills.icon_state("skill_stealth").phase=="cooldown","STEALTH-01 instant completion while effect persists")
	var origin := enemy.position
	f.manager._update_active_enemies(0.1)
	var target := enemy.wander_target
	check(target.distance_to(origin)<=30.001 and enemy.position.distance_to(origin+origin.direction_to(target)*2.0)<0.02 and target!=f.player.position,"STEALTH-02 seeded local wandering follows target at Move_speed")
	enemy.position = target
	f.manager._update_active_enemies(0.1)
	check(enemy.wander_target!=target and enemy.wander_target.distance_to(target)<=30.001,"STEALTH-02 arrival selects a new local target")
	var newcomer: EnemyActor = t._spawn(f,Vector2(-200,100))
	f.manager._update_active_enemies(0.1)
	check(newcomer.has_wander_target,"STEALTH-02 enemies spawned during stealth wander too")
	enemy.position = Vector2(3992,3992)
	enemy.has_wander_target = false
	f.manager._update_active_enemies(0.0)
	check(Rect2(-3992.001,-3992.001,7984.002,7984.002).has_point(enemy.wander_target),"STEALTH-02 wander target clamped inside map including body radius")
	advance(f,1.0)
	enemy.position = Vector2(200,0)
	f.manager._update_active_enemies(0.1)
	check(not f.player.is_stealthed() and enemy.position.distance_to(Vector2(198,0))<0.02,"STEALTH-03 expiry restores player chase next update")
	await close(f)
	f = fixture()
	enemy = t._spawn(f,Vector2(-100,0))
	enemy.shot_range = 500
	enemy.shot_interval_sec = 0.5
	enemy.projectile_id = "shot"
	f.manager._update_enemy_shot(enemy,0.5)
	enemy.shot_elapsed = 0.2
	press(f,"skill_stealth")
	f.manager._update_enemy_shot(enemy,0.6)
	check(f.manager._projectiles.size()==1 and is_equal_approx(enemy.shot_elapsed,0.2),"STEALTH-04 firing and timer pause")
	f.manager._update_projectiles(1.0)
	check(f.player.hp==92,"STEALTH-05 existing projectile continues and damages stealthed player")
	enemy.position = f.player.position
	f.manager._update_contact_damage()
	check(f.player.hp==87,"STEALTH-05 contact damage remains during stealth")
	advance(f,1.0)
	var count: int = f.manager._projectiles.size()
	f.manager._update_enemy_shot(enemy,0.3)
	check(f.manager._projectiles.size()==count+1,"STEALTH-04 firing resumes from saved timer after expiry")
	await close(f)
	f = fixture()
	enemy = t._spawn(f,Vector2(50,0))
	f.player.configure_combat(100,t._attack())
	press(f,"skill_stealth")
	press(f,"skill_rapid_slash")
	f.player.update_basic_attack(0.0,f.manager.get_living_enemies())
	f.skills.ui._process(0.0)
	check(enemy.hp==82 and f.player.is_stealthed() and f.player.modulate.a<1.0,"STEALTH-06 basic and slash attacks keep stealth and translucent display")
	await close(f)

func fear() -> void:
	var f := fixture()
	var enemy: EnemyActor = t._spawn(f,Vector2(100,0))
	var outside: EnemyActor = t._spawn(f,Vector2(100.01,0))
	enemy.move_speed = 20.0
	press(f,"skill_dragon_fear")
	check(enemy.is_feared() and not outside.is_feared() and not f.skills.skills.skill_dragon_fear.active and f.skills.icon_state("skill_dragon_fear").phase=="cooldown","FEAR-01 single inclusive range check and instant completion")
	outside.position = Vector2.ZERO
	f.manager._update_active_enemies(0.1)
	check(enemy.position==Vector2(100,0) and not outside.is_feared(),"FEAR-02 self motion stops and later entrant is not affected")
	f.player.position = enemy.position
	enemy.shot_range = 500
	enemy.shot_interval_sec = 0.5
	enemy.projectile_id = "shot"
	enemy.shot_elapsed = 0.2
	f.manager._apply_contact_damage(enemy)
	f.manager._update_enemy_shot(enemy,0.5)
	check(f.player.hp==100 and f.manager._projectiles.is_empty() and is_equal_approx(enemy.shot_elapsed,0.2),"FEAR-03 contact and firing disabled with timer frozen")
	f.player.position = Vector2.ZERO
	f.manager._update_active_enemies(0.9)
	f.manager._update_active_enemies(0.1)
	f.manager._update_enemy_shot(enemy,0.3)
	enemy.position = Vector2(16,0)
	f.manager._apply_contact_damage(enemy)
	check(not enemy.is_feared() and f.manager._projectiles.size()==1 and f.player.hp==95,"FEAR-04 expiry restores movement and both attacks from saved timer")
	await close(f)
	f = fixture()
	enemy = t._spawn(f,Vector2(-100,0))
	enemy.shot_range = 500
	enemy.shot_interval_sec = 0.5
	enemy.projectile_id = "shot"
	f.manager._update_enemy_shot(enemy,0.5)
	press(f,"skill_dragon_fear")
	f.manager._update_projectiles(1.0)
	check(f.player.hp==92,"FEAR-05 projectile launched before fear still hits")
	await close(f)
	f = fixture()
	enemy = t._spawn(f,Vector2(12,0))
	press(f,"skill_stealth")
	press(f,"skill_dragon_fear")
	f.manager._resolve_contact_pushes()
	check(enemy.position.x>12,"FEAR-06 contact pushing moves feared enemy")
	var start := enemy.position
	enemy.start_knockback(f.player.position,60,0.2)
	f.manager._update_active_enemies(0.1)
	check(enemy.position.distance_to(start+Vector2(45,0))<0.02 and enemy.is_feared(),"FEAR-06 knockback continues while fear overrides stealth wandering")
	enemy.position = Vector2(2000,2000)
	f.manager._offscreen_relocate_seconds = 0.0
	f.manager._update_active_enemies(0.1)
	check(enemy.position!=Vector2(2000,2000) and enemy.is_feared() and f.manager.get_alive_count()==1,"FEAR-07 offscreen relocation keeps fear and count during stealth")
	enemy.apply_damage(100)
	check(enemy.is_logically_dead and f.manager.get_alive_count()==0 and f.xp.get_ground_count()==1,"FEAR-07 feared enemy death uses existing death and experience flow")
	await close(f)

func common() -> void:
	var f := fixture()
	for id in ["skill_dash","skill_stealth","skill_dragon_fear"]:
		check(f.skills.skills[id].implemented and f.skills.icon_state(id).phase=="ready","EXT-01 implemented skill has normal unlocked icon: "+id)
	var enemy: EnemyActor = t._spawn(f,Vector2(50,0))
	press(f,"skill_stealth")
	press(f,"skill_dragon_fear")
	press(f,"skill_dash")
	f.player.apply_damage(100)
	advance(f,1.0,true)
	check(f.player.stealth_remaining==1.0 and enemy.fear_remaining==1.0 and f.player.dash_remaining==0.2,"EXT-02 death pauses all three effects")
	await close(f)
	f = fixture(true)
	for id in ["skill_dash","skill_stealth","skill_dragon_fear"]:
		press(f,id)
		t._s5_click(f,id)
		check(f.skills.icon_state(id).phase=="locked" and not f.skills.icon_state(id).show_plus and f.player.enhancement_points==0,"EXT-01 implemented locked zero-point skill blocks use and click: "+id)
	f.player.enhancement_points = 6
	for id in ["skill_dash","skill_stealth","skill_dragon_fear"]:
		check(f.skills.icon_state(id).show_plus,"EXT-01 implemented locked skill has plus with points: "+id)
		t._s5_click(f,id)
		check(f.skills.skills[id].level==1 and f.skills.icon_state(id).phase=="ready","EXT-01 click unlocks implemented skill: "+id)
		t._s5_click(f,id)
		check(f.skills.skills[id].level==2 and not f.skills.icon_state(id).show_plus,"EXT-01 click upgrades to table max and removes plus: "+id)
	check(f.player.enhancement_points==0,"EXT-01 three unlocks and upgrades cost exactly six points")
	await close(f)

func validate_tables() -> void:
	var sources: Dictionary = t._s5_extension_sources()
	for file in ["skill_dash_level.csv","skill_stealth_level.csv","skill_dragon_fear_level.csv"]:
		var lines: PackedStringArray = sources[file].strip_edges().split("\n")
		var header := lines[0]
		var values := lines[1].split(",")
		for mode in ["empty","start","gap"]:
			var text := header+"\n"
			if mode=="start":
				var row := values.duplicate(); row[1]="2"; text+=",".join(row)+"\n"
			elif mode=="gap":
				var row := values.duplicate(); row[0]="other"; row[1]="3"; text+=lines[1]+"\n"+",".join(row)+"\n"
			check(not table_error(file,text).is_empty(),"EXT-03 reject "+file+" level "+mode)
		var columns := header.split(",")
		for index in range(2,columns.size()-1):
			var row := values.duplicate(); row[index]="0"
			check(not table_error(file,header+"\n"+",".join(row)+"\n").is_empty(),"EXT-03 reject nonpositive "+file+" "+columns[index])
		if file!="skill_dash_level.csv":
			for cooldown in ["1","0.5"]:
				var row := values.duplicate(); row[columns.find("Cooldown_sec")]=cooldown
				check(not table_error(file,header+"\n"+",".join(row)+"\n").is_empty(),"EXT-03 reject cooldown <= duration: "+file+" "+cooldown)
	check(not table_error("stealth_rule.csv","Id,Wander_radius,Note\n").is_empty(),"EXT-03 missing stealth_rule_01 rejected")
	check(not table_error("stealth_rule.csv","Id,Wander_radius,Note\nstealth_rule_01,0,test\n").is_empty(),"EXT-03 nonpositive Wander_radius rejected")
	var store = t._store()
	var error: String = store.load_all()
	check(error.is_empty() and SkillData.validate(store).is_empty(),"EXT-04 all actual CSV load and validate")

func table_error(file: String, text: String) -> String:
	var store = t._store()
	var sources: Dictionary = t._s5_extension_sources()
	sources["skill.csv"]="Id,Name_ko,Key,Initially_unlocked,Note\nskill_dash,dash,Space,1,test\nskill_rapid_slash,slash,F,1,test\nskill_stealth,stealth,1,0,test\nskill_dragon_fear,fear,2,0,test\n"
	sources["skill_rapid_slash_level.csv"]="Id,Level,Damage,Hits,Hit_interval_sec,Range,Cooldown_sec,Note\na,1,8,5,0.1,100,6,test\n"
	sources[file]=text
	for name in sources:
		var error: String = store.load_text(name,sources[name])
		if not error.is_empty(): return error
	return SkillData.validate(store)
