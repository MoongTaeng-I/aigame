extends RefCounted

const Store = preload("res://scripts/csv_data_store.gd")
const Data = preload("res://scripts/combat_data.gd")
const Player = preload("res://scenes/player.tscn")
const Manager = preload("res://scripts/enemy_manager.gd")
const Map = preload("res://scenes/map.tscn")

func fixture(tree: SceneTree, count: int, iterations: int) -> Dictionary:
	var store := Store.new()
	Data.register_schemas(store)
	assert(store.load_all().is_empty())
	var map = Map.instantiate()
	tree.root.add_child(map)
	var row: Dictionary = store.get_row("player.csv","player_01")
	var player = Player.instantiate()
	player.configure_body(float(row.Body_radius),float(row.Push_weight))
	player.configure_combat(1000000000,store.get_row("basic_attack.csv","attack_01"))
	player.move_speed = float(row.Move_speed)
	player.get_node("Camera2D").enabled = false
	map.add_child(player)
	player.set_physics_process(false)
	var manager := Manager.new()
	var rule: Dictionary = store.get_row("spawn_rule.csv","rule_01")
	manager.configure(player,map.get_map_rect(),store.get_table("enemy.csv"),{},count,float(rule.Offscreen_relocate_sec),store.get_table("projectile.csv"),store.get_row("basic_attack.csv","attack_01"),float(rule.Separation_gap),iterations)
	map.add_child(manager)
	manager.set_physics_process(false)
	manager._random.seed = 20261109
	manager._spawn_from_row({"Spawn_count":count,"Enemy_id":"enemy_01"})
	for index in range(manager.get_alive_count()):
		manager._active_enemies[index].position = Vector2.RIGHT.rotated(TAU*index/count)*400.0
	return {"host":map,"player":player,"manager":manager}

func deficits(enemies: Array, gap: float) -> Dictionary:
	var values: Array[float] = []
	var overlaps := 0
	for i in range(enemies.size()):
		var nearest := INF
		var nearest_target := 0.0
		for j in range(enemies.size()):
			if i==j: continue
			var distance: float = enemies[i].position.distance_to(enemies[j].position)
			var radii: float = enemies[i].body_radius+enemies[j].body_radius
			if distance<nearest:
				nearest = distance
				nearest_target = radii+gap
			if j>i and distance<radii: overlaps += 1
		values.append(maxf(0.0,nearest_target-nearest))
	values.sort()
	var total := 0.0
	for value in values: total += value
	return {"count":enemies.size(),"maximum":values[-1],"p95":values[ceili(values.size()*0.95)-1],"mean":total/values.size(),"overlap_pairs":overlaps}

func simulate(tree: SceneTree, iterations: int) -> Dictionary:
	var f := fixture(tree,100,iterations)
	for frame in range(600):
		# The requested stationary player is anchored at map center. Only HP is enlarged.
		f.player.position = Vector2.ZERO
		f.player._physics_process(1.0/60.0)
		f.manager._physics_process(1.0/60.0)
	var result := deficits(f.manager.get_living_enemies(),f.manager.separation_gap)
	result.iterations = iterations
	result.player_alive = not f.player.is_dead
	f.host.free()
	return result

func benchmark(tree: SceneTree, iterations: int) -> float:
	var f := fixture(tree,200,iterations)
	# Dense initial state is deterministic and identical for every N.
	for index in range(200):
		f.manager._active_enemies[index].position = Vector2(index%20-10,index/20-5)*24.0
	var total_us := 0
	for frame in range(120):
		f.player.position = Vector2.ZERO
		f.manager._update_active_enemies(1.0/60.0)
		var started := Time.get_ticks_usec()
		f.manager._resolve_contact_pushes()
		total_us += Time.get_ticks_usec()-started
	f.host.free()
	return float(total_us)/120.0/1000.0
