extends CharacterBody2D

const PLAYER_COLOR := Color("#b18cff")
const Geometry = preload("res://scripts/combat_geometry.gd")
const Afterimage = preload("res://scripts/shadow_afterimage.gd")
const SpriteBodyScript = preload("res://scripts/sprite_body.gd")
var presentation: Dictionary = Afterimage.compiled_presentation().duplicate()
var basic_windup_sec := maxf(float(presentation.get("Basic_windup_sec",0.04)),0.000001)
var basic_windup_px := float(presentation.get("Basic_windup_px",2))
var basic_hand := Vector2(float(presentation.get("Basic_hand_x",18)),float(presentation.get("Basic_hand_y",-40)))
var basic_push_pending := false
var visuals_enabled := true
var trail_elapsed := 0.0
var dash_land_remaining := 0.0
var dash_trails: Array = []
signal leveled_up(new_level: int)
signal damaged(world_position: Vector2)
signal died
signal death_presented
# JUICE-01: hp changed by damage or healing (low-hp warning listens).
signal hp_changed
var death_presentation: Node
var death_presentation_complete := false
var last_hit_direction := Vector2.RIGHT
var basic_pose_remaining := 0.0
var basic_pose_started := false
var basic_pose_direction := Vector2.RIGHT
var basic_visual_hit_index := 1
var basic_attack_thrust := false
var visual_hitstop_remaining := 0.0
var basic_fx_pool: Array = []
var current_basic_fx: Node2D
var basic_extra_targets := 0
var basic_impacts: Node2D
var basic_stars_this_hit := 0
var managed_results := false
var run_finished := false
var level: int = 1
var experience: int = 0
var enhancement_points: int = 0
var pickup_radius: float = 0.0
var _level_requirements: Array[int] = []
var _skill_point_every_levels: int = 1
var move_speed: float = 0.0
var last_move_direction := Vector2.RIGHT
var dash_direction := Vector2.RIGHT
var dash_remaining: float = 0.0
var dash_speed: float = 0.0
var dash_pass_through: bool = false
var stealth_remaining: float = 0.0
var fear_cast_remaining: float = 0.0
var freeze_remaining: float = 0.0
var sprite_body: Node2D
var skill_presentation: Node
var character_view: Node2D

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

func configure_visual(record: Dictionary) -> void:
    if sprite_body!=null:
        sprite_body.free()
    sprite_body = SpriteBodyScript.new()
    sprite_body.name = "SpriteBody"
    add_child(sprite_body)
    sprite_body.configure(record,body_radius,PLAYER_COLOR,Color("#eee6ff"))
    sprite_body.dust_every = 1
    if is_instance_valid(character_view): sprite_body.reparent(character_view,false)
    queue_redraw()

func _ready() -> void:
    character_view = preload("res://scripts/character_presentation.gd").attach(self)
    _create_hud()
    queue_redraw()

func configure_combat(health: int, attack_data: Dictionary) -> void:
    max_hp = health
    hp = health
    _attack_data = attack_data.duplicate(true)
    _base_attack_range = float(attack_data.get("Range",0.0))
    _base_attack_interval = float(attack_data.get("Interval_sec",0.0))
    _update_hp_label()

func configure_progression(level_records: Dictionary, radius: float, skill_point_every_levels: int) -> void:
    pickup_radius = radius
    _base_pickup_radius = radius
    _skill_point_every_levels = skill_point_every_levels
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
    if amount <= 0 or is_dead or run_finished or _level_requirements.is_empty():
        return
    preload("res://scripts/audio_events.gd").sfx(self,"xp_pickup")
    experience += amount
    while experience >= get_xp_to_next():
        experience -= get_xp_to_next()
        level += 1
        if level%_skill_point_every_levels==0:
            enhancement_points += 1
        leveled_up.emit(level)

func apply_damage(amount: int) -> void:
    if is_dead or run_finished or amount <= 0 or is_fear_casting():
        return
    hp = maxi(0, hp - amount)
    hp_changed.emit()
    preload("res://scripts/audio_events.gd").sfx(self,"player_hurt")
    damaged.emit(global_position)
    _update_hp_label()
    if hp == 0:
        is_dead = true
        get_tree().paused = true
        death_presentation = preload("res://scripts/player_death_presentation.gd").new()
        add_child(death_presentation)
        death_presentation.configure(self,presentation)
        died.emit()

func record_damage_source(source: Vector2) -> void:
    var direction := global_position.direction_to(source)
    last_hit_direction = direction if direction!=Vector2.ZERO else last_move_direction

func finish_death_presentation() -> void:
    if death_presentation_complete: return
    death_presentation_complete = true
    if not managed_results:
        _death_label = Label.new()
        _death_label.text = "사망"
        _death_label.position = Vector2(570.0,320.0)
        _death_label.add_theme_font_size_override("font_size",48)
        _death_label.add_theme_color_override("font_color",Color("#ff7b83"))
        _hud_layer.add_child(_death_label)
    death_presented.emit()

func update_basic_attack(now: float, enemies: Array) -> void:
    if is_dead or run_finished or _attack_data.is_empty():
        _update_basic_windup(now,[])
        return
    if is_stealthed():
        cancel_basic_attack()
        _update_basic_windup(now,[])
        return
    while not run_finished and _remaining_hits > 0 and now + 0.000000001 >= _next_hit_at:
        basic_visual_hit_index = int(_attack_data["Hits_per_attack"])-_remaining_hits+1
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
            basic_visual_hit_index = 1
            _attack_cast_range = float(_attack_data["Range"])
            _apply_basic_triangle(first_target,enemies)
            _remaining_hits = int(_attack_data["Hits_per_attack"]) - 1
            _next_hit_at = now + float(_attack_data["Hit_gap_sec"])
            _attack_ready_at = now + _remaining_hits * float(_attack_data["Hit_gap_sec"]) + float(_attack_data["Hit_effect_sec"]) + float(_attack_data["Interval_sec"])
    _update_basic_windup(now,enemies)

# Image-only anticipation before an already-scheduled strike; never moves timing.
func _update_basic_windup(now: float, enemies: Array) -> void:
    if sprite_body==null: return
    var offset := Vector2.ZERO
    if visuals_enabled and not run_finished and not is_dead and not is_stealthed() and not _attack_data.is_empty():
        var strike_at := _next_hit_at if _remaining_hits>0 else _attack_ready_at
        var lead := strike_at-now
        if lead>0.000000001 and lead<=basic_windup_sec and (_remaining_hits>0 or not is_frozen()):
            var direction := basic_pose_direction
            if _remaining_hits==0:
                var target: Variant = choose_target(enemies)
                direction = global_position.direction_to(target.global_position) if target!=null else Vector2.ZERO
            offset = -direction.normalized()*basic_windup_px*(1-lead/basic_windup_sec)
    if sprite_body.windup_offset!=offset:
        sprite_body.windup_offset = offset
        sprite_body.request_redraw()

func choose_target(enemies: Array, range_override: float = -1.0, exclude: Array = []) -> Variant:
    var chosen: Variant = null
    for candidate in enemies:
        if candidate == null or not candidate.is_active or candidate.is_logically_dead:
            continue
        if not exclude.is_empty() and exclude.has(candidate):
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

func apply_choice_modifiers(range_add: float, interval_sub: float, pickup_add: float, targets_add: int = 0) -> void:
    _attack_data["Range"] = _base_attack_range + range_add
    _attack_data["Interval_sec"] = _base_attack_interval - interval_sub
    pickup_radius = _base_pickup_radius + pickup_add
    basic_extra_targets = maxi(0,targets_add)

func cancel_basic_attack() -> void:
    _remaining_hits = 0

func healed_hp(percent: float) -> int:
    return mini(max_hp,hp+floori(max_hp*percent/100.0))

func heal_percent(percent: float) -> void:
    if is_dead:
        return
    hp = healed_hp(percent)
    hp_changed.emit()
    _update_hp_label()

func _apply_basic_triangle(target: Variant, enemies: Array) -> void:
    var facing: Vector2 = global_position.direction_to(target.global_position)
    if facing==Vector2.ZERO: facing = last_move_direction
    basic_attack_thrust = basic_visual_hit_index%2==0
    preload("res://scripts/audio_events.gd").sfx(self,"thrust" if basic_attack_thrust else "slash")
    basic_stars_this_hit = 0
    basic_pose_started = true
    basic_pose_remaining = float(presentation.get("Basic_pose_after_sec",0.08))
    basic_pose_direction = facing
    apply_basic_pose()
    var base := global_position+facing*body_radius
    var width := _attack_cast_range*float(_attack_data.get("Tri_width_ratio",0.381))
    if sprite_body!=null and sprite_body.windup_offset!=Vector2.ZERO:
        sprite_body.windup_offset = Vector2.ZERO
        sprite_body.request_redraw()
    basic_push_pending = visuals_enabled
    if visuals_enabled: current_basic_fx = _emit_basic_fx(base,facing,width,true)
    var struck: Array = []
    # Snapshot the target set before damage signals/knockback can alter it.
    for enemy in enemies:
        if is_instance_valid(enemy) and enemy.is_active and not enemy.is_logically_dead and not struck.has(enemy) and Geometry.in_triangle(enemy.global_position,base,facing,_attack_cast_range,width):
            struck.append(enemy)
    # BAL-02 extra targets: the same pick rule chooses further distinct targets; each gets the same
    # triangle and effect, and an enemy inside several triangles is still hit once per strike.
    if basic_extra_targets>0:
        var picked: Array = [target]
        for i in range(basic_extra_targets):
            var extra: Variant = choose_target(enemies,_attack_cast_range,picked)
            if extra==null: break
            picked.append(extra)
            var extra_facing: Vector2 = global_position.direction_to(extra.global_position)
            if extra_facing==Vector2.ZERO: extra_facing = last_move_direction
            var extra_base := global_position+extra_facing*body_radius
            if visuals_enabled: _emit_basic_fx(extra_base,extra_facing,width,false)
            for enemy in enemies:
                if is_instance_valid(enemy) and enemy.is_active and not enemy.is_logically_dead and not struck.has(enemy) and Geometry.in_triangle(enemy.global_position,extra_base,extra_facing,_attack_cast_range,width):
                    struck.append(enemy)
    for enemy in struck: _apply_basic_hit(enemy)

func _emit_basic_fx(base: Vector2, facing: Vector2, width: float, primary: bool) -> Node2D:
    var effect: Node2D = acquire_basic_fx()
    effect.thrust = basic_attack_thrust
    effect.top_level = true
    effect.polygon = Geometry.triangle_points(base,facing,_attack_cast_range,width)
    effect.color = Color.TRANSPARENT
    var foot := global_position+Vector2(0,sprite_body.foot_y if sprite_body!=null else 0.0)
    var mirrored: bool = facing.x<0 or (facing.x==0 and sprite_body!=null and sprite_body.flip_h)
    effect.base = foot+Vector2(basic_hand.x*(-1.0 if mirrored else 1.0),basic_hand.y)
    effect.facing = facing
    effect.length = _attack_cast_range
    effect.width = width
    effect.life = float(_attack_data["Hit_effect_sec"])
    effect.settings = presentation
    effect.debug_source = get_parent() if get_parent().has_method("set_debug_visible") else null
    var step_px := float(presentation.get("Basic_thrust_step_px",6)) if basic_attack_thrust and int(presentation.get("Basic_fx_enabled",1))!=0 else float(presentation.get("Basic_step_px",2))
    if primary and sprite_body!=null: sprite_body.trigger_basic_step(facing,step_px,float(presentation.get("Basic_step_sec",0.1)))
    effect.activate()
    return effect

func _apply_basic_hit(enemy: Variant) -> void:
    if enemy.has_method("record_damage_presentation"): enemy.record_damage_presentation("player",self)
    var landed: bool = enemy.apply_damage(int(_attack_data["Damage"]))
    enemy.start_knockback(global_position, float(_attack_data["Knockback_distance"]), float(_attack_data["Knockback_sec"]))
    if visuals_enabled and landed and not enemy.is_logically_dead and not enemy.has_method("configure_boss") and enemy.get("sprite_body")!=null:
        enemy.sprite_body.trigger_hit_squash()

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
    basic_pose_remaining = maxf(0,basic_pose_remaining-delta)
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
    if sprite_body!=null:
        var locked := is_frozen() or is_fear_casting()
        var moved := global_position.distance_squared_to(before)>0.000001
        var slash_active: bool = is_instance_valid(skill_presentation) and skill_presentation.skills.has("skill_rapid_slash") and skill_presentation.skills.skill_rapid_slash.active
        if visual_hitstop_remaining>0.000000001:
            visual_hitstop_remaining = maxf(0,visual_hitstop_remaining-delta)
            sprite_body.advance_frozen_walk_time(moved and not locked,delta)
        else:
            sprite_body.advance_player_skill_pose(Vector2.ZERO if locked else direction,moved and not locked,delta,fear_cast_remaining>0,dash_remaining>0,slash_active,dash_direction,presentation)
            apply_basic_pose()
            sprite_body.advance_locomotion(Vector2.ZERO if locked else direction,moved and not locked,delta,dash_pass_through)
            if dash_pass_through and dash_remaining<=0: dash_land_remaining = float(presentation.get("Dash_land_sec",0.08))
            elif not dash_pass_through: dash_land_remaining = maxf(0,dash_land_remaining-delta)
            if fear_cast_remaining<=0: sprite_body.apply_dash_stretch(dash_direction,dash_pass_through,dash_land_remaining,presentation)
    if dash_pass_through and visuals_enabled:
        var at := trail_elapsed
        while at<=dash_step+0.000000001:
            var copy := Afterimage.new()
            var snapshot := {"kind":"player","radius":body_radius}
            if sprite_body!=null: snapshot["sprite_pose"] = sprite_body.pose_snapshot()
            if snapshot.has("sprite_pose"): snapshot.sprite_pose.sprite_tint *= Color(presentation.get("Dash_trail_color","#8a6bff"))
            copy.configure(snapshot,float(presentation.Trail_life_sec),float(presentation.Trail_alpha))
            get_parent().add_child(copy)
            copy.global_position = before.lerp(global_position,clampf(at/maxf(dash_step,0.000000001),0,1))
            dash_trails.append(copy)
            at+=float(presentation.get("Dash_trail_interval_sec",0.02))
        trail_elapsed = at-dash_step
    update_dash_trail_alpha()
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

func draw_body(canvas: Node2D) -> void:
    if sprite_body==null:
        canvas.draw_circle(Vector2.ZERO, body_radius, PLAYER_COLOR)
        canvas.draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 48, Color("#eee6ff"), 2.0)

func apply_basic_pose() -> void:
    if sprite_body==null or sprite_body.layout!="pose" or is_dead: return
    if int(presentation.get("Basic_pose_enabled",1))==0 or not basic_pose_started: return
    if _remaining_hits<=0 and basic_pose_remaining<=0.000000001: return
    var slash: bool = is_instance_valid(skill_presentation) and skill_presentation.skills.has("skill_rapid_slash") and skill_presentation.skills.skill_rapid_slash.active
    if fear_cast_remaining>0 or dash_remaining>0 or slash: return
    sprite_body.frame_row = 0
    sprite_body.frame_column = clampi(int(presentation.get("Basic_thrust_col" if basic_attack_thrust else "Basic_slash_col",presentation.get("Basic_pose_col",3))),0,sprite_body.columns-1)
    if basic_pose_direction.x!=0: sprite_body.flip_h = basic_pose_direction.x<0
    sprite_body.queue_redraw()

func update_dash_trail_alpha() -> void:
    for i in range(dash_trails.size()-1,-1,-1):
        if not is_instance_valid(dash_trails[i]) or dash_trails[i].is_queued_for_deletion(): dash_trails.remove_at(i)
    for i in range(dash_trails.size()):
        var trail: Node2D = dash_trails[i]
        trail.opacity = float(presentation.Trail_alpha)*lerpf(float(presentation.get("Dash_trail_back_alpha_ratio",0.25)),1,float(i)/maxi(1,dash_trails.size()-1))
        trail.modulate.a = trail.opacity*maxf(0,1-trail.elapsed/trail.lifetime)

func acquire_basic_fx() -> Node2D:
    var enabled := int(presentation.get("Basic_fx_enabled",1))!=0
    if enabled and basic_fx_pool.is_empty():
        for i in range(int(presentation.get("Basic_fx_pool",8))):
            var item = preload("res://scripts/basic_slash_fx.gd").new()
            item.pooled = true
            item.top_level = true
            item.z_index = 40
            get_parent().add_child(item)
            tree_exiting.connect(item.queue_free)
            item.finish()
            var timer := Timer.new()
            timer.one_shot = true
            item.add_child(timer)
            item.life_timer = timer
            timer.timeout.connect(item.finish)
            basic_fx_pool.append(item)
        basic_impacts = preload("res://scripts/combat_impact_pool.gd").new()
        add_child(basic_impacts)
        basic_impacts.configure(presentation,int(presentation.get("Basic_impact_pool",32)),false)
    if enabled:
        for item in basic_fx_pool:
            if not item.active: return item
        var oldest: Node2D = basic_fx_pool[0]
        for item in basic_fx_pool:
            if item.age>oldest.age: oldest = item
        return oldest
    var item = preload("res://scripts/basic_slash_fx.gd").new()
    item.top_level = true
    get_parent().add_child(item)
    var timer := Timer.new()
    timer.one_shot = true
    item.add_child(timer)
    item.life_timer = timer
    timer.timeout.connect(item.finish)
    return item

func record_visual_hit(point: Vector2) -> void:
    if int(presentation.get("Basic_fx_enabled",1))==0: return
    if basic_push_pending and is_instance_valid(skill_presentation) and skill_presentation.screen_fx!=null:
        basic_push_pending = false
        skill_presentation.screen_fx.push(basic_pose_direction,float(presentation.get("Basic_push_px",1)),float(presentation.get("Basic_push_sec",0.05)))
    visual_hitstop_remaining = float(presentation.get("Basic_hitstop_sec",0.03))
    if is_instance_valid(basic_impacts) and basic_stars_this_hit<int(presentation.get("Basic_star_max",3)):
        basic_stars_this_hit+=1
        basic_impacts.spawn("star",point,float(presentation.get("Basic_star_px",18)),float(presentation.get("Basic_star_sec",0.12)))
