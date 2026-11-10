extends "res://scripts/enemy_manager.gd"

const Reference = preload("res://tests/push_reference.gd")
var reference: bool = false
var collecting: bool = true
var costs: Dictionary = {}
var pass_us: Array[int] = []
var pair_counts: Array[int] = []
var bookkeeping_us: int = 0
# Measurement-only, default off; excludes movement/knockback from push steps.
var observe_enemy_push: bool = false
var enemy_push_max_step: float = 0.0

func begin_frame() -> void:
	costs = {"movement":0,"shots":0,"projectiles":0,"contact":0,"push":0}
	pass_us.clear()
	pair_counts.clear()
	bookkeeping_us = 0

func _update_active_enemies(delta: float) -> void:
	var started := Time.get_ticks_usec()
	var prior_shots: int = costs.get("shots",0)
	super._update_active_enemies(delta)
	costs.movement = Time.get_ticks_usec()-started-(int(costs.shots)-prior_shots)

func _update_enemy_shot(enemy: EnemyActor, delta: float) -> void:
	var started := Time.get_ticks_usec()
	super._update_enemy_shot(enemy,delta)
	costs.shots = int(costs.get("shots",0))+Time.get_ticks_usec()-started

func _update_projectiles(delta: float) -> void:
	var started := Time.get_ticks_usec()
	super._update_projectiles(delta)
	costs.projectiles = Time.get_ticks_usec()-started

func _update_contact_damage() -> void:
	var started := Time.get_ticks_usec()
	super._update_contact_damage()
	costs.contact = Time.get_ticks_usec()-started

func _resolve_contact_pushes() -> void:
	var started := Time.get_ticks_usec()
	var prior := bookkeeping_us
	var before: Array = []
	if observe_enemy_push:
		for enemy in _active_enemies: before.append(enemy.global_position)
	super._resolve_contact_pushes()
	if observe_enemy_push:
		enemy_push_max_step = 0.0
		for i in range(_active_enemies.size()):
			enemy_push_max_step = maxf(enemy_push_max_step,_active_enemies[i].global_position.distance_to(before[i]))
	costs.push = Time.get_ticks_usec()-started-(bookkeeping_us-prior)

func _resolve_contact_push_pass() -> void:
	if collecting:
		var count_started := Time.get_ticks_usec()
		pair_counts.append(candidate_count())
		bookkeeping_us += Time.get_ticks_usec()-count_started
	var started := Time.get_ticks_usec()
	if reference: Reference.resolve(self)
	else: super._resolve_contact_push_pass()
	pass_us.append(Time.get_ticks_usec()-started)

func candidate_count() -> int:
	var max_radius: float = _player.body_radius
	for enemy in _active_enemies: max_radius = maxf(max_radius,enemy.body_radius)
	var cell_size := maxf(64.0,max_radius*2.0+separation_gap)
	var bins := {}
	var bodies: Array = [_player]
	bodies.append_array(_active_enemies)
	for body in bodies:
		var cell := Vector2i(floori(body.global_position.x/cell_size),floori(body.global_position.y/cell_size))
		bins[cell] = int(bins.get(cell,0))+1
	var count := 0
	for cell in bins:
		var size: int = bins[cell]
		count += size*(size-1)/2
		for x in range(-1,2):
			for y in range(-1,2):
				if x<0 or (x==0 and y<=0): continue
				count += size*int(bins.get(cell+Vector2i(x,y),0))
	return count
