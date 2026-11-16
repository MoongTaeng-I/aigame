extends RefCounted

# Reusable targeting and damage bridge for basic and future awakened skills.
static func living_in_circle(origin: Vector2, radius: float, candidates: Array) -> Array:
	var targets: Array = []
	var seen := {}
	for enemy in candidates:
		if is_instance_valid(enemy) and enemy.is_active and not enemy.is_logically_dead and not seen.has(enemy.get_instance_id()) and origin.distance_to(enemy.global_position)<=radius:
			seen[enemy.get_instance_id()] = true
			targets.append(enemy)
	return targets

static func damage_circle(origin: Vector2, radius: float, damage: int, candidates: Array) -> void:
	for enemy in living_in_circle(origin,radius,candidates):
		if enemy.has_method("record_damage_presentation"): enemy.record_damage_presentation("player")
		enemy.apply_damage(damage)
