extends Node2D
var settings: Dictionary = preload("res://scripts/shadow_afterimage.gd").compiled_presentation().duplicate()

var value: int = 0
var radius: float = 0.0
var is_pulling: bool = false
var speed: float = 0.0
var collected: bool = false
var _start_speed: float = 0.0
var _acceleration: float = 0.0
# JUICE-01 picture only: stretch along the pull direction while pulled. Redraws only while pulling.
var pull_direction := Vector2.ZERO
var stretch := 1.0
var redraws := 0

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
	_update_stretch(movement)
	var closest := origin
	if movement.length_squared() > 0.0:
		var fraction := clampf((target-origin).dot(movement)/movement.length_squared(),0.0,1.0)
		closest += movement * fraction
	if closest.distance_to(target) <= contact_radius:
		return _collect()
	return false

func _update_stretch(movement: Vector2) -> void:
	if movement==Vector2.ZERO: return
	var full := maxf(float(settings.get("Xp_absorb_full_speed",900)),0.000001)
	var next := 1.0+(float(settings.get("Xp_absorb_stretch",1.6))-1.0)*clampf(speed/full,0,1)
	var direction := movement.normalized()
	if is_equal_approx(next,stretch) and direction.is_equal_approx(pull_direction): return
	stretch = next
	pull_direction = direction
	redraws += 1
	queue_redraw()

func _collect() -> bool:
	collected = true
	visible = false
	queue_free()
	return true

func _draw() -> void:
	var color := Color(settings.get("Xp_color","#a68cff"))
	if is_pulling and pull_direction!=Vector2.ZERO:
		# One short tail behind the stretched gem, then the gem itself in the pull frame.
		var squash := 1.0/sqrt(stretch)
		draw_set_transform(-pull_direction*radius*stretch*0.9,pull_direction.angle(),Vector2(stretch*0.8,squash*0.7))
		draw_colored_polygon(PackedVector2Array([Vector2(0,-radius),Vector2(radius,0),Vector2(0,radius),Vector2(-radius,0)]),Color(color,float(settings.get("Xp_absorb_trail_alpha",0.35))))
		draw_set_transform(Vector2.ZERO,pull_direction.angle(),Vector2(stretch,squash))
	for i in range(int(settings.get("Xp_glow_layers",3)),0,-1): draw_circle(Vector2.ZERO,radius*(1.0+float(i)*float(settings.get("Xp_glow_radius",0.25))),Color(color,float(settings.get("Xp_glow_alpha",0.18))/i))
	draw_colored_polygon(PackedVector2Array([Vector2(0,-radius),Vector2(radius,0),Vector2(0,radius),Vector2(-radius,0)]),color)
