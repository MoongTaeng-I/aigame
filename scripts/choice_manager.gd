extends Node

const Data = preload("res://scripts/choice_data.gd")
const UI = preload("res://scripts/choice_ui.gd")
var player: Node2D
var records: Dictionary = {}
var level_rows: Dictionary = {}
var levels: Dictionary = {}
var cards: Array = []
var pending: int = 0
var active: bool = false
var rerolls: int = 0
var total_rerolls: int = 0
var heal_id: String = ""
var random := RandomNumberGenerator.new()
var ui: Control
var owns_pause: bool = false

func configure(owner_player: Node2D, choices: Dictionary, rows: Dictionary, rule: Dictionary) -> void:
	player = owner_player
	records = choices.duplicate(true)
	rerolls = int(rule.Reroll_count)
	total_rerolls = rerolls
	for id in records:
		level_rows[id] = []
		if int(records[id].Effect)==Data.Effect.HEAL: heal_id = id
		else: levels[id] = 0
	for row in rows.values():
		level_rows[row.Choice_id].append(row.duplicate(true))
	for list in level_rows.values():
		list.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.Level)<int(b.Level))
	player.leveled_up.connect(_on_level_up)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	random.randomize()
	var layer := CanvasLayer.new()
	layer.layer = UI.LAYER
	add_child(layer)
	ui = UI.new()
	ui.configure(self)
	layer.add_child(ui)
	ui.hide()
	_open_if_needed()

func _on_level_up(_new_level: int) -> void:
	pending += 1
	_open_if_needed()

func _open_if_needed() -> void:
	if active or pending<=0 or player.is_dead or ui==null:
		return
	owns_pause = not get_tree().paused
	get_tree().paused = true
	active = true
	cards = draw_cards()
	ui.show()
	ui.queue_redraw()

func _process(_delta: float) -> void:
	if active and player.is_dead:
		active = false
		ui.hide()
		# Death owns the stopped game. Never unpause it from the choice UI.

func candidates() -> Array:
	var result: Array = []
	for id in levels:
		if int(levels[id])<level_rows[id].size(): result.append(id)
	return result

func draw_cards() -> Array:
	var pool := candidates()
	var result: Array = []
	if pool.size()<=3:
		result = pool.duplicate()
	else:
		for slot in range(3):
			var total := 0
			for id in pool: total += int(records[id].Weight)
			var roll := random.randi_range(1,total)
			for index in range(pool.size()):
				roll -= int(records[pool[index]].Weight)
				if roll<=0:
					result.append(pool[index])
					pool.remove_at(index)
					break
	while result.size()<3: result.append(heal_id)
	return result

func can_reroll() -> bool:
	return active and not player.is_dead and rerolls>0 and candidates().size()>3

func reroll() -> bool:
	if not can_reroll(): return false
	rerolls -= 1
	cards = draw_cards()
	ui.queue_redraw()
	return true

func select(index: int) -> bool:
	if not active or player.is_dead or index<0 or index>=cards.size(): return false
	var id: String = cards[index]
	if id==heal_id:
		player.heal_percent(float(level_rows[id][0].Value))
	else:
		levels[id] += 1
		var totals := {}
		for choice_id in levels:
			if int(levels[choice_id])==0: continue
			var effect: int = records[choice_id].Effect
			totals[effect] = float(totals.get(effect,0.0))+float(level_rows[choice_id][int(levels[choice_id])-1].Value)
		player.apply_choice_modifiers(float(totals.get(Data.Effect.ATTACK_RANGE_ADD,0.0)),float(totals.get(Data.Effect.ATTACK_INTERVAL_SUB,0.0)),float(totals.get(Data.Effect.PICKUP_RADIUS_ADD,0.0)))
	pending -= 1
	if pending>0:
		cards = draw_cards()
		ui.queue_redraw()
	else:
		active = false
		ui.hide()
		if owns_pause and not player.is_dead: get_tree().paused = false
		owns_pause = false
	return true

func card_state(index: int) -> Dictionary:
	var id: String = cards[index]
	var heal := id==heal_id
	var current := int(levels.get(id,0))
	var row: Dictionary = level_rows[id][0 if heal else current]
	return {"id":id,"name":records[id].Name_ko,"heal":heal,"description":row.Desc_ko,
		"level":current,"next":current+1,"max":level_rows[id].size(),
		"hp_before":player.hp,"hp_after":player.healed_hp(float(row.Value)) if heal else player.hp,"max_hp":player.max_hp}
