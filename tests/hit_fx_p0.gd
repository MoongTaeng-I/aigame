extends RefCounted

const FX = preload("res://scripts/hit_fx.gd")
const Data = preload("res://scripts/hit_fx_data.gd")
const Base = preload("res://tests/shadow_summons_p0.gd")
const Profile = preload("res://tests/push_profile.gd")
var t: SceneTree

func run(tree: SceneTree) -> void:
	t = tree
	var before: int = t.checks
	var prior_failures: int = t.failures
	validation()
	await paths()
	await pool_and_lifetime()
	var off: Dictionary = await profile_case(tree,false,180,30)
	var on: Dictionary = await profile_case(tree,true,180,30)
	t.check(off.trace==on.trace,"FX-EQUAL every frame damage/enemy/player/shadow state identical Enabled0/1")
	t.check(off.emitted==0 and off.capacity==0 and off.active_max==0,"FX-OFF no allocated effect slots or emitted sparks")
	t.check(on.emitted>0 and on.active_max<=on.capacity and on.fx_nodes==1,"FX-ON real 200-enemy workload emits within cap using one node")
	var equality := FileAccess.open("res://.local/fx-impl-01-p0-enabled-comparison.json",FileAccess.WRITE)
	equality.store_string(JSON.stringify({"off":off,"on":on,"equal":off.trace==on.trace}))
	await main_and_error_screen()
	print("FX NEW RESULT: %d checks, %d failures; inherited %d" % [t.checks-before,t.failures-prior_failures,before])

func fixture(capacity: int = -1, enabled: bool = true) -> Dictionary:
	var helper := Base.new()
	helper.t = t
	var f: Dictionary = helper.fixture()
	f.helper = helper
	var row: Dictionary = f.store.get_row("hit_fx.csv","hit_spark").duplicate(true)
	row.Enabled = 1 if enabled else 0
	if capacity>0: row.Max_active = capacity
	var effect := FX.new()
	effect.configure(f.manager,row)
	f.host.add_child(effect)
	effect.set_physics_process(false)
	f.fx = effect
	f.player.position = Vector2(300,300)
	return f

func validation() -> void:
	var store = t._store()
	t.check(store.load_all().is_empty() and Data.validate(store).is_empty(),"FX-CSV actual BOM CSV loads and validates")
	var row: Dictionary = store.get_row("hit_fx.csv","hit_spark")
	t.check(row.Enabled==1 and row.Duration_sec==0.25 and row.Radius==28 and row.Core_radius==7 and row.Max_active==200,"FX-CSV documented provisional start values")
	for entry in [["Enabled",2],["Duration_sec",0.0],["Duration_sec",INF],["Radius",0.0],["Core_radius",29.0],["Core_radius",0.0],["Max_active",0],["Outer_color","invalid_color"],["Core_color",""]]:
		var saved: Variant = row[entry[0]]
		row[entry[0]] = entry[1]
		var error: String = Data.validate(store)
		t.check(error.contains("hit_fx.csv, 행 2, 열 "+str(entry[0])),"FX-CSV invalid "+str(entry[0])+" has file/line/column")
		row[entry[0]] = saved
	row.Enabled = 0
	t.check(Data.validate(store).is_empty(),"FX-CSV disabled valid configuration accepted")
	store.get_table("hit_fx.csv").clear()
	t.check(Data.validate(store).contains("열 Id"),"FX-CSV required hit_spark missing rejected")

func paths() -> void:
	var f := fixture()
	var enemy: EnemyActor = t._spawn(f,Vector2(380,300))
	var at: Vector2 = enemy.global_position
	f.player._apply_basic_hit(enemy)
	t.check(f.fx.emitted==1 and f.fx.positions[0]==at and enemy.hp==90,"FX-PATH basic attack existing endpoint enemy center")
	var skills = preload("res://scripts/skill_manager.gd").new()
	skills.configure(f.player,f.manager,f.store.get_table("skill.csv"),f.store.get_table("skill_rapid_slash_level.csv"),{"skill_dash":f.store.get_table("skill_dash_level.csv"),"skill_stealth":f.store.get_table("skill_stealth_level.csv"),"skill_dragon_fear":f.store.get_table("skill_dragon_fear_level.csv")},f.store.get_row("stealth_rule.csv","stealth_rule_01"))
	f.host.add_child(skills)
	skills.set_physics_process(false)
	skills._slash_tick({"Range":160,"Damage":8,"Hit_interval_sec":0.1},0.0)
	t.check(f.fx.emitted==2 and f.fx.positions[1]==at and enemy.hp==82,"FX-PATH slash real callback/area bridge uses struck enemy center")
	var igrit = f.summons.summon("igrit")
	igrit.position = f.player.position
	igrit.motion_picker = func(_count: int) -> int: return 0
	igrit.tick(0.0)
	igrit.tick(0.15)
	t.check(f.fx.emitted==3 and f.fx.positions[2]==at and enemy.hp==72,"FX-PATH igrit real fan hit uses enemy center")
	var beru = f.summons.summon("charger_test")
	beru.position = f.player.position
	beru.tick(0.0)
	beru.tick(0.1)
	t.check(f.fx.emitted==4 and f.fx.positions[3]==at and enemy.hp==62,"FX-PATH beru real swept path hit uses enemy center")
	enemy.position += Vector2(20,0)
	t.check(f.fx.positions[0]==at,"FX-WORLD spark stays at hit position when enemy moves")
	var count: int = f.fx.emitted
	enemy.apply_damage(0)
	enemy.apply_damage(-1)
	f.manager.recycle_enemy(enemy)
	enemy.apply_damage(10)
	t.check(f.fx.emitted==count,"FX-VALID no sparks for zero/negative or inactive damage")
	var reused: EnemyActor = t._spawn(f,Vector2(350,300))
	t.check(reused==enemy and reused.damaged.get_connections().size()==1,"FX-POOL enemy reuse retains exactly one damage connection")
	reused.apply_damage(1)
	t.check(f.fx.emitted==count+1,"FX-POOL reused enemy emits once")
	reused.apply_damage(1000)
	reused.apply_damage(1)
	t.check(f.fx.emitted==count+2 and reused.is_logically_dead,"FX-DEATH lethal damage emits once; dead repeat does not")
	var contact: EnemyActor = t._spawn(f,f.player.position)
	var hp: int = f.player.hp
	f.manager._update_contact_damage()
	t.check(f.player.hp<hp and f.fx.emitted==count+2,"FX-PLAYER contact damage does not emit monster FX")
	var shot = preload("res://scripts/projectile.gd").new()
	f.host.add_child(shot)
	shot.configure(t._projectile(),f.player.position-Vector2(20,0),f.player.position,Rect2(-4000,-4000,8000,8000),f.player)
	shot.advance(0.2)
	t.check(shot.spent and f.fx.emitted==count+2,"FX-PLAYER existing projectile hits only player, no monster spark")
	await f.helper.close(f)

func pool_and_lifetime() -> void:
	var f := fixture(3)
	var enemy: EnemyActor = t._spawn(f,Vector2(300,300),1000000)
	var nodes: int = f.host.find_children("*","Node",true,false).size()
	for index in range(4):
		enemy.position = Vector2(300+index,300)
		enemy.apply_damage(1)
	t.check(f.fx.active_count==3 and f.fx.positions.size()==3 and f.fx.overwritten==1 and f.fx.positions[0]==Vector2(303,300),"FX-CAP full pool replaces oldest slot, count fixed")
	f.fx._physics_process(f.fx.duration-0.00001)
	t.check(f.fx.active_count==3,"FX-LIFE still visible before duration")
	f.fx._physics_process(0.00002)
	t.check(f.fx.active_count==0,"FX-LIFE all expired after duration")
	for index in range(3000):
		enemy.apply_damage(1)
		f.fx._physics_process(0.01)
	t.check(f.fx.positions.size()==3 and f.fx.ages.size()==3 and f.fx.active_count<=3 and f.fx.get_child_count()==0 and f.host.find_children("*","Node",true,false).size()==nodes,"FX-POOL 3000 hits allocate no extra nodes or slots")
	await f.helper.close(f)
	f = fixture(3,false)
	enemy = t._spawn(f,Vector2(300,300))
	enemy.apply_damage(1)
	t.check(f.fx.emitted==0 and f.fx.positions.is_empty() and f.fx.spark.is_empty() and not f.manager.enemy_damaged.is_connected(f.fx.emit_at),"FX-OFF no sparks, slots, geometry or listener")
	await f.helper.close(f)

func profile_case(tree: SceneTree, enabled: bool, frames: int, warmup: int) -> Dictionary:
	var profile := Profile.new()
	var f: Dictionary = profile.fixture(tree,4)
	f.manager.collecting = false
	f.manager._offscreen_relocate_seconds = 100000.0
	for enemy in f.actors:
		enemy.hp = 1000000000
		enemy.max_hp = 1000000000
	var shadows = preload("res://scripts/shadow_manager.gd").new()
	shadows.configure(f.player,f.manager,f.store.get_table("shadow.csv"),f.store.get_table("shadow_attack.csv"),f.store.get_table("shadow_motion.csv"),3)
	f.host.add_child(shadows)
	shadows.set_physics_process(false)
	for id in ["igrit","charger_test"]:
		var actor = shadows.summon(id)
		actor.position = Vector2(-80 if id=="igrit" else 80,0)
		actor.random.seed = 20261111
		actor.motion_picker = func(_count: int) -> int: return 0
	var row: Dictionary = f.store.get_row("hit_fx.csv","hit_spark").duplicate(true)
	row.Enabled = 1 if enabled else 0
	var effect := FX.new()
	effect.configure(f.manager,row)
	f.host.add_child(effect)
	effect.set_physics_process(false)
	var trace: Array = []
	var times: Array = []
	var fx_times: Array = []
	var active_max := 0
	var nodes_min := 1000000
	var nodes_max := 0
	for index in range(2): await tree.physics_frame
	for frame in range(warmup+frames):
		if frame%120==0: f.skills.skills.skill_rapid_slash.start(f.skills.clock)
		if frame==120: profile.press_fear(f)
		var start := Time.get_ticks_usec()
		shadows._physics_process(1.0/60.0)
		profile.frame(f)
		var fx_start := Time.get_ticks_usec()
		effect._physics_process(1.0/60.0)
		var fx_us: int = Time.get_ticks_usec()-fx_start
		var elapsed: int = Time.get_ticks_usec()-start-f.manager.bookkeeping_us
		if frame>=warmup:
			times.append(elapsed)
			fx_times.append(fx_us)
			var state: Dictionary = profile.snapshot(f)
			state.shadows = []
			for actor in shadows.actors:
				state.shadows.append([actor.position.x,actor.position.y,actor.facing.x,actor.facing.y,actor.target_spawn_order,actor.cast_active,actor.hit_done,actor.clock,actor.ready_at,actor.dash_travelled])
			state.player_attack = [f.player._remaining_hits,f.player._attack_ready_at,f.player._next_hit_at]
			state.alive = f.manager.get_alive_count()
			trace.append(state)
			active_max = maxi(active_max,effect.active_count)
			var nodes: int = f.host.find_children("*","Node",true,false).size()+1
			nodes_min = mini(nodes_min,nodes)
			nodes_max = maxi(nodes_max,nodes)
		await tree.physics_frame
	var mean := 0.0
	var maximum := 0
	for value in times:
		mean += float(value)/times.size()
		maximum = maxi(maximum,int(value))
	var result := {"enabled":enabled,"frames":frames,"warmup":warmup,"physics_mean_ms":mean/1000.0,"physics_max_ms":maximum/1000.0,"fx_us":fx_times,"times_us":times,"active_max":active_max,"capacity":effect.positions.size(),"emitted":effect.emitted,"overwritten":effect.overwritten,"fx_nodes":1+effect.get_child_count(),"nodes_min":nodes_min,"nodes_max":nodes_max,"alive":f.manager.get_alive_count(),"trace":trace}
	f.host.free()
	await tree.process_frame
	return result

func main_and_error_screen() -> void:
	var main = preload("res://main.tscn").instantiate()
	t.root.add_child(main)
	t.check(main.find_child("HitFx",true,false)!=null,"FX-MAIN real main startup creates configured FX node")
	main.queue_free()
	await t.process_frame
	var output: Array = []
	var code := preload("res://tests/godot_probe_process.gd").execute(PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/hit_fx_error_probe.gd","--log-file",ProjectSettings.globalize_path("res://.local/godot_logs/fx-impl-01-error.log")]),output,"res://.local/godot_logs/hit_fx_p0.log")
	var raw := FileAccess.open("res://.local/fx-impl-01-error.out",FileAccess.WRITE)
	raw.store_string("\n".join(output))
	var state: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.local/fx-impl-01-error-state.json"))
	t.check(code==0 and state is Dictionary and state.message.contains("열 Enabled") and state.paused and state.label_matches,"FX-ERROR invalid CSV field reaches existing paused data error screen")
