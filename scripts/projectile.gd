extends Node2D
class_name CombatProjectile

var direction := Vector2.RIGHT
var speed: float = 0.0
var damage: int = 0
var body_radius: float = 6.0
var expire_rule: int = 0
var max_distance: float = 0.0
var max_lifetime_sec: float = 0.0
var map_bounds := Rect2()
var player: Node2D
var traveled: float = 0.0
var lived: float = 0.0
var spent: bool = false

func configure(record: Dictionary, origin: Vector2, aim: Vector2, bounds: Rect2, target: Node2D) -> void:
	global_position = origin
	direction = origin.direction_to(aim)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	speed = float(record["Speed"])
	damage = int(record["Damage"])
	body_radius = float(record["Body_radius"])
	expire_rule = int(record["Expire_rule"])
	max_distance = float(record["Max_distance"]) if record["Max_distance"] != null else 0.0
	max_lifetime_sec = float(record["Max_lifetime_sec"]) if record["Max_lifetime_sec"] != null else 0.0
	map_bounds = bounds
	player = target
	queue_redraw()

func advance(delta: float) -> void:
	if spent:
		return
	var movement := direction * speed * delta
	global_position += movement
	traveled += movement.length()
	lived += delta
	if player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) <= body_radius + float(player.body_radius):
		spent = true
		player.apply_damage(damage)
		queue_free()
		return
	if expire_rule == 0 and traveled >= max_distance:
		spent = true
	elif expire_rule == 1 and lived >= max_lifetime_sec:
		spent = true
	elif expire_rule == 2 and not map_bounds.has_point(global_position):
		spent = true
	if spent:
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, body_radius, Color("#ffdb59"))
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 24, Color("#fff6c7"), 1.5)
