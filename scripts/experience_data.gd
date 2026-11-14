extends RefCounted

static func register_schemas(store: CsvDataStore) -> void:
	var player_schema: Dictionary = store.schemas["player.csv"].duplicate(true)
	player_schema["Pickup_radius"] = "Float"
	store.register_schema("player.csv", player_schema)
	var enemy_schema: Dictionary = store.schemas["enemy.csv"].duplicate(true)
	enemy_schema["Xp_value"] = "Int"
	store.register_schema("enemy.csv", enemy_schema)
	store.register_schema("level.csv", {"Id":"String", "Level":"Int", "Xp_to_next":"Int", "Note":"String"})
	store.register_schema("xp_rule.csv", {"Id":"String", "Pull_start_speed":"Float", "Pull_accel":"Float", "Orb_radius":"Float", "Max_ground_orbs":"Int", "Skill_point_every_levels":"Int", "Note":"String"})

static func validate(store: CsvDataStore) -> String:
	for row_id in store.get_table("enemy.csv"):
		if int(store.get_row("enemy.csv", row_id)["Xp_value"]) < 0:
			return _error(store,"enemy.csv",row_id,"Xp_value","0 이상이어야 합니다.")
	for row_id in store.get_table("player.csv"):
		if float(store.get_row("player.csv", row_id)["Pickup_radius"]) <= 0.0:
			return _error(store,"player.csv",row_id,"Pickup_radius","0보다 커야 합니다.")
	var levels: Array = store.get_table("level.csv").values()
	if levels.is_empty():
		return _error(store,"level.csv","","Level","레벨 행이 없습니다.")
	levels.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a["Level"]) < int(b["Level"]))
	for index in range(levels.size()):
		var row: Dictionary = levels[index]
		if int(row["Level"]) != index + 1:
			return _error(store,"level.csv",row["Id"],"Level","1부터 빠짐없이 이어져야 합니다.")
		if int(row["Xp_to_next"]) < 1:
			return _error(store,"level.csv",row["Id"],"Xp_to_next","1 이상이어야 합니다.")
	var rule := store.get_row("xp_rule.csv","xp_rule_01")
	if rule.is_empty():
		return _error(store,"xp_rule.csv","","Id","xp_rule_01이 없습니다.")
	for column in ["Pull_start_speed","Pull_accel","Orb_radius"]:
		if float(rule[column]) <= 0.0:
			return _error(store,"xp_rule.csv","xp_rule_01",column,"0보다 커야 합니다.")
	if int(rule["Max_ground_orbs"]) < 1:
		return _error(store,"xp_rule.csv","xp_rule_01","Max_ground_orbs","1 이상이어야 합니다.")
	if int(rule["Skill_point_every_levels"]) < 1:
		return _error(store,"xp_rule.csv","xp_rule_01","Skill_point_every_levels","1 이상이어야 합니다.")
	return ""

static func _error(store: CsvDataStore, file_name: String, row_id: String, column: String, detail: String) -> String:
	return "res://data/%s, 행 %d, 열 %s: %s" % [file_name,maxi(1,store.get_source_line(file_name,row_id)),column,detail]
