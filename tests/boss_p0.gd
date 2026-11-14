extends RefCounted

const Data = preload("res://scripts/boss_data.gd")
const Director = preload("res://scripts/boss_director.gd")
const Geometry = preload("res://scripts/combat_geometry.gd")
var t: SceneTree
var store: CsvDataStore

func run(tree: SceneTree) -> void:
	t = tree
	var first: int = t.checks
	var fail: int = t.failures
	store = t._store()
	t.check(store.load_all().is_empty(),"S8 actual registered CSV load")
	t.check(Data.validate(store).is_empty(),"S8 actual boss CSV validates")
	validate_data()
	await timeline_and_resume()
	await casting_and_states()
	await targeting_and_geometry()
	await weight_and_plan()
	print("S8 NEW RESULT: %d checks, %d failures" % [t.checks-first,t.failures-fail])

func validate_data() -> void:
	for pair in [[0,0],[100,60],[500,300],[1230,750],[159,119],[575,-1],[-1,-1]]:
		t.check(Data.mmss_seconds(pair[0])==pair[1],"S8 MMSS "+str(pair))
	for file in ["boss.csv","stage_timeline.csv","boss_action.csv","boss_rule.csv"]:
		var table: Dictionary = store.tables[file].duplicate(true)
		for id in table:
			var row: Dictionary = table[id]
			for col in row:
				if col in ["Id","Note"]: continue
				var old: Variant = store.tables[file][id][col]
				if old is float or old is int:
					store.tables[file][id][col] = -1
					t.check(not Data.validate(store).is_empty(),"S8 negative rejected "+file+"."+col)
					store.tables[file][id][col] = old
		store.tables[file] = table
	var s: CsvDataStore = t._store()
	t.check(not s.load_text("stage_timeline.csv","Id,Time_mmss,Boss_id,Note\na,,boss_early,test\n").is_empty(),"S8 blank MMSS parse rejected")
	var old: Dictionary = store.tables["boss_action.csv"].duplicate(true)
	store.tables["boss_action.csv"].erase("ice_bear_slam")
	t.check(not Data.validate(store).is_empty(),"S8 missing action kind rejected")
	store.tables["boss_action.csv"] = old.duplicate(true)
	store.tables["boss_action.csv"]["duplicate"] = old.ice_bear_basic.duplicate(true)
	t.check(not Data.validate(store).is_empty(),"S8 duplicate basic rejected")
	store.tables["boss_action.csv"] = old.duplicate(true)
	var boss: Dictionary = store.tables["boss.csv"].boss_early
	var enemy: String = boss.Enemy_id
	boss.Enemy_id = "missing"
	t.check(not Data.validate(store).is_empty(),"S8 enemy reference rejected")
	boss.Enemy_id = enemy

func fixture(events: Dictionary = {}, finals: bool = false) -> Dictionary:
	var f: Dictionary = t._fixture(1000)
	f.player.configure_combat(100000,t._attack())
	f.player.global_position = Vector2(1200,1000)
	var enemies: Dictionary = store.get_table("enemy.csv").duplicate(true)
	enemies.test = t._enemy()
	f.manager.configure(f.player,Rect2(-2000,-2000,4000,4000),enemies,{"normal":{"Id":"normal","Time_start":0.0,"Time_end":9999.0,"Enemy_id":"test","Spawn_interval":1.0,"Spawn_count":1}},1000,0.0,{},t._attack(),0,1)
	var skills := preload("res://scripts/skill_manager.gd").new()
	skills.configure(f.player,f.manager,store.get_table("skill.csv"),store.get_table("skill_rapid_slash_level.csv"),{"skill_dash":store.get_table("skill_dash_level.csv"),"skill_stealth":store.get_table("skill_stealth_level.csv"),"skill_dragon_fear":store.get_table("skill_dragon_fear_level.csv")},store.get_row("stealth_rule.csv","stealth_rule_01"))
	f.host.add_child(skills)
	skills.set_physics_process(false)
	f.skills = skills
	var bosses: Dictionary = store.get_table("boss.csv").duplicate(true)
	bosses.boss_early.Is_final = finals
	var d := Director.new()
	d.configure(f.manager,bosses,store.get_table("boss_action.csv"),events,store.get_row("boss_rule.csv","boss_rule_01"))
	f.host.add_child(d)
	f.director = d
	return f

func tick(f: Dictionary, delta: float) -> void:
	f.manager._physics_process(delta)

func active_fixture() -> Dictionary:
	var f := fixture({"event":{"Id":"event","Time_mmss":0,"Boss_id":"boss_middle"}})
	tick(f,0)
	tick(f,2)
	tick(f,1.5)
	f.boss = f.director.actor
	return f

func cleanup(f: Dictionary) -> void:
	t.paused = false
	f.host.queue_free()
	await t.process_frame

func timeline_and_resume() -> void:
	var events := {"a":{"Id":"a","Time_mmss":0,"Boss_id":"boss_early"},"b":{"Id":"b","Time_mmss":1,"Boss_id":"boss_early"}}
	var f := fixture(events)
	var normal: EnemyActor = t._spawn(f,Vector2(300,0))
	tick(f,0)
	t.check(f.director.phase=="warn" and f.manager._stop_normal_spawning,"S8 time zero starts warning and stops new normals")
	t.check(f.director.toast_text.contains("아이스 엘프 정예병") and not f.director.toast_text.contains("{name}"),"S8 toast substitution from enemy name")
	tick(f,1)
	t.check(f.director.pending.size()==1 and f.director.fired.size()==2,"S8 next due boss queued once during warning")
	tick(f,1)
	var boss: EnemyActor = f.director.actor
	t.check(f.director.phase=="emerge" and not boss.is_active and not boss.apply_damage(99),"S8 emerging invulnerable and not active")
	boss.apply_fear(4)
	t.check(not boss.is_feared() and boss.current.is_empty() and boss.collision_layer==0,"S8 emergence no fear/BT/collision")
	t.check(f.manager.get_alive_count()==1 and normal.is_active,"S8 old normal preserved, no spawns throughout warning")
	tick(f,1.5)
	t.check(boss.is_active and f.director.phase=="active","S8 emergence ends through production registration")
	t.check(f.manager.get_living_enemies().has(boss),"S8 boss included in existing player and shadow candidate list")
	boss.apply_damage(boss.hp)
	t.check(f.director.phase=="warn" and f.manager._stop_normal_spawning and f.director.pending.is_empty(),"S8 death immediately starts queued warning without spawning resume")
	tick(f,3.5)
	var last: EnemyActor = f.director.actor
	last.apply_damage(last.hp)
	t.check(not f.manager._stop_normal_spawning and is_zero_approx(f.manager._spawn_timers.normal),"S8 last early boss death resumes with zero spawn timer")
	var count: int = f.manager.get_alive_count()
	tick(f,0.9)
	t.check(f.manager.get_alive_count()==count,"S8 no accumulated generation on resume")
	tick(f,0.1)
	t.check(f.manager.get_alive_count()==count+1 and f.director.fired.size()==2,"S8 full interval resumes; events never refire")
	await cleanup(f)
	f = fixture({"final":{"Id":"final","Time_mmss":0,"Boss_id":"boss_early"}},true)
	tick(f,0)
	tick(f,3.5)
	f.director.actor.apply_damage(f.director.actor.hp)
	t.check(f.director.completed and t.paused and f.director.toast_view.completion_label.text=="완료","S8 final boss death completes and pauses")
	await cleanup(f)

func set_time(f: Dictionary, time: float) -> void:
	f.manager._elapsed_seconds = time
	f.boss.boss_tick(0)

func action(f: Dictionary, id: String) -> Dictionary:
	return store.get_row("boss_action.csv",id)

func casting_and_states() -> void:
	var f := active_fixture()
	var boss: Variant = f.boss
	boss.global_position = Vector2.ZERO
	f.player.global_position = Vector2(80,0)
	boss.clock = f.manager._elapsed_seconds
	boss.start_action(action(f,"ice_bear_basic"),f.player.global_position)
	var start: float = boss.clock
	var hp: int = f.player.hp
	f.player.stealth_remaining = 100
	set_time(f,start+0.4)
	t.check(f.player.hp==hp-12 and boss.current.is_empty(),"S8 started basic ends even if stealth begins")
	t.check(is_equal_approx(boss.ready_at.ice_bear_basic,start+0.4+1.5),"S8 cooldown starts at hit/action end, not telegraph start")
	set_time(f,start+0.5)
	t.check(boss.current.is_empty(),"S8 recovery blocks action")
	var before: Vector2 = boss.global_position
	set_time(f,start+5)
	boss.boss_tick(0.2)
	t.check(boss.current.is_empty() and boss.has_wander_target and boss.ready_at.ice_bear_basic<f.manager._elapsed_seconds,"S8 stealth wanders; cooldown progresses")
	t.check(boss.global_position!=before,"S8 stealth movement uses normal wander rule")
	f.player.stealth_remaining = 0
	boss.global_position = Vector2.ZERO
	boss.clock = f.manager._elapsed_seconds
	boss.start_action(action(f,"ice_bear_slam"),Vector2.RIGHT)
	hp = f.player.hp
	var cancelled: float = f.manager._elapsed_seconds
	boss.apply_fear(1)
	t.check(boss.current.is_empty() and boss.telegraph_geometry().is_empty(),"S8 fear immediately cancels and removes telegraph")
	t.check(is_equal_approx(boss.ready_at.ice_bear_slam,cancelled+8),"S8 fear cancellation starts action cooldown immediately")
	set_time(f,cancelled+0.5)
	boss.boss_tick(0.5)
	t.check(f.player.hp==hp and boss.global_position==Vector2.ZERO,"S8 feared boss has no movement/damage")
	boss.fear_remaining = 0
	boss.start_action(action(f,"ice_bear_dash"),f.player.global_position)
	f.skills.skills.skill_dragon_fear.level = 1
	t.check(f.skills.try_use("skill_dragon_fear") and boss.current.is_empty() and boss.is_feared(),"S8 real fear skill targets boss by center and immediately interrupts")
	boss.start_knockback(Vector2(-10,0),60,1)
	t.check(boss.knockback_duration==0,"S8 boss ignores basic knockback")
	await cleanup(f)

func targeting_and_geometry() -> void:
	var f := active_fixture()
	var boss: Variant = f.boss
	boss.global_position = Vector2.ZERO
	f.player.global_position = Vector2(200,0)
	boss.clock = f.manager._elapsed_seconds
	boss.start_action(action(f,"ice_bear_dash"),f.player.global_position)
	var g: Dictionary = boss.telegraph_geometry()
	t.check(g.end==Vector2(400,0) and g.body_radius==48 and g.direction==Vector2.RIGHT,"S8 dash display uses body width and actual clipped endpoint")
	f.player.global_position = Vector2(0,200)
	set_time(f,boss.clock+0.8)
	t.check(boss.facing==Vector2.RIGHT and boss.is_boss_dashing(),"S8 dash never reaims at moving target")
	f.player.global_position = Vector2(100,0)
	var hp: int = f.player.hp
	set_time(f,f.manager._elapsed_seconds+0.2)
	t.check(f.player.hp==hp-25,"S8 dash swept path hits player")
	f.manager._apply_contact_damage(boss)
	t.check(f.player.hp==hp-25,"S8 dash replaces ordinary contact damage")
	var normal: EnemyActor = t._spawn(f,boss.global_position)
	var position: Vector2 = normal.global_position
	f.manager._resolve_contact_pair(boss,normal)
	t.check(normal.global_position==position,"S8 dashing boss passes normal without push")
	f.manager._resolve_contact_pushes()
	t.check(normal.global_position==position,"S8 optimized push excludes dashing boss")
	set_time(f,f.manager._elapsed_seconds+1)
	t.check(boss.global_position==g.end and f.player.hp==hp-25 and boss.current.is_empty(),"S8 fixed distance finish and one damage per dash")
	boss.global_position = Vector2(1900,0)
	boss.start_action(action(f,"ice_bear_dash"),Vector2(2200,0))
	t.check(boss.dash_end==Vector2(1952,0),"S8 boss radius clips dash endpoint at map edge")
	set_time(f,f.manager._elapsed_seconds+2)
	t.check(boss.global_position==Vector2(1952,0),"S8 clipped boundary finish, no slide")
	for distance in [0.0,149.9,150.0,150.1]:
		t.check(Geometry.in_sector(Vector2.ZERO,Vector2.RIGHT,150,100,Vector2(distance,0))==(distance<=150),"S8 shared fan range boundary "+str(distance))
	boss.global_position = Vector2.ZERO
	f.player.global_position = Vector2(320,0)
	boss.start_action(action(f,"ice_bear_slam"),Vector2.ZERO)
	g = boss.telegraph_geometry()
	boss.global_position = Vector2(1000,0)
	hp = f.player.hp
	set_time(f,f.manager._elapsed_seconds+0.8)
	t.check(g.center==Vector2.ZERO and g.slam_radius==320 and f.player.hp==hp-30,"S8 slam fixed world circle and boundary damage equal display")
	await cleanup(f)

func weight_and_plan() -> void:
	var f := active_fixture()
	var boss: Variant = f.boss
	f.player.global_position = Vector2(1000,0)
	boss.global_position = Vector2.ZERO
	boss.current = {}
	boss.recover_until = 0
	boss.planned = {}
	boss.boss_tick(0)
	var chosen: String = boss.planned.Id
	t.check(chosen in ["ice_bear_dash","ice_bear_slam"],"S8 ready skills choose weighted planned skill")
	for i in range(20): boss.boss_tick(0)
	t.check(boss.planned.Id==chosen,"S8 planned skill never rerolled each frame")
	f.player.global_position = Vector2(80,0)
	boss.boss_tick(0)
	t.check(boss.current.Id==chosen and boss.planned.is_empty(),"S8 in range starts planned skill before basic")
	boss.finish_action(boss.clock)
	boss.planned = {}
	boss.recover_until = 0
	boss.ready_at.ice_bear_dash = 99999
	boss.ready_at.ice_bear_slam = 99999
	boss.boss_tick(0)
	t.check(boss.current.Id=="ice_bear_basic","S8 no ready skill allows ready basic")
	boss.finish_action(boss.clock)
	boss.recover_until = 0
	var before: Vector2 = boss.global_position
	boss.boss_tick(0.1)
	t.check(boss.global_position!=before,"S8 cooldown basic follows instead")
	# Configure the real actor with synthetic skewed weights, not a replacement picker.
	var weighted: Array = boss.actions.duplicate(true)
	for row in weighted:
		if int(row.Kind)==1: row.Pick_weight = 1000
		elif int(row.Kind)==2: row.Pick_weight = 1
	boss.configure_boss(f.manager,weighted,f.director.player_target)
	f.player.global_position = Vector2(1000,1000)
	var dash_picks := 0
	for seed_value in range(100):
		boss.current = {}
		boss.planned = {}
		boss.recover_until = 0
		boss.rng.seed = seed_value
		boss.boss_tick(0)
		if boss.planned.Id=="ice_bear_dash": dash_picks+=1
	t.check(dash_picks>=95,"S8 deterministic weighted choices honor strongly higher dash weight")
	var shadows := preload("res://scripts/shadow_manager.gd").new()
	shadows.configure(f.player,f.manager,store.get_table("shadow.csv"),store.get_table("shadow_attack.csv"),store.get_table("shadow_motion.csv"),3)
	f.host.add_child(shadows)
	shadows.set_physics_process(false)
	var shadow: Node2D = shadows.summon("igrit")
	shadow.global_position = Vector2.ZERO
	f.player.global_position = Vector2.ZERO
	boss.global_position = Vector2(80,0)
	var hp: int = boss.hp
	shadow.tick(0)
	t.check(shadow.target==boss,"S8 approved existing shadow targeting allows boss")
	shadow.tick(0.25)
	t.check(boss.hp==hp-10,"S8 existing shadow fan can damage boss through production damage path")
	await cleanup(f)
