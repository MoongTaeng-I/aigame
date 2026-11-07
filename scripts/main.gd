extends Node2D

const BOARD_COLUMNS := 4
const BOARD_ROWS := 4
const CELL_SIZE := 112.0
const CELL_GAP := 8.0
const UNIT_RADIUS := 34.0
const UNIT_FONT_SIZE := 28

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


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.08, 0.10, 0.14), true)

	var board_size := Vector2(
		BOARD_COLUMNS * CELL_SIZE + (BOARD_COLUMNS - 1) * CELL_GAP,
		BOARD_ROWS * CELL_SIZE + (BOARD_ROWS - 1) * CELL_GAP
	)
	var board_origin := (viewport_size - board_size) / 2.0
	var font := ThemeDB.fallback_font

	for row in range(BOARD_ROWS):
		for column in range(BOARD_COLUMNS):
			var cell_position := board_origin + Vector2(
				column * (CELL_SIZE + CELL_GAP),
				row * (CELL_SIZE + CELL_GAP)
			)
			var cell_rect := Rect2(cell_position, Vector2(CELL_SIZE, CELL_SIZE))
			draw_rect(cell_rect, Color(0.16, 0.20, 0.27), true)
			draw_rect(cell_rect, Color(0.32, 0.38, 0.47), false, 2.0)

			var level: int = board_state[row][column]
			if level == 0:
				continue

			var unit_center := cell_rect.get_center()
			var unit_color: Color = _unit_colors.get(level, Color(0.62, 0.64, 0.69))
			draw_circle(unit_center, UNIT_RADIUS + 2.0, Color(0.04, 0.05, 0.08))
			draw_circle(unit_center, UNIT_RADIUS, unit_color)

			var label := str(level)
			var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UNIT_FONT_SIZE)
			var baseline := unit_center + Vector2(
				-text_size.x / 2.0,
				(font.get_ascent() - font.get_descent()) / 2.0
			)
			draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, UNIT_FONT_SIZE, Color.WHITE)


func get_cell_level(cell: Vector2i) -> int:
	assert(_is_cell_in_bounds(cell), "Cell is outside the board.")
	return board_state[cell.y][cell.x]


func set_cell_level(cell: Vector2i, level: int) -> void:
	assert(_is_cell_in_bounds(cell), "Cell is outside the board.")
	board_state[cell.y][cell.x] = level
	queue_redraw()


func _is_cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < BOARD_COLUMNS and cell.y >= 0 and cell.y < BOARD_ROWS
