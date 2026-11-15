extends Node2D

const Visual = preload("res://scripts/shadow_visual.gd")
const Data = preload("res://scripts/shadow_data.gd")
const SpriteBodyScript = preload("res://scripts/sprite_body.gd")
# User-approved table-policy exception; proposed start value, not final balance.
const SHADOW_SPACING := 16.0
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
var fan_aim_updated_at: float = 0.0
var motion_picker: Callable
var angle_picker: Callable
var random := RandomNumberGenerator.new()
var diagnostic_sink: Callable
var dash_goal := Vector2.ZERO
var dash_updated_at: float = 0.0
var dash_hit_at: float = 0.0
var dash_origin := Vector2.ZERO
var dash_direction := Vector2.RIGHT
var dash_length: float = 0.0
var dash_travelled: float = 0.0
var dash_end_reason: String = "distance"
var dash_hits: Dictionary = {}
var dash_through_active: bool = false
var sprite_body: Node2D
var character_view: Node2D
var sprite_hit_at := -INF
var dash_trail_cast_at := -INF
var dash_trail_next_age := 0.0
var sweep_forward := true
var sweep_sign := 1.0
var sweep_previous_angle := 0.0
var sweep_current_angle := 0.0
var sweep_hits: Dictionary = {}
var sweep_trail: Array = []
var sweep_particles: Array = []
var presentation: Dictionary = preload("res://scripts/shadow_afterimage.gd").presentation()

func _ready() -> void:
	character_view = preload("res://scripts/character_presentation.gd").attach(self)

func configure(owner_manager: Node2D, record: Dictionary, attack_record: Dictionary, motion_records: Array) -> void:
	manager = owner_manager
	config = record.duplicate(true)
	attack = attack_record.duplicate(true)
	motions = motion_records.duplicate(true)
	body_radius = float(config.Body_radius)
	push_weight = float(config.Push_weight)
	enemy_push_share = float(config.Enemy_push_share)
	if config.get("Sprite_path")!=null and not String(config.Sprite_path).is_empty():
		sprite_body = SpriteBodyScript.new()
		sprite_body.name = "SpriteBody"
		add_child(sprite_body)
		sprite_body.configure(config,body_radius,Color("#151025"),Color("#9771dc"))
		if is_instance_valid(character_view): sprite_body.reparent(character_view,false)
	random.randomize()

func apply_damage(_amount: int) -> bool:
	return false

func nearest(enemies: Array, radius: float, screen_only: bool = false, excluded: Array = [], region_mode: int = -1) -> EnemyActor:
	var best: EnemyActor = null
	var best_distance := INF
	var screen: Rect2 = manager.enemies._get_screen_world_rect()
	for candidate: EnemyActor in enemies:
		if not candidate.is_active or candidate.is_logically_dead: continue
		if candidate.has_method("is_auto_targetable") and not candidate.is_auto_targetable(): continue
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
	if target.has_method("is_auto_targetable") and not target.is_auto_targetable(): return false
	return global_position.distance_to(target.global_position)<=float(config.Search_radius) or manager.enemies._get_screen_world_rect().has_point(target.global_position)

func choose_target(living: Array) -> void:
	if diagnostic_sink.is_valid(): diagnostic_sink.call("choose_target",{})
	var excluded: Array = manager.claimed_targets(self)
	target = choose_in_stage(living,float(config.Search_radius),false,excluded)
	if target==null: target = choose_in_stage(living,INF,true,excluded)
	target_spawn_order = target.spawn_order if target!=null else -1

func choose_in_stage(living: Array, radius: float, screen_only: bool, excluded: Array) -> EnemyActor:
	if diagnostic_sink.is_valid(): diagnostic_sink.call("selection_call",{"stage":2 if screen_only else 1})
	var selected: EnemyActor = null
	if manager.actors.size()>1:
		selected = nearest(living,radius,screen_only,excluded,0)
		if selected==null: selected = nearest(living,radius,screen_only,excluded,1)
	else:
		selected = nearest(living,radius,screen_only,excluded)
	var result: EnemyActor = selected if selected!=null else nearest(living,radius,screen_only)
	if diagnostic_sink.is_valid():
		var rule := "none" if result==null else ("duplicate" if selected==null else ("single_free" if manager.actors.size()==1 else ("own_free" if manager.region_matches(self,result.global_position,0) else "other_free")))
		diagnostic_sink.call("selection",{"stage":2 if screen_only else 1,"rule":rule,"order":result.spawn_order if result!=null else -1})
	return result

func tick(delta: float) -> void:
	var visual_origin := global_position
	var dash_visual_was_active := dash_through_active
	clock += delta
	advance_belion_effects(delta)
	var player: Node2D = manager.player
	if global_position.distance_to(player.global_position)>=float(config.Teleport_distance):
		teleport()
	var living: Array = manager.enemies.get_living_enemies()
	if global_position.distance_to(player.global_position)>float(config.Chase_leash_distance) and not cast_active:
		if diagnostic_sink.is_valid(): diagnostic_sink.call("cancel",{"reason":"leash","had_cast":cast_active})
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
	update_sprite_visual(global_position-visual_origin,delta)
	update_dash_trail(visual_origin,delta,dash_visual_was_active)
	queue_redraw()

func act_on_target(player: Node2D, delta: float) -> void:
	if target!=null:
		if global_position.distance_to(target.global_position)<=float(config.Search_radius):
			last_node = "attack"
			if is_sweep():
				var distance := global_position.distance_to(target.global_position)
				if clock+0.000000001<ready_at:
					if distance>float(attack.Range): move_to_distance(target.global_position,float(attack.Range),delta)
					return
				move_to_distance(target.global_position,float(attack.Range)*0.8,delta)
				if global_position.distance_to(target.global_position)<=float(attack.Range)*0.8+0.00001:
					start_attack()
				return
			move_to_distance(target.global_position,float(attack.Range),delta)
			if is_dash_through():
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
	var plan: Dictionary = {}
	if is_dash_through():
		plan = plan_dash()
		if not plan.allowed:
			if diagnostic_sink.is_valid(): diagnostic_sink.call("dash_rejected",plan)
			return
	cast_active = true
	hit_done = false
	sprite_hit_at = -INF
	cast_started_at = clock
	fan_aim_updated_at = clock
	facing = global_position.direction_to(target.global_position)
	if facing==Vector2.ZERO: facing = Vector2.RIGHT
	motion_index = -1 if is_sweep() else (int(motion_picker.call(motions.size())) if motion_picker.is_valid() else random.randi_range(0,motions.size()-1))
	if is_sweep():
		sweep_sign = 1.0 if sweep_forward else -1.0
		var start_offset := -deg_to_rad(float(attack.Arc_deg))*0.5*sweep_sign
		sweep_previous_angle = facing.angle()+start_offset
		sweep_current_angle = sweep_previous_angle
		sweep_hits.clear()
	if is_dash_through():
		dash_origin = global_position
		dash_goal = plan.endpoint
		dash_direction = plan.direction
		facing = dash_direction
		dash_length = float(plan.length)
		dash_travelled = 0.0
		dash_end_reason = plan.end_reason
		dash_hits.clear()
		dash_through_active = true
		dash_updated_at = clock
	if diagnostic_sink.is_valid(): diagnostic_sink.call("dash_start" if is_dash_through() else "fan_start",{"goal":[dash_goal.x,dash_goal.y]})
	advance_attack(manager.enemies.get_living_enemies())

func is_dash_through() -> bool:
	return int(attack.Shape)==Data.Shape.DASH_THROUGH

func is_sweep() -> bool:
	return int(attack.Shape)==Data.Shape.SWEEP

func is_fan_cast_active() -> bool:
	return cast_active and int(attack.Shape)==Data.Shape.FAN

func is_push_exempt_cast_active() -> bool:
	return cast_active and int(attack.Shape) in [Data.Shape.FAN,Data.Shape.SWEEP]

func advance_attack(living: Array) -> void:
	if is_dash_through():
		advance_dash(living)
		return
	if is_sweep():
		advance_sweep(living)
		return
	advance_fan_attack(living)

func advance_sweep(living: Array) -> void:
	var windup := float(attack.Windup_sec)
	var duration := float(attack.Sweep_sec)
	var age := clock-cast_started_at
	if age+0.000000001<windup: return
	var progress := 1.0 if age+0.000001>=windup+duration else clampf((age-windup)/duration,0.0,1.0)
	var half_arc := deg_to_rad(float(attack.Arc_deg))*0.5
	var start_offset := -half_arc*sweep_sign
	var end_offset := half_arc*sweep_sign
	var next_angle := facing.angle()+lerpf(start_offset,end_offset,progress)
	var previous := sweep_current_angle
	sweep_previous_angle = previous
	sweep_current_angle = next_angle
	for enemy: EnemyActor in living:
		var key := enemy.get_instance_id()
		if int(sweep_hits.get(key,-1))==enemy.spawn_order: continue
		if in_sweep_interval(enemy,previous,next_angle):
			sweep_hits[key] = enemy.spawn_order
			enemy.apply_damage(int(attack.Damage))
			spawn_belion_fragments(enemy.global_position)
	add_sweep_trail_tip()
	if progress>=1.0:
		hit_done = true
		cast_active = false
		sprite_hit_at = clock
		sweep_forward = not sweep_forward
		ready_at = cast_started_at+windup+duration+float(attack.Interval_sec)

func in_sweep_interval(enemy: EnemyActor, from_angle: float, to_angle: float) -> bool:
	if not enemy.is_active or enemy.is_logically_dead: return false
	var offset := enemy.global_position-global_position
	if offset.length_squared()>float(attack.Range)*float(attack.Range)+0.0001: return false
	var relative := angle_difference(facing.angle(),offset.angle()) if offset!=Vector2.ZERO else 0.0
	var from_relative := angle_difference(facing.angle(),from_angle)
	var to_relative := angle_difference(facing.angle(),to_angle)
	return relative>=minf(from_relative,to_relative)-0.000001 and relative<=maxf(from_relative,to_relative)+0.000001

func sweep_progress() -> float:
	if not is_sweep() or not cast_active: return 1.0
	return clampf((clock-cast_started_at-float(attack.Windup_sec))/float(attack.Sweep_sec),0.0,1.0)

func sweep_visual_state() -> Dictionary:
	if not is_sweep() or not cast_active: return {}
	var state := {"windup":clock-cast_started_at<float(attack.Windup_sec),"center":global_position,"direction":Vector2.RIGHT.rotated(sweep_current_angle),"range":float(attack.Range),"progress":sweep_progress(),"sign":sweep_sign}
	if has_chain_hand():
		state.hand = chain_hand_position()
		state.foot = global_position+Vector2(0,float(config.Sprite_foot_y))
		state.chain_width = float(presentation.Belion_chain_width)
	return state

func has_chain_hand() -> bool:
	return sprite_body!=null and not sprite_body.using_fallback and config.get("Chain_hand_x")!=null and config.get("Chain_hand_y")!=null

func chain_hand_position() -> Vector2:
	var foot := global_position+Vector2(0,float(config.Sprite_foot_y))
	return foot+Vector2(float(config.Chain_hand_x)*(-1.0 if sprite_body.flip_h else 1.0),float(config.Chain_hand_y))

func advance_fan_attack(living: Array) -> void:
	var motion: Dictionary = motions[motion_index]
	var age := clock-cast_started_at
	var aim_time := minf(clock,cast_started_at+float(motion.Hit_time_sec))
	var aim_delta := maxf(aim_time-fan_aim_updated_at,0.0)
	fan_aim_updated_at = aim_time
	if not hit_done and target_is_live():
		var direction := global_position.direction_to(target.global_position)
		if direction!=Vector2.ZERO:
			var maximum_turn := deg_to_rad(float(attack.Aim_turn_deg_per_sec))*aim_delta
			var deadband := deg_to_rad(float(attack.Aim_deadband_deg))
			var difference := absf(angle_difference(facing.angle(),direction.angle()))
			# Zero keeps the previous aiming path, including its float rounding.
			if deadband==0.0 or difference>deadband:
				if deadband>0.0: maximum_turn = minf(maximum_turn,difference-deadband)
				facing = Vector2.RIGHT.rotated(rotate_toward(facing.angle(),direction.angle(),maximum_turn))
	if not hit_done and age+0.000000001>=float(motion.Hit_time_sec):
		hit_done = true
		sprite_hit_at = clock
		var geometry := attack_geometry()
		for enemy: EnemyActor in living:
			if in_sector(enemy,geometry): enemy.apply_damage(int(attack.Damage))
	if age+0.000000001>=float(motion.Motion_sec):
		cast_active = false
		ready_at = cast_started_at+float(motion.Motion_sec)+float(attack.Interval_sec)

func plan_dash() -> Dictionary:
	if not target_is_live(): return {"allowed":false,"reason":"no_target"}
	var direction := global_position.direction_to(target.global_position)
	if direction==Vector2.ZERO: direction = facing.normalized()
	if direction==Vector2.ZERO: direction = Vector2.RIGHT
	var offset: Vector2 = global_position-manager.player.global_position
	var b := offset.dot(direction)
	var radius := float(config.Chase_leash_distance)
	var exit_distance := maxf(0.0,-b+sqrt(maxf(0.0,b*b+radius*radius-offset.length_squared())))
	var leash_length := minf(float(attack.Dash_distance),exit_distance)
	if leash_length<float(attack.Dash_min_distance):
		return {"allowed":false,"reason":"leash_minimum","length":leash_length}
	var bounds: Rect2 = manager.enemies._get_map_world_rect().grow(-body_radius)
	var length := leash_length
	if direction.x>0.0: length = minf(length,(bounds.end.x-global_position.x)/direction.x)
	elif direction.x<0.0: length = minf(length,(bounds.position.x-global_position.x)/direction.x)
	if direction.y>0.0: length = minf(length,(bounds.end.y-global_position.y)/direction.y)
	elif direction.y<0.0: length = minf(length,(bounds.position.y-global_position.y)/direction.y)
	length = maxf(0.0,length)
	return {"allowed":true,"direction":direction,"length":length,"endpoint":global_position+direction*length,"end_reason":"map" if length<leash_length else "distance","leash_length":leash_length}

func advance_dash(living: Array) -> void:
	if not hit_done:
		var previous := global_position
		var delta := maxf(clock-dash_updated_at,0.0)
		dash_updated_at = clock
		dash_travelled = minf(dash_length,dash_travelled+float(attack.Dash_speed)*delta)
		var intended := dash_origin+dash_direction*dash_travelled
		global_position = manager.enemies._clamp_body_to_map(intended,body_radius)
		for enemy: EnemyActor in living:
			if in_dash_segment(enemy,previous,global_position) and int(dash_hits.get(enemy.get_instance_id(),-1))!=enemy.spawn_order:
				dash_hits[enemy.get_instance_id()] = enemy.spawn_order
				enemy.apply_damage(int(attack.Damage))
		if dash_travelled>=dash_length or global_position!=intended:
			hit_done = true
			dash_through_active = false
			dash_hit_at = clock
			if diagnostic_sink.is_valid(): diagnostic_sink.call("dash_end",{"reason":"map" if global_position!=intended else dash_end_reason})
	if hit_done and clock-dash_hit_at+0.000000001>=float(motions[motion_index].Motion_sec):
		cast_active = false
		target = null
		ready_at = dash_hit_at+float(motions[motion_index].Motion_sec)+float(attack.Interval_sec)

func dash_geometry() -> Dictionary:
	return {"center":global_position,"radius":float(attack.Dash_hit_radius)}

func dash_visual_state() -> Dictionary:
	if not dash_through_active: return {}
	var state := dash_geometry()
	state.hit_age = -1.0
	return state

func in_dash_segment(enemy: EnemyActor, from: Vector2, to: Vector2) -> bool:
	if not enemy.is_active or enemy.is_logically_dead: return false
	var segment := to-from
	var length_squared := segment.length_squared()
	var fraction := clampf((enemy.global_position-from).dot(segment)/length_squared,0.0,1.0) if length_squared>0.0 else 0.0
	var geometry := dash_geometry()
	return enemy.global_position.distance_squared_to(from+segment*fraction)<=float(geometry.radius)*float(geometry.radius)

func attack_geometry() -> Dictionary:
	return {"center":global_position,"direction":facing,"range":float(attack.Range),"arc_deg":float(attack.Arc_deg)}

func attack_visual_state() -> Dictionary:
	if not cast_active or int(attack.Shape)!=Data.Shape.FAN: return {}
	var state := attack_geometry()
	state.hit_age = clock-cast_started_at-float(motions[motion_index].Hit_time_sec) if hit_done else -1.0
	return state

func in_sector(enemy: EnemyActor, geometry: Dictionary = {}) -> bool:
	if not enemy.is_active or enemy.is_logically_dead: return false
	if geometry.is_empty(): geometry = attack_geometry()
	return preload("res://scripts/combat_geometry.gd").in_sector(Vector2(geometry.center),Vector2(geometry.direction),float(geometry.range),float(geometry.arc_deg),enemy.global_position)

func cancel_attack() -> void:
	dash_through_active = false
	cast_active = false
	hit_done = false
	sprite_hit_at = -INF
	sweep_hits.clear()
	ready_at = clock

func teleport() -> void:
	var departure := global_position
	manager.leave_afterimage(departure,snapshot(),float(config.Afterimage_sec))
	var angle := float(angle_picker.call()) if angle_picker.is_valid() else random.randf_range(0,TAU)
	global_position = manager.enemies._clamp_body_to_map(manager.player.global_position+Vector2.RIGHT.rotated(angle)*float(config.Follow_distance),body_radius)
	target = null
	if diagnostic_sink.is_valid(): diagnostic_sink.call("cancel",{"reason":"teleport","had_cast":cast_active})
	cancel_attack()
	last_node = "teleport"
	queue_redraw()

func snapshot() -> Dictionary:
	if is_dash_through():
		var recovery_sec := float(motions[motion_index].Motion_sec) if motion_index>=0 else 0.0
		var recovery_phase := clampf((clock-dash_hit_at)/recovery_sec,0,1) if cast_active and hit_done and recovery_sec>0 else 0.0
		var result := {"radius":body_radius,"facing":facing,"motion":-1,"phase":recovery_phase,"kind":"charger_test"}
		if sprite_body!=null: result.sprite_pose = sprite_body.pose_snapshot()
		return result
	if is_sweep():
		var sweep_result := {"radius":body_radius,"facing":facing,"motion":-1,"phase":sweep_progress(),"kind":"belion"}
		if sprite_body!=null: sweep_result.sprite_pose = sprite_body.pose_snapshot()
		return sweep_result
	var phase := 0.0
	if cast_active: phase = clampf((clock-cast_started_at)/float(motions[motion_index].Motion_sec),0,1)
	var result := {"radius":body_radius,"facing":facing,"motion":motion_index if cast_active else -1,"phase":phase}
	if sprite_body!=null: result.sprite_pose = sprite_body.pose_snapshot()
	return result

func update_sprite_visual(movement: Vector2, delta: float) -> void:
	if sprite_body==null: return
	if is_dash_through():
		var after := float(config.Attack_after_frame_sec)
		if dash_through_active:
			sprite_body.flip_h = dash_direction.x<0.0
			sprite_body.set_attack_pose(dash_direction,1 if clock-cast_started_at<after-0.000000001 else 2)
			return
		if hit_done and motion_index>=0:
			var recovery := float(motions[motion_index].Motion_sec)
			var hold := recovery if recovery>0.0 else after
			if clock-dash_hit_at<hold-0.000000001:
				sprite_body.flip_h = dash_direction.x<0.0
				sprite_body.set_attack_pose(dash_direction,3)
				return
		sprite_body.advance_state_pose(movement,movement.length_squared()>0.000001,delta)
		return
	if is_sweep():
		if cast_active:
			var age := clock-cast_started_at
			if age<float(attack.Windup_sec): sprite_body.set_attack_pose(facing,0)
			else: sprite_body.set_attack_pose(facing,1)
			return
		if sprite_hit_at>-INF:
			var after := float(config.Attack_after_frame_sec)
			var age := clock-sprite_hit_at
			if age<after-0.000000001:
				sprite_body.set_attack_pose(facing,2)
				return
			if age<after*2.0-0.000000001:
				sprite_body.set_attack_pose(facing,3)
				return
		sprite_hit_at = -INF
		sprite_body.advance_state_pose(movement,movement.length_squared()>0.000001,delta)
		return
	if sprite_hit_at>-INF:
		var age := clock-sprite_hit_at
		var after := float(config.Attack_after_frame_sec)
		if age<=0.000000001:
			sprite_body.set_attack_pose(facing,1)
			return
		if age<=after+0.000000001:
			sprite_body.set_attack_pose(facing,2)
			return
		if age<=after*2.0+0.000000001:
			sprite_body.set_attack_pose(facing,3)
			return
		sprite_hit_at = -INF
	if cast_active and not hit_done and not is_dash_through():
		sprite_body.set_attack_pose(facing,0)
		return
	sprite_body.advance_state_pose(movement,movement.length_squared()>0.000001,delta)

func update_dash_trail(previous: Vector2, delta: float, was_active: bool) -> void:
	if not is_dash_through() or sprite_body==null or sprite_body.using_fallback: return
	if not dash_through_active and not (was_active and hit_done): return
	if dash_trail_cast_at!=cast_started_at or (not was_active and dash_through_active):
		dash_trail_cast_at = cast_started_at
		dash_trail_next_age = 0.0
	var life := float(presentation.Trail_life_sec)
	var interval := float(presentation.Trail_interval_sec)
	if life<=0.0 or interval<=0.0: return
	var start_age := maxf(0.0,clock-delta-cast_started_at) if was_active else 0.0
	var end_age := minf(clock-cast_started_at,start_age+previous.distance_to(global_position)/float(attack.Dash_speed)) if was_active else 0.0
	var departure := previous if was_active else dash_origin
	while dash_trail_next_age<=end_age+0.000000001:
		var age := maxf(0.0,clock-cast_started_at-dash_trail_next_age)
		if age<life:
			var fraction := clampf((dash_trail_next_age-start_age)/maxf(end_age-start_age,0.000000001),0,1)
			var pose := snapshot()
			pose.sprite_pose.frame_row = 2
			pose.sprite_pose.frame_column = 1 if dash_trail_next_age<float(config.Attack_after_frame_sec)-0.000000001 else 2
			pose.sprite_pose.flip_h = dash_direction.x<0.0
			var copy: Node2D = manager.leave_afterimage(departure.lerp(global_position,fraction),pose,life,float(presentation.Trail_alpha))
			copy.set_meta("beru_dash_trail",true)
			copy._physics_process(age)
		dash_trail_next_age += interval

func _draw() -> void:
	if is_dash_through():
		var circle := dash_visual_state()
		if not circle.is_empty(): Visual.draw_circle_attack(self,circle)
		return
	if is_sweep():
		var sweep := sweep_visual_state()
		if not sweep.is_empty():
			if bool(sweep.windup):
				if sweep.has("hand"): Visual.draw_belion_hand_windup(self,sweep.hand,body_radius)
				else: Visual.draw_belion_windup(self,facing,body_radius)
			else: Visual.draw_belion_chain(self,sweep,int(float(presentation.Belion_chain_segments)))
		draw_belion_effects()
		return
	var sector := attack_visual_state()
	if not sector.is_empty(): Visual.draw_sector(self,sector)

func draw_body(canvas: Node2D) -> void:
	if sprite_body==null:
		var size := Vector2(float(config.Shadow_w) if config.get("Shadow_w")!=null else 32.0,float(config.Shadow_h) if config.get("Shadow_h")!=null else 12.0)
		SpriteBodyScript.draw_ground_shadow(canvas,size)
		if is_dash_through():
			Visual.draw_charger_pose(canvas,body_radius,facing)
		elif is_sweep():
			Visual.draw_belion_pose(canvas,body_radius,facing)
		else:
			var pose := snapshot()
			Visual.draw_pose(canvas,body_radius,facing,int(pose.motion),float(pose.phase))

func add_sweep_trail_tip() -> void:
	var point := global_position+Vector2.RIGHT.rotated(sweep_current_angle)*float(attack.Range)
	sweep_trail.append({"point":point,"age":0.0})

func spawn_belion_fragments(point: Vector2) -> void:
	for index in range(5):
		var angle := TAU*float(index)/5.0+float(index%2)*0.23
		sweep_particles.append({"point":point,"velocity":Vector2.RIGHT.rotated(angle)*(35.0+index*6.0),"age":0.0,"life":0.18})

func advance_belion_effects(delta: float) -> void:
	var trail_life := float(presentation.get("Belion_trail_sec",0.15))
	for index in range(sweep_trail.size()-1,-1,-1):
		sweep_trail[index].age = float(sweep_trail[index].age)+delta
		if float(sweep_trail[index].age)>=trail_life: sweep_trail.remove_at(index)
	for index in range(sweep_particles.size()-1,-1,-1):
		var particle: Dictionary = sweep_particles[index]
		particle.age = float(particle.age)+delta
		particle.point = Vector2(particle.point)+Vector2(particle.velocity)*delta
		sweep_particles[index] = particle
		if float(particle.age)>=float(particle.life): sweep_particles.remove_at(index)

func draw_belion_effects() -> void:
	var trail_life := float(presentation.get("Belion_trail_sec",0.15))
	for sample in sweep_trail:
		var alpha := 1.0-float(sample.age)/trail_life
		draw_circle(to_local(Vector2(sample.point)),4.0,Color(0.7,0.35,1.0,0.55*alpha))
	for particle in sweep_particles:
		var alpha := 1.0-float(particle.age)/float(particle.life)
		draw_circle(to_local(Vector2(particle.point)),2.5,Color(0.82,0.55,1.0,0.8*alpha))
