extends SceneTree

const Profile = preload("res://tests/push_profile.gd")
const FX = preload("res://scripts/hit_fx.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var profile := Profile.new()
	var f: Dictionary = profile.fixture(self,4)
	for enemy in f.manager.get_living_enemies(): f.manager.recycle_enemy(enemy)
	var rule: Dictionary = f.store.get_row("spawn_rule.csv","rule_01")
	f.manager.configure(f.player,f.host.get_map_rect(),f.store.get_table("enemy.csv"),f.store.get_table("spawn.csv"),int(rule.Max_alive),100000,f.store.get_table("projectile.csv"),f.store.get_row("basic_attack.csv","attack_01"),float(rule.Separation_gap),int(rule.Push_iterations),f.store.get_table("enemy_scaling.csv"))
	f.manager._elapsed_seconds = 330
	f.manager._random.seed = 20261109
	f.manager.collecting = false
	f.manager._spawn_from_row({"Spawn_count":120,"Enemy_id":"enemy_01"})
	f.actors = f.manager.get_living_enemies()
	var spawned_hp: int = f.actors[0].max_hp
	var spawned_speed: float = f.actors[0].move_speed
	var spawned_damage: int = f.actors[0].contact_damage
	for i in range(f.actors.size()):
		var enemy: EnemyActor = f.actors[i]
		enemy.position = Vector2.RIGHT.rotated(TAU*i/120.0)*400.0
		# Same immortality preparation as the prior 200-actor FX measurement.
		enemy.hp = 1000000000
		enemy.max_hp = 1000000000
	var shadows := preload("res://scripts/shadow_manager.gd").new()
	shadows.configure(f.player,f.manager,f.store.get_table("shadow.csv"),f.store.get_table("shadow_attack.csv"),f.store.get_table("shadow_motion.csv"),2)
	f.host.add_child(shadows)
	shadows.set_physics_process(false)
	for id in ["igrit","charger_test"]:
		var actor: Node2D = shadows.summon(id)
		actor.position = Vector2(-80 if id=="igrit" else 80,0)
		actor.random.seed = 20261111
		actor.motion_picker = func(_count: int) -> int: return 0
	var effect := FX.new()
	effect.configure(f.manager,f.store.get_row("hit_fx.csv","hit_spark"))
	f.host.add_child(effect)
	effect.set_physics_process(false)
	for i in range(2): await physics_frame
	var samples: Array[int] = []
	var all_120 := true
	for frame in range(720):
		if frame%120==0: f.skills.skills.skill_rapid_slash.start(f.skills.clock)
		if frame==120: profile.press_fear(f)
		var start := Time.get_ticks_usec()
		shadows._physics_process(1.0/60.0)
		profile.frame(f)
		effect._physics_process(1.0/60.0)
		var elapsed: int = Time.get_ticks_usec()-start-f.manager.bookkeeping_us
		if frame>=120: samples.append(elapsed)
		all_120 = all_120 and f.manager.get_alive_count()==120
		await physics_frame
	var total := 0
	for value in samples: total+=value
	var sorted := samples.duplicate()
	sorted.sort()
	var result := {"frames":600,"warmup":120,"alive_every_frame_120":all_120,"physics_mean_ms":float(total)/samples.size()/1000.0,"physics_p95_ms":sorted[ceili(samples.size()*0.95)-1]/1000.0,"physics_max_ms":sorted.back()/1000.0,"rendering_included":false,"stage_seconds":330,"spawned_hp":spawned_hp,"spawned_speed":spawned_speed,"spawned_damage":spawned_damage,"enemy_hp_override_for_measurement":1000000000,"push_iterations":f.manager.push_iterations,"fx_enabled":true,"shadows":2,"times_us":samples}
	var path := "res://.local/s8-impl-04-physics-attempt1.json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	file.close()
	result.erase("times_us")
	print("S8-I4 PHYSICS ",JSON.stringify(result))
	f.host.queue_free()
	await process_frame
	await preload("res://tests/test_exit.gd").finish("enemy_scaling_profile",0 if all_120 and spawned_hp==90 and is_equal_approx(spawned_speed,156) and spawned_damage==8 else 1)
