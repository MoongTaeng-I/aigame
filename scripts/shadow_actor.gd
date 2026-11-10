extends Node2D

const Visual = preload("res://scripts/shadow_visual.gd")
var manager: Node2D
var config: Dictionary
var attack: Dictionary
var motions: Array = []
var body_radius: float
var push_weight: float
var target: EnemyActor
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

func configure(owner_manager: Node2D, record: Dictionary, attack_record: Dictionary, motion_records: Array) -> void:
	manager = owner_manager
	config = record.duplicate(true)
	attack = attack_record.duplicate(true)
	motions = motion_records.duplicate(true)
	body_radius = float(config.Body_radius)
	push_weight = float(config.Push_weight)
	random.randomize()

func apply_damage(_amount: int) -> bool:
	return false

func nearest(enemies: Array, radius: float, screen_only: bool = false) -> EnemyActor:
	var best: EnemyActor = null
	var best_distance := INF
	var screen: Rect2 = manager.enemies._get_screen_world_rect()
	for candidate: EnemyActor in enemies:
		if not candidate.is_active or candidate.is_logically_dead: continue
		if screen_only and not screen.has_point(candidate.global_position): continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance>radius*radius: continue
		if best==null or distance<best_distance or (distance==best_distance and candidate.spawn_order<best.spawn_order):
			best = candidate
			best_distance = distance
	return best

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
		move_to_distance(player.global_position,float(config.Follow_distance),delta)
	elif cast_active:
		advance_attack(living)
	else:
		target = nearest(living,float(config.Search_radius))
		if target!=null:
			last_node = "attack"
			move_to_distance(target.global_position,float(attack.Range),delta)
			if global_position.distance_to(target.global_position)<=float(attack.Range)+0.00001 and clock+0.000000001>=ready_at:
				start_attack()
		else:
			target = nearest(living,INF,true)
			if target!=null:
				last_node = "screen"
				move_to_distance(target.global_position,0.0,delta)
			else:
				last_node = "follow"
				move_to_distance(player.global_position,float(config.Follow_distance),delta)
	global_position = manager.enemies._clamp_body_to_map(global_position,body_radius)
	queue_redraw()

func move_to_distance(point: Vector2, stop_distance: float, delta: float) -> void:
	var distance := global_position.distance_to(point)
	if distance<=stop_distance: return
	facing = global_position.direction_to(point)
	global_position += facing*minf(float(config.Move_speed)*delta,distance-stop_distance)

func start_attack() -> void:
	cast_active = true
	hit_done = false
	cast_started_at = clock
	facing = global_position.direction_to(target.global_position)
	if facing==Vector2.ZERO: facing = Vector2.RIGHT
	motion_index = int(motion_picker.call(motions.size())) if motion_picker.is_valid() else random.randi_range(0,motions.size()-1)
	advance_attack(manager.enemies.get_living_enemies())

func advance_attack(living: Array) -> void:
	var motion: Dictionary = motions[motion_index]
	var age := clock-cast_started_at
	if not hit_done and age+0.000000001>=float(motion.Hit_time_sec):
		hit_done = true
		for enemy: EnemyActor in living:
			if in_sector(enemy): enemy.apply_damage(int(attack.Damage))
	if age+0.000000001>=float(motion.Motion_sec):
		cast_active = false
		ready_at = cast_started_at+float(motion.Motion_sec)+float(attack.Interval_sec)

func in_sector(enemy: EnemyActor) -> bool:
	if not enemy.is_active or enemy.is_logically_dead: return false
	var offset := enemy.global_position-global_position
	if offset.length_squared()>float(attack.Range)*float(attack.Range): return false
	if offset==Vector2.ZERO: return true
	return absf(wrapf(offset.angle()-facing.angle(),-PI,PI))<=deg_to_rad(float(attack.Arc_deg))*0.5+0.000000001

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
	var phase := 0.0
	if cast_active: phase = clampf((clock-cast_started_at)/float(motions[motion_index].Motion_sec),0,1)
	return {"radius":body_radius,"facing":facing,"motion":motion_index if cast_active else -1,"phase":phase}

func _draw() -> void:
	var pose := snapshot()
	Visual.draw_pose(self,body_radius,facing,int(pose.motion),float(pose.phase))
