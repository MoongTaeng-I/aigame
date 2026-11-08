extends CharacterBody2D
class_name EnemyActor

const ENEMY_COLOR := Color("#ff7d68")
const OUTLINE_COLOR := Color("#ffe4df")

enum AttackRangeType { MELEE, RANGED }

var enemy_id: String = ""
var move_speed: float = 0.0
var attack_range_type: AttackRangeType = AttackRangeType.MELEE
var body_radius: float = 16.0
var push_weight: float = 1.0
var offscreen_seconds: float = 0.0
var is_active: bool = false

@onready var collision_shape := $CollisionShape2D as CollisionShape2D

func configure(record: Dictionary) -> void:
	enemy_id = String(record["Id"])
	move_speed = float(record["Move_speed"])
	attack_range_type = int(record["Attack_range_type"])
	body_radius = float(record["Body_radius"])
	push_weight = float(record["Push_weight"])
	if is_node_ready():
		(collision_shape.shape as CircleShape2D).set_deferred("radius", body_radius)
		queue_redraw()

func activate_at(world_position: Vector2) -> void:
	global_position = world_position
	offscreen_seconds = 0.0
	is_active = true
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

func move_toward_player(player_position: Vector2, delta: float) -> void:
	var direction := global_position.direction_to(player_position)
	if direction != Vector2.ZERO:
		move_and_collide(direction * move_speed * delta)

func _ready() -> void:
	collision_shape.shape = collision_shape.shape.duplicate()
	(collision_shape.shape as CircleShape2D).radius = body_radius
	collision_shape.disabled = not is_active
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, body_radius, ENEMY_COLOR)
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 48, OUTLINE_COLOR, 2.0)
