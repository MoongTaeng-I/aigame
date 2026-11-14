extends Node2D

const CsvDataStore = preload("res://scripts/csv_data_store.gd")
const CombatDataScript = preload("res://scripts/combat_data.gd")
const ExperienceData = preload("res://scripts/experience_data.gd")
const ExperienceManager = preload("res://scripts/experience_manager.gd")
const EnemyManagerScript = preload("res://scripts/enemy_manager.gd")
const EnemyActorScript = preload("res://scripts/enemy.gd")
const SkillData = preload("res://scripts/skill_data.gd")
const SkillManager = preload("res://scripts/skill_manager.gd")
const ChoiceData = preload("res://scripts/choice_data.gd")
const ChoiceManager = preload("res://scripts/choice_manager.gd")
const ShadowData = preload("res://scripts/shadow_data.gd")
const ShadowManager = preload("res://scripts/shadow_manager.gd")
const HitFxData = preload("res://scripts/hit_fx_data.gd")
const HitFx = preload("res://scripts/hit_fx.gd")
const MapScene = preload("res://scenes/map.tscn")
const PlayerScene = preload("res://scenes/player.tscn")

signal round_ended(result: Dictionary)
var supplied_data: CsvDataStore
var managed_flow := false
var round_finished := false
var kills := 0
var round_nodes: Dictionary = {}

func _ready() -> void:
	_configure_window()
	var data_store: CsvDataStore = supplied_data
	if data_store==null:
		data_store = CsvDataStore.new()
		CombatDataScript.register_schemas(data_store)
		var load_error := data_store.load_all()
		if not load_error.is_empty():
			_show_data_error(load_error)
			return
	var error := validate_store(data_store)
	if not error.is_empty():
		_show_data_error(error)
		return
	_create_game(data_store)

func validate_store(data_store: CsvDataStore) -> String:
	var combat_error := CombatDataScript.validate(data_store)
	if combat_error.is_empty():
		combat_error = ExperienceData.validate(data_store)
	if combat_error.is_empty():
		combat_error = SkillData.validate(data_store)
	if combat_error.is_empty():
		combat_error = ChoiceData.validate(data_store,float(data_store.get_row("basic_attack.csv","attack_01").Interval_sec))
	if combat_error.is_empty():
		combat_error = ShadowData.validate(data_store)
	if combat_error.is_empty():
		combat_error = HitFxData.validate(data_store)
	if not combat_error.is_empty():
		return combat_error
	var boss_error := preload("res://scripts/boss_data.gd").validate(data_store)
	if not boss_error.is_empty():
		return boss_error
	var player_record: Dictionary = data_store.get_row("player.csv", "player_01")
	if player_record.is_empty():
		return "res://data/player.csv, 행 1, 열 Id: 플레이어 ID player_01이 없습니다."
	var spawn_rule: Dictionary = data_store.get_row("spawn_rule.csv", "rule_01")
	if spawn_rule.is_empty():
		return "res://data/spawn_rule.csv, 행 1, 열 Id: 규칙 ID rule_01이 없습니다."
	var enemy_records: Dictionary = data_store.get_table("enemy.csv")
	var spawn_records: Dictionary = data_store.get_table("spawn.csv")
	var data_error := _validate_gameplay_data(data_store, player_record, enemy_records, spawn_records, spawn_rule)
	if not data_error.is_empty():
		return data_error
	return preload("res://scripts/flow_data.gd").validate(data_store)

func _create_game(data_store: CsvDataStore) -> void:
	var player_record: Dictionary = data_store.get_row("player.csv","player_01")
	var spawn_rule: Dictionary = data_store.get_row("spawn_rule.csv","rule_01")
	var enemy_records: Dictionary = data_store.get_table("enemy.csv")
	var spawn_records: Dictionary = data_store.get_table("spawn.csv")
	var map = MapScene.instantiate()
	add_child(map)
	var player = PlayerScene.instantiate()
	player.managed_results = managed_flow
	player.move_speed = float(player_record["Move_speed"])
	player.configure_body(float(player_record["Body_radius"]), float(player_record["Push_weight"]))
	player.configure_combat(int(player_record["Max_hp"]), data_store.get_row("basic_attack.csv", "attack_01"))
	player.configure_progression(data_store.get_table("level.csv"),float(player_record["Pickup_radius"]))
	map.add_child(player)
	player.position = Vector2.ZERO
	var enemy_manager = EnemyManagerScript.new()
	enemy_manager.configure(
		player,
		map.get_map_rect(),
		enemy_records,
		spawn_records,
		int(spawn_rule["Max_alive"]),
		float(spawn_rule["Offscreen_relocate_sec"]),
		data_store.get_table("projectile.csv"),
		data_store.get_row("basic_attack.csv", "attack_01"),
		float(spawn_rule["Separation_gap"]),
		int(spawn_rule["Push_iterations"]),
		data_store.get_table("enemy_scaling.csv")
	)
	enemy_manager.name = "EnemyManager"
	map.add_child(enemy_manager)
	var hit_fx := HitFx.new()
	hit_fx.name = "HitFx"
	hit_fx.configure(enemy_manager,data_store.get_row("hit_fx.csv","hit_spark"))
	map.add_child(hit_fx)
	var experience_manager := ExperienceManager.new()
	experience_manager.name = "ExperienceManager"
	experience_manager.configure(player,enemy_manager,data_store.get_row("xp_rule.csv","xp_rule_01"))
	map.add_child(experience_manager)
	var skill_manager := SkillManager.new()
	skill_manager.name = "SkillManager"
	skill_manager.configure(player,enemy_manager,data_store.get_table("skill.csv"),data_store.get_table("skill_rapid_slash_level.csv"),{"skill_dash":data_store.get_table("skill_dash_level.csv"),"skill_stealth":data_store.get_table("skill_stealth_level.csv"),"skill_dragon_fear":data_store.get_table("skill_dragon_fear_level.csv")},data_store.get_row("stealth_rule.csv","stealth_rule_01"))
	map.add_child(skill_manager)
	var choices := ChoiceManager.new()
	var shadows := ShadowManager.new()
	var capacity: int = ShadowManager.MAX_TYPES
	shadows.name = "ShadowManager"
	shadows.configure(player,enemy_manager,data_store.get_table("shadow.csv"),data_store.get_table("shadow_attack.csv"),data_store.get_table("shadow_motion.csv"),capacity)
	map.add_child(shadows)
	choices.name = "ChoiceManager"
	choices.configure(player,data_store.get_table("choice.csv"),data_store.get_table("choice_level.csv"),data_store.get_row("choice_rule.csv","choice_rule_01"),shadows)
	map.add_child(choices)
	var boss_director := preload("res://scripts/boss_director.gd").new()
	boss_director.configure(enemy_manager,data_store.get_table("boss.csv"),data_store.get_table("boss_action.csv"),data_store.get_table("stage_timeline.csv"),data_store.get_row("boss_rule.csv","boss_rule_01"))
	boss_director.managed_results = managed_flow
	map.add_child(boss_director)
	boss_director.toast_view.pause_with_game = managed_flow
	if preload("res://scripts/elf_debug_recorder.gd").requested():
		var elf_debug := preload("res://scripts/elf_debug_recorder.gd").new()
		elf_debug.name = "ElfDebugRecorder"
		elf_debug.configure(enemy_manager)
		add_child(elf_debug)
	var temporary_hud := preload("res://scripts/temporary_hud.gd").new()
	temporary_hud.name = "TemporaryHud"
	temporary_hud.configure(enemy_manager,shadows,skill_manager.ui)
	map.add_child(temporary_hud)

	if managed_flow:
		player._hp_label.position = Vector2(20,558)
		experience_manager._label.position = Vector2(20,596)
		player.died.connect(_end_round.bind(false))
		boss_director.run_completed.connect(_end_round.bind(true))
		enemy_manager.enemy_died.connect(_count_kill)
	round_nodes = {"map":map,"player":player,"manager":enemy_manager,"skills":skill_manager,"choices":choices,"shadows":shadows,"director":boss_director}

func _count_kill(_enemy: EnemyActor) -> void:
	if not round_finished: kills+=1

func _end_round(cleared: bool) -> void:
	if round_finished: return
	round_finished = true
	var player: Node2D = round_nodes.player
	var names: Array[String] = []
	for actor in round_nodes.shadows.actors: names.append(String(actor.config.Name_ko))
	var result := {"cleared":cleared,"seconds":round_nodes.manager._elapsed_seconds,"level":player.level,"kills":kills,"shadows":names}
	player.run_finished = true
	round_nodes.director.result_locked = true
	round_nodes.choices.result_locked = true
	round_nodes.choices.active = false
	round_nodes.choices.pending = 0
	round_nodes.choices.ui.hide()
	round_nodes.director.toast_view.result_keep_running = true
	get_tree().paused = true
	round_ended.emit(result)

func _validate_gameplay_data(data_store: Variant, player_record: Dictionary, enemy_records: Dictionary, spawn_records: Dictionary, spawn_rule: Dictionary) -> String:
	if float(player_record["Body_radius"]) <= 0.0:
		return _data_field_error(data_store, "player.csv", String(player_record["Id"]), "Body_radius", "0보다 큰 값이어야 합니다.")
	if float(player_record["Push_weight"]) <= 0.0:
		return _data_field_error(data_store, "player.csv", String(player_record["Id"]), "Push_weight", "0보다 큰 값이어야 합니다.")
	for enemy_id_variant in enemy_records:
		var enemy_record: Dictionary = enemy_records[enemy_id_variant]
		if float(enemy_record["Move_speed"]) < 0.0:
			return _data_field_error(data_store, "enemy.csv", String(enemy_id_variant), "Move_speed", "0 이상이어야 합니다.")
		if float(enemy_record["Body_radius"]) <= 0.0:
			return _data_field_error(data_store, "enemy.csv", String(enemy_id_variant), "Body_radius", "0보다 큰 값이어야 합니다.")
		if float(enemy_record["Push_weight"]) <= 0.0:
			return _data_field_error(data_store, "enemy.csv", String(enemy_id_variant), "Push_weight", "0보다 큰 값이어야 합니다.")
	for spawn_id_variant in spawn_records:
		var spawn_id := String(spawn_id_variant)
		var spawn_record: Dictionary = spawn_records[spawn_id]
		var enemy_id := String(spawn_record["Enemy_id"])
		if not enemy_records.has(enemy_id):
			return _data_field_error(data_store, "spawn.csv", spawn_id, "Enemy_id", "enemy.csv에 ID %s가 없습니다." % enemy_id)
		if float(spawn_record["Spawn_interval"]) <= 0.0:
			return _data_field_error(data_store, "spawn.csv", spawn_id, "Spawn_interval", "0보다 큰 값이어야 합니다.")
	if int(spawn_rule["Max_alive"]) < 0:
		return _data_field_error(data_store, "spawn_rule.csv", String(spawn_rule["Id"]), "Max_alive", "0 이상이어야 합니다.")
	if float(spawn_rule["Separation_gap"]) < 0.0:
		return _data_field_error(data_store,"spawn_rule.csv",String(spawn_rule["Id"]),"Separation_gap","0 이상이어야 합니다.")
	if int(spawn_rule["Push_iterations"]) < 1:
		return _data_field_error(data_store,"spawn_rule.csv",String(spawn_rule["Id"]),"Push_iterations","1 이상이어야 합니다.")
	if float(spawn_rule["Offscreen_relocate_sec"]) < 0.0:
		return _data_field_error(data_store, "spawn_rule.csv", String(spawn_rule["Id"]), "Offscreen_relocate_sec", "0 이상이어야 합니다.")
	return ""

func _data_field_error(data_store: Variant, file_name: String, row_id: String, column_name: String, message: String) -> String:
	var row_number: int = int(data_store.get_source_line(file_name, row_id))
	return "res://data/%s, 행 %d, 열 %s: %s" % [file_name, row_number, column_name, message]

func _configure_window() -> void:
	var window := get_window()
	window.title = "나 혼자만 서바이벌"
	window.mode = Window.MODE_WINDOWED
	window.unresizable = true
	window.size = Vector2i(1280, 720)

func _show_data_error(message: String) -> void:
	show_data_error(self,message)

static func show_data_error(source: Node, message: String) -> void:
	push_error(message)
	source.get_tree().paused = true
	var layer := CanvasLayer.new()
	layer.layer = 200
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	source.add_child(layer)
	var background := ColorRect.new()
	background.color = Color("#111018")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)
	var label := Label.new()
	label.text = "데이터 오류\n\n" + message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("#ff7b83"))
	label.add_theme_font_size_override("font_size", 24)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 32
	label.offset_top = 32
	label.offset_right = -32
	label.offset_bottom = -32
	layer.add_child(label)
