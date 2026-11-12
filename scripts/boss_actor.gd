extends "res://scripts/enemy.gd"

const Geometry = preload("res://scripts/combat_geometry.gd")
var manager: EnemyManager
var target_provider: Callable
var actions: Array = []
var ready_at: Dictionary = {}
var planned: Dictionary = {}
var current: Dictionary = {}
var clock: float = 0
var phase := "idle"
var phase_end: float = 0
var recover_until: float = 0
var facing := Vector2.RIGHT
var origin := Vector2.ZERO
var dash_end := Vector2.ZERO
var dash_length: float = 0
var dash_started: float = 0
var dash_hit := false
var rng := RandomNumberGenerator.new()

func configure_boss(owner_manager: EnemyManager, rows: Array, provider: Callable) -> void:
	manager = owner_manager
	actions = rows.duplicate(true)
	target_provider = provider
	clock = manager._elapsed_seconds
	rng.randomize()
	for row in actions: ready_at[row.Id] = clock

func start_knockback(_source: Vector2, _distance: float, _duration: float) -> void:
	pass

func apply_fear(duration: float) -> void:
	if not is_active or is_logically_dead: return
	clock = manager._elapsed_seconds
	if not current.is_empty(): finish_action(clock)
	super.apply_fear(duration)

func is_boss_dashing() -> bool:
	return phase=="dash" and not current.is_empty()

func boss_tick(delta: float) -> void:
	if not is_active or is_logically_dead: return
	clock = manager._elapsed_seconds
	var locked := minf(delta,fear_remaining)
	fear_remaining = maxf(0,fear_remaining-delta)
	if locked>0 or is_feared():
		queue_redraw()
		return
	if not current.is_empty():
		advance_action()
		queue_redraw()
		return
	if clock<recover_until: return
	var target: Node2D = target_provider.call()
	if not is_instance_valid(target): return
	if target.is_stealthed():
		if not has_wander_target or global_position.distance_to(wander_target)<=0.000001:
			wander_target = clamp_position_to_map(global_position+Vector2.RIGHT.rotated(rng.randf()*TAU)*sqrt(rng.randf())*manager.wander_radius,map_bounds)
			has_wander_target = true
		move_boss(wander_target,delta,true)
		return
	has_wander_target = false
	if planned.is_empty():
		var available: Array = []
		var total := 0
		for row in actions:
			if int(row.Kind)!=0 and clock>=float(ready_at[row.Id]):
				available.append(row)
				total+=int(row.Pick_weight)
		if total>0:
			var pick := rng.randi_range(1,total)
			for row in available:
				pick-=int(row.Pick_weight)
				if pick<=0:
					planned = row
					break
	var distance := global_position.distance_to(target.global_position)
	if not planned.is_empty() and distance<=float(planned.Use_range):
		start_action(planned,target.global_position)
		planned = {}
		return
	for row in actions:
		if int(row.Kind)==0 and distance<=float(row.Use_range) and clock>=float(ready_at[row.Id]):
			start_action(row,target.global_position)
			return
	move_boss(target.global_position,delta)

func move_boss(point: Vector2, delta: float, stop: bool = false) -> void:
	var distance := global_position.distance_to(point)
	var step := move_speed*delta
	if stop: step = minf(step,distance)
	global_position = clamp_position_to_map(global_position+global_position.direction_to(point)*step,map_bounds)
	queue_redraw()

func start_action(row: Dictionary, target_position: Vector2) -> void:
	current = row.duplicate(true)
	phase = "telegraph"
	phase_end = clock+float(row.Telegraph_sec)
	origin = global_position
	facing = global_position.direction_to(target_position)
	if facing==Vector2.ZERO: facing = Vector2.RIGHT
	dash_hit = false
	if int(row.Kind)==1:
		dash_length = float(row.Dash_distance)
		var bounds := map_bounds.grow(-body_radius)
		if facing.x>0: dash_length = minf(dash_length,(bounds.end.x-origin.x)/facing.x)
		elif facing.x<0: dash_length = minf(dash_length,(bounds.position.x-origin.x)/facing.x)
		if facing.y>0: dash_length = minf(dash_length,(bounds.end.y-origin.y)/facing.y)
		elif facing.y<0: dash_length = minf(dash_length,(bounds.position.y-origin.y)/facing.y)
		dash_length = maxf(0,dash_length)
		dash_end = origin+facing*dash_length
	queue_redraw()

func advance_action() -> void:
	var target: Node2D = target_provider.call()
	if phase=="telegraph" and clock>=phase_end:
		if int(current.Kind)==1:
			phase = "dash"
			dash_started = phase_end
			collision_layer = 0
		else:
			var hit := Geometry.in_sector(origin,facing,float(current.Range),float(current.Arc_deg),target.global_position) if int(current.Kind)==0 else origin.distance_to(target.global_position)<=float(current.Slam_radius)
			if hit: target.apply_damage(int(current.Damage))
			finish_action(phase_end)
			return
	if phase=="dash":
		var previous := global_position
		var travelled := minf(dash_length,maxf(0,clock-dash_started)*float(current.Dash_speed))
		global_position = origin+facing*travelled
		# Telegraph and damage both use the clipped body-width corridor.
		if not dash_hit and Geometry.in_corridor(target.global_position,previous,global_position,facing,body_radius):
			dash_hit = true
			target.apply_damage(int(current.Damage))
		if travelled>=dash_length: finish_action(dash_started+dash_length/float(current.Dash_speed))

func finish_action(at: float) -> void:
	if current.is_empty(): return
	ready_at[current.Id] = at+float(current.Cooldown_sec)
	recover_until = at+float(current.Recovery_sec)
	current = {}
	phase = "idle"
	collision_layer = 2 if is_active else 0
	queue_redraw()

func telegraph_geometry() -> Dictionary:
	if current.is_empty(): return {}
	return {"kind":int(current.Kind),"center":origin,"direction":facing,"end":dash_end,"body_radius":body_radius,"range":current.Range,"arc_deg":current.Arc_deg,"slam_radius":current.Slam_radius}

func _draw() -> void:
	draw_circle(Vector2.ZERO,body_radius,Color("#c5edff"))
	draw_arc(Vector2.ZERO,body_radius,0,TAU,48,Color.WHITE,2)
	# Reuse the existing enemy hp/max_hp state; temporary compact health bar.
	draw_line(Vector2(-body_radius,-body_radius-8),Vector2(-body_radius+body_radius*2*float(hp)/maxi(max_hp,1),-body_radius-8),Color("#ff6d6d"),4)
	if current.is_empty(): return
	var color := Color(0.3,0.7,1,0.3)
	var center := to_local(origin)
	if int(current.Kind)==1:
		var side := facing.orthogonal()*body_radius
		var end := to_local(dash_end)
		draw_colored_polygon(PackedVector2Array([center+side,end+side,end-side,center-side]),color)
	elif int(current.Kind)==2:
		draw_circle(center,float(current.Slam_radius),color)
		var progress := clampf(1-(phase_end-clock)/float(current.Telegraph_sec),0,1)
		draw_circle(center,float(current.Slam_radius)*progress,Color(0.3,0.7,1,0.4))
	else:
		var polygon := PackedVector2Array([center])
		for i in range(33):
			var angle := facing.angle()-deg_to_rad(float(current.Arc_deg))*0.5+deg_to_rad(float(current.Arc_deg))*i/32
			polygon.append(center+Vector2.RIGHT.rotated(angle)*float(current.Range))
		draw_colored_polygon(polygon,color)
