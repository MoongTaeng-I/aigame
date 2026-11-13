extends "res://scripts/player.gd"

var attack_us: int = 0
var legacy_single_target := false

func _apply_basic_triangle(target: Variant, enemies: Array) -> void:
	# Only the archived pre-optimization artifact uses its historical combat.
	if legacy_single_target: _apply_basic_hit(target)
	else: super._apply_basic_triangle(target,enemies)

func update_basic_attack(now: float, enemies: Array) -> void:
	var started := Time.get_ticks_usec()
	super.update_basic_attack(now,enemies)
	attack_us += Time.get_ticks_usec()-started
