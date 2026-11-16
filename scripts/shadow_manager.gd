extends Node2D

signal list_changed

const Actor = preload("res://scripts/shadow_actor.gd")
const Afterimage = preload("res://scripts/shadow_afterimage.gd")
const ENABLE_DEBUG_TELEPORT := true
const DEBUG_TELEPORT_KEY := KEY_T
const MAX_TYPES := 2
const REGION_BOUNDARY_EPS := 0.0000001
var player: Node2D
var enemies: EnemyManager
var records: Dictionary = {}
var attacks: Dictionary = {}
var motions: Dictionary = {}
var capacity: int = 0
var actors: Array = []
var _steering_positions: Dictionary = {}

func configure(owner_player: Node2D, enemy_manager: EnemyManager, shadow_records: Dictionary, attack_records: Dictionary, motion_records: Dictionary, limit: int) -> void:
	player = owner_player
	enemies = enemy_manager
	records = shadow_records
	attacks = attack_records
	motions = motion_records
	capacity = mini(limit,MAX_TYPES)
	process_physics_priority = -1

func can_summon(id: String = "") -> bool:
	if actors.size()>=capacity: return false
	if id.is_empty(): return true
	if not records.has(id): return false
	for actor in actors:
		if actor.config.Id==id: return false
	return true

func summon(id: String = "igrit", from_selection: bool = false) -> Node2D:
	if not can_summon(id): return null
	var record: Dictionary = records[id]
	var matching: Array = []
	for motion in motions.values():
		if motion.Attack_id==record.Attack_id: matching.append(motion)
	var actor := Actor.new()
	actor.configure(self,record,attacks[record.Attack_id],matching)
	add_child(actor)
	actor.global_position = enemies._clamp_body_to_map(player.global_position,float(record.Body_radius))
	actors.append(actor)
	preload("res://scripts/audio_events.gd").sfx(self,"shadow_summon")
	enemies.register_shadow_body(actor)
	actor.tree_exiting.connect(_remove_actor.bind(actor),CONNECT_ONE_SHOT)
	actor.setup_visual_aura()
	list_changed.emit()
	if from_selection:
		preload("res://scripts/boss_toast.gd").notify(self,"[그림자 병사 %s 소환합니다]" % preload("res://scripts/boss_toast.gd").particle(String(record.Name_ko),"을","를"))
	return actor

func _remove_actor(actor: Node2D) -> void:
	actors.erase(actor)
	list_changed.emit()

func _physics_process(delta: float) -> void:
	if player==null or player.is_dead: return
	_steering_positions.clear()
	for actor in actors:
		_steering_positions[actor.get_instance_id()] = actor.global_position
	for actor in actors:
		actor.tick(delta)
	_steering_positions.clear()

func steering_position(actor: Node2D) -> Vector2:
	return _steering_positions.get(actor.get_instance_id(),actor.global_position)

func claimed_targets(except_actor: Node2D) -> Array:
	var result: Array = []
	# actors is summon order; earlier tick decisions are visible immediately.
	for actor in actors:
		if actor!=except_actor and actor.target_is_live(): result.append(actor.target)
	return result

func region_index(point: Vector2, count: int) -> int:
	var offset := point-player.global_position
	if count<=0 or offset==Vector2.ZERO: return -1
	var angle := fposmod(offset.angle(),TAU)
	# Compensate only float-vector rounding at exact angular boundaries.
	return floori(angle*count/TAU+REGION_BOUNDARY_EPS)%count

func region_matches(actor: Node2D, point: Vector2, mode: int) -> bool:
	if mode<0: return true
	var region := region_index(point,actors.size())
	var own := actors.find(actor)
	return region==own if mode==0 else (region>=0 and region!=own)

func follow_slot(actor: Node2D, distance: float) -> Vector2:
	var angle := TAU*(actors.find(actor)+0.5)/actors.size()
	return player.global_position+Vector2.RIGHT.rotated(angle)*distance

func leave_afterimage(point: Vector2, pose: Dictionary, seconds: float, alpha: float = 0.45) -> Node2D:
	var copy := Afterimage.new()
	copy.configure(pose,seconds,alpha)
	add_child(copy)
	copy.global_position = point
	return copy

func _unhandled_input(event: InputEvent) -> void:
	if not ENABLE_DEBUG_TELEPORT or player==null or player.is_dead: return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==DEBUG_TELEPORT_KEY:
		for actor in actors: actor.teleport()
		get_viewport().set_input_as_handled()
