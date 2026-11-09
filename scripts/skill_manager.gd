extends Node2D

const SkillData = preload("res://scripts/skill_data.gd")
const Cast = preload("res://scripts/skill_cast.gd")
const Area = preload("res://scripts/skill_area.gd")
const UI = preload("res://scripts/skill_ui.gd")

var player: Node2D
var enemies: EnemyManager
var records: Dictionary = {}
var skills: Dictionary = {}
var clock: float = 0.0
var effects: Array = []
var ui: Control

func configure(owner_player: Node2D, enemy_manager: EnemyManager, skill_records: Dictionary, slash_levels: Dictionary, extra_levels: Dictionary = {}, stealth_rule: Dictionary = {}) -> void:
	player = owner_player
	enemies = enemy_manager
	if not stealth_rule.is_empty():
		enemies.wander_radius = float(stealth_rule.Wander_radius)
	records = skill_records.duplicate(true)
	for id in SkillData.IDS:
		if not InputMap.has_action(id):
			InputMap.add_action(id)
		InputMap.action_erase_events(id)
		var event := InputEventKey.new()
		event.physical_keycode = SkillData.standard_key(records[id].Key)
		InputMap.action_add_event(id,event)
		var cast := Cast.new()
		var callback := Callable(self,"_slash_tick") if id=="skill_rapid_slash" else Callable()
		var rows: Array = slash_levels.values() if id=="skill_rapid_slash" else []
		var mode := "ticks"
		if extra_levels.has(id):
			rows = extra_levels[id].values()
			if id=="skill_dash":
				callback = Callable(self,"_dash_start")
				mode = "timed"
			elif id=="skill_stealth":
				callback = Callable(self,"_stealth_start")
				mode = "instant"
			elif id=="skill_dragon_fear":
				callback = Callable(self,"_fear_start")
				mode = "timed"
		cast.configure(rows,1 if records[id].Initially_unlocked else 0,callback,mode,"Cast_sec" if id=="skill_dragon_fear" else "Duration_sec")
		skills[id] = cast

func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = UI.new()
	ui.configure(self)
	layer.add_child(ui)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	for id in SkillData.IDS:
		if event.is_action_pressed(id):
			try_use(id)

func try_use(id: String) -> bool:
	if player.is_dead or get_tree().paused or player.is_stealthed() or player.is_fear_casting():
		return false
	return skills[id].start(clock)

func try_upgrade(id: String) -> bool:
	var cast = skills[id]
	if player.is_dead or get_tree().paused or not cast.implemented or player.enhancement_points<1 or cast.level>=cast.max_level():
		return false
	player.enhancement_points -= 1
	cast.level += 1
	return true

func _physics_process(delta: float) -> void:
	if player==null or player.is_dead or get_tree().paused:
		return
	clock += delta
	for cast in skills.values():
		cast.advance(clock)
	for index in range(effects.size()-1,-1,-1):
		if clock>=float(effects[index].until):
			effects.remove_at(index)
	queue_redraw()

func _slash_tick(stats: Dictionary, at: float) -> void:
	if player.is_dead or player.is_stealthed():
		return
	Area.damage_circle(player.global_position,float(stats.Range),int(stats.Damage),enemies.get_living_enemies())
	effects.append({"center":player.global_position,"radius":float(stats.Range),"until":at+float(stats.Hit_interval_sec)})
	queue_redraw()

func icon_state(id: String) -> Dictionary:
	var cast = skills[id]
	var remaining := maxf(0.0,cast.cooldown_until-clock)
	var cooling: bool = not cast.active and remaining>0.000000001
	var progress := 0.0
	if not cast.snapshot.is_empty() and not cast.active:
		progress = clampf((clock-cast.completed_at)/float(cast.snapshot.Cooldown_sec),0.0,1.0)
	return {"phase":"unimplemented" if not cast.implemented else ("locked" if cast.level==0 else ("active" if cast.active else ("cooldown" if cooling else "ready"))),
		"level":cast.level,"name":records[id].Name_ko,"key":records[id].Key,
		"show_plus":cast.implemented and player.enhancement_points>=1 and cast.level<cast.max_level(),
		"active_border":cast.active,"show_gauge":cooling,"progress":progress,
		"cooldown_text":"%.1f" % (maxf(1.0,ceil(remaining*10.0-0.000000001))/10.0) if cooling else ""}

func _dash_start(stats: Dictionary, _at: float) -> void:
	player.begin_dash(float(stats.Distance),float(stats.Duration_sec))

func _stealth_start(stats: Dictionary, at: float) -> void:
	player.stealth_remaining = float(stats.Duration_sec)
	player.cancel_basic_attack()
	skills["skill_rapid_slash"].cancel(at)

func _fear_start(stats: Dictionary, at: float) -> void:
	player.fear_cast_remaining = float(stats.Cast_sec)
	for enemy in Area.living_in_circle(player.global_position,float(stats.Range),enemies.get_living_enemies()):
		enemy.apply_fear(float(stats.Duration_sec))
	effects.append({"center":player.global_position,"radius":float(stats.Range),"until":at+UI.FEAR_FLASH_SEC})
	queue_redraw()

func _draw() -> void:
	UI.draw_ranges(self,effects)
