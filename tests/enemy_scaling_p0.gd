extends RefCounted

const Data = preload("res://scripts/combat_data.gd")
var t: SceneTree
var store: CsvDataStore

func run(tree: SceneTree) -> void:
	t = tree
	var before: int = t.checks
	var failures: int = t.failures
	store = t._store()
	t.check(store.load_all().is_empty() and Data.validate(store).is_empty(),"S8-I4 actual scaling CSV loads and validates")
	validation()
	await stages_and_ranged()
	await lifetime_and_pool()
	await experience_rounding()
	await spawn_counts()
	await bosses_and_shadows()
	await error_screen()
	print("S8-IMPL-04 NEW RESULT: %d checks, %d failures" % [t.checks-before,t.failures-failures])

func fixture(spawning: bool = false) -> Dictionary:
	var cap := int(store.get_row("spawn_rule.csv","rule_01").Max_alive)
	var f: Dictionary = t._fixture(cap)
	f.player.configure_combat(100000,{})
	f.manager.configure(f.player,Rect2(-4000,-4000,8000,8000),store.get_table("enemy.csv"),store.get_table("spawn.csv") if spawning else {},cap,100000,store.get_table("projectile.csv"),{},0,1,store.get_table("enemy_scaling.csv"))
	return f

func cleanup(f: Dictionary) -> void:
	t.paused = false
	f.host.queue_free()
	await t.process_frame

func spawn(f: Dictionary, id: String = "enemy_01") -> EnemyActor:
	f.manager._spawn_from_row({"Spawn_count":1,"Enemy_id":id})
	return f.manager.get_living_enemies().back()

func validation() -> void:
	var original: Dictionary = store.get_table("enemy_scaling.csv").duplicate(true)
	store.tables["enemy_scaling.csv"].erase("scaling_00")
	t.check(Data.validate(store).contains("Time_start"),"S8-I4 rejects missing time0")
	store.tables["enemy_scaling.csv"] = original.duplicate(true)
	store.tables["enemy_scaling.csv"].scaling_02.Time_start = 60.0
	t.check(Data.validate(store).contains("Time_start"),"S8-I4 rejects duplicate times across IDs")
	store.tables["enemy_scaling.csv"] = original.duplicate(true)
	for column in ["Hp_mult","Speed_mult","Damage_mult","Xp_mult"]:
		for invalid in [0,-1,INF,NAN]:
			store.tables["enemy_scaling.csv"].scaling_01[column] = invalid
			t.check(Data.validate(store).contains(column),"S8-I4 rejects invalid "+column+str(invalid))
		store.tables["enemy_scaling.csv"].scaling_01[column] = original.scaling_01[column]
	for invalid in [-1,INF,NAN]:
		store.tables["enemy_scaling.csv"].scaling_01.Time_start = invalid
		t.check(Data.validate(store).contains("Time_start"),"S8-I4 rejects invalid time "+str(invalid))
	store.tables["enemy_scaling.csv"] = original.duplicate(true)
	var file := FileAccess.get_file_as_string("res://data/enemy_scaling.csv")
	t.check(not t._store().load_text("enemy_scaling.csv",file.replace(",1.5,",",bad,")).is_empty(),"S8-I4 rejects malformed Float")
	t.check(Data.validate(store).is_empty(),"S8-I4 validation fixtures restored")

func stages_and_ranged() -> void:
	var f := fixture()
	for pair in [[0,"scaling_00"],[59.999,"scaling_00"],[60,"scaling_01"],[179.999,"scaling_01"],[180,"scaling_02"],[329.999,"scaling_02"],[330,"scaling_03"],[900,"scaling_03"],[9999,"scaling_03"]]:
		t.check(f.manager.scaling_at(pair[0]).Id==pair[1],"S8-I4 latest inclusive stage "+str(pair[0]))
	for row in [[0,30,120,5,100],[60,45,132,6,110],[180,66,144,7,120],[330,90,156,8,130]]:
		f.manager._elapsed_seconds = row[0]
		var enemy := spawn(f)
		t.check(enemy.max_hp==row[1] and enemy.hp==row[1] and is_equal_approx(enemy.move_speed,row[2]) and enemy.contact_damage==row[3],"S8-I4 actual melee HP/speed/damage "+str(row[0]))
		var ranged := spawn(f,"enemy_test_ranged")
		t.check(ranged.max_hp==row[1] and is_equal_approx(ranged.move_speed,row[4]) and ranged.contact_damage==row[3],"S8-I4 temporary ranged receives same multipliers "+str(row[0]))
		t.check(ranged.shot_interval_sec==2 and ranged.shot_range==400 and ranged.projectile_id=="proj_test_01","S8-I4 ranged interval/range/projectile unchanged")
		ranged.global_position = f.player.global_position+Vector2(100,0)
		var shots: int = f.manager._projectiles.size()
		f.manager._update_enemy_shot(ranged,1.99)
		t.check(f.manager._projectiles.size()==shots,"S8-I4 no early ranged shot")
		f.manager._update_enemy_shot(ranged,0.01)
		t.check(f.manager._projectiles.size()==shots+1,"S8-I4 same2 second shot after scaling")
	# A synthetic tie case independently asserts half-up for both integer fields.
	var base: Dictionary = store.get_row("enemy.csv","enemy_01").duplicate()
	base.Id = "half_tie"
	base.Max_hp = 5
	base.Contact_damage = 5
	f.manager._enemy_records = f.manager._enemy_records.duplicate(true)
	f.manager._enemy_records.half_tie = base
	f.manager.configure_scaling({"tie":{"Time_start":0,"Hp_mult":1.5,"Speed_mult":1,"Damage_mult":1.5,"Xp_mult":1}})
	var tie := spawn(f,"half_tie")
	t.check(tie.max_hp==8 and tie.contact_damage==8,"S8-I4 7.5 half rounds upward to8")
	await cleanup(f)

func lifetime_and_pool() -> void:
	var f := fixture()
	var first := spawn(f)
	first.apply_damage(3)
	f.manager._elapsed_seconds = 330
	f.manager._offscreen_relocate_seconds = 0
	first.global_position = Vector2(2000,1000)
	var previous := first.global_position
	f.manager._update_active_enemies(0.1)
	t.check(first.global_position!=previous and first.hp==27 and first.max_hp==30 and first.move_speed==120 and first.contact_damage==5 and first.xp_value==1,"S8-I4 living enemy and actual offscreen relocation retain original stats")
	var later := spawn(f)
	t.check(later.max_hp==90 and later.move_speed==156 and later.contact_damage==8,"S8-I4 new enemy uses current stage beside old enemy")
	f.manager.recycle_enemy(later)
	f.manager._elapsed_seconds = 60
	var reused := spawn(f)
	t.check(reused==later and reused.max_hp==45 and reused.hp==45 and is_equal_approx(reused.move_speed,132) and reused.contact_damage==6,"S8-I4 pool reuse recomputes from base, no compounded multipliers")
	f.manager.recycle_enemy(reused)
	f.manager._elapsed_seconds = 0
	reused = spawn(f)
	t.check(reused==later and reused.max_hp==30 and reused.move_speed==120 and reused.contact_damage==5 and reused.xp_value==1,"S8-I4 pool reset can return to stage0 including XP")
	t.check(store.get_row("enemy.csv","enemy_01").Max_hp==30 and f.manager._enemy_records.enemy_01.Move_speed==120,"S8-I4 base dictionaries remain immutable")
	var xp := preload("res://scripts/experience_manager.gd").new()
	xp.configure(f.player,f.manager,store.get_row("xp_rule.csv","xp_rule_01"))
	f.host.add_child(xp)
	xp.set_physics_process(false)
	f.manager._elapsed_seconds = 330
	var doomed := spawn(f)
	var determined: int = doomed.xp_value
	f.manager._elapsed_seconds = 0
	var rng_before: int = f.manager._random.state
	doomed.apply_damage(doomed.hp)
	doomed.apply_damage(1)
	t.check(xp.get_ground_count()==1 and xp.get_ground_total()==determined and f.manager._random.state==rng_before,"S8-I4 death drops creation-time XP exactly once without another RNG draw")
	await cleanup(f)

func experience_rounding() -> void:
	var f := fixture()
	for pair in [[60,1.1],[180,1.2],[330,1.3]]:
		f.manager._elapsed_seconds = pair[0]
		f.manager._random.seed = 20261114
		var total := 0
		var count := 0
		var allowed := true
		while count<10000:
			f.manager._spawn_from_row({"Spawn_count":mini(120,10000-count),"Enemy_id":"enemy_01"})
			for enemy in f.manager.get_living_enemies():
				allowed = allowed and enemy.xp_value in [1,2]
				total+=enemy.xp_value
				count+=1
				f.manager.recycle_enemy(enemy)
			await t.process_frame
		var mean := float(total)/count
		t.check(count==10000 and allowed,"S8-I4 real creation samples only floor/ceil XP "+str(pair[0]))
		t.check(absf(mean-pair[1])<=0.02,"S8-I4 XP mean converges within0.02 "+str(pair[1]))
		print("S8-I4 XP SAMPLE ",pair[0]," n=",count," mean=",mean," expected=",pair[1]," tolerance=0.02")
	await cleanup(f)

func spawn_counts() -> void:
	for pair in [[0,2],[60,3],[180,4],[330,5]]:
		var f := fixture(true)
		for second in range(1,6):
			f.manager._elapsed_seconds = pair[0]+second
			f.manager._advance_spawn_rows(1)
		var melee: Array = f.manager.get_living_enemies().filter(func(e: EnemyActor) -> bool: return e.enemy_id=="enemy_01")
		var ranged: Array = f.manager.get_living_enemies().filter(func(e: EnemyActor) -> bool: return e.enemy_id=="enemy_test_ranged")
		t.check(melee.size()==pair[1]*5 and ranged.size()==1,"S8-I4 actual rows per-second melee count and unchanged ranged "+str(pair[0]))
		await cleanup(f)
	var f := fixture(true)
	for pair in [[59.999,2],[60,3],[180,4],[330,5]]:
		var before: int = f.manager.get_alive_count()
		f.manager._elapsed_seconds = pair[0]
		f.manager._advance_spawn_rows(1)
		t.check(f.manager.get_alive_count()-before==pair[1],"S8-I4 boundary has one active melee row, no double spawn "+str(pair[0]))
	f.manager._elapsed_seconds = 900
	var before: int = f.manager.get_alive_count()
	f.manager._advance_spawn_rows(1)
	t.check(f.manager.get_alive_count()-before==6,"S8-I4 original inclusive final endpoint900 (melee5 plus due ranged1)")
	f.manager._elapsed_seconds = 900.000001
	before = f.manager.get_alive_count()
	f.manager._advance_spawn_rows(1)
	t.check(f.manager.get_alive_count()==before,"S8-I4 past final endpoint inactive")
	f.manager._spawn_from_row({"Spawn_count":500,"Enemy_id":"enemy_01"})
	t.check(f.manager.get_alive_count()==120,"BAL-01 actual120 cap maintained")
	f.manager._spawn_from_row({"Spawn_count":1,"Enemy_id":"enemy_01"})
	t.check(f.manager.get_alive_count()==120,"BAL-01 cap rejects further spawn above120")
	await cleanup(f)

func bosses_and_shadows() -> void:
	var roles := preload("res://tests/boss_roles_p0.gd").new()
	roles.t = t
	roles.store = store
	var f: Dictionary = roles.fixture()
	var old := spawn(f)
	roles.at(f,60)
	var before: int = f.manager.get_alive_count()
	f.manager._advance_spawn_rows(10)
	t.check(f.manager.get_alive_count()==before and old.is_active,"S8-I4 warning stops creation and retains old enemies")
	roles.at(f,63.5)
	var boss: EnemyActor = f.director.actor
	roles.at(f,65)
	before = f.manager.get_alive_count()
	f.manager._advance_spawn_rows(10)
	t.check(f.manager.get_alive_count()==before,"S8-I4 living boss normal creation0")
	boss.apply_damage(boss.hp)
	t.check(not f.manager._stop_normal_spawning,"S8-I4 ordinary boss death resumes spawning")
	before = f.manager.get_alive_count()
	f.manager._advance_spawn_rows(0.999)
	t.check(f.manager.get_alive_count()==before,"S8-I4 resume starts timer0 without backlog")
	f.manager._advance_spawn_rows(0.001)
	t.check(f.manager.get_alive_count()==before+3 and f.manager.get_living_enemies().back().max_hp==45 and old.max_hp==30,"S8-I4 resume emits current stage3 scaled enemies after full interval")
	await cleanup(f)
	f = roles.fixture()
	roles.at(f,330)
	for pair in [[333.5,"boss_ice_elf",525,110],[337.0,"boss_ice_bear",1100,90],[340.5,"boss_baruka",1750,156]]:
		roles.at(f,pair[0])
		boss = f.director.actor
		t.check(boss.enemy_id==pair[1] and boss.max_hp==pair[2] and is_equal_approx(boss.move_speed,pair[3]) and boss.xp_value==store.get_row("enemy.csv",pair[1]).Xp_value,"MVP-01 boss stats and XP unscaled after5:30 "+pair[1])
		boss.apply_damage(boss.hp)
	t.paused = false
	var shadows: Node2D = f.host.get_child(0).get_node("ShadowManager")
	var shadow: Node2D = shadows.summon("igrit")
	t.check(shadow.config==store.get_row("shadow.csv","igrit") and shadow.attack==store.get_row("shadow_attack.csv",shadow.config.Attack_id),"S8-I4 actual shadow config/attack unscaled")
	await cleanup(f)

func error_screen() -> void:
	var output: Array = []
	var log := "res://.local/godot_logs/s8-impl-04-scaling-error-"+str(Time.get_ticks_usec())+".log"
	var arguments := PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/scaling_error_probe.gd","--log-file",ProjectSettings.globalize_path(log)])
	var code := preload("res://tests/godot_probe_process.gd").execute(arguments,output,log)
	var raw := FileAccess.open("res://.local/s8-impl-04-scaling-error.out",FileAccess.WRITE)
	raw.store_string("\n".join(output))
	var state: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.local/s8-impl-04-scaling-error-state.json"))
	t.check(code==0 and state is Dictionary and state.loaded and state.paused and state.label_matches and state.message.contains("enemy_scaling.csv"),"S8-I4 invalid scaling reaches actual paused data-error screen")
