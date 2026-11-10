extends Node2D

const Visual = preload("res://scripts/shadow_visual.gd")
const Data = preload("res://scripts/shadow_data.gd")
# User-approved table-policy exception; proposed start value, not final balance.
const SHADOW_SPACING := 16.0
# User-requested proposed arrival tolerance, not a steering/push distance.
const DASH_ARRIVAL_DISTANCE := 8.0
var manager: Node2D
var config: Dictionary
var attack: Dictionary
var motions: Array = []
var body_radius: float
var push_weight: float
var enemy_push_share: float
var target: EnemyActor
var target_spawn_order: int = -1
var last_node: String = "follow"
var facing := Vector2.RIGHT
var clock: float = 0.0
var ready_at: float = 0.0
var cast_started_at: float = 0.0
var cast_active: bool = false
var hit_done: bool = false
var motion_index: int = -1
var motion_picker: Callable
var angle_picker: Callable
var random := RandomNumberGenerator.new()
var dash_goal := Vector2.ZERO
var dash_updated_at: float = 0.0
var dash_hit_at: float = 0.0

func configure(owner_manager: Node2D, record: Dictionary, attack_record: Dictionary, motion_records: Array) -> void:
	manager = owner_manager
	config = record.duplicate(true)
	attack = attack_record.duplicate(true)
	motions = motion_records.duplicate(true)
	body_radius = float(config.Body_radius)
	push_weight = float(config.Push_weight)
	enemy_push_share = float(config.Enemy_push_share)
	random.randomize()

func apply_damage(_amount: int) -> bool:
	return false

func nearest(enemies: Array, radius: float, screen_only: bool = false, excluded: Array = [], region_mode: int = -1) -> EnemyActor:
	var best: EnemyActor = null
	var best_distance := INF
	var screen: Rect2 = manager.enemies._get_screen_world_rect()
	for candidate: EnemyActor in enemies:
		if not candidate.is_active or candidate.is_logically_dead: continue
		if excluded.has(candidate): continue
		if not manager.region_matches(self,candidate.global_position,region_mode): continue
		if screen_only and not screen.has_point(candidate.global_position): continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance>radius*radius: continue
		if best==null or distance<best_distance or (distance==best_distance and candidate.spawn_order<best.spawn_order):
			best = candidate
			best_distance = distance
	return best

func target_is_live() -> bool:
	return is_instance_valid(target) and target.is_active and not target.is_logically_dead and target.spawn_order==target_spawn_order

func can_retain_target() -> bool:
	if not target_is_live(): return false
	return global_position.distance_to(target.global_position)<=float(config.Search_radius) or manager.enemies._get_screen_world_rect().has_point(target.global_position)

func choose_target(living: Array) -> void:
	var excluded: Array = manager.claimed_targets(self)
	target = choose_in_stage(living,float(config.Search_radius),false,excluded)
	if target==null: target = choose_in_stage(living,INF,true,excluded)
	target_spawn_order = target.spawn_order if target!=null else -1

func choose_in_stage(living: Array, radius: float, screen_only: bool, excluded: Array) -> EnemyActor:
	var selected: EnemyActor = null
	if manager.actors.size()>1:
		selected = nearest(living,radius,screen_only,excluded,0)
		if selected==null: selected = nearest(living,radius,screen_only,excluded,1)
	else:
		selected = nearest(living,radius,screen_only,excluded)
	return selected if selected!=null else nearest(living,radius,screen_only)

func tick(delta: float) -> void:
	clock += delta
	var player: Node2D = manager.player
	if global_position.distance_to(player.global_position)>=float(config.Teleport_distance):
		teleport()
	var living: Array = manager.enemies.get_living_enemies()
	if global_position.distance_to(player.global_position)>float(config.Chase_leash_distance):
		cancel_attack()
		target = null
		last_node = "follow"
		follow_return(delta)
	else:
		if not can_retain_target(): target = null
		if cast_active:
			advance_attack(living)
		else:
			if target==null: choose_target(living)
			act_on_target(player,delta)
	global_position = manager.enemies._clamp_body_to_map(global_position,body_radius)
	queue_redraw()

func act_on_target(player: Node2D, delta: float) -> void:
	if target!=null:
		if global_position.distance_to(target.global_position)<=float(config.Search_radius):
			last_node = "attack"
			move_to_distance(target.global_position,float(attack.Range),delta)
			if is_circle_dash():
				var distance := global_position.distance_to(target.global_position)
				# Vector2 float rounding can leave an exact Range stop a few
				# millionths outside. Keep the existing fan predicate unchanged.
				if (distance<=float(attack.Range) or is_equal_approx(distance,float(attack.Range))) and clock+0.000000001>=ready_at:
					start_attack()
			elif global_position.distance_to(target.global_position)<=float(attack.Range)+0.00001 and clock+0.000000001>=ready_at:
				start_attack()
		else:
			last_node = "screen"
			move_to_distance(target.global_position,0.0,delta)
	else:
		last_node = "follow"
		follow_return(delta)

func follow_return(delta: float) -> void:
	var center: Vector2 = manager.player.global_position
	var distance := float(config.Follow_distance)
	if manager.actors.size()<=1 or global_position.distance_to(center)<=distance:
		move_to_distance(center,distance,delta)
		return
	var before := global_position
	move_to_distance(manager.follow_slot(self,distance),0.0,delta)
	# Stop at the first intersection with the original Follow distance circle,
	# rather than crossing it to reach the assigned slot exactly.
	var motion := global_position-before
	var offset := before-center
	var a := motion.length_squared()
	if a<=0.0: return
	var b := 2.0*offset.dot(motion)
	var c := offset.length_squared()-distance*distance
	var discriminant := b*b-4.0*a*c
	if discriminant<0.0: return
	var fraction := (-b-sqrt(discriminant))/(2.0*a)
	if fraction>=0.0 and fraction<=1.0: global_position = before+motion*fraction

func move_to_distance(point: Vector2, stop_distance: float, delta: float) -> void:
	var distance := global_position.distance_to(point)
	var maximum_step := float(config.Move_speed)*delta
	if maximum_step<=0.0: return
	var base_motion := Vector2.ZERO
	if distance>stop_distance:
		facing = global_position.direction_to(point)
		base_motion = facing*minf(maximum_step,distance-stop_distance)
	var correction := separation_velocity()*maximum_step
	if correction==Vector2.ZERO:
		if base_motion!=Vector2.ZERO: global_position += base_motion
		return
	var motion := (base_motion+correction).limit_length(maximum_step)
	var next_position := global_position+motion
	# Preserve arrival membership. Steering must not undo Range/Follow arrival.
	if stop_distance>0.0 and distance<=stop_distance+maximum_step and next_position.distance_to(point)>stop_distance:
		next_position = point+point.direction_to(next_position)*stop_distance
		if next_position.distance_to(global_position)>maximum_step+0.000001:
			next_position = global_position+base_motion
	global_position = next_position

func separation_velocity() -> Vector2:
	if cast_active: return Vector2.ZERO
	var result := Vector2.ZERO
	var origin: Vector2 = manager.steering_position(self)
	for other in manager.actors:
		if other==self: continue
		var offset: Vector2 = origin-manager.steering_position(other)
		var distance := offset.length()
		var gap: float = distance-body_radius-float(other.body_radius)
		if gap>=SHADOW_SPACING: continue
		var direction := offset/distance if distance>0.000001 else (Vector2.LEFT if get_instance_id()<other.get_instance_id() else Vector2.RIGHT)
		result += direction*clampf((SHADOW_SPACING-gap)/SHADOW_SPACING,0.0,1.0)
	return result.limit_length(1.0)

func start_attack() -> void:
	cast_active = true
	hit_done = false
	cast_started_at = clock
	facing = global_position.direction_to(target.global_position)
	if facing==Vector2.ZERO: facing = Vector2.RIGHT
	motion_index = int(motion_picker.call(motions.size())) if motion_picker.is_valid() else random.randi_range(0,motions.size()-1)
	if is_circle_dash():
		dash_goal = target.global_position
		dash_updated_at = clock
	advance_attack(manager.enemies.get_living_enemies())

func is_circle_dash() -> bool:
	return int(attack.Shape)==Data.Shape.CIRCLE_DASH

func advance_attack(living: Array) -> void:
	if is_circle_dash():
		advance_dash(living)
		return
	advance_fan_attack(living)

func advance_fan_attack(living: Array) -> void:
	var motion: Dictionary = motions[motion_index]
	var age := clock-cast_started_at
	if not hit_done and target_is_live():
		var direction := global_position.direction_to(target.global_position)
		if direction!=Vector2.ZERO: facing = direction
	if not hit_done and age+0.000000001>=float(motion.Hit_time_sec):
		hit_done = true
		var geometry := attack_geometry()
		for enemy: EnemyActor in living:
			if in_sector(enemy,geometry): enemy.apply_damage(int(attack.Damage))
	if age+0.000000001>=float(motion.Motion_sec):
		cast_active = false
		ready_at = cast_started_at+float(motion.Motion_sec)+float(attack.Interval_sec)

func advance_dash(living: Array) -> void:
	if not hit_done:
		var remaining := float(attack.Dash_max_sec)-(dash_updated_at-cast_started_at)
		var delta := minf(maxf(clock-dash_updated_at,0.0),maxf(remaining,0.0))
		dash_updated_at = clock
		var distance := global_position.distance_to(dash_goal)
		if distance>DASH_ARRIVAL_DISTANCE:
			facing = global_position.direction_to(dash_goal)
			global_position += facing*minf(float(attack.Dash_speed)*delta,distance)
		global_position = manager.enemies._clamp_body_to_map(global_position,body_radius)
		if global_position.distance_to(dash_goal)<=DASH_ARRIVAL_DISTANCE or clock-cast_started_at+0.000000001>=float(attack.Dash_max_sec):
			hit_done = true
			dash_hit_at = clock
			var geometry := circle_geometry()
			for enemy: EnemyActor in living:
				if in_circle(enemy,geometry): enemy.apply_damage(int(attack.Damage))
	if hit_done and clock-dash_hit_at+0.000000001>=float(motions[motion_index].Motion_sec):
		cast_active = false
		ready_at = dash_hit_at+float(motions[motion_index].Motion_sec)+float(attack.Interval_sec)

func circle_geometry() -> Dictionary:
	return {"center":global_position,"radius":float(attack.Circle_radius)}

func circle_visual_state() -> Dictionary:
	if not cast_active: return {}
	var state := circle_geometry()
	state.hit_age = clock-dash_hit_at if hit_done else -1.0
	return state

func in_circle(enemy: EnemyActor, geometry: Dictionary = {}) -> bool:
	if not enemy.is_active or enemy.is_logically_dead: return false
	if geometry.is_empty(): geometry = circle_geometry()
	return enemy.global_position.distance_squared_to(Vector2(geometry.center))<=float(geometry.radius)*float(geometry.radius)

func attack_geometry() -> Dictionary:
	return {"center":global_position,"direction":facing,"range":float(attack.Range),"arc_deg":float(attack.Arc_deg)}

func attack_visual_state() -> Dictionary:
	if not cast_active: return {}
	var state := attack_geometry()
	state.hit_age = clock-cast_started_at-float(motions[motion_index].Hit_time_sec) if hit_done else -1.0
	return state

func in_sector(enemy: EnemyActor, geometry: Dictionary = {}) -> bool:
	if not enemy.is_active or enemy.is_logically_dead: return false
	if geometry.is_empty(): geometry = attack_geometry()
	var offset: Vector2 = enemy.global_position-Vector2(geometry.center)
	if offset.length_squared()>float(geometry.range)*float(geometry.range): return false
	if offset==Vector2.ZERO: return true
	return absf(wrapf(offset.angle()-Vector2(geometry.direction).angle(),-PI,PI))<=deg_to_rad(float(geometry.arc_deg))*0.5+0.000000001

func cancel_attack() -> void:
	cast_active = false
	hit_done = false
	ready_at = clock

func teleport() -> void:
	var departure := global_position
	manager.leave_afterimage(departure,snapshot(),float(config.Afterimage_sec))
	var angle := float(angle_picker.call()) if angle_picker.is_valid() else random.randf_range(0,TAU)
	global_position = manager.enemies._clamp_body_to_map(manager.player.global_position+Vector2.RIGHT.rotated(angle)*float(config.Follow_distance),body_radius)
	target = null
	cancel_attack()
	last_node = "teleport"
	queue_redraw()

func snapshot() -> Dictionary:
	if is_circle_dash():
		var recovery_phase := clampf((clock-dash_hit_at)/float(motions[motion_index].Motion_sec),0,1) if cast_active and hit_done else 0.0
		return {"radius":body_radius,"facing":facing,"motion":-1,"phase":recovery_phase,"kind":"charger_test"}
	var phase := 0.0
	if cast_active: phase = clampf((clock-cast_started_at)/float(motions[motion_index].Motion_sec),0,1)
	return {"radius":body_radius,"facing":facing,"motion":motion_index if cast_active else -1,"phase":phase}

func _draw() -> void:
	if is_circle_dash():
		var circle := circle_visual_state()
		if not circle.is_empty(): Visual.draw_circle_attack(self,circle)
		Visual.draw_charger_pose(self,body_radius,facing)
		return
	var sector := attack_visual_state()
	if not sector.is_empty(): Visual.draw_sector(self,sector)
	var pose := snapshot()
	Visual.draw_pose(self,body_radius,facing,int(pose.motion),float(pose.phase))
