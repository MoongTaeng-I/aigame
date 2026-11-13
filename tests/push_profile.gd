extends RefCounted

const Crowd = preload("res://tests/crowd_measurement.gd")
const ProfileManager = preload("res://tests/profile_enemy_manager.gd")
const ProfilePlayer = preload("res://tests/profile_player.gd")
const Skills = preload("res://scripts/skill_manager.gd")

func fixture(tree: SceneTree, n: int, reference: bool = false, legacy_single_target: bool = false) -> Dictionary:
	# Same scenes, CSV configuration and production spawning as the crowd regression.
	var store := Crowd.Store.new()
	Crowd.Data.register_schemas(store)
	assert(store.load_all().is_empty())
	var host = Crowd.Map.instantiate()
	tree.root.add_child(host)
	var player = Crowd.Player.instantiate()
	player.set_script(ProfilePlayer)
	player.legacy_single_target = legacy_single_target
	var row: Dictionary = store.get_row("player.csv","player_01")
	player.configure_body(float(row.Body_radius),float(row.Push_weight))
	player.configure_combat(1000000000,store.get_row("basic_attack.csv","attack_01"))
	player.move_speed = float(row.Move_speed)
	player.get_node("Camera2D").enabled = false
	host.add_child(player)
	player.set_physics_process(false)
	var manager := ProfileManager.new()
	var rule: Dictionary = store.get_row("spawn_rule.csv","rule_01")
	manager.configure(player,host.get_map_rect(),store.get_table("enemy.csv"),{},200,float(rule.Offscreen_relocate_sec),store.get_table("projectile.csv"),store.get_row("basic_attack.csv","attack_01"),float(rule.Separation_gap),n)
	manager.reference = reference
	host.add_child(manager)
	manager.set_physics_process(false)
	manager._random.seed = 20261109
	manager._spawn_from_row({"Spawn_count":200,"Enemy_id":"enemy_01"})
	var actors: Array = manager.get_living_enemies()
	for index in range(actors.size()): actors[index].position = Vector2.RIGHT.rotated(TAU*index/200.0)*400.0
	var skills := Skills.new()
	skills.configure(player,manager,store.get_table("skill.csv"),store.get_table("skill_rapid_slash_level.csv"),{"skill_dash":store.get_table("skill_dash_level.csv"),"skill_stealth":store.get_table("skill_stealth_level.csv"),"skill_dragon_fear":store.get_table("skill_dragon_fear_level.csv")},store.get_row("stealth_rule.csv","stealth_rule_01"))
	host.add_child(skills)
	skills.set_physics_process(false)
	skills.skills.skill_dragon_fear.level = 1
	return {"host":host,"player":player,"manager":manager,"skills":skills,"actors":actors,"store":store}

func frame(f: Dictionary) -> Dictionary:
	f.manager.begin_frame()
	f.player.attack_us = 0
	f.player.position = Vector2.ZERO
	var started := Time.get_ticks_usec()
	f.player._physics_process(1.0/60.0)
	f.manager._physics_process(1.0/60.0)
	var skill_started := Time.get_ticks_usec()
	f.skills._physics_process(1.0/60.0)
	var skill_us := Time.get_ticks_usec()-skill_started
	var total_us: int = Time.get_ticks_usec()-started-f.manager.bookkeeping_us
	var result: Dictionary = f.manager.costs.duplicate()
	result.attack = f.player.attack_us
	result.skills = skill_us
	result.physics = total_us
	result.passes = f.manager.pass_us.duplicate()
	result.pairs = f.manager.pair_counts.duplicate()
	return result

func press_fear(f: Dictionary) -> int:
	var started := Time.get_ticks_usec()
	for pressed in [true,false]:
		var key := InputEventKey.new()
		key.physical_keycode = f.skills.SkillData.standard_key(f.skills.records.skill_dragon_fear.Key)
		key.pressed = pressed
		Input.parse_input_event(key)
		Input.flush_buffered_events()
	return Time.get_ticks_usec()-started

func scenario(tree: SceneTree, n: int, fear: bool, frames: int = 180, reference: bool = false, detail: bool = true, legacy_single_target: bool = false) -> Dictionary:
	var f := fixture(tree,n,reference,legacy_single_target)
	f.manager.collecting = detail
	for i in range(120): frame(f)
	var application_us := press_fear(f) if fear else 0
	var rows: Array = []
	for i in range(frames):
		var row := frame(f)
		if detail: rows.append(row)
	var state := snapshot(f)
	var result := {"n":n,"fear":fear,"frames":frames,"application_us":application_us,"rows":rows,"state":state,"alive":f.manager.get_alive_count()}
	f.host.free()
	return result

func snapshot(f: Dictionary) -> Dictionary:
	var actors: Array = []
	for enemy in f.actors:
		actors.append({"order":enemy.spawn_order,"x":enemy.global_position.x,"y":enemy.global_position.y,"hp":enemy.hp,"fear":enemy.fear_remaining,"dead":enemy.is_logically_dead})
	return {"enemies":actors,"player":{"x":f.player.global_position.x,"y":f.player.global_position.y,"hp":f.player.hp}}

static func compare(a: Variant, b: Variant) -> float:
	if a is Dictionary:
		if not b is Dictionary or a.size()!=b.size(): return INF
		var error := 0.0
		for key in a:
			if not b.has(key): return INF
			error = maxf(error,compare(a[key],b[key]))
		return error
	if a is Array:
		if not b is Array or a.size()!=b.size(): return INF
		var error := 0.0
		for i in range(a.size()): error = maxf(error,compare(a[i],b[i]))
		return error
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b))
	return 0.0 if a==b else INF
