extends RefCounted
class_name CombatData

const EnemyActorScript = preload("res://scripts/enemy.gd")
const ExperienceData = preload("res://scripts/experience_data.gd")

static func register_schemas(store: CsvDataStore) -> void:
	store.register_schema("player.csv", {
		"Id": "String", "Name_ko": "String", "Move_speed": "Float",
		"Body_radius": "Float", "Push_weight": "Float", "Note": "String", "Max_hp": "Int",
	})
	store.register_schema("enemy.csv", {
		"Id": "String", "Name_ko": "String", "Move_speed": "Float",
		"Attack_range_type": {"type": "Enum", "values": {"melee": EnemyActorScript.AttackRangeType.MELEE, "ranged": EnemyActorScript.AttackRangeType.RANGED}},
		"Body_radius": "Float", "Push_weight": "Float", "Note": "String", "Max_hp": "Int",
		"Contact_damage": "Int", "Contact_rehit_sec": "Float", "Death_fade_sec": "Float",
		"Shot_interval_sec": {"type": "Optional", "inner": "Float"},
		"Shot_range": {"type": "Optional", "inner": "Float"},
		"Projectile_id": {"type": "Optional", "inner": "String"},
	})
	store.register_schema("spawn.csv", {
		"Id": "String", "Time_start": "Float", "Time_end": "Float", "Enemy_id": "String",
		"Spawn_interval": "Float", "Spawn_count": "Int", "Note": "String",
	})
	store.register_schema("spawn_rule.csv", {"Id": "String", "Max_alive": "Int", "Offscreen_relocate_sec": "Float", "Note": "String"})
	store.register_schema("projectile.csv", {
		"Id": "String", "Speed": "Float", "Damage": "Int", "Body_radius": "Float",
		"Expire_rule": {"type": "Enum", "values": {"distance": 0, "lifetime": 1, "bounds": 2}},
		"Max_distance": {"type": "Optional", "inner": "Float"},
		"Max_lifetime_sec": {"type": "Optional", "inner": "Float"}, "Note": "String",
	})
	store.register_schema("basic_attack.csv", {
		"Id": "String", "Hits_per_attack": "Int", "Hit_gap_sec": "Float",
		"Hit_effect_sec": "Float", "Interval_sec": "Float", "Range": "Float",
		"Damage": "Int", "Knockback_distance": "Float", "Knockback_sec": "Float", "Note": "String",
	})
	ExperienceData.register_schemas(store)

static func validate(store: CsvDataStore) -> String:
	var projectiles: Dictionary = store.get_table("projectile.csv")
	for projectile_id in projectiles:
		var row: Dictionary = projectiles[projectile_id]
		var expires_by_distance := int(row["Expire_rule"]) == 0
		var expires_by_lifetime := int(row["Expire_rule"]) == 1
		if expires_by_distance:
			if row["Max_distance"] == null or float(row["Max_distance"]) <= 0.0:
				return _field_error(store, "projectile.csv", String(projectile_id), "Max_distance", "distance 조건에는 0보다 큰 값이 필요합니다.")
			if row["Max_lifetime_sec"] != null:
				return _field_error(store, "projectile.csv", String(projectile_id), "Max_lifetime_sec", "고르지 않은 소멸 조건의 값은 비워야 합니다.")
		elif expires_by_lifetime:
			if row["Max_lifetime_sec"] == null or float(row["Max_lifetime_sec"]) <= 0.0:
				return _field_error(store, "projectile.csv", String(projectile_id), "Max_lifetime_sec", "lifetime 조건에는 0보다 큰 값이 필요합니다.")
			if row["Max_distance"] != null:
				return _field_error(store, "projectile.csv", String(projectile_id), "Max_distance", "고르지 않은 소멸 조건의 값은 비워야 합니다.")
		elif row["Max_distance"] != null or row["Max_lifetime_sec"] != null:
			return _field_error(store, "projectile.csv", String(projectile_id), "Expire_rule", "bounds 조건에서는 거리와 시간 제한을 비워야 합니다.")
		if float(row["Speed"]) <= 0.0 or int(row["Damage"]) < 0 or float(row["Body_radius"]) <= 0.0:
			return _field_error(store, "projectile.csv", String(projectile_id), "Speed", "투사체 수치가 올바르지 않습니다.")
	for enemy_id in store.get_table("enemy.csv"):
		var row: Dictionary = store.get_row("enemy.csv", String(enemy_id))
		var ranged := int(row["Attack_range_type"]) == EnemyActorScript.AttackRangeType.RANGED
		var shot_values := [row["Shot_interval_sec"], row["Shot_range"], row["Projectile_id"]]
		if ranged:
			for value in shot_values:
				if value == null or (value is String and String(value).is_empty()):
					return _field_error(store, "enemy.csv", String(enemy_id), "Shot_interval_sec", "ranged 적은 발사 열을 모두 입력해야 합니다.")
			if not projectiles.has(String(row["Projectile_id"])):
				return _field_error(store, "enemy.csv", String(enemy_id), "Projectile_id", "projectile.csv에 ID가 없습니다: %s" % row["Projectile_id"])
			if float(row["Shot_interval_sec"]) <= 0.0 or float(row["Shot_range"]) <= 0.0:
				return _field_error(store, "enemy.csv", String(enemy_id), "Shot_interval_sec", "발사 간격과 사거리는 0보다 커야 합니다.")
		elif row["Shot_interval_sec"] != null or row["Shot_range"] != null or row["Projectile_id"] != null:
			return _field_error(store, "enemy.csv", String(enemy_id), "Shot_interval_sec", "melee 적의 발사 열은 비워야 합니다.")
	for enemy_id in store.get_table("enemy.csv"):
		var row: Dictionary = store.get_row("enemy.csv", String(enemy_id))
		if int(row["Max_hp"]) <= 0 or int(row["Contact_damage"]) < 0 or float(row["Contact_rehit_sec"]) < 0.0 or float(row["Death_fade_sec"]) < 0.0:
			return _field_error(store, "enemy.csv", String(enemy_id), "Max_hp", "전투 수치가 올바르지 않습니다.")
	return ""

static func _field_error(store: CsvDataStore, file_name: String, row_id: String, column: String, message: String) -> String:
	return "res://data/%s, 행 %d, 열 %s: %s" % [file_name, store.get_source_line(file_name, row_id), column, message]
