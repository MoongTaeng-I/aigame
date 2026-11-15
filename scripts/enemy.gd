extends CharacterBody2D
class_name EnemyActor

signal died(enemy: EnemyActor)
signal damaged(world_position: Vector2)

const ENEMY_COLOR := Color("#ff7d68")
const OUTLINE_COLOR := Color("#ffe4df")

enum AttackRangeType { MELEE, RANGED }

var enemy_id: String = ""
var character_view: Node2D
var sprite_body: Node2D
var visual_record: Dictionary = {}
var move_speed: float = 0.0
var attack_range_type: AttackRangeType = AttackRangeType.MELEE
var body_radius: float = 16.0
var push_weight: float = 1.0
var offscreen_seconds: float = 0.0
var is_active: bool = false
var is_logically_dead: bool = false
var max_hp: int = 1
var hp: int = 1
var xp_value: int = 0
var contact_damage: int = 0
var contact_rehit_sec: float = 1.0
var death_fade_sec: float = 0.4
var spawn_order: int = 0
var shot_interval_sec: float = 0.0
var shot_range: float = 0.0
var projectile_id: String = ""
var shot_elapsed: float = 0.0
var knockback_direction := Vector2.ZERO
var knockback_distance: float = 0.0
var knockback_duration: float = 0.0
var knockback_elapsed: float = 0.0
var map_bounds := Rect2()
var _fade_elapsed: float = 0.0
var wander_target := Vector2.ZERO
var has_wander_target: bool = false
var fear_remaining: float = 0.0
var action_delta: float = 0.0
const SkillUI = preload("res://scripts/skill_ui.gd")

func is_feared() -> bool:
	return fear_remaining>0.000000001

func apply_fear(duration: float) -> void:
	if is_active and not is_logically_dead:
		fear_remaining = duration
		update_sprite_tint()
		queue_redraw()

@onready var collision_shape := $CollisionShape2D as CollisionShape2D

func configure(record: Dictionary) -> void:
	visual_record = record.duplicate()
	enemy_id = String(record["Id"])
	move_speed = float(record["Move_speed"])
	attack_range_type = int(record["Attack_range_type"])
	body_radius = float(record["Body_radius"])
	push_weight = float(record["Push_weight"])
	max_hp = int(record.get("Max_hp", 1))
	hp = max_hp
	xp_value = int(record.get("Xp_value",0))
	contact_damage = int(record.get("Contact_damage", 0))
	contact_rehit_sec = float(record.get("Contact_rehit_sec", 1.0))
	death_fade_sec = float(record.get("Death_fade_sec", 0.4))
	shot_interval_sec = float(record.get("Shot_interval_sec", 0.0)) if record.get("Shot_interval_sec") != null else 0.0
	shot_range = float(record.get("Shot_range", 0.0)) if record.get("Shot_range") != null else 0.0
	projectile_id = String(record.get("Projectile_id", "")) if record.get("Projectile_id") != null else ""
	if is_node_ready():
		configure_visual()
		(collision_shape.shape as CircleShape2D).set_deferred("radius", body_radius)
		queue_redraw()

func activate_at(world_position: Vector2, order: int = 0) -> void:
	configure_visual()
	global_position = world_position
	offscreen_seconds = 0.0
	is_active = true
	is_logically_dead = false
	spawn_order = order
	shot_elapsed = 0.0
	has_wander_target = false
	fear_remaining = 0.0
	_fade_elapsed = 0.0
	knockback_direction = Vector2.ZERO
	knockback_distance = 0.0
	knockback_duration = 0.0
	knockback_elapsed = 0.0
	collision_layer = 2
	collision_mask = 1
	modulate.a = 1.0
	update_sprite_tint()
	visible = true
	if is_node_ready():
		collision_shape.set_deferred("disabled", false)
	queue_redraw()

func deactivate_to_pool() -> void:
	is_active = false
	visible = false
	offscreen_seconds = 0.0
	if is_node_ready():
		collision_shape.set_deferred("disabled", true)

func apply_damage(amount: int) -> bool:
	if not is_active or is_logically_dead or amount <= 0:
		return false
	hp = maxi(0, hp - amount)
	damaged.emit(global_position)
	if hp == 0:
		begin_death()
	return true

func begin_death() -> void:
	if is_logically_dead:
		return
	is_logically_dead = true
	is_active = false
	collision_layer = 0
	collision_mask = 0
	knockback_direction = Vector2.ZERO
	knockback_distance = 0.0
	knockback_duration = 0.0
	knockback_elapsed = 0.0
	_fade_elapsed = 0.0
	if is_node_ready():
		collision_shape.set_deferred("disabled", true)
	died.emit(self)
	if death_fade_sec <= 0.0:
		queue_free()

func start_knockback(source_position: Vector2, distance: float, duration: float) -> void:
	if not is_active or is_logically_dead or distance <= 0.0 or duration <= 0.0:
		return
	var direction := source_position.direction_to(global_position)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	knockback_direction = direction
	knockback_distance = distance
	knockback_duration = duration
	knockback_elapsed = 0.0

func update_actor(delta: float, player_position: Vector2, bounds: Rect2, stop_at_target: bool = false) -> void:
	var visual_origin := global_position
	var visual_knockback := knockback_elapsed<knockback_duration
	map_bounds = bounds
	if is_logically_dead:
		_fade_elapsed += delta
		modulate.a = clampf(1.0 - _fade_elapsed / maxf(death_fade_sec, 0.0001), 0.0, 1.0)
		if _fade_elapsed >= death_fade_sec:
			queue_free()
		return
	if not is_active:
		return
	action_delta = maxf(0.0,delta-fear_remaining)
	fear_remaining = maxf(0.0,fear_remaining-delta)
	queue_redraw()
	var motion := global_position.direction_to(player_position) * move_speed * action_delta
	if stop_at_target:
		motion = global_position.direction_to(player_position)*minf(move_speed*action_delta,global_position.distance_to(player_position))
	if knockback_elapsed < knockback_duration and knockback_duration > 0.0:
		# Integrate the linear decay so total displacement does not depend on frame size.
		var end_time := minf(knockback_duration, knockback_elapsed + delta)
		var start_speed := 2.0 * knockback_distance / knockback_duration
		var duration := end_time - knockback_elapsed
		var displacement := start_speed * (duration - (end_time * end_time - knockback_elapsed * knockback_elapsed) / (2.0 * knockback_duration))
		motion += knockback_direction * displacement
		knockback_elapsed = end_time
	if motion != Vector2.ZERO:
		move_and_collide(motion)
	global_position = clamp_position_to_map(global_position, bounds)
	update_walk_visual(player_position,global_position.distance_squared_to(visual_origin)>0.000001,action_delta,visual_knockback)

func get_knockback_velocity() -> Vector2:
	if is_logically_dead or knockback_duration <= 0.0 or knockback_elapsed >= knockback_duration:
		return Vector2.ZERO
	var fraction := clampf(knockback_elapsed / knockback_duration, 0.0, 1.0)
	return knockback_direction * (2.0 * knockback_distance / knockback_duration) * (1.0 - fraction)

func get_combined_velocity(player_position: Vector2) -> Vector2:
	if is_logically_dead or not is_active:
		return Vector2.ZERO
	return (Vector2.ZERO if is_feared() else global_position.direction_to(player_position)*move_speed)+get_knockback_velocity()

func clamp_position_to_map(world_position: Vector2, bounds: Rect2) -> Vector2:
	return Vector2(
		clampf(world_position.x, bounds.position.x + body_radius, bounds.end.x - body_radius),
		clampf(world_position.y, bounds.position.y + body_radius, bounds.end.y - body_radius)
	)

func move_toward_player(player_position: Vector2, delta: float) -> void:
	if is_logically_dead or is_feared():
		return
	var direction := global_position.direction_to(player_position)
	if direction != Vector2.ZERO:
		move_and_collide(direction * move_speed * delta)

func _ready() -> void:
	character_view = preload("res://scripts/character_presentation.gd").attach(self)
	configure_visual()
	collision_shape.shape = collision_shape.shape.duplicate()
	(collision_shape.shape as CircleShape2D).radius = body_radius
	collision_shape.disabled = not is_active
	queue_redraw()

func draw_body(canvas: Node2D) -> void:
	if sprite_body!=null and sprite_body.visible: return
	canvas.draw_circle(Vector2.ZERO, body_radius, SkillUI.FEAR_COLOR if is_feared() else ENEMY_COLOR)
	canvas.draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 48, OUTLINE_COLOR, 2.0)

func configure_visual() -> void:
	if visual_record.get("Sprite_path")==null or String(visual_record.get("Sprite_path","")).is_empty():
		if sprite_body!=null: sprite_body.hide()
		return
	if sprite_body==null:
		sprite_body = preload("res://scripts/sprite_body.gd").new()
		sprite_body.name = "SpriteBody"
		add_child(sprite_body)
		if is_instance_valid(character_view): sprite_body.reparent(character_view,false)
	sprite_body.configure(visual_record,body_radius,ENEMY_COLOR,OUTLINE_COLOR)
	sprite_body.show()
	update_sprite_tint()

func update_sprite_tint() -> void:
	if sprite_body==null: return
	var color := Color(String(visual_record.Sprite_tint)) if visual_record.get("Sprite_tint")!=null else Color.WHITE
	sprite_body.sprite_tint = color.lerp(SkillUI.FEAR_COLOR,0.5) if is_feared() else color
	sprite_body.queue_redraw()

func update_walk_visual(player_position: Vector2, moved: bool, delta: float, keep_facing: bool) -> void:
	if sprite_body==null or not sprite_body.visible: return
	sprite_body.advance_walk_pose(global_position.direction_to(player_position),moved and not is_feared(),delta,keep_facing)
	update_sprite_tint()
