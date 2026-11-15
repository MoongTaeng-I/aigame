extends RefCounted

const Base = preload("res://tests/shadow_summons_p0.gd")
const Data = preload("res://scripts/shadow_data.gd")
const ChoiceData = preload("res://scripts/choice_data.gd")
var t: SceneTree
var helper: RefCounted
const EPS := 0.001

func run(tree: SceneTree) -> void:
	t = tree
	helper = Base.new()
	helper.t = tree
	var before: int = t.checks
	var failures: int = t.failures
	await regions()
	await priorities()
	await single_and_repartition()
	await return_slots()
	await dash_and_circle()
	await dash_arrival_and_blocking()
	await cancellations()
	await pass_through_and_pool()
	await instrumentation_equivalence()
	await type_capacity()
	validate_shapes()
	error_screen()
	print("S7-IMPL-02 NEW RESULT: %d checks, %d failures; inherited %d" % [t.checks-before,t.failures-failures,before])

func regions() -> void:
	for count in [1,2]:
		var f: Dictionary = helper.fixture()
		f.player.position = Vector2(300,300)
		for i in range(count): helper.summon_test_type(f,i)
		t.check(f.summons.actors.size()==count,"S7-I2-REG production summon path supports test N="+str(count))
		t.check(f.summons.region_index(f.player.position,count)==-1,"S7-I2-REG player-center enemy has no region N="+str(count))
		for i in range(count):
			var angle: float = TAU*i/count
			var exact: Vector2 = f.player.position+Vector2.RIGHT.rotated(angle)*150.0
			var previous: Vector2 = f.player.position+Vector2.RIGHT.rotated(angle-0.0001)*150.0
			var next: Vector2 = f.player.position+Vector2.RIGHT.rotated(angle+0.0001)*150.0
			t.check(f.summons.region_index(exact,count)==i and f.summons.region_index(next,count)==i and f.summons.region_index(previous,count)==posmod(i-1,count),"S7-I2-REG clockwise start inclusive/end exclusive N=%d boundary=%d" % [count,i])
			var slot: Vector2 = f.summons.follow_slot(f.summons.actors[i],200.0)
			t.check(helper.near(slot,f.player.position+Vector2.RIGHT.rotated(angle+PI/count)*200.0),"S7-I2-REG assigned slot is sector midpoint N=%d i=%d" % [count,i])
		await helper.close(f)

func priorities() -> void:
	for screen in [false,true]:
		var f: Dictionary = helper.fixture()
		f.player.position = Vector2(300,300)
		var first = f.summons.summon()
		var second = f.summons.summon("charger_test")
		first.ready_at = 100.0
		second.ready_at = 100.0
		var own: EnemyActor = t._spawn(f,Vector2(650,350) if screen else Vector2(420,400))
		var other: EnemyActor = t._spawn(f,Vector2(600,299) if screen else Vector2(300,250))
		f.summons._physics_process(0.0)
		t.check(first.target==own and second.target==other,"S7-I2-PRI own region outranks nearer other region in stage "+str(2 if screen else 1))
		t.check(first.last_node==("screen" if screen else "attack"),"S7-I2-PRI BT search/screen priority preserved")
		await helper.close(f)
		f = helper.fixture()
		f.player.position = Vector2(300,300)
		first = f.summons.summon()
		second = f.summons.summon("charger_test")
		first.ready_at = 100.0
		second.ready_at = 100.0
		own = t._spawn(f,Vector2(650,350) if screen else Vector2(420,400))
		second.tick(0.0)
		other = t._spawn(f,Vector2(600,299) if screen else Vector2(300,250))
		first.tick(0.0)
		t.check(second.target==own and first.target==other,"S7-I2-PRI free other region precedes claimed own region, stage "+str(2 if screen else 1))
		f.manager.recycle_enemy(other)
		first.tick(0.0)
		t.check(first.target==own and second.target==own,"S7-I2-PRI all candidates claimed permits duplicate nearest, stage "+str(2 if screen else 1))
		await helper.close(f)
	var f: Dictionary = helper.fixture()
	f.player.position = Vector2(300,300)
	var s = f.summons.summon()
	f.summons.summon("charger_test")
	s.ready_at = 100.0
	var no_region: EnemyActor = t._spawn(f,f.player.position)
	var own: EnemyActor = t._spawn(f,Vector2(400,400))
	s.tick(0.0)
	t.check(s.target==own,"S7-I2-PRI regionless enemy waits behind own-region free candidate")
	f.manager.recycle_enemy(own)
	s.tick(0.0)
	t.check(s.target==no_region,"S7-I2-PRI regionless candidate participates in final fallback")
	await helper.close(f)

func single_and_repartition() -> void:
	var f: Dictionary = helper.fixture()
	f.player.position = Vector2(300,300)
	var s = f.summons.summon()
	s.ready_at = 100.0
	var near: EnemyActor = t._spawn(f,Vector2(300,250))
	var far: EnemyActor = t._spawn(f,Vector2(400,400))
	s.tick(0.0)
	t.check(s.target==near,"S7-I2-N1 single shadow retains original nearest result across angular boundary")
	f.manager.recycle_enemy(near)
	f.manager.recycle_enemy(far)
	var centered: EnemyActor = t._spawn(f,Vector2(300,300))
	far = t._spawn(f,Vector2(400,400))
	s.tick(0.0)
	t.check(s.target==centered,"S7-I2-N1 existing nearest behavior includes player-center enemy")
	f.manager.recycle_enemy(centered)
	f.manager.recycle_enemy(far)
	s.position = Vector2(600,300)
	s.tick(0.1)
	t.check(helper.near(s.position,Vector2(568,300)),"S7-I2-N1 return step matches original player-directed 32px step")
	await helper.close(f)
	f = helper.fixture()
	f.player.position = Vector2(300,300)
	s = f.summons.summon()
	s.ready_at = 100.0
	near = t._spawn(f,Vector2(300,200))
	s.tick(0.0)
	var order: int = s.target_spawn_order
	f.summons.summon("charger_test")
	f.summons._physics_process(0.0)
	t.check(s.target==near and s.target_spawn_order==order and f.summons.region_index(near.position,2)==1,"S7-I2-LOCK N1 to N2 repartition keeps existing target in the other region")
	var rejected_third = helper.summon_test_type(f,2)
	f.summons._physics_process(0.0)
	t.check(rejected_third==null and f.summons.actors.size()==2 and s.target==near and s.target_spawn_order==order,"MVP-01 N2 limit rejects third type and keeps prior target")
	await helper.close(f)

func return_slots() -> void:
	var f: Dictionary = helper.fixture()
	f.player.position = Vector2(300,300)
	var s = f.summons.summon()
	var other = f.summons.summon("charger_test")
	s.position = Vector2(600,300)
	other.position = Vector2(0,0)
	var before: Vector2 = s.position
	var direction := Vector2(-300,200).normalized()
	s.tick(0.1)
	t.check(helper.near(s.position,before+direction*32.0) and s.last_node=="follow","S7-I2-FOLLOW approaches own midpoint slot instead of player center")
	s.position = Vector2(600,300)
	s.tick(2.0)
	t.check(absf(s.position.distance_to(f.player.position)-200.0)<EPS and not helper.near(s.position,Vector2(300,500)),"S7-I2-FOLLOW stops on first Follow circle crossing before exact slot")
	before = s.position
	s.tick(0.1)
	t.check(helper.near(s.position,before),"S7-I2-FOLLOW no extra movement just to stand at slot")
	s.position = Vector2(499.9,300)
	before = s.position
	s.tick(0.1)
	t.check(s.position==before,"S7-I2-FOLLOW already inside Follow radius remains stopped")
	await helper.close(f)

func dash_and_circle() -> void:
	var f: Dictionary = helper.fixture()
	f.player.position = Vector2(300,300)
	var s = f.summons.summon("charger_test")
	var target: EnemyActor = t._spawn(f,Vector2(480,300))
	s.choose_target(f.manager.get_living_enemies())
	var start_edge: EnemyActor = t._spawn(f,Vector2(300,340))
	var middle: EnemyActor = t._spawn(f,Vector2(450,340))
	var outside: EnemyActor = t._spawn(f,Vector2(450,340.1))
	# Nearby path probes arrived after the target was locked by normal selection.
	t.check(s.dash_visual_state().is_empty(),"S7-I3-VIS no radius display outside dash")
	s.tick(0.0)
	t.check(s.cast_active and s.dash_through_active and s.dash_goal==Vector2(600,300) and s.dash_direction==Vector2.RIGHT,"S7-I3-START Range180 fixes direction and distance300 endpoint beyond target")
	t.check(start_edge.hp==90 and target.hp==100,"S7-I3-PATH first zero-length segment includes starting radius40 edge")
	target.position = Vector2(300,480)
	s.tick(0.3)
	t.check(helper.near(s.position,Vector2(480,300)) and s.facing==Vector2.RIGHT and s.dash_goal==Vector2(600,300),"S7-I3-DIR moving target cannot turn fixed dash")
	t.check(middle.hp==90 and outside.hp==100 and target.hp==100,"S7-I3-PATH long frame segment hits intervening center at40, excludes40.1; no endpoint explosion")
	var geometry: Dictionary = s.dash_geometry()
	var view: Dictionary = s.dash_visual_state()
	t.check(view.center==geometry.center and view.radius==geometry.radius and view.radius==40 and s.separation_velocity()==Vector2.ZERO,"S7-I3-VIS same radius40/center and no steering while moving")
	s.tick(0.2)
	t.check(helper.near(s.position,Vector2(600,300)) and s.hit_done and not s.dash_through_active and s.cast_active and s.dash_visual_state().is_empty(),"S7-I3-END distance completion begins stationary recovery without explosion display")
	t.check(middle.hp==90 and start_edge.hp==90,"S7-I3-ONCE same generation receives at most one damage per dash")
	var stopped: Vector2 = s.position
	s.tick(0.3)
	t.check(not s.cast_active and s.target==null and s.position==stopped and absf(s.ready_at-1.8)<EPS,"S7-I3-RECOVERY ends after0.3, releases target; interval1.0 starts at recovery end")
	# Fresh legal candidate at fixed distance; do not conflate cooldown with
	# selection of the moving former target or minimum-length constraints.
	for enemy in f.manager.get_living_enemies(): f.manager.recycle_enemy(enemy)
	f.player.position = s.position
	target = t._spawn(f,s.position+Vector2(100,0))
	s.tick(1.0-0.00001)
	t.check(not s.cast_active,"S7-I3-INTERVAL no early dash during post-recovery interval")
	s.tick(0.00001)
	t.check(s.cast_active and s.target==target,"S7-I3-INTERVAL exact cooldown permits new BT-selected dash")
	await helper.close(f)

func dash_arrival_and_blocking() -> void:
	var f: Dictionary = helper.fixture()
	f.player.position = Vector2.ZERO
	var s = f.summons.summon("charger_test")
	s.position = Vector2(400,0)
	var enemy: EnemyActor = t._spawn(f,Vector2(500,0))
	s.tick(0.0)
	t.check(s.cast_active and helper.near(s.dash_goal,Vector2(560,0)) and absf(s.dash_length-160.0)<EPS,"S7-I3-LEASH endpoint clipped to initial player leash560")
	await helper.close(f)
	f = helper.fixture()
	s = f.summons.summon("charger_test")
	s.position = Vector2(480,0)
	enemy = t._spawn(f,Vector2(580,0))
	s.tick(0.0)
	t.check(not s.cast_active and not s.dash_through_active and s.last_node=="attack" and s.target==enemy and s.ready_at==0.0,"S7-I3-MIN leash-limited80 below100 does not start or alter shared cooldown/BT")
	s.position = Vector2(460,0)
	s.tick(0.0)
	t.check(s.cast_active and absf(s.dash_length-100.0)<EPS,"S7-I3-MIN exact100 length can start")
	await helper.close(f)
	f = helper.fixture()
	f.player.position = Vector2(3900,0)
	s = f.summons.summon("charger_test")
	s.position = Vector2(3950,0)
	enemy = t._spawn(f,Vector2(3980,0))
	s.tick(0.0)
	t.check(s.cast_active and absf(s.dash_length-34.0)<EPS and helper.near(s.dash_goal,Vector2(3984,0)),"S7-I3-MAP user answer permits map-only short34 dash below100")
	s.tick(0.1)
	t.check(s.hit_done and not s.dash_through_active and helper.near(s.position,Vector2(3984,0)) and s.dash_end_reason=="map","S7-I3-MAP ends at radius-aware map border without sliding or time cap")
	await helper.close(f)
	f = helper.fixture()
	f.player.position = Vector2(300,300)
	s = f.summons.summon("charger_test")
	enemy = t._spawn(f,s.position)
	s.facing = Vector2.DOWN
	s.tick(0.0)
	t.check(s.dash_direction==Vector2.DOWN and helper.near(s.dash_goal,Vector2(300,600)),"S7-I3-ZERO zero target vector falls back to last direction")
	await helper.close(f)
	f = helper.fixture()
	s = f.summons.summon("charger_test")
	enemy = t._spawn(f,s.position)
	s.facing = Vector2.ZERO
	s.tick(0.0)
	t.check(s.dash_direction==Vector2.RIGHT,"S7-I3-ZERO zero last direction finally uses RIGHT")
	await helper.close(f)

func cancellations() -> void:
	var f: Dictionary = helper.fixture()
	f.player.position = Vector2(300,300)
	var s = f.summons.summon("charger_test")
	var target: EnemyActor = t._spawn(f,Vector2(480,300))
	s.tick(0.0)
	f.player.position = Vector2(-300,300)
	s.tick(0.1)
	t.check(s.cast_active and s.dash_through_active and s.position.distance_to(f.player.position)>560,"S7-I3-CAST moving player can exceed leash without cancelling dash")
	f.player.position = Vector2(-200,300)
	s.tick(0.4)
	s.tick(0.2)
	t.check(s.cast_active and s.hit_done and not s.dash_through_active and s.position.distance_to(f.player.position)>560 and s.position.distance_to(f.player.position)<900,"S7-I3-CAST recovery also ignores leash until its end, below common teleport threshold")
	await helper.close(f)
	f = helper.fixture()
	f.player.position = Vector2(300,300)
	s = f.summons.summon("charger_test")
	target = t._spawn(f,Vector2(480,300))
	s.tick(0.0)
	f.player.position = Vector2(-100,300)
	s.tick(0.5)
	s.tick(0.3)
	t.check(not s.cast_active and s.target==null and s.ready_at>s.clock and s.position.distance_to(f.player.position)>560,"S7-I3-CAST recovery completes outside leash with target cleared and cooldown preserved")
	s.tick(0.0)
	t.check(s.last_node=="follow" and s.ready_at==s.clock,"S7-I3-COMMON idle leash still resets cooldown exactly as before")
	await helper.close(f)
	f = helper.fixture()
	f.player.position = Vector2(300,300)
	s = f.summons.summon("charger_test")
	target = t._spawn(f,Vector2(480,300))
	s.tick(0.0)
	s.angle_picker = func() -> float: return 0.0
	s.teleport()
	var teleport_images: Array = helper.images(f).filter(func(copy: Node) -> bool: return not copy.has_meta("beru_dash_trail"))
	t.check(not s.cast_active and not s.dash_through_active and s.target==null and teleport_images.size()==1,"S7-I3-TELEPORT cancels dash and keeps original teleport afterimage/clear behavior")
	var old_hp: int = target.hp
	f.manager.recycle_enemy(target)
	s.tick(1.0)
	t.check(target.hp==old_hp and not s.hit_done,"S7-I3-TELEPORT cancelled dash cannot deal late damage")
	await helper.close(f)

func pass_through_and_pool() -> void:
	var f: Dictionary = helper.fixture()
	f.player.position = Vector2(300,300)
	var s = f.summons.summon("charger_test")
	var enemy: EnemyActor = t._spawn(f,Vector2(480,300))
	s.tick(0.0)
	s.tick(0.3)
	var shadow_before: Vector2 = s.position
	var enemy_before: Vector2 = enemy.position
	f.manager.push_iterations = 1
	f.manager._resolve_contact_pushes()
	f.manager._resolve_contact_pair(enemy,s)
	f.manager._resolve_contact_pair(s,enemy)
	t.check(s.position==shadow_before and enemy.position==enemy_before,"S7-I3-PUSH optimized and direct enemy pairs both skip only moving dash")
	# Normal player and other-shadow pairs still participate during the dash.
	f.player.position = s.position+Vector2(10,0)
	f.manager._resolve_contact_pushes()
	t.check(s.position!=shadow_before and f.player.position!=shadow_before+Vector2(10,0),"S7-I3-PUSH player-shadow still resolves during enemy pass-through")
	var other = f.summons.summon("igrit")
	other.position = s.position+Vector2(20,0)
	f.player.position = Vector2(300,300)
	shadow_before = s.position
	f.manager._resolve_contact_pair(s,other)
	t.check(s.position!=shadow_before,"S7-I3-PUSH shadow-shadow remains weighted during dash")
	other.position = Vector2(300,0)
	s.tick(0.2)
	enemy.position = s.position
	shadow_before = s.position
	enemy_before = enemy.position
	f.manager._resolve_contact_pair(enemy,s)
	t.check(not s.dash_through_active and s.position!=shadow_before and enemy.position!=enemy_before,"S7-I3-PUSH recovery restores normal enemy0.9/shadow0.1 separation immediately")
	await helper.close(f)
	f = helper.fixture()
	f.player.position = Vector2(300,300)
	s = f.summons.summon("charger_test")
	enemy = t._spawn(f,Vector2(350,300))
	s.tick(0.0)
	s.tick(0.1)
	t.check(enemy.hp==90,"S7-I3-POOL first lifetime receives path hit")
	f.manager.recycle_enemy(enemy)
	var reused: EnemyActor = t._spawn(f,s.position)
	s.tick(0.0)
	t.check(reused==enemy and reused.hp==90,"S7-I3-POOL reused instance with new spawn_order can receive one new lifetime hit")
	s.tick(0.01)
	t.check(reused.hp==90,"S7-I3-POOL same reentered lifetime never receives a second hit")
	await helper.close(f)

func instrumentation_equivalence() -> void:
	var results: Array = []
	var recorded := 0
	for enabled in [false,true]:
		var f: Dictionary = helper.fixture()
		f.player.position = Vector2(300,300)
		var s = f.summons.summon("charger_test")
		var igrit = f.summons.summon("igrit")
		igrit.position = Vector2(300,100)
		igrit.motion_picker = func(_n: int) -> int: return 0
		var counter: Array = [0]
		if enabled: s.diagnostic_sink = func(_event: String,_details: Dictionary) -> void: counter[0] += 1
		var enemy: EnemyActor = t._spawn(f,Vector2(480,300))
		enemy.hp = 100000
		var frames: Array = []
		for frame in range(48):
			f.summons._physics_process(0.05)
			f.manager._resolve_contact_pushes()
			frames.append([s.position,s.facing,s.cast_active,s.hit_done,s.ready_at,s.target_spawn_order,igrit.position,igrit.cast_active,igrit.ready_at,enemy.hp])
		results.append(frames)
		recorded += counter[0]
		await helper.close(f)
	t.check(results[0]==results[1] and recorded>0,"S7-I3-TRACE same seeded state sequence with diagnostic hook off/on")
	var f: Dictionary = helper.fixture()
	f.player.position = Vector2(300,300)
	var igrit = f.summons.summon("igrit")
	igrit.motion_picker = func(_n: int) -> int: return 0
	var enemy: EnemyActor = t._spawn(f,Vector2(450,300))
	for frame in range(40): igrit.tick(0.05)
	t.check(helper.near(igrit.position,Vector2(310,300)) and enemy.hp==80 and igrit.cast_active and igrit.hit_done and absf(igrit.ready_at-1.65)<EPS,"S7-I3-IGRIT frozen original fan outcome: two hits, Range140, motion/cooldown unchanged")
	await helper.close(f)

func type_capacity() -> void:
	var f: Dictionary = helper.fixture()
	for i in range(2):
		var s: Node2D = helper.summon_test_type(f,i)
		t.check(s!=null and f.summons.summon(s.config.Id)==null,"S7-I2-TYPE one instance per unique type i="+str(i))
	var extra: Dictionary = f.store.get_row("shadow.csv","igrit").duplicate(true)
	extra.Id = "p0_third_type"
	f.summons.records[extra.Id] = extra
	t.check(f.summons.actors.size()==2 and not f.summons.can_summon(extra.Id) and f.summons.summon(extra.Id)==null,"MVP-01 two distinct slots reject a different third test type")
	await helper.close(f)

func validate_shapes() -> void:
	var store = t._store()
	t.check(store.load_all().is_empty() and Data.validate(store).is_empty(),"S7-I2-CSV real fan/dash_through schemas and data validate")
	var schema: Dictionary = store.schemas["shadow_attack.csv"]
	t.check(schema.has("Dash_distance") and schema.has("Dash_hit_radius") and schema.has("Dash_min_distance") and not schema.has("Circle_radius") and not schema.has("Dash_max_sec") and not Data.SHAPES.has("circle_dash"),"S7-I3-CSV new path columns present; old shape and arrival-explosion columns removed")
	var text := FileAccess.get_file_as_string("res://data/shadow_attack.csv")
	for shape in ["cone","","circle_dash"]:
		var bad: String = store.load_text("shadow_attack.csv",text.replace(",fan,",","+shape+","))
		t.check(bad.contains("Shape") and bad.contains("행 2"),"S7-I2-CSV invalid Shape Enum rejected with source line, value="+shape)
	t.check(store.load_all().is_empty(),"SETUP reload valid shadow tables")
	var fan: Dictionary = store.get_row("shadow_attack.csv","igrit_attack")
	for key in ["Dash_speed","Dash_distance","Dash_hit_radius","Dash_min_distance"]: fan[key] = -1.0
	t.check(Data.validate(store).is_empty(),"S7-I2-CSV fan ignores dash-only value ranges")
	var circle: Dictionary = store.get_row("shadow_attack.csv","charger_attack")
	circle.Arc_deg = -1.0
	store.get_row("shadow_motion.csv","charger_dash").Hit_time_sec = -999.0
	t.check(Data.validate(store).is_empty(),"S7-I2-CSV dash_through ignores Arc_deg and unused Hit_time_sec value ranges")
	for key in ["Dash_speed","Dash_distance","Dash_hit_radius","Dash_min_distance"]:
		var saved: Variant = circle[key]
		circle[key] = 0.0
		t.check(Data.validate(store).contains(key),"S7-I2-CSV dash_through requires positive "+key)
		circle[key] = saved
	var diagonal: Dictionary = store.get_row("shadow_motion.csv","igrit_diagonal")
	diagonal.Hit_time_sec = null
	t.check(Data.validate(store).contains("Hit_time_sec"),"S7-I2-CSV fan still requires scheduled hit time")
	diagonal.Hit_time_sec = 0.15
	store.get_row("shadow_motion.csv","charger_dash").Motion_sec = 0.0
	t.check(Data.validate(store).contains("Motion_sec"),"S7-I2-CSV dash_through recovery must be positive")
	t.check(store.load_all().is_empty(),"SETUP reload card tables")
	var rows: Dictionary = store.get_table("choice_level.csv")
	var repeated: Dictionary = rows.choice_igrit_01.duplicate(true)
	repeated.Id = "p0_repeat"
	repeated.Level = 2
	rows[repeated.Id] = repeated
	t.check(ChoiceData.validate(store,0.6).contains("종류당 1마리"),"S7-I2-CSV repeated shadow-card rows rejected without defining growth")

func error_screen() -> void:
	# Capture an intentionally invalid-data child process, including its
	# expected error diagnostic, rather than sending it to the P0 stderr.
	var output: Array = []
	var exit_code := preload("res://tests/godot_probe_process.gd").execute(PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/shadow_data_error_probe.gd","--log-file",ProjectSettings.globalize_path("res://.local/godot_logs/s7-impl-02-data-error.log")]),output,"res://.local/godot_logs/shadow_regions_dash_p0.log")
	var captured := "\n".join(output)
	var raw := FileAccess.open("res://.local/s7-impl-02-data-error.out",FileAccess.WRITE)
	raw.store_string(captured)
	# Windows OS.execute text conversion corrupts Korean diagnostics; use the
	# child's UTF-8 state to check the same source field and actual UI outcome.
	var state: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.local/s7-impl-02-data-error-state.json"))
	t.check(exit_code==0 and captured.contains("S7-ERROR-SCREEN PASS") and not captured.contains("SCRIPT ERROR:") and state is Dictionary and state.message.contains("열 Shape") and state.paused and state.label_matches and state.loaded,"S7-I2-ERROR invalid Shape reaches production data-error screen and pauses")
