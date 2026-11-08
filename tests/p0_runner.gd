extends SceneTree

const CsvDataStore = preload("res://scripts/csv_data_store.gd")
const CombatDataScript = preload("res://scripts/combat_data.gd")
const PlayerScript = preload("res://scripts/player.gd")
const EnemyScene = preload("res://scenes/enemy.tscn")
const ManagerScript = preload("res://scripts/enemy_manager.gd")
const ProjectileScript = preload("res://scripts/projectile.gd")

class DummyEnemy:
	extends Node2D
	var is_active := true
	var is_logically_dead := false
	var hp := 20
	var spawn_order := 0
	var body_radius := 8.0
	var push_weight := 1.0
	var hit_count := 0
	var knockback_count := 0
	func apply_damage(amount: int) -> bool:
		hit_count += 1
		hp = maxi(0, hp - amount)
		return true
	func start_knockback(_source: Vector2, _distance: float, _duration: float) -> void:
		knockback_count += 1

var _failures := 0
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_p0_01()
	_test_p0_02()
	_test_p0_03()
	_test_p0_04_and_05()
	_test_p0_06_and_07()
	_test_p0_08()
	_test_p0_09_and_10()
	print("P0 RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _assert(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL " + label)

func _new_store() -> CsvDataStore:
	var store := CsvDataStore.new()
	CombatDataScript.register_schemas(store)
	return store

func _test_p0_01() -> void:
	var store := _new_store()
	var error := store.load_all()
	_assert(error.is_empty(), "P0-01 actual CSV files load")
	_assert(CombatDataScript.validate(store).is_empty(), "P0-01 actual combat data validates")

func _test_p0_02() -> void:
	var store := _new_store()
	_assert(not bool(store._convert_value("", {"type":"Enum", "values":{"distance":0,"lifetime":1,"bounds":2}})["ok"]), "P0-02 empty Expire_rule rejected")
	_assert(not bool(store._convert_value("other", {"type":"Enum", "values":{"distance":0,"lifetime":1,"bounds":2}})["ok"]), "P0-02 unknown Expire_rule rejected")
	var valid := _new_store()
	valid.load_all()
	var base_projectiles: Dictionary = valid.tables["projectile.csv"].duplicate(true)
	var base_enemies: Dictionary = valid.tables["enemy.csv"].duplicate(true)
	var projectile: Dictionary = base_projectiles["proj_test_01"].duplicate(true)
	projectile["Max_distance"] = null
	base_projectiles["proj_test_01"] = projectile
	_assert(_validation_error(base_enemies, base_projectiles), "P0-02 distance without Max_distance rejected")
	projectile = base_projectiles["proj_test_01"].duplicate(true)
	projectile["Expire_rule"] = 2
	projectile["Max_distance"] = 10.0
	base_projectiles["proj_test_01"] = projectile
	_assert(_validation_error(base_enemies, base_projectiles), "P0-02 bounds with Max_distance rejected")
	projectile = valid.get_row("projectile.csv", "proj_test_01").duplicate(true)
	base_projectiles["proj_test_01"] = projectile
	var enemy: Dictionary = base_enemies["enemy_test_ranged"].duplicate(true)
	enemy["Projectile_id"] = "missing"
	base_enemies["enemy_test_ranged"] = enemy
	_assert(_validation_error(base_enemies, base_projectiles), "P0-02 unresolved Projectile_id rejected")
	enemy["Projectile_id"] = null
	base_enemies["enemy_test_ranged"] = enemy
	_assert(_validation_error(base_enemies, base_projectiles), "P0-02 ranged missing shot field rejected")
	enemy = base_enemies["enemy_01"].duplicate(true)
	enemy["Projectile_id"] = "proj_test_01"
	base_enemies["enemy_01"] = enemy
	_assert(_validation_error(base_enemies, base_projectiles), "P0-02 melee filled shot field rejected")

func _validation_error(enemies: Dictionary, projectiles: Dictionary) -> bool:
	var store := _new_store()
	store.tables["enemy.csv"] = enemies
	store.tables["projectile.csv"] = projectiles
	store.source_lines["enemy.csv"] = {"enemy_01":2,"enemy_test_ranged":3}
	store.source_lines["projectile.csv"] = {"proj_test_01":2}
	return not CombatDataScript.validate(store).is_empty()

func _attack_data() -> Dictionary:
	return {"Range":90.0,"Damage":10,"Hit_gap_sec":0.15,"Hit_effect_sec":0.20,"Interval_sec":0.60,"Knockback_distance":60.0,"Knockback_sec":0.20}

func _test_p0_03() -> void:
	var player = PlayerScript.new()
	player.configure_combat(100, _attack_data())
	player.position = Vector2.ZERO
	var out := DummyEnemy.new()
	out.position = Vector2(91, 0)
	var high := DummyEnemy.new()
	high.position = Vector2(30, 0)
	high.hp = 12
	high.spawn_order = 1
	var low := DummyEnemy.new()
	low.position = Vector2(50, 0)
	low.hp = 5
	low.spawn_order = 2
	_assert(player.choose_target([out, high, low]) == low, "P0-03 range excludes and lower HP wins")
	high.hp = 5
	_assert(player.choose_target([high, low]) == high, "P0-03 equal HP chooses nearest")
	low.position = high.position
	_assert(player.choose_target([low, high]) == high, "P0-03 equal HP and distance chooses earlier spawn order")
	high.is_logically_dead = true
	_assert(player.choose_target([high, low]) == low, "P0-03 logical death excludes target")
	player.free()

func _test_p0_04_and_05() -> void:
	var host := Node2D.new()
	root.add_child(host)
	var player = PlayerScript.new()
	host.add_child(player)
	player.configure_combat(100, _attack_data())
	var first := DummyEnemy.new()
	first.position = Vector2(20,0)
	first.spawn_order = 1
	host.add_child(first)
	var second := DummyEnemy.new()
	second.position = Vector2(40,0)
	second.spawn_order = 2
	host.add_child(second)
	player.update_basic_attack(0.0, [first,second])
	_assert(first.hit_count == 1, "P0-04 first hit is immediate")
	player.update_basic_attack(0.149, [first,second])
	_assert(second.hit_count == 0, "P0-04 second hit waits for Hit_gap")
	first.hp = 0
	first.is_logically_dead = true
	player.update_basic_attack(0.15, [first,second])
	_assert(second.hit_count == 1, "P0-05 second hit reselects after first target death")
	player.update_basic_attack(0.949, [second])
	_assert(second.hit_count == 1, "P0-04 next attack waits until 0.95")
	second.is_logically_dead = true
	player.update_basic_attack(0.95, [second])
	_assert(second.hit_count == 1, "P0-04 no candidate means wait")
	second.is_logically_dead = false
	player.update_basic_attack(0.951, [second])
	_assert(second.hit_count == 2, "P0-04 attack starts when candidate appears")
	host.queue_free()
	await process_frame

func _test_p0_06_and_07() -> void:
	var player = PlayerScript.new()
	root.add_child(player)
	player.configure_combat(100, _attack_data())
	var manager = ManagerScript.new()
	root.add_child(manager)
	manager.configure(player, Rect2(-100,-100,200,200), {}, {}, 10, 3.0)
	var enemy = EnemyScene.instantiate()
	root.add_child(enemy)
	enemy.configure({"Id":"test","Move_speed":0.0,"Attack_range_type":0,"Body_radius":8.0,"Push_weight":1.0,"Max_hp":10,"Contact_damage":5,"Contact_rehit_sec":1.0,"Death_fade_sec":0.4})
	enemy.activate_at(Vector2(0,0), 1)
	manager._active_enemies.append(enemy)
	var deaths := [0]
	enemy.died.connect(func(_dead): deaths[0] += 1)
	enemy.apply_damage(10)
	enemy.apply_damage(10)
	_assert(deaths[0] == 1 and manager.get_alive_count() == 0, "P0-06 death signal and alive decrement happen once")
	_assert(manager._dying_enemies.has(enemy) and not manager._enemy_pool.has(enemy), "P0-06 fading enemy is excluded and not pooled")
	manager._elapsed_seconds = 0.0
	manager._apply_contact_damage(enemy)
	_assert(player.hp == 100, "P0-06 dead enemy cannot contact damage")
	var live = EnemyScene.instantiate()
	root.add_child(live)
	live.configure({"Id":"live","Move_speed":0.0,"Attack_range_type":0,"Body_radius":8.0,"Push_weight":1.0,"Max_hp":10,"Contact_damage":5,"Contact_rehit_sec":1.0,"Death_fade_sec":0.4})
	live.activate_at(Vector2(0,0), 2)
	manager._elapsed_seconds = 0.0
	manager._apply_contact_damage(live)
	manager._apply_contact_damage(live)
	_assert(player.hp == 95, "P0-07 contact damage is immediate and cooldown suppresses repeat")
	manager._elapsed_seconds = 1.0
	manager._apply_contact_damage(live)
	_assert(player.hp == 90, "P0-07 contact damage repeats after cooldown")
	manager._elapsed_seconds = 1.0
	manager._apply_contact_damage(enemy)
	_assert(player.hp == 85, "P0-07 a different enemy has its own cooldown")
	root.paused = false
	manager.queue_free()
	player.queue_free()
	await process_frame

func _test_p0_08() -> void:
	var player = PlayerScript.new()
	root.add_child(player)
	player.configure_combat(100, _attack_data())
	var record := {"Speed":10.0,"Damage":8,"Body_radius":2.0,"Expire_rule":0,"Max_distance":50.0,"Max_lifetime_sec":null}
	var projectile = ProjectileScript.new()
	root.add_child(projectile)
	projectile.configure(record, Vector2.ZERO, Vector2(100,0), Rect2(-100,-100,200,200), player)
	player.position = Vector2(0,50)
	projectile.advance(0.1)
	_assert(projectile.direction.is_equal_approx(Vector2.RIGHT), "P0-08 projectile direction remains fixed after player moves")
	projectile.global_position = Vector2(0,50)
	projectile.advance(0.01)
	_assert(player.hp == 92 and projectile.is_queued_for_deletion(), "P0-08 projectile hits once and disappears")
	var lifetime = ProjectileScript.new()
	root.add_child(lifetime)
	lifetime.configure({"Speed":1.0,"Damage":1,"Body_radius":1.0,"Expire_rule":1,"Max_distance":null,"Max_lifetime_sec":0.1}, Vector2.ZERO, Vector2.RIGHT, Rect2(-100,-100,200,200), player)
	lifetime.advance(0.1)
	_assert(lifetime.is_queued_for_deletion(), "P0-08 lifetime expiry works")
	var bounds = ProjectileScript.new()
	root.add_child(bounds)
	bounds.configure({"Speed":10.0,"Damage":1,"Body_radius":1.0,"Expire_rule":2,"Max_distance":null,"Max_lifetime_sec":null}, Vector2(9,0), Vector2.RIGHT, Rect2(0,0,10,10), player)
	bounds.advance(0.2)
	_assert(bounds.is_queued_for_deletion(), "P0-08 bounds expiry works")
	player.queue_free()
	await process_frame

func _test_p0_09_and_10() -> void:
	var player = PlayerScript.new()
	root.add_child(player)
	player.configure_combat(10, _attack_data())
	player.apply_damage(10)
	_assert(player.is_dead and root.paused, "P0-10 zero HP pauses the game")
	_assert(player._death_label != null and player._death_label.text == "사망", "P0-10 death indicator appears")
	root.paused = false
	player.queue_free()
	await process_frame
