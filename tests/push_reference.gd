extends RefCounted

# Frozen pre-optimization pass and pair equations; only manager access is adapted.
static func resolve(manager: EnemyManager) -> void:
	var _player = manager._player
	var _active_enemies: Array = manager._active_enemies
	var separation_gap: float = manager.separation_gap
	var bodies: Array = [_player]
	bodies.append_array(_active_enemies)
	var maximum_radius := float(_player.body_radius)
	for enemy in _active_enemies:
		maximum_radius = maxf(maximum_radius, enemy.body_radius)
	var cell_size := maxf(64.0, maximum_radius * 2.0 + separation_gap)
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
					pair(manager, first, bodies[int(second_index)])

static func pair(manager: EnemyManager, first: Variant, second: Variant) -> void:
	var _player = manager._player
	var separation_gap: float = manager.separation_gap
	if _player.dash_pass_through and (first==_player or second==_player):
		return
	if (first is EnemyActor and not first.is_active) or (second is EnemyActor and not second.is_active):
		return
	var combined_radius := float(first.body_radius) + float(second.body_radius)
	if first is EnemyActor and second is EnemyActor:
		combined_radius += separation_gap
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
	first.global_position = manager._clamp_body_to_map(first_position, float(first.body_radius))
	second.global_position = manager._clamp_body_to_map(second_position, float(second.body_radius))

