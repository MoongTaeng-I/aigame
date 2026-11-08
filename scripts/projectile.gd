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
	var step := delta
	if expire_rule == 0:
		step = minf(step, maxf(0.0, max_distance - traveled) / speed)
	elif expire_rule == 1:
		step = minf(step, maxf(0.0, max_lifetime_sec - lived))
	elif expire_rule == 2:
		for axis in range(2):
			var component := direction[axis] * speed
			if component > 0.0:
				step = minf(step, maxf(0.0, map_bounds.end[axis] - global_position[axis]) / component)
			elif component < 0.0:
				step = minf(step, maxf(0.0, global_position[axis] - map_bounds.position[axis]) / -component)
	var origin := global_position
	var movement := direction * speed * step
	global_position += movement
	traveled += speed * step
	lived += step
	if player != null and is_instance_valid(player) and _segment_hits_player(origin, global_position):
		spent = true
		visible = false
		player.apply_damage(damage)
		queue_free()
		return
	if expire_rule == 0 and traveled + 0.000000001 >= max_distance:
		spent = true
	elif expire_rule == 1 and lived + 0.000000001 >= max_lifetime_sec:
		spent = true
	elif expire_rule == 2 and (global_position.x <= map_bounds.position.x or global_position.y <= map_bounds.position.y or global_position.x >= map_bounds.end.x or global_position.y >= map_bounds.end.y):
		spent = true
	if spent:
		visible = false
		queue_free()

func _segment_hits_player(origin: Vector2, endpoint: Vector2) -> bool:
	var segment := endpoint - origin
	var length_squared := segment.length_squared()
	var fraction := 0.0
	if length_squared > 0.0:
		fraction = clampf((player.global_position - origin).dot(segment) / length_squared, 0.0, 1.0)
	var closest := origin + segment * fraction
	var radius := body_radius + float(player.body_radius)
	return closest.distance_squared_to(player.global_position) <= radius * radius

func _draw() -> void:
	draw_circle(Vector2.ZERO, body_radius, Color("#ffdb59"))
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 24, Color("#fff6c7"), 1.5)
