extends Node2D

const Actor = preload("res://scripts/shadow_actor.gd")
const Afterimage = preload("res://scripts/shadow_afterimage.gd")
const ENABLE_DEBUG_TELEPORT := true
const DEBUG_TELEPORT_KEY := KEY_T
var player: Node2D
var enemies: EnemyManager
var records: Dictionary = {}
var attacks: Dictionary = {}
var motions: Dictionary = {}
var capacity: int = 0
var actors: Array = []

func configure(owner_player: Node2D, enemy_manager: EnemyManager, shadow_records: Dictionary, attack_records: Dictionary, motion_records: Dictionary, limit: int) -> void:
	player = owner_player
	enemies = enemy_manager
	records = shadow_records
	attacks = attack_records
	motions = motion_records
	capacity = limit
	process_physics_priority = -1

func can_summon() -> bool:
	return actors.size()<capacity

func summon(id: String = "igrit") -> Node2D:
	if not can_summon() or not records.has(id): return null
	var record: Dictionary = records[id]
	var matching: Array = []
	for motion in motions.values():
		if motion.Attack_id==record.Attack_id: matching.append(motion)
	var actor := Actor.new()
	actor.configure(self,record,attacks[record.Attack_id],matching)
	add_child(actor)
	actor.global_position = enemies._clamp_body_to_map(player.global_position,float(record.Body_radius))
	actors.append(actor)
	enemies.register_shadow_body(actor)
	actor.tree_exiting.connect(_remove_actor.bind(actor),CONNECT_ONE_SHOT)
	return actor

func _remove_actor(actor: Node2D) -> void:
	actors.erase(actor)

func _physics_process(delta: float) -> void:
	if player==null or player.is_dead: return
	for actor in actors:
		actor.tick(delta)

func leave_afterimage(point: Vector2, pose: Dictionary, seconds: float) -> Node2D:
	var copy := Afterimage.new()
	copy.configure(pose,seconds)
	add_child(copy)
	copy.global_position = point
	return copy

func _unhandled_input(event: InputEvent) -> void:
	if not ENABLE_DEBUG_TELEPORT or player==null or player.is_dead: return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==DEBUG_TELEPORT_KEY:
		for actor in actors: actor.teleport()
		get_viewport().set_input_as_handled()
