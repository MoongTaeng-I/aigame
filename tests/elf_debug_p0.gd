extends RefCounted

const Recorder = preload("res://scripts/elf_debug_recorder.gd")
const DT := 1.0/60.0
var t: SceneTree
var roles: RefCounted
var store: CsvDataStore
var summaries: Array = []
var stem: String

func run(tree: SceneTree) -> void:
	t = tree
	var before: int = t.checks
	var failed: int = t.failures
	store = t._store()
	t.check(store.load_all().is_empty(),"S8-I4-B debug probe data load")
	roles = preload("res://tests/boss_roles_p0.gd").new()
	roles.t = t
	roles.store = store
	stem = "res://.local/s8-impl-04-b-elf-"+str(Time.get_ticks_usec())
	t.check(not Recorder.requested(),"S8-I4-B debug defaults off (no flag/file)")
	var disabled := debug_files()
	var off: Array = await replay(false)
	t.check(debug_files()==disabled,"S8-I4-B disabled actual main creates no debug file")
	var on: Array = await replay(true)
	t.check(off==on,"S8-I4-B on/off identical every-frame position damage cooldown shots and RNG")
	for scenario in ["wall","corner","wall_flee","after_push","shadow_attacks","crowd4","crowd5"]:
		await investigate(scenario)
	var file := FileAccess.open(stem+"-summary.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(summaries,"\t"))
	file.close()
	print("S8-I4-B INVESTIGATION: ",stem,"-summary.json and scenario JSONL files")
	print("S8-IMPL-04-B NEW RESULT: %d checks, %d failures" % [t.checks-before,t.failures-failed])

func debug_files() -> PackedStringArray:
	var result := PackedStringArray()
	for name in DirAccess.get_files_at("res://.local"):
		if name.begins_with("elf-debug-") and name.ends_with(".jsonl"): result.append(name)
	result.sort()
	return result

func fixture(scenario: String = "") -> Dictionary:
	var f: Dictionary = roles.fixture()
	f.director.timeline = [{"Id":"probe","Time_mmss":0,"Boss_id":"boss_early"}]
	f.manager._random.seed = 7
	if scenario.begins_with("crowd"):
		# Historical stage fixture: normal 4/5-per-second accumulation BEFORE warning.
		f.director.timeline = []
		var start := 180.0 if scenario=="crowd4" else 330.0
		for second in range(20):
			f.manager._elapsed_seconds = start+second
			f.manager._advance_spawn_rows(1.0)
		f.director.timeline = [{"Id":"probe","Time_mmss":0,"Boss_id":"boss_early"}]
	roles.at(f,f.manager._elapsed_seconds)
	roles.at(f,f.manager._elapsed_seconds+3.5)
	f.boss = f.director.actor
	f.boss.global_position = Vector2.ZERO
	f.player.global_position = Vector2(350,0)
	f.boss.rng.seed = 7
	f.boss.hp = 1000000000
	f.boss.max_hp = 1000000000
	f.start = f.manager._elapsed_seconds
	return f

func attach(f: Dictionary, suffix: String) -> Node:
	var recorder := Recorder.new()
	recorder.configure(f.manager,stem+"-"+suffix+".jsonl")
	f.host.add_child(recorder)
	recorder.set_physics_process(false)
	f.recorder = recorder
	return recorder

func frame(f: Dictionary) -> void:
	f.player._physics_process(DT)
	f.skills._physics_process(DT)
	f.manager._physics_process(DT)

func replay(enabled: bool) -> Array:
	var f := fixture()
	t.check(f.host.get_node_or_null("ElfDebugRecorder")==null,"S8-I4-B off main has no recorder node")
	var recorder: Node
	if enabled: recorder = attach(f,"parity")
	var states: Array = []
	for i in range(720):
		if i==60: f.player.stealth_remaining = 2
		if i==240: f.boss.apply_fear(0.5)
		if i==300: f.player.apply_freeze(0.5)
		if i==420: f.player.global_position = Vector2(700,0)
		frame(f)
		if enabled: recorder.observe()
		states.append([f.player.hp,f.player.global_position,f.boss.global_position,f.boss.ready_at.duplicate(),f.boss.elf.shots_fired,f.boss.elf.last_branch,f.boss.fear_remaining,f.manager._random.state])
	if enabled:
		var pre := lines(recorder.output_path)
		recorder.observe()
		recorder.observe()
		t.check(lines(recorder.output_path).size()==pre.size(),"S8-I4-B same branch creates zero extra lines")
		var key := InputEventKey.new()
		key.keycode = KEY_F9
		key.pressed = true
		# Deliver through Godot input dispatch, including a paused/dead snapshot.
		f.player.is_dead = true
		t.paused = true
		Input.parse_input_event(key)
		await t.process_frame
		key.echo = true
		Input.parse_input_event(key)
		await t.process_frame
		t.paused = false
		var output := lines(recorder.output_path)
		var marker: Dictionary = output.back()
		t.check(output.size()==pre.size()+1 and marker.event=="user_marker" and marker.label=="사용자 표시" and marker.player_dead and marker.paused,"S8-I4-B F9 one full marker while paused/dead; echo ignored")
		var previous := ""
		var transitions_only := true
		for row in pre:
			transitions_only = transitions_only and row.event=="branch_change" and row.previous_branch==previous and row.next_branch!=previous
			previous = row.next_branch
		t.check(transitions_only and pre.size()<720,"S8-I4-B records only actual branch transitions")
		for field in ["wall_time","time","reason","distance","inside416","player_stealth","player_frozen","player_dead","elf_hidden","flee","burst","fear","cooldowns","recovery_remaining","shots","elf_position","player_position","elf_map_edges","player_map_edges","map_bounds"]:
			t.check(marker.has(field),"S8-I4-B full state field "+field)
	await roles.cleanup(f)
	return states

func lines(path: String) -> Array:
	var output: Array = []
	for line in FileAccess.get_file_as_string(path).split("\n",false): output.append(JSON.parse_string(line))
	return output

func eligible(f: Dictionary) -> bool:
	var e: Variant = f.boss.elf
	var at: float = f.manager._elapsed_seconds+DT
	var distance: float = f.boss.global_position.distance_to(f.player.global_position)
	if f.player.is_dead or f.player.is_stealthed() or f.boss.fear_remaining>0 or e.fleeing or e.burst or at<e.recovery_until: return false
	if distance>e.detect_range or distance>float(e.rows[3].Use_range): return false
	if distance<=float(e.rows[4].Use_range) and at>=float(f.boss.ready_at[e.rows[4].Id]): return false
	if not e.hidden and at>=float(f.boss.ready_at[e.rows[6].Id]): return false
	if distance<=float(e.rows[5].Use_range) and at>=float(f.boss.ready_at[e.rows[5].Id]): return false
	return at+0.000000001>=float(f.boss.ready_at[e.rows[3].Id])

func investigate(scenario: String) -> void:
	var f := fixture(scenario)
	var e: Variant = f.boss.elf
	if scenario=="wall":
		f.player.global_position = Vector2(1264,0)
		f.boss.global_position = Vector2(1000,0)
	elif scenario=="corner":
		f.player.global_position = Vector2(1264,704)
		f.boss.global_position = Vector2(1100,540)
	elif scenario=="wall_flee":
		f.boss.global_position = Vector2(1252,0)
		f.player.global_position = Vector2(1100,0)
		for kind in [4,5,6]: f.boss.ready_at[e.rows[kind].Id] = f.start+30
	elif scenario=="after_push":
		f.boss.global_position = Vector2(1100,0)
		f.player.global_position = Vector2(1200,0)
	elif scenario=="shadow_attacks":
		var shadows: Node2D = f.host.get_child(0).get_node("ShadowManager")
		var shadow: Node2D = shadows.summon("igrit")
		shadow.random.seed = 7
		shadow.global_position = Vector2(30,0)
	elif scenario.begins_with("crowd"):
		var normals: Array = f.manager.get_living_enemies()
		var index := 0
		for enemy in normals:
			if enemy==f.boss: continue
			enemy.global_position = Vector2.RIGHT.rotated(TAU*index/normals.size())*(50+index%5*20)
			index+=1
	var recorder := attach(f,scenario)
	var counts := {}
	var missed := 0
	var eligible_frames := 0
	var target_errors := 0
	var clock_errors := 0
	var max_no_shot := 0.0
	var last_shot: float = f.manager._elapsed_seconds
	var max_idle_displacement := 0.0
	var saw_flee := false
	var saw_push := false
	var initial_alive: int = f.manager.get_alive_count()
	var start_hp: int = f.boss.hp
	f.player.enhancement_points = 1
	t.check(f.skills.try_upgrade("skill_stealth"),"S8-I4-B probe real stealth unlock "+scenario)
	for i in range(1200):
		if i==120 or i==850:
			t.check(f.skills.try_use("skill_stealth"),"S8-I4-B probe first/second real stealth cast "+scenario)
		var can_attack := eligible(f)
		var shots: int = e.shots_fired
		var position: Vector2 = f.boss.global_position
		var shadows: Node2D = f.host.get_child(0).get_node("ShadowManager")
		shadows._physics_process(DT)
		frame(f)
		recorder.observe()
		if can_attack:
			eligible_frames+=1
			if e.shots_fired==shots: missed+=1
		if e.shots_fired>shots: last_shot = f.manager._elapsed_seconds
		max_no_shot = maxf(max_no_shot,f.manager._elapsed_seconds-last_shot)
		counts[e.last_branch] = int(counts.get(e.last_branch,0))+1
		if e.last_branch in ["basic","stealth_wait","recovery","burst","burst_start","stealth","push"]:
			max_idle_displacement = maxf(max_idle_displacement,position.distance_to(f.boss.global_position))
		if e.fleeing or e.last_branch=="flee": saw_flee = true
		if e.last_branch=="push": saw_push = true
		if f.boss.target_provider.call()!=f.player: target_errors+=1
		if not is_equal_approx(f.boss.clock,f.manager._elapsed_seconds): clock_errors+=1
	var summary := {"scenario":scenario,"frames":1200,"duration_sec":20,"shots":e.shots_fired,"eligible_basic_frames":eligible_frames,"eligible_but_no_shot_frames":missed,"max_no_shot_sec":max_no_shot,"branch_frames":counts,"target_errors":target_errors,"clock_errors":clock_errors,"saw_flee":saw_flee,"saw_push":saw_push,"elf_damage_from_shadows":start_hp-f.boss.hp,"initial_alive":initial_alive,"final_alive":f.manager.get_alive_count(),"max_nonmoving_branch_displacement":max_idle_displacement,"log":recorder.output_path}
	summaries.append(summary)
	t.check(missed==0 and target_errors==0 and clock_errors==0,"S8-I4-B no eligible basic missed/BT clock/target failure "+scenario)
	t.check(e.shots_fired>0,"S8-I4-B attacks occur in probe "+scenario)
	if scenario=="wall_flee": t.check(saw_flee,"S8-I4-B probe really reaches wall flee and resumes")
	if scenario=="after_push": t.check(saw_push,"S8-I4-B probe really reaches push and resumes")
	if scenario=="shadow_attacks": t.check(f.boss.hp<start_hp,"S8-I4-B actual shadow attacks damage elf")
	if scenario.begins_with("crowd"):
		t.check(initial_alive>80 and f.manager._stop_normal_spawning and max_idle_displacement>0,"S8-I4-B preexisting 4/5-per-sec crowd pushes while boss stops new spawns "+scenario)
	print("S8-I4-B PROBE ",JSON.stringify(summary))
	await roles.cleanup(f)
