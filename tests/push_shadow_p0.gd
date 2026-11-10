extends RefCounted

const Equivalence = preload("res://tests/push_equivalence_p0.gd")
const Reference = preload("res://tests/push_reference.gd")
const Profile = preload("res://tests/push_profile.gd")
const EPS := 0.00002
var t: SceneTree

# Push-only test double; no real shadow content or production balance values.
class ShadowBody extends Node2D:
	var body_radius: float = 10.0
	var push_weight: float = 2.0
	var hp: int = 100
	var damage_calls: int = 0
	func apply_damage(amount: int) -> void:
		damage_calls += 1
		hp -= amount

func shadow(f: Dictionary, point: Vector2, radius: float = 10.0, weight: float = 2.0) -> ShadowBody:
	var body := ShadowBody.new()
	body.body_radius = radius
	body.push_weight = weight
	f.host.add_child(body)
	body.global_position = point
	f.manager.register_shadow_body(body)
	return body

func near(actual: Vector2, expected: Vector2) -> bool:
	return actual.distance_to(expected)<=EPS

func run(tree: SceneTree) -> void:
	t = tree
	await exact_without_shadows()
	await shadow_pairs()
	await mixed_spacing_and_dash()
	await projectile_and_contact()
	await chase_player()
	await bounds_and_lifecycle()

func exact_without_shadows() -> void:
	var helper := Equivalence.new()
	helper.t = t
	for seed_value in range(8):
		for iterations in [1,8]:
			for dash in [false,true]:
				var a: Dictionary = helper.layout(seed_value,iterations,dash)
				var b: Dictionary = helper.layout(seed_value,iterations,dash)
				for iteration in range(iterations):
					Reference.resolve(a.manager)
				b.manager._resolve_contact_pushes()
				var error := Profile.compare(helper.state(a),helper.state(b))
				t.check(error==0.0,"SHADOW-01 exact no-shadow equivalence seed=%d N=%d dash=%s error=%.12f" % [seed_value,iterations,str(dash),error])
				a.host.queue_free()
				b.host.queue_free()
				await t.process_frame

func shadow_pairs() -> void:
	for kind in ["enemy","player","shadow"]:
		var f: Dictionary = t._fixture()
		f.player.position = Vector2(500,500)
		f.manager.separation_gap = 8.0
		var a := shadow(f,Vector2.ZERO)
		var b: Node2D
		var expected_a := Vector2.ZERO
		var expected_b := Vector2.ZERO
		var expected_distance := 18.0
		if kind=="enemy":
			b = t._spawn(f,Vector2(10,0))
			expected_a = Vector2(-8.0/3.0,0)
			expected_b = Vector2(10.0+16.0/3.0,0)
		elif kind=="player":
			b = f.player
			b.global_position = Vector2(10,0)
			expected_a = Vector2(-4.8,0)
			expected_b = Vector2(13.2,0)
		else:
			b = shadow(f,Vector2(10,0),6.0,4.0)
			expected_a = Vector2(-4,0)
			expected_b = Vector2(12,0)
			expected_distance = 16.0
		# Duplicate registration must not introduce a second body in the solve.
		f.manager.register_shadow_body(a)
		f.manager._resolve_contact_pushes()
		t.check(near(a.global_position,expected_a) and near(b.global_position,expected_b),"SHADOW-02 shadow-%s inverse-weight displacement" % kind)
		t.check(absf(a.global_position.distance_to(b.global_position)-expected_distance)<=EPS,"SHADOW-02 shadow-%s radius sum only, gap zero (temporary)" % kind)
		f.host.queue_free()
		await t.process_frame

func mixed_spacing_and_dash() -> void:
	var f: Dictionary = t._fixture()
	f.player.position = Vector2(500,500)
	f.manager.separation_gap = 8.0
	var a: EnemyActor = t._spawn(f,Vector2.ZERO)
	var b: EnemyActor = t._spawn(f,Vector2(10,0))
	var s := shadow(f,Vector2(100,100))
	var other := shadow(f,Vector2(110,100),6.0,4.0)
	f.manager._resolve_contact_pushes()
	t.check(near(a.global_position,Vector2(-7,0)) and near(b.global_position,Vector2(17,0)),"SHADOW-03 mixed world preserves enemy-enemy radius sum plus gap 8")
	t.check(near(s.global_position,Vector2(96,100)) and near(other.global_position,Vector2(112,100)),"SHADOW-03 mixed world shadow-shadow gap remains zero")
	f.player.position = Vector2(100,100)
	s.position = Vector2(110,100)
	other.position = Vector2(300,300)
	f.player.dash_pass_through = true
	f.manager._resolve_contact_pushes()
	t.check(near(f.player.global_position,Vector2(100,100)) and near(s.global_position,Vector2(110,100)),"SHADOW-04 dash excludes player-shadow pair (temporary)")
	# Other pairs must still run while the player is dashing.
	s.position = Vector2.ZERO
	a.position = Vector2(10,0)
	b.position = Vector2(300,0)
	f.manager._resolve_contact_pushes()
	t.check(near(s.global_position,Vector2(-8.0/3.0,0)) and near(a.global_position,Vector2(10.0+16.0/3.0,0)),"SHADOW-04 dash keeps shadow-enemy push active")
	f.player.dash_pass_through = false
	f.player.position = Vector2(100,100)
	s.position = Vector2(110,100)
	f.manager._resolve_contact_pushes()
	t.check(near(f.player.global_position,Vector2(96.8,100)) and near(s.global_position,Vector2(114.8,100)),"SHADOW-04 player-shadow push resumes after dash")
	f.host.queue_free()
	await t.process_frame

func projectile_and_contact() -> void:
	var f: Dictionary = t._fixture()
	f.player.position = Vector2(100,0)
	var enemy: EnemyActor = t._spawn(f,Vector2.ZERO)
	var s := shadow(f,Vector2(30,0))
	enemy.shot_range = 200.0
	enemy.shot_interval_sec = 0.5
	enemy.projectile_id = "shot"
	f.manager._update_enemy_shot(enemy,0.5)
	t.check(f.manager._projectiles.size()==1,"SETUP SHADOW projectile created by production ranged shot")
	if f.manager._projectiles.size()==1:
		var shot: CombatProjectile = f.manager._projectiles[0]
		f.manager._update_projectiles(0.5)
		t.check(near(shot.global_position,Vector2(50,0)) and not shot.spent and s.hp==100 and s.damage_calls==0 and f.player.hp==100,"SHADOW-05 projectile passes through shadow with no damage")
		f.manager._update_projectiles(0.5)
		t.check(shot.spent and f.player.hp==92 and s.hp==100 and s.damage_calls==0,"SHADOW-05 projectile hits only player after passing shadow")
	s.position = enemy.position
	f.manager._update_contact_damage()
	t.check(s.hp==100 and s.damage_calls==0 and f.player.hp==92,"SHADOW-06 enemy overlap does not damage shadow or distant player")
	f.player.position = enemy.position
	f.manager._update_contact_damage()
	t.check(f.player.hp==87 and s.hp==100 and s.damage_calls==0,"SHADOW-06 real contact still damages player only")
	t.check(f.manager.get_alive_count()==1 and f.manager.get_living_enemies()==[enemy],"SHADOW-06 shadow registration does not enter enemy count or target list")
	f.host.queue_free()
	await t.process_frame

func chase_player() -> void:
	var f: Dictionary = t._fixture()
	# Isolate the real CharacterBody from physics-server bodies awaiting cleanup
	# after earlier fixtures. Use the same independent World2D as foundation P0.
	var view := SubViewport.new()
	view.size = Vector2i(1280,720)
	view.world_2d = World2D.new()
	t.root.add_child(view)
	f.host.reparent(view)
	# This case tests chase, not offscreen relocation.
	f.manager.configure(f.player,Rect2(-4000,-4000,8000,8000),{"test":t._enemy()},{},10,1000.0)
	f.player.position = Vector2(100,100)
	var enemy: EnemyActor = t._spawn(f,Vector2.ZERO)
	enemy.move_speed = 60.0
	var s := shadow(f,Vector2(-20,0))
	# Full-suite measurement found the server transform still stale at the first
	# physics_frame signal and synchronized at the second. Wait for that step.
	for _frame in range(2):
		await t.physics_frame
	t.check(enemy.get_world_2d()==view.world_2d,"SETUP SHADOW chase uses isolated physics world")
	f.manager._update_active_enemies(0.1)
	var expected := Vector2.ONE.normalized()*6.0
	t.check(near(enemy.global_position,expected) and near(s.global_position,Vector2(-20,0)),"SHADOW-07 actual enemy movement approaches player with closer shadow present actual=%s expected=%s" % [str(enemy.global_position),str(expected)])
	view.queue_free()
	await t.process_frame

func bounds_and_lifecycle() -> void:
	var f: Dictionary = t._fixture()
	f.player.position = Vector2(500,500)
	f.manager.push_iterations = 8
	# The radius-10 shadow starts on the existing left boundary. A push that
	# would move it further left is clamped by the existing pair write path.
	var s := shadow(f,Vector2(-3990,0))
	var enemy: EnemyActor = t._spawn(f,Vector2(-3980,0))
	f.manager._resolve_contact_pushes()
	t.check(near(s.global_position,Vector2(-3990,0)) and enemy.global_position.x>=-3980.0,"SHADOW-08 participating shadow uses existing radius-aware boundary clamp")
	# A pass has never clamped separated bodies: registration adds no movement.
	s.position = Vector2(-4010,100)
	enemy.position = Vector2.ZERO
	f.manager._resolve_contact_pushes()
	t.check(near(s.global_position,Vector2(-4010,100)),"SHADOW-08 isolated out-of-bounds double is not clamped without a push")
	# Public unregister and scene exit must both remove future participation.
	f.manager.unregister_shadow_body(s)
	s.position = Vector2.ZERO
	f.player.position = Vector2(500,500)
	enemy.position = Vector2(10,0)
	f.manager._resolve_contact_pushes()
	t.check(near(s.global_position,Vector2.ZERO) and near(enemy.global_position,Vector2(10,0)),"SHADOW-09 explicit unregister removes participant")
	f.manager.register_shadow_body(s)
	f.host.remove_child(s)
	f.manager._resolve_contact_pushes()
	t.check(near(enemy.global_position,Vector2(10,0)),"SHADOW-09 scene exit removes participant before next solve")
	s.free()
	var freed := shadow(f,Vector2(10,0))
	freed.free()
	f.manager._resolve_contact_pushes()
	t.check(near(enemy.global_position,Vector2(10,0)),"SHADOW-09 freed double does not leave a stale body")
	f.host.queue_free()
	await t.process_frame
