extends Node2D

const BOARD_COLUMNS := 4
const BOARD_ROWS := 4
const CELL_SIZE := 112.0
const CELL_GAP := 8.0
const UNIT_RADIUS := 34.0
const UNIT_FONT_SIZE := 28
const HIGHEST_TEST_LEVEL := 3
const GAME_OVER_FONT_SIZE := 40
const NO_CELL := Vector2i(-1, -1)

var board_state: Array = [
	[1, 1, 0, 0],
	[0, 0, 2, 0],
	[0, 0, 0, 0],
	[1, 0, 0, 1],
]

var _unit_colors: Dictionary = {
	1: Color(0.30, 0.58, 0.91),
	2: Color(0.93, 0.59, 0.27),
	3: Color(0.35, 0.70, 0.51),
}

var _drag_source_cell := NO_CELL
var _dragged_level := 0
var _drag_position := Vector2.ZERO
var _drag_grab_offset := Vector2.ZERO
var _game_over := false


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.08, 0.10, 0.14), true)

	for row in range(BOARD_ROWS):
		for column in range(BOARD_COLUMNS):
			var cell := Vector2i(column, row)
			var cell_rect := _get_cell_rect(cell)
			draw_rect(cell_rect, Color(0.16, 0.20, 0.27), true)
			draw_rect(cell_rect, Color(0.32, 0.38, 0.47), false, 2.0)

			if _is_dragging() and cell == _drag_source_cell:
				continue

			var level: int = board_state[row][column]
			if level != 0:
				_draw_unit(level, cell_rect.get_center())

	if _is_dragging():
		_draw_unit(_dragged_level, _drag_position + _drag_grab_offset)
	if _game_over:
		_draw_game_over_label(viewport_size)


func _unhandled_input(event: InputEvent) -> void:
	if _game_over:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		elif _is_dragging():
			_finish_drag(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _is_dragging():
		_drag_position = event.position
		queue_redraw()
		get_viewport().set_input_as_handled()


func _begin_drag(pointer_position: Vector2) -> void:
	if _game_over:
		return

	var cell := _get_cell_at_position(pointer_position)
	if cell == NO_CELL:
		return

	var level := get_cell_level(cell)
	if level == 0:
		return

	_drag_source_cell = cell
	_dragged_level = level
	_drag_position = pointer_position
	_drag_grab_offset = _get_cell_rect(cell).get_center() - pointer_position
	queue_redraw()
	get_viewport().set_input_as_handled()


func _finish_drag(pointer_position: Vector2) -> void:
	if _game_over:
		return

	var source_cell := _drag_source_cell
	var target_cell := _get_cell_at_position(pointer_position)

	if target_cell != NO_CELL and target_cell != source_cell:
		var source_level := get_cell_level(source_cell)
		var target_level := get_cell_level(target_cell)
		if target_level == 0:
			board_state[source_cell.y][source_cell.x] = 0
			board_state[target_cell.y][target_cell.x] = source_level
		elif target_level == source_level and source_level < HIGHEST_TEST_LEVEL:
			board_state[source_cell.y][source_cell.x] = 0
			board_state[target_cell.y][target_cell.x] = source_level + 1
			if source_level + 1 == HIGHEST_TEST_LEVEL:
				_game_over = true
		# Same-cell drops, different levels, outside drops, and top-level merges leave the board unchanged.

	_drag_source_cell = NO_CELL
	_dragged_level = 0
	queue_redraw()


func _get_cell_at_position(position: Vector2) -> Vector2i:
	for row in range(BOARD_ROWS):
		for column in range(BOARD_COLUMNS):
			var cell := Vector2i(column, row)
			if _get_cell_rect(cell).has_point(position):
				return cell
	return NO_CELL


func _get_cell_rect(cell: Vector2i) -> Rect2:
	var cell_position := _get_board_origin() + Vector2(
		cell.x * (CELL_SIZE + CELL_GAP),
		cell.y * (CELL_SIZE + CELL_GAP)
	)
	return Rect2(cell_position, Vector2(CELL_SIZE, CELL_SIZE))


func _get_board_origin() -> Vector2:
	return (get_viewport_rect().size - _get_board_size()) / 2.0


func _get_board_size() -> Vector2:
	return Vector2(
		BOARD_COLUMNS * CELL_SIZE + (BOARD_COLUMNS - 1) * CELL_GAP,
		BOARD_ROWS * CELL_SIZE + (BOARD_ROWS - 1) * CELL_GAP
	)


func _draw_game_over_label(viewport_size: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var label := "종료"
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, GAME_OVER_FONT_SIZE)
	var label_center := Vector2(viewport_size.x / 2.0, _get_board_origin().y / 2.0)
	var baseline := label_center + Vector2(
		-text_size.x / 2.0,
		(font.get_ascent() - font.get_descent()) / 2.0
	)
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, GAME_OVER_FONT_SIZE, Color.WHITE)


func _draw_unit(level: int, center: Vector2) -> void:
	var unit_color: Color = _unit_colors.get(level, Color(0.62, 0.64, 0.69))
	draw_circle(center, UNIT_RADIUS + 2.0, Color(0.04, 0.05, 0.08))
	draw_circle(center, UNIT_RADIUS, unit_color)

	var font := ThemeDB.fallback_font
	var label := str(level)
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UNIT_FONT_SIZE)
	var baseline := center + Vector2(
		-text_size.x / 2.0,
		(font.get_ascent() - font.get_descent()) / 2.0
	)
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, UNIT_FONT_SIZE, Color.WHITE)


func _is_dragging() -> bool:
	return _drag_source_cell != NO_CELL


func get_cell_level(cell: Vector2i) -> int:
	assert(_is_cell_in_bounds(cell), "Cell is outside the board.")
	return board_state[cell.y][cell.x]


func set_cell_level(cell: Vector2i, level: int) -> void:
	assert(_is_cell_in_bounds(cell), "Cell is outside the board.")
	board_state[cell.y][cell.x] = level
	queue_redraw()


func _is_cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < BOARD_COLUMNS and cell.y >= 0 and cell.y < BOARD_ROWS
