extends "res://scripts/player.gd"

var attack_us: int = 0

func update_basic_attack(now: float, enemies: Array) -> void:
	var started := Time.get_ticks_usec()
	super.update_basic_attack(now,enemies)
	attack_us += Time.get_ticks_usec()-started
