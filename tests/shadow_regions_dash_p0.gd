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
	await type_capacity()
	validate_shapes()
	error_screen()
	print("S7-IMPL-02 NEW RESULT: %d checks, %d failures; inherited %d" % [t.checks-before,t.failures-failures,before])

func regions() -> void:
	for count in [1,2,3]:
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
	helper.summon_test_type(f,2)
	f.summons._physics_process(0.0)
	t.check(s.target==near and s.target_spawn_order==order,"S7-I2-LOCK N2 to N3 keeps prior target and spawn generation")
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
	var edge: EnemyActor = t._spawn(f,Vector2(550,300))
	var outside: EnemyActor = t._spawn(f,Vector2(550.1,300))
	var inside: EnemyActor = t._spawn(f,Vector2(480,350))
	t.check(s.circle_visual_state().is_empty(),"S7-I2-DASH no circle visualization outside attack")
	s.tick(0.0)
	t.check(s.cast_active and not s.hit_done and s.dash_goal==Vector2(480,300),"S7-I2-DASH starts at exact Range180, snapshots target point without early hit")
	target.position = Vector2(300,480)
	s.tick(0.1)
	t.check(helper.near(s.position,Vector2(360,300)) and s.dash_goal==Vector2(480,300) and s.facing==Vector2.RIGHT and target.hp==100,"S7-I2-DASH speed600 follows fixed point rather than moving target")
	t.check(s.separation_velocity()==Vector2.ZERO,"S7-I2-DASH no steering throughout active dash")
	s.tick(0.2)
	t.check(s.hit_done and helper.near(s.position,Vector2(480,300)) and target.hp==100 and edge.hp==90 and inside.hp==90 and outside.hp==100,"S7-I2-CIRCLE arrival hits once at current center, includes radius70 edge and excludes outside")
	var geometry: Dictionary = s.circle_geometry()
	var state: Dictionary = s.circle_visual_state()
	t.check(state.center==geometry.center and state.radius==geometry.radius and state.radius==70 and absf(state.hit_age)<EPS,"S7-I2-CIRCLE visualization shares hit center/radius and flashes at dash end")
	var old_hp: int = edge.hp
	s.tick(0.1)
	t.check(edge.hp==old_hp and s.cast_active,"S7-I2-CIRCLE recovery does not repeat damage")
	s.tick(0.2)
	t.check(not s.cast_active and s.circle_visual_state().is_empty() and absf(s.ready_at-2.1)<EPS,"S7-I2-DASH recovery0.3 ends before Interval1.5 begins")
	s.tick(1.5-0.00001)
	t.check(not s.cast_active,"S7-I2-DASH interval does not expire early")
	s.tick(0.00001)
	t.check(s.cast_active,"S7-I2-DASH exact post-recovery interval permits next dash")
	await helper.close(f)

func dash_arrival_and_blocking() -> void:
	for distance in [8.0,8.01]:
		var f: Dictionary = helper.fixture()
		f.player.position = Vector2(300,300)
		var s = f.summons.summon("charger_test")
		var target: EnemyActor = t._spawn(f,Vector2(300+distance,300))
		s.tick(0.0)
		t.check(s.hit_done==(distance==8.0) and target.hp==(90 if distance==8.0 else 100),"S7-I2-ARRIVAL named 8px tolerance inclusive, distance="+str(distance))
		await helper.close(f)
	var f: Dictionary = helper.fixture()
	# Narrow test map and a genuinely configured smaller enemy make the fixed
	# goal unreachable by the shadow radius. All pushes remain production code.
	f.manager._map_rect = Rect2(-40,-20,80,40)
	f.manager._enemy_records.test.Body_radius = 4.0
	f.manager.push_iterations = 4
	var s = f.summons.summon("charger_test")
	var target: EnemyActor = t._spawn(f,Vector2(36,0))
	s.tick(0.0)
	var blocked_before_timeout := true
	for i in range(4):
		s.tick(0.1)
		f.manager._resolve_contact_pushes()
		blocked_before_timeout = blocked_before_timeout and not s.hit_done and target.hp==100
	t.check(blocked_before_timeout and s.position.distance_to(s.dash_goal)>8.0,"S7-I2-BLOCK real pushes/map clamp keep dash blocked without early damage")
	s.tick(0.1)
	t.check(s.hit_done and s.position.distance_to(s.dash_goal)>8.0 and target.hp==90 and absf(s.dash_hit_at-0.5)<EPS,"S7-I2-BLOCK timeout0.5 emits circle at blocked position")
	var position: Vector2 = s.position
	f.manager._resolve_contact_pushes()
	t.check(s.position!=position and s.position.x<=24.0+EPS,"S7-I2-BLOCK existing enemy push still applies after hit and obeys map bounds")
	print("S7-I2 BLOCK ",JSON.stringify({"shadow":[s.position.x,s.position.y],"fixed_goal":[s.dash_goal.x,s.dash_goal.y],"hit_at":s.dash_hit_at,"target_hp":target.hp}))
	await helper.close(f)

func cancellations() -> void:
	for reason in ["leash","teleport"]:
		var f: Dictionary = helper.fixture()
		f.player.position = Vector2(300,300)
		var s = f.summons.summon("charger_test")
		var target: EnemyActor = t._spawn(f,Vector2(480,300))
		s.tick(0.0)
		t.check(s.cast_active,"S7-I2-CANCEL fixture starts a real dash, "+reason)
		if reason=="leash":
			s.position = f.player.position+Vector2(561,0)
			s.tick(0.0)
		else:
			s.angle_picker = func() -> float: return 0.0
			s.teleport()
			t.check(helper.images(f).size()==1 and helper.images(f)[0].pose.kind=="charger_test","S7-I2-CANCEL teleport leaves temporary charger-pose afterimage")
		t.check(not s.cast_active and s.target==null and target.hp==100,"S7-I2-CANCEL cancels pending circle without damage, "+reason)
		f.manager.recycle_enemy(target)
		s.tick(1.0)
		t.check(not s.hit_done,"S7-I2-CANCEL cancelled cast cannot emit late damage, "+reason)
		await helper.close(f)

func type_capacity() -> void:
	var f: Dictionary = helper.fixture()
	for i in range(3):
		var s: Node2D = helper.summon_test_type(f,i)
		t.check(s!=null and f.summons.summon(s.config.Id)==null,"S7-I2-TYPE one instance per unique type i="+str(i))
	var extra: Dictionary = f.store.get_row("shadow.csv","igrit").duplicate(true)
	extra.Id = "p0_fourth_type"
	f.summons.records[extra.Id] = extra
	t.check(f.summons.actors.size()==3 and not f.summons.can_summon(extra.Id) and f.summons.summon(extra.Id)==null,"S7-I2-TYPE three distinct slots reject even a different fourth test type")
	await helper.close(f)

func validate_shapes() -> void:
	var store = t._store()
	t.check(store.load_all().is_empty() and Data.validate(store).is_empty(),"S7-I2-CSV real fan/circle_dash schemas and data validate")
	var text := FileAccess.get_file_as_string("res://data/shadow_attack.csv")
	for shape in ["cone",""]:
		var bad: String = store.load_text("shadow_attack.csv",text.replace(",fan,",","+shape+","))
		t.check(bad.contains("Shape") and bad.contains("행 2"),"S7-I2-CSV invalid Shape Enum rejected with source line, value="+shape)
	t.check(store.load_all().is_empty(),"SETUP reload valid shadow tables")
	var fan: Dictionary = store.get_row("shadow_attack.csv","igrit_attack")
	for key in ["Circle_radius","Dash_speed","Dash_max_sec"]: fan[key] = -1.0
	t.check(Data.validate(store).is_empty(),"S7-I2-CSV fan ignores dash-only value ranges")
	var circle: Dictionary = store.get_row("shadow_attack.csv","charger_attack")
	circle.Arc_deg = -1.0
	store.get_row("shadow_motion.csv","charger_dash").Hit_time_sec = -999.0
	t.check(Data.validate(store).is_empty(),"S7-I2-CSV circle ignores Arc_deg and unused Hit_time_sec value ranges")
	for key in ["Circle_radius","Dash_speed","Dash_max_sec"]:
		var saved: Variant = circle[key]
		circle[key] = 0.0
		t.check(Data.validate(store).contains(key),"S7-I2-CSV circle requires positive "+key)
		circle[key] = saved
	var diagonal: Dictionary = store.get_row("shadow_motion.csv","igrit_diagonal")
	diagonal.Hit_time_sec = null
	t.check(Data.validate(store).contains("Hit_time_sec"),"S7-I2-CSV fan still requires scheduled hit time")
	diagonal.Hit_time_sec = 0.15
	store.get_row("shadow_motion.csv","charger_dash").Motion_sec = 0.0
	t.check(Data.validate(store).contains("Motion_sec"),"S7-I2-CSV circle recovery must be positive")
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
	var exit_code := OS.execute(OS.get_executable_path(),PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/shadow_data_error_probe.gd","--log-file",ProjectSettings.globalize_path("res://.local/godot_logs/s7-impl-02-data-error.log")]),output,true)
	var captured := "\n".join(output)
	var raw := FileAccess.open("res://.local/s7-impl-02-data-error.out",FileAccess.WRITE)
	raw.store_string(captured)
	# Windows OS.execute text conversion corrupts Korean diagnostics; use the
	# child's UTF-8 state to check the same source field and actual UI outcome.
	var state: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.local/s7-impl-02-data-error-state.json"))
	t.check(exit_code==0 and captured.contains("S7-ERROR-SCREEN PASS") and not captured.contains("SCRIPT ERROR:") and state is Dictionary and state.message.contains("열 Shape") and state.paused and state.label_matches and state.loaded,"S7-I2-ERROR invalid Shape reaches production data-error screen and pauses")
