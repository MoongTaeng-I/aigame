extends RefCounted

# Reusable targeting and damage bridge for basic and future awakened skills.
static func living_in_circle(origin: Vector2, radius: float, candidates: Array) -> Array:
	var targets: Array = []
	for enemy in candidates:
		if is_instance_valid(enemy) and enemy.is_active and not enemy.is_logically_dead and not targets.has(enemy) and origin.distance_to(enemy.global_position)<=radius:
			targets.append(enemy)
	return targets

static func damage_circle(origin: Vector2, radius: float, damage: int, candidates: Array) -> void:
	for enemy in living_in_circle(origin,radius,candidates):
		enemy.apply_damage(damage)
