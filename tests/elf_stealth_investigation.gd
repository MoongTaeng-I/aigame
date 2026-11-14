extends RefCounted

const DT := 1.0/60.0
var t: SceneTree
var roles: RefCounted
var log_file: FileAccess
var summaries: Array = []

func run(tree: SceneTree) -> void:
	t = tree
	roles = preload("res://tests/boss_roles_p0.gd").new()
	roles.t = t
	roles.store = t._store()
	roles.store.load_all()
	# A separate file per P0 execution; no earlier investigation log is overwritten.
	var stem := "res://.local/s8-impl-03-e-elf-"+str(Time.get_ticks_usec())
	log_file = FileAccess.open(stem+"-transitions.jsonl",FileAccess.WRITE)
	for mode in ["stationary","stationary_edge","away","away_open_control"]:
		await lifecycle(mode)
	for state in ["basic","flee","burst","push","self_stealth"]:
		await during_state(state)
	var file := FileAccess.open(stem+"-summary.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(summaries,"\t"))
	file.close()
	log_file.close()
	print("S8-I3-D INVESTIGATION LOG: ",stem.trim_prefix("res://"),"-transitions.jsonl / -summary.json")

func fixture(open_arena: bool = false) -> Dictionary:
	var f: Dictionary
	if open_arena:
		var helper := preload("res://tests/boss_p0.gd").new()
		helper.t = t
		helper.store = roles.store
		f = helper.fixture({"probe":{"Id":"probe","Time_mmss":0,"Boss_id":"boss_early"}})
		f.manager.configure(f.player,Rect2(-20000,-20000,40000,40000),roles.store.get_table("enemy.csv"),{},1000,0,roles.store.get_table("projectile.csv"),{},0,1)
		var player_data: Dictionary = roles.store.get_row("player.csv","player_01")
		f.player.configure_body(float(player_data.Body_radius),float(player_data.Push_weight))
		f.player.move_speed = float(player_data.Move_speed)
		f.player.configure_combat(100000,{})
		roles.at(f,0)
		roles.at(f,3.5)
	else:
		f = roles.fixture()
		# Keep actual Enemy_id/Kind generation, shifting only this probe's spawn time.
		f.director.timeline = [{"Id":"probe","Time_mmss":0,"Boss_id":"boss_early"}]
		roles.at(f,0)
		roles.at(f,3.5)
	f.boss = f.director.actor
	f.boss.global_position = Vector2.ZERO
	f.player.global_position = Vector2(350,0)
	f.boss.rng.seed = 7
	f.player.enhancement_points = 1
	t.check(f.skills.try_upgrade("skill_stealth"),"S8-I3-D investigation unlocks stealth through production upgrade")
	f.last_logged = ""
	f.frames = 0
	f.target_errors = 0
	f.clock_errors = 0
	f.timer_error = 0.0
	f.start_time = f.manager._elapsed_seconds
	f.checkpoints = []
	f.casts = 0
	f.outside_visible_frames = 0
	f.outside_visible_follow_frames = 0
	f.in_bounds_moving_frames = 0
	f.gap_growth_frames = 0
	f.hidden_starts = 0
	f.hidden_ends = 0
	f.hidden_extensions = 0
	f.stealth_move_max = 0.0
	f.gap_shrink_frames = 0
	return f

func snapshot(f: Dictionary) -> Dictionary:
	var e: Variant = f.boss.elf
	var distance: float = f.player.global_position.distance_to(f.boss.global_position)
	var cooldowns: Dictionary = {}
	for row in f.boss.actions: cooldowns[row.Id] = maxf(0,float(f.boss.ready_at[row.Id])-f.manager._elapsed_seconds)
	return {"time":f.manager._elapsed_seconds,"relative_time":f.manager._elapsed_seconds-f.start_time,"player_stealth":f.player.is_stealthed(),"player_timer":f.player.stealth_remaining,"distance":distance,"inside416":distance<=416,"elf_hidden":e.hidden,"elf_hidden_remaining":maxf(0,e.hidden_until-f.manager._elapsed_seconds) if e.hidden else 0.0,"flee":e.fleeing,"burst":e.burst,"cooldowns":cooldowns,"recovery_remaining":maxf(0,e.recovery_until-f.manager._elapsed_seconds),"branch":e.last_branch,"shots":e.shots_fired}

func reason(state: Dictionary, decision_distance: float) -> String:
	match state.branch:
		"stealth_wait": return "player stealth branch interrupts flee/burst and waits in place"
		"follow": return "outside Detect_range; no new attack; approach" if decision_distance>416 else "approach to Use_range"
		"stealth": return "self stealth ready (also allowed outside Detect_range)"
		"push": return "inside Use_range and push ready; higher priority"
		"burst_start": return "inside Detect_range/Use_range and burst ready"
		"burst": return "committed burst precedes detection check"
		"flee": return "committed flee precedes skill selection"
		"recovery": return "burst recovery deadline not elapsed"
	return "inside Detect_range/Use_range; ranged basic branch (shot only when ready)"

func step(f: Dictionary, scenario: String, phase: String, moving: bool) -> void:
	var old_timer: float = f.player.stealth_remaining
	var old_hidden: bool = f.boss.elf.hidden
	var old_hidden_until: float = f.boss.elf.hidden_until
	var old_position: Vector2 = f.player.global_position
	var old_distance: float = old_position.distance_to(f.boss.global_position)
	if moving:
		var direction: Vector2 = f.boss.global_position.direction_to(old_position)
		Input.action_press("move_right",maxf(0,direction.x))
		Input.action_press("move_left",maxf(0,-direction.x))
		Input.action_press("move_down",maxf(0,direction.y))
		Input.action_press("move_up",maxf(0,-direction.y))
	f.player._physics_process(DT)
	for action in ["move_right","move_left","move_down","move_up"]: Input.action_release(action)
	f.skills._physics_process(DT)
	var boss_before: Vector2 = f.boss.global_position
	var decision_distance: float = f.player.global_position.distance_to(f.boss.global_position)
	f.manager._physics_process(DT)
	f.frames+=1
	if f.boss.target_provider.call()!=f.player: f.target_errors+=1
	if not is_equal_approx(f.boss.clock,f.manager._elapsed_seconds): f.clock_errors+=1
	f.timer_error = maxf(f.timer_error,absf(f.player.stealth_remaining-maxf(0,old_timer-DT)))
	if not old_hidden and f.boss.elf.hidden: f.hidden_starts+=1
	if old_hidden and not f.boss.elf.hidden: f.hidden_ends+=1
	if old_hidden and f.boss.elf.hidden and f.boss.elf.hidden_until>old_hidden_until+0.000001: f.hidden_extensions+=1
	if f.player.is_stealthed(): f.stealth_move_max = maxf(f.stealth_move_max,boss_before.distance_to(f.boss.global_position))
	var state := snapshot(f)
	if not state.player_stealth and decision_distance>416:
		f.outside_visible_frames+=1
		if state.branch=="follow": f.outside_visible_follow_frames+=1
	if moving and f.player.global_position.distance_to(old_position)>4.0 and state.branch=="follow":
		f.in_bounds_moving_frames+=1
		if state.distance>old_distance: f.gap_growth_frames+=1
		if state.distance<old_distance: f.gap_shrink_frames+=1
	if state.branch!=f.last_logged:
		state.scenario = scenario
		state.phase = phase
		state.previous_branch = f.last_logged
		state.decision_distance = decision_distance
		state.reason = reason(state,decision_distance)
		log_file.store_line(JSON.stringify(state))
		f.last_logged = state.branch

func checkpoint(f: Dictionary, phase: String) -> void:
	var state := snapshot(f)
	state.phase = phase
	f.checkpoints.append(state)

func cast(f: Dictionary) -> void:
	t.check(f.skills.try_use("skill_stealth"),"S8-I3-D investigation actual stealth cast")
	f.casts+=1
	t.check(is_equal_approx(f.player.stealth_remaining,2) and not f.skills.try_use("skill_stealth"),"S8-I3-D actual timer2 starts once and duplicate rejected")

func finish(f: Dictionary, scenario: String) -> void:
	t.check(f.clock_errors==0 and f.target_errors==0 and f.timer_error<0.000001,"S8-I3-D probe BT clock/target/timer invariant "+scenario)
	t.check(f.stealth_move_max<0.000001,"S8-I3-E same D scenario stays still throughout player stealth "+scenario)
	t.check(f.hidden_extensions==0,"S8-I3-D self stealth timer never refreshed by player stealth "+scenario)
	var result := {"scenario":scenario,"frames":f.frames,"max_stealth_displacement":f.stealth_move_max,"gap_shrink_frames":f.gap_shrink_frames,"clock_errors":f.clock_errors,"target_errors":f.target_errors,"max_player_timer_error":f.timer_error,"elf_hidden_starts":f.hidden_starts,"elf_hidden_ends":f.hidden_ends,"elf_hidden_extensions":f.hidden_extensions,"casts":f.casts,"outside_visible_frames":f.outside_visible_frames,"outside_visible_follow_frames":f.outside_visible_follow_frames,"in_bounds_moving_follow_frames":f.in_bounds_moving_frames,"gap_growth_frames":f.gap_growth_frames,"checkpoints":f.checkpoints}
	summaries.append(result)
	print("S8-I3-D PROBE SUMMARY ",scenario," frames=",f.frames," clock_errors=",f.clock_errors," target_errors=",f.target_errors," timer_error=",f.timer_error)
	await roles.cleanup(f)

func lifecycle(mode: String) -> void:
	var f := fixture(mode=="away_open_control")
	if mode=="stationary_edge": f.player.global_position = Vector2(415,0)
	var moving := mode.begins_with("away")
	for i in range(30): step(f,mode,"before_first",moving)
	checkpoint(f,"before_first")
	cast(f)
	step(f,mode,"first_start",moving)
	checkpoint(f,"first_start")
	for i in range(59): step(f,mode,"first_maintained",moving)
	checkpoint(f,"first_maintained")
	for i in range(61): step(f,mode,"first_expired",moving)
	checkpoint(f,"first_expired")
	for i in range(600): step(f,mode,"between_casts",moving)
	checkpoint(f,"before_second")
	cast(f)
	step(f,mode,"second_start",moving)
	checkpoint(f,"second_start")
	for i in range(120): step(f,mode,"second_expired",moving)
	checkpoint(f,"second_expired")
	t.check(not f.player.is_stealthed(),"S8-I3-D two real stealth expirations "+mode)
	await finish(f,mode)

func during_state(state: String) -> void:
	var f := fixture()
	var e: Variant = f.boss.elf
	# State-isolation setup changes only fixture readiness, never production data.
	for kind in [4,5,6]: f.boss.ready_at[e.rows[kind].Id] = f.manager._elapsed_seconds+30
	if state=="flee": f.player.global_position = Vector2(200,0)
	elif state=="push":
		f.player.global_position = Vector2(100,0)
		f.boss.ready_at.ice_elf_push = 0
	elif state=="burst": f.boss.ready_at.ice_elf_burst = 0
	elif state=="self_stealth": f.boss.ready_at.ice_elf_stealth = 0
	step(f,state,"prepare_state",false)
	if state=="flee" or state=="burst":
		for i in range(3 if state=="flee" else 22): step(f,state,"prepare_state",false)
	checkpoint(f,"before_cast")
	t.check((e.last_branch=="basic" if state=="basic" else e.fleeing if state=="flee" else e.burst if state=="burst" else f.player.boss_push_duration>f.player.boss_push_elapsed if state=="push" else e.hidden),"S8-I3-D probe reaches actual state "+state)
	cast(f)
	step(f,state,"stealth_start",false)
	checkpoint(f,"stealth_start")
	t.check(e.last_branch=="stealth_wait" and not e.fleeing and not e.burst,"S8-I3-D stealth interrupts flee/burst through actual BT "+state)
	for i in range(121): step(f,state,"stealth_expired",false)
	checkpoint(f,"stealth_expired")
	for i in range(360): step(f,state,"post_visible",false)
	checkpoint(f,"post_visible")
	t.check(not f.player.is_stealthed() and not e.hidden and e.last_branch!="stealth_wait","S8-I3-D no retained stealth or wander lock "+state)
	await finish(f,state)
