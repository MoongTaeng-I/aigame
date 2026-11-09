extends Node2D
class_name EnemyManager

signal enemy_died(enemy: EnemyActor)

const EnemyScene = preload("res://scenes/enemy.tscn")
const ProjectileScript = preload("res://scripts/projectile.gd")
const SPAWN_CLEARANCE := 2.0

var _player: CharacterBody2D
var _map_rect := Rect2()
var _enemy_records: Dictionary = {}
var _spawn_records: Dictionary = {}
var _projectile_records: Dictionary = {}
var _attack_record: Dictionary = {}
var _max_alive: int = 0
var _offscreen_relocate_seconds: float = 0.0
var _active_enemies: Array = []
var _enemy_pool: Array = []
var _dying_enemies: Array = []
var _projectiles: Array = []
var _spawn_order_counter: int = 0
var _contact_ready_at: Dictionary = {}
var _spawn_timers: Dictionary = {}
var _stop_normal_spawning: bool = false
# 임시 경과 시각이다. 시스템 8의 시간 관리가 생기면 그쪽으로 옮긴다.
var _elapsed_seconds: float = 0.0
var _random := RandomNumberGenerator.new()
var wander_radius: float = 0.0
var _count_label: Label

func configure(player: CharacterBody2D, map_rect: Rect2, enemy_records: Dictionary, spawn_records: Dictionary, max_alive: int, offscreen_relocate_seconds: float, projectile_records: Dictionary = {}, attack_record: Dictionary = {}) -> void:
	_player = player
	_map_rect = map_rect
	_enemy_records = enemy_records
	_spawn_records = spawn_records
	_projectile_records = projectile_records
	_attack_record = attack_record
	_max_alive = max_alive
	_offscreen_relocate_seconds = offscreen_relocate_seconds
	for spawn_id in _spawn_records:
		_spawn_timers[String(spawn_id)] = 0.0

func set_normal_spawning_stopped(stopped: bool) -> void:
	_stop_normal_spawning = stopped

func get_alive_count() -> int:
	return _active_enemies.size()

func get_living_enemies() -> Array:
	return _active_enemies.duplicate()

func recycle_enemy(enemy: EnemyActor) -> void:
	if not _active_enemies.has(enemy):
		return
	_active_enemies.erase(enemy)
	enemy.deactivate_to_pool()
	_enemy_pool.append(enemy)
	_update_count_label()

func _ready() -> void:
	_random.randomize()
	_create_temporary_enemy_counter()
	_update_count_label()

func _physics_process(delta: float) -> void:
	if _player == null:
		return
	# 임시 타이머이며 시스템 8의 스테이지 시간으로 대체한다.
	_elapsed_seconds += delta
	_advance_spawn_rows(delta)
	_update_active_enemies(delta)
	_update_dying_enemies(delta)
	_update_projectiles(delta)
	if _player.is_dead:
		return
	if _player.has_method("update_basic_attack"):
		_player.update_basic_attack(_elapsed_seconds, _active_enemies)
	_update_contact_damage()
	if _player.is_dead:
		return
	_resolve_contact_pushes()
	_update_count_label()

func _advance_spawn_rows(delta: float) -> void:
	for spawn_id_variant in _spawn_records:
		var spawn_id := String(spawn_id_variant)
		var row: Dictionary = _spawn_records[spawn_id]
		var start_time := float(row["Time_start"])
		var end_time := float(row["Time_end"])
		if _elapsed_seconds < start_time or _elapsed_seconds > end_time:
			_spawn_timers[spawn_id] = 0.0
			continue
		var interval := float(row["Spawn_interval"])
		var timer := float(_spawn_timers.get(spawn_id, 0.0)) + delta
		if interval <= 0.0:
			_spawn_timers[spawn_id] = 0.0
			continue
		while timer >= interval:
			timer -= interval
			if not _stop_normal_spawning:
				_spawn_from_row(row)
		_spawn_timers[spawn_id] = timer

func _spawn_from_row(row: Dictionary) -> void:
	var requested_count := int(row["Spawn_count"])
	var actual_count := maxi(0, mini(requested_count, _max_alive - _active_enemies.size()))
	var enemy_id := String(row["Enemy_id"])
	var enemy_record: Dictionary = _enemy_records.get(enemy_id, {})
	if enemy_record.is_empty():
		return
	for _index in range(actual_count):
		var spawn_position: Variant = _try_get_spawn_position(float(enemy_record["Body_radius"]))
		if spawn_position == null:
			return
		var enemy: EnemyActor
		if not _enemy_pool.is_empty():
			enemy = _enemy_pool.pop_back() as EnemyActor
		else:
			enemy = EnemyScene.instantiate() as EnemyActor
			add_child(enemy)
			if not enemy.died.is_connected(_on_enemy_died):
				enemy.died.connect(_on_enemy_died)
		enemy.configure(enemy_record)
		_contact_ready_at.erase(enemy.get_instance_id())
		_spawn_order_counter += 1
		enemy.activate_at(spawn_position, _spawn_order_counter)
		enemy.map_bounds = _get_map_world_rect()
		_active_enemies.append(enemy)

func _update_active_enemies(delta: float) -> void:
	if _player.is_dead:
		return
	var screen_rect := _get_screen_world_rect()
	for enemy in _active_enemies.duplicate():
		var target: Vector2 = _player.global_position
		var wandering: bool = _player.is_stealthed()
		if wandering:
			if not enemy.has_wander_target or enemy.global_position.distance_to(enemy.wander_target)<=0.000001:
				var offset := Vector2.RIGHT.rotated(_random.randf()*TAU)*sqrt(_random.randf())*wander_radius
				enemy.wander_target = _clamp_body_to_map(enemy.global_position+offset,enemy.body_radius)
				enemy.has_wander_target = true
			target = enemy.wander_target
		else:
			enemy.has_wander_target = false
		enemy.update_actor(delta, target, _get_map_world_rect(),wandering)
		_update_enemy_shot(enemy, delta)
		if screen_rect.grow(enemy.body_radius).has_point(enemy.global_position):
			enemy.offscreen_seconds = 0.0
			continue
		enemy.offscreen_seconds += delta
		if enemy.offscreen_seconds > _offscreen_relocate_seconds:
			var relocation_position: Variant = _try_get_spawn_position(enemy.body_radius)
			if relocation_position != null:
				enemy.global_position = relocation_position
				enemy.offscreen_seconds = 0.0

func _update_dying_enemies(delta: float) -> void:
	for enemy in _dying_enemies.duplicate():
		if not is_instance_valid(enemy):
			_dying_enemies.erase(enemy)
			continue
		enemy.update_actor(delta, _player.global_position, _get_map_world_rect())
		if enemy.is_queued_for_deletion():
			_dying_enemies.erase(enemy)

func _on_enemy_died(enemy: EnemyActor) -> void:
	if _active_enemies.has(enemy):
		_active_enemies.erase(enemy)
		_contact_ready_at.erase(enemy.get_instance_id())
		_dying_enemies.append(enemy)
		_update_count_label()
		enemy_died.emit(enemy)

func _update_enemy_shot(enemy: EnemyActor, delta: float) -> void:
	if _player.is_stealthed():
		return
	if not enemy.is_active or enemy.is_logically_dead or enemy.projectile_id.is_empty() or enemy.shot_interval_sec <= 0.0:
		return
	if enemy.global_position.distance_to(_player.global_position) > enemy.shot_range:
		return
	enemy.shot_elapsed += delta
	if enemy.shot_elapsed >= enemy.shot_interval_sec:
		enemy.shot_elapsed -= enemy.shot_interval_sec
		var projectile_record: Dictionary = _projectile_records.get(enemy.projectile_id, {})
		if projectile_record.is_empty():
			return
		var projectile := ProjectileScript.new() as CombatProjectile
		add_child(projectile)
		projectile.configure(projectile_record, enemy.global_position, _player.global_position, _get_map_world_rect(), _player)
		_projectiles.append(projectile)

func _update_projectiles(delta: float) -> void:
	for projectile in _projectiles.duplicate():
		if not is_instance_valid(projectile):
			_projectiles.erase(projectile)
			continue
		projectile.advance(delta)
		if projectile.is_queued_for_deletion():
			_projectiles.erase(projectile)

func _try_get_spawn_position(body_radius: float) -> Variant:
	var screen_rect := _get_screen_world_rect()
	var map_world_rect := _get_map_world_rect()
	var safe_left := map_world_rect.position.x + body_radius
	var safe_top := map_world_rect.position.y + body_radius
	var safe_right := map_world_rect.end.x - body_radius
	var safe_bottom := map_world_rect.end.y - body_radius
	if safe_left > safe_right or safe_top > safe_bottom:
		return null
	var candidates: Array[Dictionary] = []
	var spawn_offset := body_radius + SPAWN_CLEARANCE
	var left_edge := screen_rect.position.x
	var right_edge := screen_rect.end.x
	var top_edge := screen_rect.position.y
	var bottom_edge := screen_rect.end.y
	var horizontal_start := maxf(left_edge, safe_left)
	var horizontal_end := minf(right_edge, safe_right)
	var vertical_start := maxf(top_edge, safe_top)
	var vertical_end := minf(bottom_edge, safe_bottom)
	var top_spawn_y := top_edge - spawn_offset
	if horizontal_start <= horizontal_end and top_spawn_y >= safe_top and top_spawn_y <= safe_bottom:
		candidates.append({"horizontal": true, "fixed": top_spawn_y, "start": horizontal_start, "end": horizontal_end})
	var bottom_spawn_y := bottom_edge + spawn_offset
	if horizontal_start <= horizontal_end and bottom_spawn_y >= safe_top and bottom_spawn_y <= safe_bottom:
		candidates.append({"horizontal": true, "fixed": bottom_spawn_y, "start": horizontal_start, "end": horizontal_end})
	var left_spawn_x := left_edge - spawn_offset
	if vertical_start <= vertical_end and left_spawn_x >= safe_left and left_spawn_x <= safe_right:
		candidates.append({"horizontal": false, "fixed": left_spawn_x, "start": vertical_start, "end": vertical_end})
	var right_spawn_x := right_edge + spawn_offset
	if vertical_start <= vertical_end and right_spawn_x >= safe_left and right_spawn_x <= safe_right:
		candidates.append({"horizontal": false, "fixed": right_spawn_x, "start": vertical_start, "end": vertical_end})
	if candidates.is_empty():
		return null
	var candidate: Dictionary = candidates[_random.randi_range(0, candidates.size() - 1)]
	var along_edge := _random.randf_range(float(candidate["start"]), float(candidate["end"]))
	var world_position := Vector2(along_edge, float(candidate["fixed"])) if bool(candidate["horizontal"]) else Vector2(float(candidate["fixed"]), along_edge)
	return world_position

func _get_screen_world_rect() -> Rect2:
	var viewport_size := get_viewport().get_visible_rect().size
	var inverse_transform := get_viewport().get_canvas_transform().affine_inverse()
	var corners := [
		inverse_transform * Vector2.ZERO,
		inverse_transform * Vector2(viewport_size.x, 0.0),
		inverse_transform * viewport_size,
		inverse_transform * Vector2(0.0, viewport_size.y),
	]
	var minimum: Vector2 = corners[0]
	var maximum: Vector2 = corners[0]
	for corner in corners:
		minimum.x = minf(minimum.x, corner.x)
		minimum.y = minf(minimum.y, corner.y)
		maximum.x = maxf(maximum.x, corner.x)
		maximum.y = maxf(maximum.y, corner.y)
	return Rect2(minimum, maximum - minimum)

func _get_map_world_rect() -> Rect2:
	var map_node := get_parent() as Node2D
	var top_left := map_node.to_global(_map_rect.position)
	var bottom_right := map_node.to_global(_map_rect.end)
	return Rect2(top_left, bottom_right - top_left)

func _resolve_contact_pushes() -> void:
	var bodies: Array = [_player]
	bodies.append_array(_active_enemies)
	var maximum_radius := float(_player.body_radius)
	for enemy in _active_enemies:
		maximum_radius = maxf(maximum_radius, enemy.body_radius)
	var cell_size := maxf(64.0, maximum_radius * 2.0)
	var spatial_grid: Dictionary = {}
	var body_cells: Array[Vector2i] = []
	for body_index in range(bodies.size()):
		var body: Variant = bodies[body_index]
		var cell := Vector2i(floori(body.global_position.x / cell_size), floori(body.global_position.y / cell_size))
		body_cells.append(cell)
		var cell_indices: Array = spatial_grid.get(cell, [])
		cell_indices.append(body_index)
		spatial_grid[cell] = cell_indices
	for first_index in range(bodies.size()):
		var first: Variant = bodies[first_index]
		var center_cell: Vector2i = body_cells[first_index]
		for cell_x in range(-1, 2):
			for cell_y in range(-1, 2):
				var neighbor_cell := center_cell + Vector2i(cell_x, cell_y)
				var nearby_indices: Array = spatial_grid.get(neighbor_cell, [])
				for second_index in nearby_indices:
					if int(second_index) <= first_index:
						continue
					_resolve_contact_pair(first, bodies[int(second_index)])

func _resolve_contact_pair(first: Variant, second: Variant) -> void:
	if _player.dash_pass_through and (first==_player or second==_player):
		return
	if (first is EnemyActor and not first.is_active) or (second is EnemyActor and not second.is_active):
		return
	var combined_radius := float(first.body_radius) + float(second.body_radius)
	var offset: Vector2 = second.global_position - first.global_position
	var distance_squared: float = offset.length_squared()
	if distance_squared >= combined_radius * combined_radius:
		return
	var distance := sqrt(distance_squared)
	var direction: Vector2 = offset / distance if distance > 0.001 else Vector2.RIGHT
	var overlap := combined_radius - distance
	var first_weight := maxf(float(first.push_weight), 0.0001)
	var second_weight := maxf(float(second.push_weight), 0.0001)
	var total_weight := first_weight + second_weight
	var first_share := second_weight / total_weight
	var second_share := first_weight / total_weight
	var first_position: Vector2 = first.global_position - direction * overlap * first_share
	var second_position: Vector2 = second.global_position + direction * overlap * second_share
	first.global_position = _clamp_body_to_map(first_position, float(first.body_radius))
	second.global_position = _clamp_body_to_map(second_position, float(second.body_radius))

func _update_contact_damage() -> void:
	for enemy in _active_enemies:
		var radius := float(_player.body_radius) + float(enemy.body_radius)
		if _player.global_position.distance_squared_to(enemy.global_position) <= radius * radius + 0.0001:
			_apply_contact_damage(enemy)
		if _player.is_dead:
			return

func _apply_contact_damage(enemy: EnemyActor) -> void:
	if not enemy.is_active or enemy.is_logically_dead or enemy.contact_damage <= 0:
		return
	var key := enemy.get_instance_id()
	var ready_at := float(_contact_ready_at.get(key, 0.0))
	if _elapsed_seconds + 0.000000001 < ready_at:
		return
	_player.apply_damage(enemy.contact_damage)
	_contact_ready_at[key] = _elapsed_seconds + enemy.contact_rehit_sec

func _clamp_body_to_map(world_position: Vector2, body_radius: float) -> Vector2:
	var bounds := _get_map_world_rect()
	return Vector2(
		clampf(world_position.x, bounds.position.x + body_radius, bounds.end.x - body_radius),
		clampf(world_position.y, bounds.position.y + body_radius, bounds.end.y - body_radius)
	)

func _create_temporary_enemy_counter() -> void:
	# 임시 적 수 표시다. 시스템 9의 정식 HUD로 대체한다.
	var layer := CanvasLayer.new()
	add_child(layer)
	_count_label = Label.new()
	_count_label.position = Vector2(20.0, 16.0)
	_count_label.add_theme_color_override("font_color", Color("#ffffff"))
	_count_label.add_theme_font_size_override("font_size", 22)
	layer.add_child(_count_label)

func _update_count_label() -> void:
	if _count_label != null:
		_count_label.text = "적 수: %d / %d" % [_active_enemies.size(), _max_alive]
