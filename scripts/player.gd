extends CharacterBody2D

const PLAYER_COLOR := Color("#b18cff")
const Geometry = preload("res://scripts/combat_geometry.gd")
const Afterimage = preload("res://scripts/shadow_afterimage.gd")
var presentation: Dictionary = Afterimage.presentation()
var visuals_enabled := true
var trail_elapsed := 0.0
signal leveled_up(new_level: int)
signal damaged(world_position: Vector2)
var level: int = 1
var experience: int = 0
var enhancement_points: int = 0
var pickup_radius: float = 0.0
var _level_requirements: Array[int] = []
var move_speed: float = 0.0
var last_move_direction := Vector2.RIGHT
var dash_direction := Vector2.RIGHT
var dash_remaining: float = 0.0
var dash_speed: float = 0.0
var dash_pass_through: bool = false
var stealth_remaining: float = 0.0
var fear_cast_remaining: float = 0.0
var freeze_remaining: float = 0.0

func is_frozen() -> bool:
    return freeze_remaining > 0.000000001

func apply_freeze(seconds: float) -> void:
    if not is_dead:
        freeze_remaining = seconds

func is_fear_casting() -> bool:
    return fear_cast_remaining > 0.000000001

func is_stealthed() -> bool:
    return stealth_remaining > 0.000000001
var body_radius: float = 18.0
var push_weight: float = 1.0
var max_hp: int = 100
var hp: int = 100
var _attack_data: Dictionary = {}
var _remaining_hits: int = 0
var _next_hit_at: float = 0.0
var _attack_ready_at: float = 0.0
var _base_attack_range: float = 0.0
var _base_attack_interval: float = 0.0
var _base_pickup_radius: float = 0.0
var _attack_cast_range: float = 0.0
var is_dead: bool = false
var _hp_label: Label
var _death_label: Label
var _hud_layer: CanvasLayer

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
    _base_attack_range = float(attack_data.get("Range",0.0))
    _base_attack_interval = float(attack_data.get("Interval_sec",0.0))
    _update_hp_label()

func configure_progression(level_records: Dictionary, radius: float) -> void:
    pickup_radius = radius
    _base_pickup_radius = radius
    level = 1
    experience = 0
    enhancement_points = 0
    _level_requirements.clear()
    var rows: Array = level_records.values()
    rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a["Level"]) < int(b["Level"]))
    for row in rows:
        _level_requirements.append(int(row["Xp_to_next"]))

func get_xp_to_next() -> int:
    if _level_requirements.is_empty():
        return 0
    return _level_requirements[mini(level,_level_requirements.size())-1]

func add_experience(amount: int) -> void:
    if amount <= 0 or is_dead or _level_requirements.is_empty():
        return
    experience += amount
    while experience >= get_xp_to_next():
        experience -= get_xp_to_next()
        level += 1
        enhancement_points += 1
        leveled_up.emit(level)

func apply_damage(amount: int) -> void:
    if is_dead or amount <= 0 or is_fear_casting():
        return
    hp = maxi(0, hp - amount)
    damaged.emit(global_position)
    _update_hp_label()
    if hp == 0:
        is_dead = true
        _death_label = Label.new()
        _death_label.text = "사망"
        _death_label.position = Vector2(570.0, 320.0)
        _death_label.add_theme_font_size_override("font_size", 48)
        _death_label.add_theme_color_override("font_color", Color("#ff7b83"))
        _hud_layer.add_child(_death_label)
        get_tree().paused = true

func update_basic_attack(now: float, enemies: Array) -> void:
    if is_dead or _attack_data.is_empty():
        return
    if is_stealthed():
        cancel_basic_attack()
        return
    while _remaining_hits > 0 and now + 0.000000001 >= _next_hit_at:
        var target: Variant = choose_target(enemies,_attack_cast_range)
        if target != null:
            _apply_basic_triangle(target,enemies)
        if _remaining_hits==1:
            _attack_ready_at = _next_hit_at + float(_attack_data["Hit_effect_sec"]) + float(_attack_data["Interval_sec"])
        _remaining_hits -= 1
        _next_hit_at += float(_attack_data["Hit_gap_sec"])
    if not is_frozen() and _remaining_hits == 0 and now + 0.000000001 >= _attack_ready_at:
        var first_target: Variant = choose_target(enemies)
        if first_target != null:
            _attack_cast_range = float(_attack_data["Range"])
            _apply_basic_triangle(first_target,enemies)
            _remaining_hits = int(_attack_data["Hits_per_attack"]) - 1
            _next_hit_at = now + float(_attack_data["Hit_gap_sec"])
            _attack_ready_at = now + _remaining_hits * float(_attack_data["Hit_gap_sec"]) + float(_attack_data["Hit_effect_sec"]) + float(_attack_data["Interval_sec"])

func choose_target(enemies: Array, range_override: float = -1.0) -> Variant:
    var chosen: Variant = null
    for candidate in enemies:
        if candidate == null or not candidate.is_active or candidate.is_logically_dead:
            continue
        if candidate.has_method("is_auto_targetable") and not candidate.is_auto_targetable():
            continue
        var distance := global_position.distance_to(candidate.global_position)
        if distance > (range_override if range_override>=0.0 else float(_attack_data["Range"])):
            continue
        if chosen == null:
            chosen = candidate
            continue
        if candidate.hp < chosen.hp or (candidate.hp == chosen.hp and distance < global_position.distance_to(chosen.global_position)) or (candidate.hp == chosen.hp and distance == global_position.distance_to(chosen.global_position) and candidate.spawn_order < chosen.spawn_order):
            chosen = candidate
    return chosen

func apply_choice_modifiers(range_add: float, interval_sub: float, pickup_add: float) -> void:
    _attack_data["Range"] = _base_attack_range + range_add
    _attack_data["Interval_sec"] = _base_attack_interval - interval_sub
    pickup_radius = _base_pickup_radius + pickup_add

func cancel_basic_attack() -> void:
    _remaining_hits = 0

func healed_hp(percent: float) -> int:
    return mini(max_hp,hp+floori(max_hp*percent/100.0))

func heal_percent(percent: float) -> void:
    if is_dead:
        return
    hp = healed_hp(percent)
    _update_hp_label()

func _apply_basic_triangle(target: Variant, enemies: Array) -> void:
    var facing: Vector2 = global_position.direction_to(target.global_position)
    if facing==Vector2.ZERO: facing = last_move_direction
    var base := global_position+facing*body_radius
    var struck: Array = []
    # Snapshot the target set before damage signals/knockback can alter it.
    for enemy in enemies:
        if is_instance_valid(enemy) and enemy.is_active and not enemy.is_logically_dead and not struck.has(enemy) and Geometry.in_triangle(enemy.global_position,base,facing,_attack_cast_range,_attack_cast_range*160.0/140.0):
            struck.append(enemy)
    for enemy in struck: _apply_basic_hit(enemy)

func _apply_basic_hit(enemy: Variant) -> void:
    enemy.apply_damage(int(_attack_data["Damage"]))
    enemy.start_knockback(global_position, float(_attack_data["Knockback_distance"]), float(_attack_data["Knockback_sec"]))
    var effect := Line2D.new()
    effect.top_level = true
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
    _hud_layer = CanvasLayer.new()
    add_child(_hud_layer)
    _hp_label = Label.new()
    _hp_label.position = Vector2(20.0, 46.0)
    _hp_label.add_theme_color_override("font_color", Color.WHITE)
    _hp_label.add_theme_font_size_override("font_size", 22)
    _hud_layer.add_child(_hp_label)
    _update_hp_label()

func _update_hp_label() -> void:
    if _hp_label != null:
        _hp_label.text = "플레이어 HP: %d / %d" % [hp, max_hp]

func movement_input() -> Vector2:
    return Vector2(
        Input.get_axis("move_left", "move_right"),
        Input.get_axis("move_up", "move_down")
    ).normalized()

func begin_dash(distance: float, duration: float) -> void:
    var input := movement_input()
    dash_direction = input if input != Vector2.ZERO else last_move_direction
    dash_remaining = duration
    dash_speed = distance / duration
    dash_pass_through = true
    trail_elapsed = 0.0

func _physics_process(delta: float) -> void:
    if is_dead:
        return
    stealth_remaining = maxf(0.0,stealth_remaining-delta)
    var frozen_time := minf(delta,freeze_remaining)
    freeze_remaining = maxf(0.0,freeze_remaining-delta)
    var locked_time := minf(delta,fear_cast_remaining)
    fear_cast_remaining = maxf(0.0,fear_cast_remaining-delta)
    var movement_delta := delta-maxf(locked_time,frozen_time)
    var direction := movement_input()
    dash_pass_through = dash_remaining > 0.0
    var travel := move_speed * movement_delta
    var dash_step := minf(delta,dash_remaining)
    var before := global_position
    if dash_pass_through:
        direction = dash_direction
        travel = dash_speed * minf(delta,dash_remaining)
        dash_remaining = maxf(0.0,dash_remaining-delta)
    elif direction != Vector2.ZERO and movement_delta>0.0:
        last_move_direction = direction
    # Resolve each axis independently so a blocked component does not cancel motion along the wall.
    move_and_collide(Vector2(direction.x * travel, 0.0))
    move_and_collide(Vector2(0.0, direction.y * travel))
    if dash_pass_through and visuals_enabled:
        var at := trail_elapsed
        while at<=dash_step+0.000000001:
            var copy := Afterimage.new()
            copy.configure({"kind":"player","radius":body_radius},float(presentation.Trail_life_sec),float(presentation.Trail_alpha))
            get_parent().add_child(copy)
            copy.global_position = before.lerp(global_position,clampf(at/maxf(dash_step,0.000000001),0,1))
            at+=float(presentation.Trail_interval_sec)
        trail_elapsed = at-dash_step
    _advance_boss_push(delta)

var boss_push_direction := Vector2.ZERO
var boss_push_distance: float = 0
var boss_push_duration: float = 0
var boss_push_elapsed: float = 0
var boss_push_bounds := Rect2()

func start_boss_push(source: Vector2, distance: float, duration: float, bounds: Rect2) -> void:
    if is_dead or distance<=0 or duration<=0: return
    boss_push_direction = source.direction_to(global_position)
    if boss_push_direction==Vector2.ZERO: boss_push_direction = Vector2.RIGHT
    boss_push_distance = distance
    boss_push_duration = duration
    boss_push_elapsed = 0
    boss_push_bounds = bounds

func _advance_boss_push(delta: float) -> void:
    if boss_push_duration<=0 or boss_push_elapsed>=boss_push_duration: return
    var end_time := minf(boss_push_duration,boss_push_elapsed+delta)
    var start_speed := 2.0*boss_push_distance/boss_push_duration
    var elapsed := end_time-boss_push_elapsed
    var displacement := start_speed*(elapsed-(end_time*end_time-boss_push_elapsed*boss_push_elapsed)/(2.0*boss_push_duration))
    var collision := move_and_collide(boss_push_direction*displacement)
    var bounded := Vector2(clampf(global_position.x,boss_push_bounds.position.x+body_radius,boss_push_bounds.end.x-body_radius),clampf(global_position.y,boss_push_bounds.position.y+body_radius,boss_push_bounds.end.y-body_radius))
    if collision!=null or bounded!=global_position:
        global_position = bounded
        boss_push_elapsed = boss_push_duration
    else: boss_push_elapsed = end_time

func _draw() -> void:
    draw_circle(Vector2.ZERO, body_radius, PLAYER_COLOR)
    draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 48, Color("#eee6ff"), 2.0)
