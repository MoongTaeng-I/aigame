extends Node2D

const Data = preload("res://scripts/boss_data.gd")
var manager: EnemyManager
var bosses: Dictionary
var actions: Dictionary
var timeline: Array
var rule: Dictionary
var fired: Dictionary = {}
var pending: Array = []
var active_id := ""
var phase := "idle"
var deadline: float = 0
var actor: EnemyActor
var completed := false
var toast: Label
var toast_text := ""
var gate_position := Vector2.ZERO

func configure(owner_manager: EnemyManager, records: Dictionary, action_rows: Dictionary, events: Dictionary, rules: Dictionary) -> void:
	manager = owner_manager
	bosses = records
	actions = action_rows
	timeline = events.values().duplicate(true)
	timeline.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.Time_mmss)<int(b.Time_mmss))
	rule = rules
	manager.boss_director = self
	gate_position = manager._get_map_world_rect().get_center()

func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	toast = Label.new()
	toast.position = Vector2(160,28)
	layer.add_child(toast)

func player_target() -> Node2D:
	return manager._player

func advance(now: float, _delta: float) -> void:
	if completed or manager._player.is_dead or get_tree().paused: return
	for row in timeline:
		if not fired.has(row.Id) and now>=Data.mmss_seconds(int(row.Time_mmss)):
			fired[row.Id] = true
			pending.append(row.Boss_id)
	if active_id.is_empty() and not pending.is_empty(): begin_warning(now)
	if phase=="warn" and now>=deadline:
		var rows: Array = []
		for row in actions.values():
			if row.Boss_id==active_id: rows.append(row)
		actor = manager.create_boss(String(bosses[active_id].Enemy_id),rows,player_target)
		actor.global_position = gate_position
		phase = "emerge"
		deadline+=float(rule.Emerge_sec)
	if phase=="emerge" and now>=deadline:
		manager.activate_boss(actor)
		actor.died.connect(_boss_died)
		phase = "active"
		toast_text = ""
	if is_instance_valid(toast): toast.text = toast_text
	queue_redraw()

func begin_warning(now: float) -> void:
	active_id = String(pending.pop_front())
	phase = "warn"
	deadline = now+float(rule.Warn_sec)
	manager.set_normal_spawning_stopped(true)
	var name_ko: String = manager._enemy_records[bosses[active_id].Enemy_id].Name_ko
	toast_text = String(rule.Toast_text).replace("{name}",name_ko)
	if is_instance_valid(toast): toast.text = toast_text
	queue_redraw()

func _boss_died(_dead: EnemyActor) -> void:
	var final := bool(bosses[active_id].Is_final)
	active_id = ""
	phase = "idle"
	actor = null
	if final:
		completed = true
		toast_text = "완료"
		if is_instance_valid(toast): toast.text = toast_text
		get_tree().paused = true
	elif not pending.is_empty(): begin_warning(manager._elapsed_seconds)
	else: manager.set_normal_spawning_stopped(false)
	queue_redraw()

func _draw() -> void:
	if phase in ["warn","emerge"]:
		draw_arc(to_local(gate_position),float(rule.Gate_radius),0,TAU,64,Color("#8ce8ff"),4)
