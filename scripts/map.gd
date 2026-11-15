extends Node2D

# 임시 A단계 검증용 맵 크기와 격자 간격이다. 맵 크기는 콘텐츠 CSV가 아닌 이 씬에 고정한다.
const MAP_SIZE := Vector2(2560, 1440)
const MAP_RECT := Rect2(-MAP_SIZE * 0.5, MAP_SIZE)
const GRID_STEP := 128
const WALL_THICKNESS := 32.0
var debug_visible := false
var settings: Dictionary
var ground: Texture2D
var prop_layout: Array = []

func _ready() -> void:
    var bodies := Node2D.new()
    bodies.name = "CharacterBodies"
    bodies.y_sort_enabled = true
    add_child(bodies)
    _create_boundaries()
    settings = load("res://scripts/shadow_afterimage.gd").presentation()
    ground = load("res://assets/art/env/snow_ground.png")
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    _create_environment(bodies)
    queue_redraw()

func get_map_rect() -> Rect2:
    return MAP_RECT

func _draw() -> void:
    if ground!=null:
        var brightness := float(settings.get("Ground_brightness",0.93))
        draw_texture_rect(ground,MAP_RECT,true,Color(brightness,brightness,brightness))
    if not debug_visible: return
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

func set_debug_visible(value: bool) -> void:
    debug_visible = value
    queue_redraw()

func _create_environment(bodies: Node2D) -> void:
    var container := Node.new()
    container.name = "EnvironmentProps"
    add_child(container)
    var rng := RandomNumberGenerator.new()
    rng.seed = int(settings.get("Forest_seed",11015))
    var band := float(settings.get("Forest_band_px",160))
    var spacing := float(settings.get("Tree_spacing_px",90))
    var jitter := float(settings.get("Tree_jitter_px",12))
    for edge in range(4):
        var length := MAP_SIZE.x if edge<2 else MAP_SIZE.y
        for row in range(2):
            var distance := spacing*0.5+row*spacing*0.5
            while distance<length:
                var depth := clampf(band*(0.25+row*0.5)+rng.randf_range(-jitter,jitter),0,band)
                var along := clampf(distance+rng.randf_range(-jitter,jitter),0,length)
                var pos := Vector2(MAP_RECT.position.x+along,MAP_RECT.position.y+depth) if edge==0 else (Vector2(MAP_RECT.position.x+along,MAP_RECT.end.y-depth) if edge==1 else (Vector2(MAP_RECT.position.x+depth,MAP_RECT.position.y+along) if edge==2 else Vector2(MAP_RECT.end.x-depth,MAP_RECT.position.y+along)))
                _add_prop(bodies,pos,rng.randi_range(0,3),rng.randf()<0.5,1.0)
                distance += spacing
    var inner := MAP_RECT.grow(-band)
    for i in range(int(settings.get("Inner_props",14))):
        var pos := Vector2(rng.randf_range(inner.position.x,inner.end.x),rng.randf_range(inner.position.y,inner.end.y))
        var column := rng.randi_range(0,5)
        _add_prop(bodies,pos,column,rng.randf()<0.5,float(settings.get("Inner_prop_scale",0.55)) if column<4 else 1.0)
    container.set_meta("count",prop_layout.size())
    modulate = Color(String(settings.get("World_tint","#eef2fa")))
    var weather := preload("res://scripts/snow_weather.gd").new()
    weather.name = "SnowWeather"
    weather.settings = settings
    add_child(weather)

func _add_prop(bodies: Node2D, pos: Vector2, column: int, mirrored: bool, factor: float) -> void:
    var prop := preload("res://scripts/environment_prop.gd").new()
    prop.texture = load("res://assets/art/env/env_props.png")
    prop.column = column
    prop.mirrored = mirrored
    prop.display_height = float(settings.get("Prop_cell_height",234))*factor
    prop.shadow_size = Vector2(float(settings.get("Prop_shadow_w",70)),float(settings.get("Prop_shadow_h",24)))*factor
    prop.position = pos
    prop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    bodies.add_child(prop)
    prop_layout.append({"position":pos,"column":column,"mirrored":mirrored,"factor":factor})

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
