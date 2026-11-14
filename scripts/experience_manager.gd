extends Node2D

const Orb = preload("res://scripts/experience_orb.gd")

var _player: Node2D
var _rule: Dictionary = {}
var _orbs: Array = []
var _label: Label

func configure(player: Node2D, enemy_manager: EnemyManager, rule: Dictionary) -> void:
	_player = player
	_rule = rule.duplicate(true)
	enemy_manager.enemy_died.connect(_on_enemy_died)

func _on_enemy_died(enemy: EnemyActor) -> void:
	if _player.run_finished: return
	drop_experience(enemy.global_position,enemy.xp_value)

func drop_experience(world_position: Vector2, amount: int) -> Node2D:
	if amount <= 0:
		return null
	if _orbs.size() >= int(_rule["Max_ground_orbs"]):
		var oldest: Node2D = _orbs[0]
		oldest.value += amount
		_update_label()
		return oldest
	var orb := Orb.new()
	add_child(orb)
	orb.configure(amount,world_position,_rule)
	_orbs.append(orb)
	_update_label()
	return orb

func get_ground_count() -> int:
	return _orbs.size()

func get_ground_total() -> int:
	var total := 0
	for orb in _orbs:
		total += int(orb.value)
	return total

func _physics_process(delta: float) -> void:
	if _player == null or _player.is_dead:
		return
	for orb in _orbs.duplicate():
		if orb.advance(delta,_player):
			_orbs.erase(orb)
			_player.add_experience(int(orb.value))
	_update_label()

func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(20.0,76.0)
	_label.add_theme_font_size_override("font_size",22)
	layer.add_child(_label)
	_update_label()

func _update_label() -> void:
	if _label != null and _player != null:
		_label.text = "레벨: %d  경험치: %d / %d  강화 포인트: %d\n바닥 경험치: %d개 / 총량 %d" % [_player.level,_player.experience,_player.get_xp_to_next(),_player.enhancement_points,get_ground_count(),get_ground_total()]
