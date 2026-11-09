extends SceneTree

const Store = preload("res://scripts/csv_data_store.gd")
const Data = preload("res://scripts/combat_data.gd")
const PlayerScene = preload("res://scenes/player.tscn")
const Manager = preload("res://scripts/enemy_manager.gd")
const Projectile = preload("res://scripts/projectile.gd")
const MapScene = preload("res://scenes/map.tscn")
const ExperienceData = preload("res://scripts/experience_data.gd")
const ExperienceManager = preload("res://scripts/experience_manager.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_data()
	await _test_targeting()
	await _test_timing()
	await _test_death()
	await _test_contact()
	await _test_projectiles()
	await _test_knockback()
	await _test_player_death()
	print("S3 BASELINE: %d checks, %d failures" % [checks, failures])
	await _test_xp_drop()
	await _test_xp_pickup()
	await _test_xp_progression()
	await _test_xp_cap()
	_test_xp_csv()
	print("S3+S4 BASELINE: %d checks, %d failures" % [checks, failures])
	var foundation = preload("res://tests/foundation_p0.gd").new()
	await foundation.run(self)
	checks += foundation.checks
	failures += foundation.failures
	print("MISMATCH SUMMARY: %d spec mismatches" % foundation.mismatches.size())
	for item in foundation.mismatches:
		print("MISMATCH ", JSON.stringify(item))
	print("P0 RESULT: %d checks, %d failures, %d spec mismatches" % [checks, failures, foundation.mismatches.size()])
	quit(0 if failures == 0 else 1)

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		push_error("FAIL " + label)

func _attack() -> Dictionary:
	return {"Hits_per_attack":2,"Range":90.0,"Damage":10,"Hit_gap_sec":0.15,"Hit_effect_sec":0.20,"Interval_sec":0.60,"Knockback_distance":60.0,"Knockback_sec":0.20}

func _enemy() -> Dictionary:
	return {"Id":"test","Move_speed":0.0,"Attack_range_type":0,"Body_radius":8.0,"Push_weight":1.0,"Max_hp":100,"Contact_damage":5,"Contact_rehit_sec":1.0,"Death_fade_sec":0.4,"Shot_interval_sec":null,"Shot_range":null,"Projectile_id":null}

func _projectile(rule: int = 0) -> Dictionary:
	return {"Id":"shot","Speed":100.0,"Damage":8,"Body_radius":2.0,"Expire_rule":rule,"Max_distance":500.0 if rule == 0 else null,"Max_lifetime_sec":1.0 if rule == 1 else null}

func _fixture(cap: int = 10) -> Dictionary:
	var host := Node2D.new()
	root.add_child(host)
	var player = PlayerScene.instantiate()
	player.get_node("Camera2D").enabled = false
	player.configure_body(8.0, 3.0)
	player.configure_combat(100, _attack())
	host.add_child(player)
	player.set_physics_process(false)
	var manager = Manager.new()
	manager.configure(player, Rect2(-4000,-4000,8000,8000), {"test":_enemy()}, {}, cap, 0.0, {"shot":_projectile()})
	host.add_child(manager)
	manager.set_physics_process(false)
	return {"host":host,"player":player,"manager":manager}

func _spawn(f: Dictionary, position: Vector2, hp: int = 100) -> EnemyActor:
	var manager: EnemyManager = f.manager
	var previous := manager.get_alive_count()
	manager._spawn_from_row({"Spawn_count":1,"Enemy_id":"test"})
	check(manager.get_alive_count() == previous + 1, "SETUP production spawn connects enemy to manager")
	var enemy: EnemyActor = manager._active_enemies.back()
	enemy.global_position = position
	enemy.hp = hp
	return enemy

func _store() -> CsvDataStore:
	var store := Store.new()
	Data.register_schemas(store)
	return store

# All non-P0-01 data is synthetic, independent of editable CSV values and IDs.
func _csv_error(projectile_values: Array, enemy_values: Array) -> String:
	var store := _store()
	var projectile_header := "Id,Speed,Damage,Body_radius,Expire_rule,Max_distance,Max_lifetime_sec,Note\n"
	var enemy_header := "Id,Name_ko,Move_speed,Attack_range_type,Body_radius,Push_weight,Note,Max_hp,Contact_damage,Contact_rehit_sec,Death_fade_sec,Shot_interval_sec,Shot_range,Projectile_id,Xp_value\n"
	var error := store.load_text("projectile.csv", projectile_header + ",".join(projectile_values) + "\n")
	if not error.is_empty():
		return error
	error = store.load_text("enemy.csv", enemy_header + ",".join(enemy_values) + ",0\n")
	if not error.is_empty():
		return error
	return Data.validate(store)

func _test_data() -> void:
	var store := _store()
	var error := store.load_all()
	check(error.is_empty(), "P0-01 all actual CSV files load: " + error)
	if error.is_empty():
		check(Data.validate(store).is_empty(), "P0-01 actual combat data validates")
	var shot := ["shot","100","8","2","distance","500","","test"]
	var ranged := ["test","test","0","ranged","8","1","test","100","5","1","0.4","0.5","100","shot"]
	check(_csv_error(shot, ranged).is_empty(), "P0-02 valid synthetic baseline")
	for invalid in ["other", ""]:
		var bad := shot.duplicate()
		bad[4] = invalid
		check(_csv_error(bad, ranged).contains("Expire_rule"), "P0-02 invalid/empty Expire_rule rejected: " + invalid)
	var missing := shot.duplicate()
	missing[5] = ""
	check(_csv_error(missing, ranged).contains("Max_distance"), "P0-02 distance requires Max_distance")
	var bounds := shot.duplicate()
	bounds[4] = "bounds"
	check(not _csv_error(bounds, ranged).is_empty(), "P0-02 bounds forbids filled Max_distance")
	var lifetime := shot.duplicate()
	lifetime[4] = "lifetime"
	lifetime[5] = ""
	check(_csv_error(lifetime, ranged).contains("Max_lifetime_sec"), "P0-02 lifetime requires lifetime value")
	var unused := shot.duplicate()
	unused[6] = "1"
	check(_csv_error(unused, ranged).contains("Max_lifetime_sec"), "P0-02 distance forbids unused lifetime value")
	var unknown := ranged.duplicate()
	unknown[13] = "missing"
	check(_csv_error(shot, unknown).contains("Projectile_id"), "P0-02 unresolved projectile reference rejected")
	for column in [11,12,13]:
		var bad := ranged.duplicate()
		bad[column] = ""
		check(not _csv_error(shot, bad).is_empty(), "P0-02 ranged missing shot column %d rejected" % column)
		bad = ranged.duplicate()
		bad[3] = "melee"
		for index in [11,12,13]:
			if index != column:
				bad[index] = ""
		check(not _csv_error(shot, bad).is_empty(), "P0-02 melee filled shot column %d rejected" % column)

func _test_targeting() -> void:
	var f := _fixture()
	var outside := _spawn(f, Vector2(91,0), 1)
	var first := _spawn(f, Vector2(30,0), 12)
	var second := _spawn(f, Vector2(50,0), 5)
	check(f.player.choose_target([outside]) == null, "P0-03 outside range is excluded")
	check(f.player.choose_target(f.manager._active_enemies) == second, "P0-03 lowest current HP wins")
	first.hp = 5
	check(f.player.choose_target(f.manager._active_enemies) == first, "P0-03 equal HP chooses nearest")
	second.position = Vector2(-30,0)
	check(f.player.choose_target([second,first]) == first, "P0-03 equal HP/distance chooses earlier spawn")
	first.apply_damage(5)
	check(f.player.choose_target([first,second]) == second, "P0-03 dead enemy excluded immediately")
	second.position = Vector2(90,0)
	check(f.player.choose_target([second]) == second, "P0-03 range includes exact center distance")
	var old_order: int = second.spawn_order
	f.manager.recycle_enemy(second)
	var reused := _spawn(f, Vector2(30,0), 5)
	check(reused == second and reused.spawn_order > old_order, "P0-03 pooled reentry gets a new spawn order")
	f.host.queue_free()
	await process_frame

func _effects(host: Node) -> int:
	var count := 0
	for child in host.get_children():
		if child is Line2D:
			count += 1
	return count

func _test_timing() -> void:
	var f := _fixture()
	var first := _spawn(f, Vector2(20,0), 100)
	var second := _spawn(f, Vector2(40,0), 110)
	f.player.update_basic_attack(0.0, f.manager._active_enemies)
	check(first.hp == 90 and _effects(f.host) == 1, "P0-04 first damage/effect at attack start")
	f.player.update_basic_attack(0.149, f.manager._active_enemies)
	check(first.hp == 90 and second.hp == 110, "P0-04 no second damage before 0.15")
	second.hp = 80
	f.player.update_basic_attack(0.15, f.manager._active_enemies)
	check(first.hp == 90 and second.hp == 70, "P0-04 second damage at 0.15 reselects current target")
	check(_effects(f.host) == 2, "P0-04 second effect overlaps first without waiting")
	f.player.update_basic_attack(0.949999, f.manager._active_enemies)
	check(second.hp == 70, "P0-04 next attack cannot start before 0.95")
	f.player.update_basic_attack(0.95, f.manager._active_enemies)
	check(second.hp == 60, "P0-04 next attack starts at 0.95")
	f.host.queue_free()
	await process_frame
	f = _fixture()
	first = _spawn(f, Vector2(20,0), 100)
	f.player.update_basic_attack(0.0, f.manager._active_enemies)
	first.position = Vector2(200,0)
	f.player.update_basic_attack(0.15, f.manager._active_enemies)
	check(first.hp == 90 and _effects(f.host) == 1, "P0-04 skipped second hit has no damage or effect")
	first.position = Vector2(20,0)
	f.player.update_basic_attack(0.949999, f.manager._active_enemies)
	check(first.hp == 90, "P0-04 skipped second hit still waits until 0.95")
	first.position = Vector2(200,0)
	f.player.update_basic_attack(0.95, f.manager._active_enemies)
	check(first.hp == 90, "P0-04 no target at 0.95 means wait")
	first.position = Vector2(20,0)
	f.player.update_basic_attack(1.0, f.manager._active_enemies)
	check(first.hp == 80, "P0-04 candidate entering after ready time is hit that frame")
	f.host.queue_free()
	await process_frame
	f = _fixture()
	first = _spawn(f, Vector2(20,0), 10)
	second = _spawn(f, Vector2(40,0), 50)
	f.player.update_basic_attack(0.0, f.manager._active_enemies)
	check(first.is_logically_dead, "P0-05 first hit really kills its target")
	f.player.update_basic_attack(0.15, f.manager._active_enemies)
	check(second.hp == 40, "P0-05 second hit targets surviving candidate")
	f.host.queue_free()
	await process_frame

func _test_death() -> void:
	var f := _fixture(1)
	var enemy := _spawn(f, Vector2(2000,2000), 10)
	enemy.offscreen_seconds = 20.0
	enemy.start_knockback(Vector2.ZERO,60.0,0.2)
	var events := [0]
	enemy.died.connect(func(_dead): events[0] += 1)
	enemy.apply_damage(10)
	enemy.apply_damage(10)
	check(events[0] == 1 and f.manager.get_alive_count() == 0, "P0-06 same-frame damage causes one death and alive decrement")
	check(enemy.collision_layer == 0 and enemy.collision_mask == 0, "P0-06 logical death disables collision immediately")
	check(f.manager._dying_enemies.has(enemy) and not f.manager._enemy_pool.has(enemy), "P0-06 dying object stays out of pool")
	check(f.player.choose_target([enemy]) == null, "P0-06 dead enemy cannot be targeted")
	var dead_position := enemy.global_position
	f.manager._update_active_enemies(0.1)
	check(enemy.position == dead_position and enemy.offscreen_seconds == 20.0, "P0-06 dead enemy never relocates")
	f.manager._apply_contact_damage(enemy)
	check(f.player.hp == 100, "P0-06 dead enemy cannot inflict contact damage")
	f.player.position = dead_position
	f.manager._resolve_contact_pushes()
	check(f.player.position == dead_position and enemy.position == dead_position, "P0-06 dead enemy excluded from contact pushes")
	enemy.update_actor(0.2, Vector2.ZERO, Rect2(-4000,-4000,8000,8000))
	check(enemy.position == dead_position and enemy.get_knockback_velocity() == Vector2.ZERO, "P0-06 death cancels ongoing knockback")
	check(is_equal_approx(enemy.modulate.a,0.5) and not enemy.is_queued_for_deletion(), "P0-06 half fade remains visible")
	var replacement := _spawn(f, Vector2(100,100))
	check(replacement != enemy and f.manager.get_alive_count() == 1, "P0-06 released alive slot spawns without reusing fading object")
	f.manager._update_dying_enemies(0.2)
	check(enemy.is_queued_for_deletion() and f.manager.get_alive_count() == 1 and events[0] == 1, "P0-06 fade end removes object without second death/count change")
	await process_frame
	check(not is_instance_valid(enemy), "P0-06 faded object is removed from scene")
	f.host.queue_free()
	await process_frame

func _test_contact() -> void:
	var f := _fixture()
	var first := _spawn(f, Vector2(16,0))
	f.manager._update_contact_damage()
	check(f.player.hp == 95, "P0-07 touching at exact radii immediately inflicts damage")
	f.manager._elapsed_seconds = 0.999999
	f.manager._update_contact_damage()
	check(f.player.hp == 95, "P0-07 same enemy suppressed during cooldown")
	f.manager._elapsed_seconds = 1.0
	f.manager._update_contact_damage()
	check(f.player.hp == 90, "P0-07 continuous touch repeats at cooldown expiry")
	var other := _spawn(f, Vector2(-16,0))
	f.manager._update_contact_damage()
	check(other.is_active and first.is_active and f.player.hp == 85, "P0-07 a different living enemy damages immediately")
	f.host.queue_free()
	await process_frame

func _new_projectile(f: Dictionary, record: Dictionary, origin: Vector2, aim: Vector2, bounds: Rect2 = Rect2(-4000,-4000,8000,8000)) -> CombatProjectile:
	var shot := Projectile.new()
	f.host.add_child(shot)
	shot.configure(record,origin,aim,bounds,f.player)
	return shot

func _test_projectiles() -> void:
	var f := _fixture()
	f.player.position = Vector2(100,0)
	var enemy := _spawn(f,Vector2.ZERO)
	enemy.shot_range = 100.0
	enemy.shot_interval_sec = 0.5
	enemy.projectile_id = "shot"
	f.manager._update_enemy_shot(enemy,0.499)
	check(f.manager._projectiles.is_empty(), "P0-08 ranged shot waits for interval")
	f.manager._update_enemy_shot(enemy,0.001)
	check(f.manager._projectiles.size() == 1, "P0-08 shot at interval and exact Shot_range")
	var shot: CombatProjectile = f.manager._projectiles[0]
	check(shot.global_position == enemy.global_position and shot.direction == Vector2.RIGHT, "P0-08 launch position and direction use shooter/player positions")
	f.player.position = Vector2(100,100)
	shot.advance(0.1)
	check(shot.direction == Vector2.RIGHT and is_equal_approx(shot.position.y,0.0), "P0-08 player motion does not change projectile direction")
	f.player.position = Vector2(100,0)
	shot.advance(1.0)
	check(f.player.hp == 92 and shot.spent and shot.is_queued_for_deletion(), "P0-08 swept hit before expiry damages once and removes projectile")
	shot.advance(1.0)
	check(f.player.hp == 92, "P0-08 spent projectile cannot damage twice")
	f.manager._update_enemy_shot(enemy,0.5)
	var second: CombatProjectile = f.manager._projectiles.back()
	second.advance(1.0)
	check(second != shot and second.spent and f.player.hp == 84, "P0-08 different projectiles from same enemy damage independently")
	enemy.position = Vector2(84,0)
	f.manager._update_contact_damage()
	check(f.player.hp == 79, "P0-08 contact damage is independent immediately after same shooter's projectile")
	f.player.position = Vector2(1000,1000)
	var count: int = f.manager._projectiles.size()
	f.manager._update_enemy_shot(enemy,10.0)
	check(f.manager._projectiles.size() == count, "P0-08 no firing outside Shot_range")
	var distance := _new_projectile(f,_projectile(),Vector2.ZERO,Vector2(100,0))
	distance.advance(4.99)
	check(not distance.spent, "P0-08 distance projectile survives before limit")
	distance.advance(0.01)
	check(distance.spent and is_equal_approx(distance.traveled,500), "P0-08 distance expiry at Max_distance")
	var lifetime := _new_projectile(f,_projectile(1),Vector2.ZERO,Vector2(100,0))
	lifetime.advance(0.99)
	check(not lifetime.spent, "P0-08 lifetime projectile survives before limit")
	lifetime.advance(0.01)
	check(lifetime.spent, "P0-08 lifetime expiry at Max_lifetime_sec")
	var bounds := _new_projectile(f,_projectile(2),Vector2(9,5),Vector2(20,5),Rect2(0,0,10,10))
	bounds.advance(0.01)
	check(bounds.spent and is_equal_approx(bounds.position.x,10), "P0-08 bounds expiry at boundary toward aim position")
	var short_record := _projectile()
	short_record.Max_distance = 10.0
	f.player.position = Vector2(50,0)
	var short_shot := _new_projectile(f,short_record,Vector2.ZERO,Vector2(100,0))
	short_shot.advance(1.0)
	check(short_shot.spent and f.player.hp == 79, "P0-08 expiry prevents hits beyond distance limit")
	f.host.queue_free()
	await process_frame

func _test_knockback() -> void:
	var f := _fixture()
	var enemy := _spawn(f,Vector2(100,0))
	await physics_frame
	var player_start: Vector2 = f.player.global_position
	enemy.start_knockback(player_start,60.0,0.2)
	check(enemy.get_knockback_velocity() == Vector2(600,0), "P0-09 initial knockback points away with 2*distance/duration speed")
	enemy.update_actor(0.1,player_start,Rect2(-4000,-4000,8000,8000))
	check(is_equal_approx(enemy.position.x,145.0) and enemy.get_knockback_velocity() == Vector2(300,0), "P0-09 velocity decays linearly over time")
	enemy.update_actor(0.1,player_start,Rect2(-4000,-4000,8000,8000))
	check(is_equal_approx(enemy.position.x,160.0) and enemy.get_knockback_velocity() == Vector2.ZERO, "P0-09 full deceleration integrates to configured distance")
	enemy.position = Vector2(100,0)
	enemy.move_speed = 100.0
	enemy.start_knockback(player_start,60.0,0.2)
	enemy.update_actor(0.1,player_start,Rect2(-4000,-4000,8000,8000))
	check(is_equal_approx(enemy.position.x,135.0), "P0-09 chase displacement adds during knockback")
	enemy.apply_damage(100)
	var dead_position := enemy.position
	enemy.update_actor(0.1,player_start,Rect2(-4000,-4000,8000,8000))
	check(enemy.position == dead_position, "P0-09 death freezes enemy during knockback")
	check(f.player.global_position == player_start, "P0-09 attack knockback never moves player")
	f.host.queue_free()
	await process_frame
	f = _fixture()
	var map = MapScene.instantiate()
	f.host.add_child(map)
	enemy = _spawn(f,Vector2(1260,0))
	enemy.start_knockback(Vector2.ZERO,60.0,0.2)
	await physics_frame
	enemy.update_actor(0.2,Vector2.ZERO,map.get_map_rect())
	check(enemy.position.x <= 1272.0 and enemy.position.x >= 1259.0, "P0-09 knockback is blocked by actual map wall")
	f.host.queue_free()
	await process_frame

func _test_player_death() -> void:
	var f := _fixture()
	f.player.configure_combat(10,_attack())
	f.player.apply_damage(10)
	check(f.player.is_dead and paused, "P0-10 zero HP pauses SceneTree")
	check(f.player._death_label != null and f.player._death_label.visible and f.player._death_label.text == "\uC0AC\uB9DD", "P0-10 death indicator appears")
	check(f.player._hp_label.text.contains("0 / 10"), "P0-10 temporary HP display reflects death")
	f.player.apply_damage(10)
	check(f.player.hp == 0, "P0-10 dead player cannot lose health again")
	paused = false
	f.host.queue_free()
	await process_frame

func _level_records(requirements: Array) -> Dictionary:
	var records: Dictionary = {}
	for index in range(requirements.size()):
		var id := "level_%d" % (index+1)
		records[id] = {"Id":id,"Level":index+1,"Xp_to_next":requirements[index]}
	return records

func _xp_rule(cap: int = 300) -> Dictionary:
	return {"Id":"xp_rule_01","Pull_start_speed":150.0,"Pull_accel":600.0,"Orb_radius":6.0,"Max_ground_orbs":cap}

func _xp_fixture(cap: int = 300, xp_value: int = 1) -> Dictionary:
	var f := _fixture()
	f.player.configure_progression(_level_records([5,8,11]),100.0)
	f.manager._enemy_records["test"]["Xp_value"] = xp_value
	var xp_manager := ExperienceManager.new()
	xp_manager.configure(f.player,f.manager,_xp_rule(cap))
	f.host.add_child(xp_manager)
	xp_manager.set_physics_process(false)
	f["xp"] = xp_manager
	return f

func _test_xp_drop() -> void:
	var f := _xp_fixture()
	var enemy := _spawn(f,Vector2(500,200),1)
	enemy.apply_damage(1)
	enemy.apply_damage(1)
	check(f.xp.get_ground_count()==1 and f.xp.get_ground_total()==1, "S4-01 death produces one orb with Xp_value once")
	var orb: Node2D = f.xp._orbs[0]
	check(orb.global_position==Vector2(500,200), "S4-01 orb is at actual death position")
	f.manager._update_dying_enemies(0.2)
	check(f.xp.get_ground_count()==1, "S4-01 no extra drop during fade")
	f.manager._enemy_records["test"]["Xp_value"] = 0
	enemy = _spawn(f,Vector2(600,200),1)
	enemy.apply_damage(1)
	check(f.xp.get_ground_count()==1 and f.xp.get_ground_total()==1, "S4-02 Xp_value zero produces no orb")
	f.xp._physics_process(10000.0)
	check(f.xp.get_ground_count()==1 and orb.position==Vector2(500,200), "S4-02 uncollected ground XP has no expiry")
	f.host.queue_free()
	await process_frame

func _test_xp_pickup() -> void:
	var f := _xp_fixture()
	var edge: Node2D = f.xp.drop_experience(Vector2(100,0),1)
	var outside: Node2D = f.xp.drop_experience(Vector2(100.5,0),1)
	f.xp._physics_process(0.0)
	check(edge.is_pulling and not outside.is_pulling and outside.position==Vector2(100.5,0), "S4-03 radius 100 includes 100.0 and excludes 100.5")
	f.player.position = Vector2(-1000,0)
	f.xp._physics_process(0.5)
	check(is_equal_approx(edge.speed,450.0), "S4-04 speed after 0.5 sec is 150+600*0.5")
	check(edge.is_pulling and edge.position.x<100.0 and not outside.is_pulling, "S4-05 pursuit continues outside pickup radius")
	f.player.pickup_radius = 2000.0
	f.xp._physics_process(0.0)
	check(outside.is_pulling, "S4-05 runtime pickup radius is mutable")
	f.host.queue_free()
	await process_frame
	f = _xp_fixture()
	var orb: Node2D = f.xp.drop_experience(Vector2(-100,0),1)
	f.xp._physics_process(0.0)
	var credited_at := 0.0
	for frame in range(1,301):
		f.player.position.x += 250.0/60.0
		f.xp._physics_process(1.0/60.0)
		if f.xp.get_ground_count()==0:
			credited_at = float(frame)/60.0
			break
	check(credited_at>0.0 and credited_at<=5.0 and f.player.experience==1, "S4-05 accelerating orb catches player fleeing at 250 within 5 seconds")
	check(orb.collected, "S4-05 caught orb marked collected once")
	f.host.queue_free()
	await process_frame
	f = _xp_fixture()
	orb = f.xp.drop_experience(Vector2(100,0),1)
	f.xp._physics_process(0.0)
	orb.speed = 100000.0
	f.xp._physics_process(1.0)
	check(f.xp.get_ground_count()==0 and f.player.experience==1, "S4-06 high-speed one-frame path credits without overshooting")
	f.xp._physics_process(1.0)
	check(f.player.experience==1, "S4-06 collected orb cannot be credited twice")
	f.host.queue_free()
	await process_frame
	f = _xp_fixture()
	f.player.pickup_radius = 1.0
	orb = f.xp.drop_experience(Vector2(100,0),1)
	f.xp._physics_process(0.0)
	check(not orb.is_pulling, "S4-07 contact fixture starts with a stationary orb")
	f.player.position = Vector2(90,0)
	f.xp._physics_process(0.0)
	check(orb.collected and not orb.is_pulling and f.player.experience==1, "S4-07 stationary orb credits on body contact despite smaller pickup radius")
	f.host.queue_free()
	await process_frame

func _test_xp_progression() -> void:
	var f := _xp_fixture()
	var events: Array = []
	f.player.leveled_up.connect(func(new_level: int): events.append(new_level))
	check(f.player.level==1 and f.player.experience==0 and f.player.enhancement_points==0, "S4-08 starting level XP and points are 1/0/0")
	f.player.add_experience(4)
	check(f.player.level==1 and f.player.experience==4 and events.is_empty(), "S4-08 four XP stays at level 1")
	f.player.add_experience(1)
	check(f.player.level==2 and f.player.experience==0 and f.player.enhancement_points==1 and events==[2], "S4-08 fifth XP gives level 2 point 1 and one signal")
	check(not paused, "S4-08 level up does not pause the game")
	f.player.configure_progression(_level_records([5,8,11]),100.0)
	events.clear()
	f.player.add_experience(26)
	check(f.player.level==4 and f.player.experience==2 and f.player.enhancement_points==3 and events==[2,3,4], "S4-09 26 XP gives level 4 remainder 2 points 3 ordered signals 2/3/4")
	f.player.configure_progression(_level_records([5,8]),100.0)
	events.clear()
	f.player.add_experience(29)
	check(f.player.level==5 and f.player.experience==0 and f.player.enhancement_points==4 and events==[2,3,4,5] and f.player.get_xp_to_next()==8, "S4-10 final requirement repeats without maximum level")
	f.host.queue_free()
	await process_frame

func _test_xp_cap() -> void:
	var f := _xp_fixture(3)
	var first: Node2D = f.xp.drop_experience(Vector2(100,0),1)
	f.xp.drop_experience(Vector2(300,0),1)
	f.xp.drop_experience(Vector2(500,0),1)
	f.xp._physics_process(0.0)
	var before: Vector2 = first.position
	f.xp.drop_experience(Vector2(700,0),1)
	check(f.xp.get_ground_count()==3 and first.value==2 and f.xp.get_ground_total()==4, "S4-11 cap 3 merges fourth value into oldest with no loss")
	check(first.position==before and first.is_pulling, "S4-11 merging preserves oldest location and pulling state")
	for orb in f.xp._orbs:
		orb.position = f.player.position
	f.xp._physics_process(0.0)
	check(f.xp.get_ground_count()==0 and f.player.experience==4 and f.player.level==1, "S4-12 merged orbs credit total 4")
	f.host.queue_free()
	await process_frame

func _xp_csv_error(enemy_xp: String="1", levels: String="level_1,1,5,test\nlevel_2,2,8,test\n", pickup: String="100", cap: String="3", rule_id: String="xp_rule_01", pull_start: String="150", acceleration: String="600", radius: String="6") -> String:
	var store := _store()
	var sources := {
		"enemy.csv":"Id,Name_ko,Move_speed,Attack_range_type,Body_radius,Push_weight,Note,Max_hp,Contact_damage,Contact_rehit_sec,Death_fade_sec,Shot_interval_sec,Shot_range,Projectile_id,Xp_value\ntest,test,0,melee,8,1,test,100,5,1,0.4,,,,"+enemy_xp+"\n",
		"player.csv":"Id,Name_ko,Move_speed,Body_radius,Push_weight,Note,Max_hp,Pickup_radius\ntest,test,250,8,3,test,100,"+pickup+"\n",
		"level.csv":"Id,Level,Xp_to_next,Note\n"+levels,
		"xp_rule.csv":"Id,Pull_start_speed,Pull_accel,Orb_radius,Max_ground_orbs,Note\n"+rule_id+","+pull_start+","+acceleration+","+radius+","+cap+",test\n",
	}
	for name in sources:
		var error := store.load_text(name,sources[name])
		if not error.is_empty():
			return error
	return ExperienceData.validate(store)

func _test_xp_csv() -> void:
	check(_xp_csv_error().is_empty(), "S4-13 valid synthetic experience CSV passes")
	check(_xp_csv_error("-1").contains("Xp_value"), "S4-13 negative Xp_value rejected")
	check(_xp_csv_error("").contains("Xp_value"), "S4-13 blank Xp_value rejected")
	check(_xp_csv_error("1","level_1,1,5,test\nlevel_3,3,8,test\n").contains("Level"), "S4-13 missing level 2 rejected")
	check(_xp_csv_error("1","level_1,1,0,test\n").contains("Xp_to_next"), "S4-13 zero Xp_to_next rejected")
	check(_xp_csv_error("1","level_1,1,,test\n").contains("Xp_to_next"), "S4-13 blank Xp_to_next rejected")
	check(_xp_csv_error("1","").contains("Level"), "S4-13 empty level table rejected")
	check(_xp_csv_error("1","level_2,2,5,test\n").contains("Level"), "S4-13 level sequence not starting at 1 rejected")
	check(_xp_csv_error("1","level_1,1,5,test\n","0").contains("Pickup_radius"), "S4-13 zero pickup radius rejected")
	check(_xp_csv_error("1","level_1,1,5,test\n","").contains("Pickup_radius"), "S4-13 blank pickup radius rejected")
	check(_xp_csv_error("1","level_1,1,5,test\n","100","0").contains("Max_ground_orbs"), "S4-13 zero ground cap rejected")
	check(_xp_csv_error("1","level_1,1,5,test\n","100","").contains("Max_ground_orbs"), "S4-13 blank ground cap rejected")
	check(_xp_csv_error("1","level_1,1,5,test\n","100","3","missing").contains("Id"), "S4-13 missing xp_rule_01 rejected")
	for invalid in ["0",""]:
		check(_xp_csv_error("1","level_1,1,5,test\n","100","3","xp_rule_01",invalid).contains("Pull_start_speed"), "S4-13 invalid start speed rejected: "+invalid)
		check(_xp_csv_error("1","level_1,1,5,test\n","100","3","xp_rule_01","150",invalid).contains("Pull_accel"), "S4-13 invalid acceleration rejected: "+invalid)
		check(_xp_csv_error("1","level_1,1,5,test\n","100","3","xp_rule_01","150","600",invalid).contains("Orb_radius"), "S4-13 invalid orb radius rejected: "+invalid)
	var store := _store()
	var error := store.load_all()
	check(error.is_empty(), "S4-14 all actual CSV including new tables load: "+error)
	if error.is_empty():
		check(ExperienceData.validate(store).is_empty(), "S4-14 actual experience data validates")
