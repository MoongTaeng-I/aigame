extends RefCounted

const Data = preload("res://scripts/boss_data.gd")
const Probe = preload("res://tests/elf_stealth_investigation.gd")
var t: SceneTree
var helper: RefCounted
var roles: RefCounted
var store: CsvDataStore

func run(tree: SceneTree) -> void:
	t = tree
	var before: int = t.checks
	var failures: int = t.failures
	store = t._store()
	t.check(store.load_all().is_empty(),"S8-I3-E actual CSV load")
	roles = preload("res://tests/boss_roles_p0.gd").new()
	roles.t = t
	roles.store = store
	helper = preload("res://tests/elf_boss_p0.gd").new()
	helper.t = t
	helper.store = store
	helper.helper = preload("res://tests/boss_p0.gd").new()
	helper.helper.t = t
	helper.helper.store = store
	validation()
	await speed_boundaries()
	await wait_and_resume()
	await self_stealth_and_burst()
	await pursuit_after_stealth()
	await other_actors()
	print("S8-IMPL-03-E NEW RESULT: %d checks, %d failures" % [t.checks-before,t.failures-failures])

func validation() -> void:
	t.check(Data.validate(store).is_empty() and store.get_row("boss.csv","boss_early").Outside_detect_speed==275,"S8-I3-E actual required speed275")
	var elf: Dictionary = store.get_row("boss.csv","boss_early")
	for value in [null,0,-1,INF,NAN]:
		elf.Outside_detect_speed = value
		t.check(Data.validate(store).contains("Outside_detect_speed"),"S8-I3-E rejects missing/nonpositive/nonfinite outside speed "+str(value))
	elf.Outside_detect_speed = 275.0
	for id in ["boss_middle","boss_final"]:
		var row: Dictionary = store.get_row("boss.csv",id)
		t.check(row.Outside_detect_speed==null,"S8-I3-E other profile blank "+id)
		for value in [0,275]:
			row.Outside_detect_speed = value
			t.check(Data.validate(store).contains("Outside_detect_speed"),"S8-I3-E other profile rejects filled speed "+id+str(value))
		row.Outside_detect_speed = null
	t.check(Data.validate(store).is_empty(),"S8-I3-E validation fixtures restored")
	var text := FileAccess.get_file_as_string("res://data/boss.csv")
	t.check(not t._store().load_text("boss.csv",text.replace(",275",",bad")).is_empty(),"S8-I3-E schema rejects malformed float")

func unlock_and_cast(f: Dictionary) -> void:
	f.player.enhancement_points = 1
	t.check(f.skills.try_upgrade("skill_stealth") and f.skills.try_use("skill_stealth"),"S8-I3-E real upgrade and stealth use")

func step(f: Dictionary, delta: float) -> void:
	f.player._physics_process(delta)
	f.skills._physics_process(delta)
	helper.step(f,delta)

func speed_boundaries() -> void:
	var f: Dictionary = helper.fixture()
	helper.disable_skills(f)
	var b: Variant = f.boss
	var e: Variant = b.elf
	f.player.global_position = Vector2(417,0)
	helper.step(f,0.01)
	t.check(b.global_position.is_equal_approx(Vector2(2.75,0)) and b.move_speed==110 and e.last_branch=="follow","S8-I3-E at417 outside moves275 without changing base110")
	b.global_position = Vector2.ZERO
	f.player.global_position = Vector2(416,0)
	helper.step(f,0.01)
	t.check(b.global_position==Vector2.ZERO and e.last_branch=="basic","S8-I3-E exact416 enters inside attack branch")
	# Actual inside BT stops to shoot at416. Narrow just the fixture Use_range to
	# expose the unchanged inside-follow branch and measure its existing speed.
	e.rows[3].Use_range = 415.0
	b.global_position = Vector2.ZERO
	helper.step(f,0.01)
	t.check(e.last_branch=="follow" and b.global_position.is_equal_approx(Vector2(1.1,0)),"S8-I3-E inside follow416 uses110")
	b.global_position = Vector2.ZERO
	f.player.global_position = Vector2(417,0)
	helper.step(f,0.01)
	t.check(b.global_position.is_equal_approx(Vector2(2.75,0)),"S8-I3-E outside417 switches to275")
	e.rows[3].Use_range = 416.0
	b.global_position = Vector2.ZERO
	f.player.global_position = Vector2(700,0)
	b.ready_at.ice_elf_stealth = 0
	helper.step(f,0.01)
	t.check(e.hidden and e.last_branch=="stealth" and b.global_position==Vector2.ZERO,"S8-I3-E outside self stealth retains priority over chase")
	helper.step(f,0.1)
	t.check(e.hidden and e.last_branch=="follow" and b.global_position.is_equal_approx(Vector2(27.5,0)),"S8-I3-E self-hidden elf still chases visible player275")
	await roles.cleanup(f)

func wait_and_resume() -> void:
	var f: Dictionary = helper.fixture()
	helper.disable_skills(f)
	f.player.global_position = Vector2(200,0)
	helper.step(f,0)
	var e: Variant = f.boss.elf
	t.check(e.fleeing,"S8-I3-E actual basic enters flee before stealth")
	var position: Vector2 = f.boss.global_position
	var ready: float = f.boss.ready_at.ice_elf_basic
	var shots: int = e.shots_fired
	unlock_and_cast(f)
	var displacement := 0.0
	for i in range(190):
		step(f,0.01)
		displacement = maxf(displacement,position.distance_to(f.boss.global_position))
	t.check(displacement==0 and e.last_branch=="stealth_wait" and not e.fleeing and not e.burst,"S8-I3-E waits at exactly same location and releases flee")
	t.check(e.shots_fired==shots and f.boss.ready_at.ice_elf_basic==ready and ready<f.manager._elapsed_seconds,"S8-I3-E no new attack while existing cooldown expires")
	step(f,0.11)
	t.check(not f.player.is_stealthed() and e.shots_fired==shots+1 and e.last_branch=="basic","S8-I3-E inside resumes basic without second stealth")
	await roles.cleanup(f)

func self_stealth_and_burst() -> void:
	var f: Dictionary = helper.fixture()
	helper.disable_skills(f)
	var b: Variant = f.boss
	var e: Variant = b.elf
	b.ready_at.ice_elf_stealth = 0
	helper.step(f,0)
	var hidden_until: float = e.hidden_until
	b.ready_at.ice_elf_burst = 0
	helper.step(f,0)
	helper.step(f,0.3)
	t.check(e.hidden and e.burst and e.shots_fired==1,"S8-I3-E actual hidden burst before player stealth")
	unlock_and_cast(f)
	var position: Vector2 = b.global_position
	helper.step(f,0)
	var interrupted: float = f.manager._elapsed_seconds
	t.check(not e.burst and e.last_branch=="stealth_wait" and b.ready_at.ice_elf_burst==interrupted+9 and e.recovery_until==interrupted,"S8-I3-E burst interruption starts same9 cooldown without recovery")
	step(f,1)
	t.check(b.global_position==position and e.hidden and e.hidden_until==hidden_until and is_equal_approx(b.ready_at.ice_elf_burst-f.manager._elapsed_seconds,8),"S8-I3-E self stealth deadline unchanged and burst cooldown progresses while waiting")
	b.apply_damage(1)
	t.check(not e.hidden and b.ready_at.ice_elf_stealth==f.manager._elapsed_seconds+12,"S8-I3-E existing hit break and12 cooldown work during player stealth")
	await roles.cleanup(f)
	f = helper.fixture()
	helper.disable_skills(f)
	b = f.boss
	e = b.elf
	b.ready_at.ice_elf_stealth = 0
	helper.step(f,0)
	hidden_until = e.hidden_until
	helper.step(f,4)
	unlock_and_cast(f)
	step(f,1.5)
	t.check(f.player.is_stealthed() and not e.hidden and b.ready_at.ice_elf_stealth==hidden_until+12 and e.last_branch=="stealth_wait","S8-I3-E self stealth naturally expires during player stealth wait")
	await roles.cleanup(f)

func pursuit_after_stealth() -> void:
	var probe := Probe.new()
	probe.t = t
	probe.roles = roles
	var f: Dictionary = probe.fixture(true)
	helper.disable_skills(f)
	t.check(f.skills.try_use("skill_stealth") and f.player.move_speed==250,"S8-I3-E continuous250 escape starts with real stealth")
	var e: Variant = f.boss.elf
	var last := ""
	var log := FileAccess.open("res://.local/s8-impl-03-e-pursuit-"+str(Time.get_ticks_usec())+".jsonl",FileAccess.WRITE)
	var result: Dictionary = {}
	var still := true
	var shrinking := 0
	var visible_follow := 0
	for i in range(1800):
		var previous: float = f.boss.global_position.distance_to(f.player.global_position)
		var boss_position: Vector2 = f.boss.global_position
		Input.action_press("move_right")
		f.player._physics_process(Probe.DT)
		Input.action_release("move_right")
		f.skills._physics_process(Probe.DT)
		f.manager._physics_process(Probe.DT)
		var state: Dictionary = probe.snapshot(f)
		if f.player.is_stealthed(): still = still and f.boss.global_position==boss_position
		elif e.last_branch=="follow":
			visible_follow+=1
			if state.distance<previous: shrinking+=1
		if e.last_branch!=last:
			state.reason = probe.reason(state,state.distance)
			log.store_line(JSON.stringify(state))
			last = e.last_branch
		if e.shots_fired>0:
			result = state
			break
	t.check(still and visible_follow>0 and shrinking==visible_follow,"S8-I3-E after stealth every visible open chase frame closes gap against250")
	t.check(not result.is_empty() and result.inside416 and result.branch=="basic" and result.relative_time<30,"S8-I3-E continuously escaping250 player eventually attacked inside416 without recast")
	print("S8-I3-E CHASE RESULT ",JSON.stringify(result)," shrink_frames=",shrinking,"/",visible_follow," LOG ",log.get_path().trim_prefix("res://"))
	log.close()
	await roles.cleanup(f)

func other_actors() -> void:
	var f: Dictionary = helper.helper.active_fixture()
	var b: Variant = f.boss
	b.global_position = Vector2.ZERO
	f.player.stealth_remaining = 2
	b.rng.seed = 7
	b.boss_tick(0.1)
	t.check(b.elf==null and b.has_wander_target and b.move_speed==90 and is_equal_approx(b.global_position.length(),minf(9,b.wander_target.length())),"S8-I3-E bear keeps wandering and90 speed")
	await roles.cleanup(f)
	var baruka := preload("res://tests/baruka_boss_p0.gd").new()
	baruka.t = t
	baruka.store = store
	baruka.base = helper.helper
	f = baruka.fixture()
	b = f.boss
	f.player.stealth_remaining = 2
	b.rng.seed = 7
	b.boss_tick(0.1)
	t.check(b.baruka.last_branch=="wander" and b.has_wander_target and b.move_speed==156 and is_equal_approx(b.global_position.length(),minf(15.6,b.wander_target.length())),"S8-I3-E Baruka keeps wandering and156 speed")
	await roles.cleanup(f)
	f = roles.fixture()
	f.player.stealth_remaining = 2
	f.manager._random.seed = 7
	f.manager._spawn_from_row({"Spawn_count":1,"Enemy_id":"enemy_01"})
	var normal: EnemyActor = f.manager._active_enemies.back()
	normal.global_position = Vector2(300,0)
	f.manager._update_active_enemies(0.1)
	t.check(normal.has_wander_target and normal.move_speed==120 and normal.global_position!=Vector2(300,0) and is_equal_approx(normal.global_position.distance_to(Vector2(300,0)),minf(12,normal.wander_target.distance_to(Vector2(300,0)))),"S8-I3-E normal enemy keeps wandering and120 speed")
	await roles.cleanup(f)
