extends CharacterBody2D

const PLAYER_COLOR := Color("#b18cff")
var move_speed: float = 0.0
var body_radius: float = 18.0
var push_weight: float = 1.0
var max_hp: int = 100
var hp: int = 100
var _attack_data: Dictionary = {}
var _attack_phase: int = 0
var _second_hit_at: float = 0.0
var _attack_ready_at: float = 0.0
var is_dead: bool = false
var _hp_label: Label
var _death_label: Label

func configure_body(radius: float, weight: float) -> void:
    body_radius = radius
    push_weight = weight
    var collision_shape := get_node("CollisionShape2D") as CollisionShape2D
    var circle := collision_shape.shape as CircleShape2D
    circle.radius = body_radius
    queue_redraw()

func _ready() -> void:
    _create_hud()
    queue_redraw()

func configure_combat(health: int, attack_data: Dictionary) -> void:
    max_hp = health
    hp = health
    _attack_data = attack_data.duplicate(true)
    _update_hp_label()

func apply_damage(amount: int) -> void:
    if is_dead or amount <= 0:
        return
    hp = maxi(0, hp - amount)
    _update_hp_label()
    if hp == 0:
        is_dead = true
        _death_label = Label.new()
        _death_label.text = "사망"
        _death_label.position = Vector2(570.0, 320.0)
        _death_label.add_theme_font_size_override("font_size", 48)
        _death_label.add_theme_color_override("font_color", Color("#ff7b83"))
        get_tree().root.add_child(_death_label)
        get_tree().paused = true

func update_basic_attack(now: float, enemies: Array) -> void:
    if is_dead or _attack_data.is_empty():
        return
    if _attack_phase == 1 and now + 0.000001 >= _second_hit_at:
        var second_target: Variant = choose_target(enemies)
        if second_target != null:
            _apply_basic_hit(second_target)
        _attack_phase = 0
    if _attack_phase == 0 and now + 0.000001 >= _attack_ready_at:
        var first_target: Variant = choose_target(enemies)
        if first_target != null:
            _apply_basic_hit(first_target)
            _attack_phase = 1
            _second_hit_at = now + float(_attack_data["Hit_gap_sec"])
            _attack_ready_at = now + float(_attack_data["Hit_gap_sec"]) + float(_attack_data["Hit_effect_sec"]) + float(_attack_data["Interval_sec"])

func choose_target(enemies: Array) -> Variant:
    var chosen: Variant = null
    for candidate in enemies:
        if candidate == null or not candidate.is_active or candidate.is_logically_dead:
            continue
        var distance := global_position.distance_to(candidate.global_position)
        if distance > float(_attack_data["Range"]):
            continue
        if chosen == null:
            chosen = candidate
            continue
        if candidate.hp < chosen.hp or (candidate.hp == chosen.hp and distance < global_position.distance_to(chosen.global_position)) or (candidate.hp == chosen.hp and is_equal_approx(distance, global_position.distance_to(chosen.global_position)) and candidate.spawn_order < chosen.spawn_order):
            chosen = candidate
    return chosen

func _apply_basic_hit(enemy: Variant) -> void:
    enemy.apply_damage(int(_attack_data["Damage"]))
    enemy.start_knockback(global_position, float(_attack_data["Knockback_distance"]), float(_attack_data["Knockback_sec"]))
    var effect := Line2D.new()
    effect.width = 4.0
    effect.default_color = Color("#fff1a8")
    effect.add_point(global_position)
    effect.add_point(enemy.global_position)
    get_parent().add_child(effect)
    var timer := Timer.new()
    timer.one_shot = true
    timer.wait_time = float(_attack_data["Hit_effect_sec"])
    effect.add_child(timer)
    timer.timeout.connect(effect.queue_free)
    timer.start()

func _create_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    _hp_label = Label.new()
    _hp_label.position = Vector2(20.0, 46.0)
    _hp_label.add_theme_color_override("font_color", Color.WHITE)
    _hp_label.add_theme_font_size_override("font_size", 22)
    layer.add_child(_hp_label)
    _update_hp_label()

func _update_hp_label() -> void:
    if _hp_label != null:
        _hp_label.text = "플레이어 HP: %d / %d" % [hp, max_hp]

func _physics_process(delta: float) -> void:
    var direction := Vector2(
        Input.get_axis("move_left", "move_right"),
        Input.get_axis("move_up", "move_down")
    )
    if direction != Vector2.ZERO:
        direction = direction.normalized()
    # Resolve each axis independently so a blocked component does not cancel motion along the wall.
    move_and_collide(Vector2(direction.x * move_speed * delta, 0.0))
    move_and_collide(Vector2(0.0, direction.y * move_speed * delta))

func _draw() -> void:
    draw_circle(Vector2.ZERO, body_radius, PLAYER_COLOR)
    draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 48, Color("#eee6ff"), 2.0)
