extends Node2D

# 임시 A단계 검증용 맵 크기와 격자 간격이다. 맵 크기는 콘텐츠 CSV가 아닌 이 씬에 고정한다.
const MAP_SIZE := Vector2(2560, 1440)
const MAP_RECT := Rect2(-MAP_SIZE * 0.5, MAP_SIZE)
const GRID_STEP := 128
const WALL_THICKNESS := 32.0

func _ready() -> void:
    var bodies := Node2D.new()
    bodies.name = "CharacterBodies"
    bodies.y_sort_enabled = true
    add_child(bodies)
    _create_boundaries()
    queue_redraw()

func get_map_rect() -> Rect2:
    return MAP_RECT

func _draw() -> void:
    draw_rect(MAP_RECT, Color("#17151f"), true)
    # 임시 눈금으로 월드 좌표를 확인한다. 실제 아트와 맵 디자인은 후속 작업에서 만든다.
    var grid_color := Color("#24212e")
    var x := int(MAP_RECT.position.x) + GRID_STEP
    while x < int(MAP_RECT.end.x):
        draw_line(Vector2(x, MAP_RECT.position.y), Vector2(x, MAP_RECT.end.y), grid_color, 1.0)
        x += GRID_STEP
    var y := int(MAP_RECT.position.y) + GRID_STEP
    while y < int(MAP_RECT.end.y):
        draw_line(Vector2(MAP_RECT.position.x, y), Vector2(MAP_RECT.end.x, y), grid_color, 1.0)
        y += GRID_STEP
    draw_rect(MAP_RECT, Color("#9b7cff"), false, 4.0)

func _create_boundaries() -> void:
    _add_wall(Vector2(MAP_RECT.position.x - WALL_THICKNESS * 0.5, 0), Vector2(WALL_THICKNESS, MAP_SIZE.y + WALL_THICKNESS * 2))
    _add_wall(Vector2(MAP_RECT.end.x + WALL_THICKNESS * 0.5, 0), Vector2(WALL_THICKNESS, MAP_SIZE.y + WALL_THICKNESS * 2))
    _add_wall(Vector2(0, MAP_RECT.position.y - WALL_THICKNESS * 0.5), Vector2(MAP_SIZE.x, WALL_THICKNESS))
    _add_wall(Vector2(0, MAP_RECT.end.y + WALL_THICKNESS * 0.5), Vector2(MAP_SIZE.x, WALL_THICKNESS))

func _add_wall(wall_position: Vector2, wall_size: Vector2) -> void:
    var wall := StaticBody2D.new()
    wall.position = wall_position
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = wall_size
    collision.shape = shape
    wall.add_child(collision)
    add_child(wall)
