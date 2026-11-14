extends RefCounted

const SEED := 20261114
const CASES := 128
const FRAME_LIMIT := 240
var t: SceneTree

func run(tree: SceneTree) -> void:
	t = tree
	var before: int = t.checks
	var failed: int = t.failures
	var summary := await trials(tree,"after",true)
	t.check(summary.stuck_count==0,"S8-F4 variable delta/large-coordinate flee never sticks")
	print("S8-FIX-04 NEW RESULT: %d checks, %d failures" % [t.checks-before,t.failures-failed])

func trials(tree: SceneTree, phase: String, check_results: bool) -> Dictionary:
	var store := preload("res://scripts/csv_data_store.gd").new()
	preload("res://scripts/combat_data.gd").register_schemas(store)
	var error := store.load_all()
	if not error.is_empty():
		push_error(error)
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var results: Array = []
	var stuck := 0
	for index in range(CASES):
		# Independent input streams keep before/after cases identical even if they
		# terminate on different frames.
		rng.seed = SEED+index
		var actual_map := index<CASES/2
		var start := Vector2(rng.randf_range(1000,1040),rng.randf_range(350,500)) if actual_map else Vector2(rng.randf_range(1000,2500),rng.randf_range(1000,2500))
		var direction := Vector2.RIGHT.rotated(rng.randf_range(-PI,PI))
		# Real main -> director warning/emergence -> manager -> configured elf.
		var host: Node = load("res://main.tscn").instantiate()
		host.supplied_data = store
		tree.root.add_child(host)
		var nodes: Dictionary = host.round_nodes
		for child in nodes.map.get_children(): child.set_physics_process(false)
		nodes.player.configure_combat(100000,{})
		nodes.director.timeline = [{"Id":"probe","Time_mmss":0,"Boss_id":"boss_early"}]
		nodes.director.advance(0,0)
		nodes.manager._elapsed_seconds = 3.5
		nodes.director.advance(3.5,0)
		var boss: Node2D = nodes.director.actor
		if not actual_map: boss.map_bounds = Rect2(-4000,-4000,8000,8000)
		boss.global_position = start
		nodes.player.global_position = start-direction*200
		var e: Variant = boss.elf
		# Isolate basic -> flee; other skill priority is independently regression-tested.
		for kind in [4,5,6]: boss.ready_at[e.rows[kind].Id] = 99999
		boss.boss_tick(0)
		var entered: bool = e.fleeing and e.shots_fired==1
		var frames := 0
		var zeros := 0
		var first_zero := -1
		var first_zero_state := {}
		var min_delta := 1.0
		var max_delta := 0.0
		while e.fleeing and frames<FRAME_LIMIT:
			var delta := rng.randf_range(0.0166,0.0172)
			min_delta = minf(min_delta,delta)
			max_delta = maxf(max_delta,delta)
			var previous: Vector2 = boss.global_position
			nodes.manager._elapsed_seconds+=delta
			boss.boss_tick(delta)
			frames+=1
			if previous==boss.global_position:
				zeros+=1
				if first_zero<0:
					first_zero = frames
					first_zero_state = {"position":[previous.x,previous.y],"remaining":100.0-e.flee_travelled,"requested_distance":minf(100.0-e.flee_travelled,260*delta),"direction":[e.flee_direction.x,e.flee_direction.y],"branch":e.last_branch}
		var was_stuck: bool = e.fleeing
		if was_stuck: stuck+=1
		var travelled: float = e.flee_travelled
		var end: Vector2 = boss.global_position
		var shots: int = e.shots_fired
		var attack_frames := 0
		if not was_stuck:
			# No stealth reset: remain inside basic range, await the original cooldown.
			while e.shots_fired==shots and attack_frames<90:
				var delta := rng.randf_range(0.0166,0.0172)
				nodes.manager._elapsed_seconds+=delta
				boss.boss_tick(delta)
				attack_frames+=1
		var row := {"case":index,"seed":SEED+index,"arena":"actual_map" if actual_map else "wide_probe","start":[start.x,start.y],"player":[nodes.player.global_position.x,nodes.player.global_position.y],"end":[end.x,end.y],"frames":frames,"first_zero_frame":first_zero,"zero_move_frames":zeros,"first_zero_state":first_zero_state,"delta_min":min_delta,"delta_max":max_delta,"entered_flee":entered,"stuck":was_stuck,"flee_travelled":travelled,"position_distance":start.distance_to(end),"reselection_count":e.flee_reselections,"resumed_basic":e.shots_fired==shots+1 and e.last_branch=="basic","resume_frames":attack_frames}
		results.append(row)
		if check_results:
			t.check(entered and not was_stuck,"S8-F4 production basic enters and completes flee case%d" % index)
			t.check(absf(travelled-100.0)<=0.01 and absf(start.distance_to(end)-100.0)<=0.01,"S8-F4 actual path length100 +/-0.01 case%d" % index)
			t.check(row.resumed_basic,"S8-F4 basic resumes without stealth/reset case%d" % index)
			t.check(e.flee_reselections==0 and boss.map_bounds.grow(-boss.body_radius).has_point(end),"S8-F4 open ray unchanged direction, no reselection or map exit case%d" % index)
		host.queue_free()
		await tree.process_frame
	var summary := {"seed":SEED,"delta_range":[0.0166,0.0172],"cases":CASES,"frame_limit":FRAME_LIMIT,"stuck_count":stuck,"results":results}
	var path := "res://.local/s8-fix-04-flee-"+phase+"-"+str(Time.get_ticks_usec())+".json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(summary,"\t"))
	file.close()
	print("S8-F4 PRECISION phase=",phase," cases=",CASES," stuck=",stuck," LOG ",path.trim_prefix("res://"))
	return summary
