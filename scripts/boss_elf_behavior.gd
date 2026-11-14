extends RefCounted

const Projectile = preload("res://scripts/projectile.gd")
const BODY_COLOR := Color("#8fd8df")
const BOW_COLOR := Color("#d3a6ff")
const PUSH_COLOR := Color(0.7,0.8,1,0.6)
const PUSH_FX_SEC := 0.25
const PREP_BOW_SCALE := 1.6
var boss: Node2D
var rows: Dictionary = {}
var detect_range: float
var hidden := false
var hidden_until: float = 0
var burst := false
var burst_first: float = 0
var burst_end: float = 0
var shot_index := 0
var recovery_until: float = 0
var push_effect_until: float = 0
var push_effect_center := Vector2.ZERO
var shots_fired := 0
var last_branch := ""
var fleeing := false
var flee_direction := Vector2.ZERO
var flee_travelled := 0.0
var flee_reselections := 0

func configure(actor: Node2D) -> void:
	boss = actor
	for row in boss.actions: rows[int(row.Kind)] = row
	detect_range = float(boss.manager.boss_director.bosses[rows[3].Boss_id].Detect_range)

func now() -> float:
	return boss.manager._elapsed_seconds

func ready(kind: int) -> bool:
	return now()+0.000000001>=float(boss.ready_at[rows[kind].Id])

func tick(delta: float) -> void:
	if hidden and now()>=hidden_until: end_stealth(hidden_until)
	var locked: float = minf(delta,boss.fear_remaining)
	boss.fear_remaining = maxf(0,boss.fear_remaining-delta)
	if locked>0 or boss.is_feared():
		fleeing = false
		interrupt_burst()
		last_branch = "fear"
		boss.queue_redraw()
		return
	var target: Node2D = boss.target_provider.call()
	if not is_instance_valid(target): return
	if target.is_stealthed():
		fleeing = false
		interrupt_burst()
		last_branch = "wander"
		if not boss.has_wander_target or boss.global_position.distance_to(boss.wander_target)<=0.000001:
			boss.wander_target = boss.clamp_position_to_map(boss.global_position+Vector2.RIGHT.rotated(boss.rng.randf()*TAU)*sqrt(boss.rng.randf())*boss.manager.wander_radius,boss.map_bounds)
			boss.has_wander_target = true
		boss.move_boss(boss.wander_target,delta,true)
		boss.queue_redraw()
		return
	boss.has_wander_target = false
	if fleeing:
		last_branch = "flee"
		advance_flee(delta)
	elif burst:
		last_branch = "burst"
		advance_burst(target)
	elif now()<recovery_until:
		last_branch = "recovery"
	else:
		var distance: float = boss.global_position.distance_to(target.global_position)
		if distance>detect_range:
			if not hidden and ready(6):
				last_branch = "stealth"
				start_stealth()
			else:
				last_branch = "follow"
				boss.move_boss(target.global_position,delta)
		elif ready(4) and distance<=float(rows[4].Use_range):
			last_branch = "push"
			target.start_boss_push(boss.global_position,float(rows[4].Push_distance),float(rows[4].Push_sec),boss.map_bounds)
			boss.ready_at[rows[4].Id] = now()+float(rows[4].Cooldown_sec)
			push_effect_center = boss.global_position
			push_effect_until = now()+PUSH_FX_SEC
		elif not hidden and ready(6):
			last_branch = "stealth"
			start_stealth()
		elif ready(5) and distance<=float(rows[5].Use_range):
			last_branch = "burst_start"
			burst = true
			burst_first = now()+float(rows[5].Telegraph_sec)
			burst_end = burst_first+float(rows[5].Duration_sec)
			shot_index = 0
		elif distance<=float(rows[3].Use_range):
			last_branch = "basic"
			if ready(3):
				fire(rows[3],target)
				boss.ready_at[rows[3].Id] = now()+float(rows[3].Shot_interval_sec)
				if distance<=float(rows[3].Flee_trigger_range):
					flee_travelled = 0.0
					flee_reselections = 0
					flee_direction = choose_flee_direction(target.global_position)
					fleeing = flee_direction!=Vector2.ZERO
		else:
			last_branch = "follow"
			boss.move_boss(target.global_position,delta)
	boss.queue_redraw()

func advance_flee(delta: float) -> void:
	var previous: Vector2 = boss.global_position
	var distance := minf(float(rows[3].Flee_distance)-flee_travelled,float(rows[3].Flee_speed)*delta)
	# Stop at the first wall along the committed ray, without diagonal sliding.
	var bounds: Rect2 = boss.map_bounds.grow(-boss.body_radius)
	var allowed := distance
	if flee_direction.x>0: allowed = minf(allowed,(bounds.end.x-previous.x)/flee_direction.x)
	elif flee_direction.x<0: allowed = minf(allowed,(bounds.position.x-previous.x)/flee_direction.x)
	if flee_direction.y>0: allowed = minf(allowed,(bounds.end.y-previous.y)/flee_direction.y)
	elif flee_direction.y<0: allowed = minf(allowed,(bounds.position.y-previous.y)/flee_direction.y)
	boss.global_position = previous+flee_direction*maxf(0,allowed)
	var moved := previous.distance_to(boss.global_position)
	flee_travelled+=moved
	if flee_travelled+0.000001>=float(rows[3].Flee_distance):
		fleeing = false
	elif allowed<distance-0.000001:
		if flee_reselections>=1:
			fleeing = false
		else:
			flee_reselections+=1
			flee_direction = choose_flee_direction(boss.target_provider.call().global_position)
			fleeing = flee_direction!=Vector2.ZERO

func choose_flee_direction(player_position: Vector2) -> Vector2:
	var start: Vector2 = boss.global_position
	var bounds: Rect2 = boss.map_bounds.grow(-boss.body_radius)
	var distance := float(rows[3].Flee_distance)
	var away := player_position.direction_to(start)
	if away==Vector2.ZERO: away = Vector2.RIGHT
	var end := start+away*distance
	var parallel := away
	if end.x<bounds.position.x or end.x>bounds.end.x: parallel.x = 0
	if end.y<bounds.position.y or end.y>bounds.end.y: parallel.y = 0
	var candidates: Array[Vector2] = []
	if parallel==away: candidates.append(away)
	if parallel!=Vector2.ZERO:
		candidates.append(parallel.normalized())
	else:
		# When no parallel component remains, prefer the most open wall direction.
		var directions: Array[Vector2] = []
		if away.x!=0: directions.assign([Vector2.UP,Vector2.DOWN])
		else: directions.assign([Vector2.LEFT,Vector2.RIGHT])
		if away.x!=0 and away.y!=0: directions = [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]
		directions.sort_custom(func(a: Vector2,b: Vector2) -> bool: return wall_room(start,a,bounds)>wall_room(start,b,bounds))
		candidates.append_array(directions)
	for direction in candidates:
		end = start+direction*distance
		var bounded: Vector2 = boss.clamp_position_to_map(end,boss.map_bounds)
		if bounded.is_equal_approx(end) and end.distance_squared_to(player_position)>start.distance_squared_to(player_position)+0.000001:
			return direction
	return Vector2.ZERO

func wall_room(start: Vector2, direction: Vector2, bounds: Rect2) -> float:
	if direction==Vector2.UP: return start.y-bounds.position.y
	if direction==Vector2.DOWN: return bounds.end.y-start.y
	if direction==Vector2.LEFT: return start.x-bounds.position.x
	return bounds.end.x-start.x

func fire(row: Dictionary, target: Node2D) -> void:
	var arrow := Projectile.new()
	boss.manager.add_child(arrow)
	arrow.configure(boss.manager._projectile_records[row.Projectile_id],boss.global_position,target.global_position,boss.map_bounds,target)
	boss.manager._projectiles.append(arrow)
	shots_fired+=1

func advance_burst(target: Node2D) -> void:
	while burst:
		var at := burst_first+shot_index*float(rows[5].Shot_interval_sec)
		if at>burst_end+0.000000001 or at>now()+0.000000001: break
		fire(rows[5],target)
		shot_index+=1
	if now()+0.000000001>=burst_end: finish_burst(burst_end)

func finish_burst(at: float) -> void:
	burst = false
	recovery_until = at+float(rows[5].Recovery_sec)
	boss.ready_at[rows[5].Id] = recovery_until+float(rows[5].Cooldown_sec)

func interrupt_burst() -> void:
	if not burst: return
	burst = false
	recovery_until = now()
	boss.ready_at[rows[5].Id] = now()+float(rows[5].Cooldown_sec)

func start_stealth() -> void:
	hidden = true
	hidden_until = now()+float(rows[6].Duration_sec)
	for shadow in boss.manager._shadow_bodies:
		if shadow.target==boss: shadow.target = null
	boss.queue_redraw()

func end_stealth(at: float) -> void:
	hidden = false
	boss.ready_at[rows[6].Id] = at+float(rows[6].Cooldown_sec)
	boss.queue_redraw()

func cleanup() -> void:
	fleeing = false
	burst = false
	hidden = false
	hidden_until = 0
	push_effect_until = 0

func draw() -> void:
	if now()<push_effect_until:
		boss.draw_arc(boss.to_local(push_effect_center),float(rows[4].Use_range),0,TAU,48,PUSH_COLOR,2)
	if hidden: return
	boss.draw_circle(Vector2.ZERO,boss.body_radius,BODY_COLOR)
	var bow_scale := PREP_BOW_SCALE if burst and now()<burst_first else 1.3
	boss.draw_arc(Vector2.ZERO,boss.body_radius*bow_scale,-PI/2,PI/2,24,BOW_COLOR,2)
	boss.draw_line(Vector2(-boss.body_radius,-boss.body_radius-8),Vector2(-boss.body_radius+boss.body_radius*2*float(boss.hp)/maxi(boss.max_hp,1),-boss.body_radius-8),Color("#ff6d6d"),4)
