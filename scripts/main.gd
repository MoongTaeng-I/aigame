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
const MapScene = preload("res://scenes/map.tscn")
const PlayerScene = preload("res://scenes/player.tscn")

func _ready() -> void:
	_configure_window()
	var data_store = CsvDataStore.new()
	CombatDataScript.register_schemas(data_store)
	var load_error: String = data_store.load_all()
	if not load_error.is_empty():
		_show_data_error(load_error)
		return
	var combat_error := CombatDataScript.validate(data_store)
	if combat_error.is_empty():
		combat_error = ExperienceData.validate(data_store)
	if combat_error.is_empty():
		combat_error = SkillData.validate(data_store)
	if combat_error.is_empty():
		combat_error = ChoiceData.validate(data_store,float(data_store.get_row("basic_attack.csv","attack_01").Interval_sec))
	if not combat_error.is_empty():
		_show_data_error(combat_error)
		return
	var player_record: Dictionary = data_store.get_row("player.csv", "player_01")
	if player_record.is_empty():
		_show_data_error("res://data/player.csv, 행 1, 열 Id: 플레이어 ID player_01이 없습니다.")
		return
	var spawn_rule: Dictionary = data_store.get_row("spawn_rule.csv", "rule_01")
	if spawn_rule.is_empty():
		_show_data_error("res://data/spawn_rule.csv, 행 1, 열 Id: 규칙 ID rule_01이 없습니다.")
		return
	var enemy_records: Dictionary = data_store.get_table("enemy.csv")
	var spawn_records: Dictionary = data_store.get_table("spawn.csv")
	var data_error := _validate_gameplay_data(data_store, player_record, enemy_records, spawn_records, spawn_rule)
	if not data_error.is_empty():
		_show_data_error(data_error)
		return
	var map = MapScene.instantiate()
	add_child(map)
	var player = PlayerScene.instantiate()
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
		data_store.get_row("basic_attack.csv", "attack_01")
	)
	enemy_manager.name = "EnemyManager"
	map.add_child(enemy_manager)
	var experience_manager := ExperienceManager.new()
	experience_manager.name = "ExperienceManager"
	experience_manager.configure(player,enemy_manager,data_store.get_row("xp_rule.csv","xp_rule_01"))
	map.add_child(experience_manager)
	var skill_manager := SkillManager.new()
	skill_manager.name = "SkillManager"
	skill_manager.configure(player,enemy_manager,data_store.get_table("skill.csv"),data_store.get_table("skill_rapid_slash_level.csv"),{"skill_dash":data_store.get_table("skill_dash_level.csv"),"skill_stealth":data_store.get_table("skill_stealth_level.csv"),"skill_dragon_fear":data_store.get_table("skill_dragon_fear_level.csv")},data_store.get_row("stealth_rule.csv","stealth_rule_01"))
	map.add_child(skill_manager)
	var choices := ChoiceManager.new()
	choices.name = "ChoiceManager"
	choices.configure(player,data_store.get_table("choice.csv"),data_store.get_table("choice_level.csv"),data_store.get_row("choice_rule.csv","choice_rule_01"))
	map.add_child(choices)

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
	push_error(message)
	get_tree().paused = true
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
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
