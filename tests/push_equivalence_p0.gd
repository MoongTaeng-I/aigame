extends RefCounted

const Reference = preload("res://tests/push_reference.gd")
const Profile = preload("res://tests/push_profile.gd")
var t: SceneTree

func run(tree: SceneTree) -> void:
	t = tree
	for seed_value in range(8):
		for iterations in [1,8]:
			for dash in [false,true]:
				var a := layout(seed_value,iterations,dash)
				var b := layout(seed_value,iterations,dash)
				for iteration in range(iterations): Reference.resolve(a.manager)
				b.manager._resolve_contact_pushes()
				var error := Profile.compare(state(a),state(b))
				t.check(error<=0.001,"PUSH-EQ-01 frozen reference random layout seed=%d N=%d dash=%s max_error=%.9f" % [seed_value,iterations,str(dash),error])
				a.host.queue_free()
				b.host.queue_free()
				await t.process_frame
	var helper := Profile.new()
	var original: Dictionary = helper.scenario(t,8,true,600,true,false)
	var optimized: Dictionary = helper.scenario(t,8,true,600,false,false)
	var error := Profile.compare(original.state,optimized.state)
	t.check(error<=0.001,"PUSH-EQ-02 full 600-frame fear scenario against frozen reference max_error=%.12f" % error)
	# The task artifact is optional for future clean checkouts; the frozen run above is permanent.
	if FileAccess.file_exists("res://.local/s5-fix-03-reference.json"):
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.local/s5-fix-03-reference.json"))
		error = Profile.compare(saved,optimized.state)
		t.check(error<=0.001,"PUSH-EQ-03 pre-optimization saved 600-frame state max_error=%.12f" % error)

func layout(seed_value: int, iterations: int, dash: bool) -> Dictionary:
	var f: Dictionary = t._fixture(24)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000+seed_value
	# Includes transformed parents and map-edge clamping, not only central positions.
	f.host.position = Vector2(23,-31)
	if seed_value%3==0:
		f.host.rotation = 0.03
		f.host.scale = Vector2(1.1,0.9)
	f.manager.separation_gap = 8.0 if seed_value%2==0 else 0.0
	f.manager.push_iterations = iterations
	f.manager._random.seed = 20261109
	f.player.dash_pass_through = dash
	f.player.position = Vector2.ZERO
	f.manager._spawn_from_row({"Spawn_count":24,"Enemy_id":"test"})
	var actors: Array = f.manager.get_living_enemies()
	t.check(actors.size()==24,"SETUP equivalence actors use production spawning")
	for index in range(actors.size()):
		var enemy: EnemyActor = actors[index]
		enemy.position = Vector2(rng.randf_range(-65,65),rng.randf_range(-65,65))
		if seed_value%3==1: enemy.position += Vector2(3970,3970)
		if seed_value%3==2 and index<5: enemy.position = Vector2.ZERO
		enemy.body_radius = rng.randf_range(4,20)
		enemy.push_weight = rng.randf_range(0.1,5)
		enemy.fear_remaining = 2.0 if index%3==0 else 0.0
	actors[0].apply_damage(100)
	actors[1].is_active = false
	f.actors = actors
	return f

func state(f: Dictionary) -> Dictionary:
	var actors: Array = []
	for enemy in f.actors:
		actors.append([enemy.global_position.x,enemy.global_position.y,enemy.hp,enemy.fear_remaining,enemy.is_active,enemy.is_logically_dead])
	return {"enemies":actors,"player":[f.player.global_position.x,f.player.global_position.y,f.player.hp]}
