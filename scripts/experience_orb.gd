extends Node2D

var value: int = 0
var radius: float = 0.0
var is_pulling: bool = false
var speed: float = 0.0
var collected: bool = false
var _start_speed: float = 0.0
var _acceleration: float = 0.0

func configure(amount: int, world_position: Vector2, rule: Dictionary) -> void:
	value = amount
	global_position = world_position
	radius = float(rule["Orb_radius"])
	_start_speed = float(rule["Pull_start_speed"])
	_acceleration = float(rule["Pull_accel"])
	queue_redraw()

func advance(delta: float, player: Node2D) -> bool:
	if collected or player.is_dead:
		return false
	var target := player.global_position
	var distance := global_position.distance_to(target)
	var contact_radius := float(player.body_radius) + radius
	if distance <= contact_radius:
		return _collect()
	if not is_pulling and distance <= float(player.pickup_radius):
		is_pulling = true
		speed = _start_speed
	if not is_pulling:
		return false
	# Integrate acceleration and test the entire movement segment for contact.
	var travel := speed * delta + 0.5 * _acceleration * delta * delta
	speed += _acceleration * delta
	var origin := global_position
	var movement := origin.direction_to(target) * minf(travel,distance)
	global_position += movement
	var closest := origin
	if movement.length_squared() > 0.0:
		var fraction := clampf((target-origin).dot(movement)/movement.length_squared(),0.0,1.0)
		closest += movement * fraction
	if closest.distance_to(target) <= contact_radius:
		return _collect()
	return false

func _collect() -> bool:
	collected = true
	visible = false
	queue_free()
	return true

func _draw() -> void:
	draw_circle(Vector2.ZERO,radius,Color("#b18cff"))
