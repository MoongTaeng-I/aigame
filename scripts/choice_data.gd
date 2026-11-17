extends RefCounted

enum Effect { ATTACK_RANGE_ADD, ATTACK_INTERVAL_SUB, PICKUP_RADIUS_ADD, HEAL, SHADOW_IGRIT, SHADOW_CHARGER_TEST, SHADOW_BELION, ATTACK_TARGETS_ADD }
const EFFECTS := {"attack_range_add":Effect.ATTACK_RANGE_ADD,"attack_interval_sub":Effect.ATTACK_INTERVAL_SUB,"pickup_radius_add":Effect.PICKUP_RADIUS_ADD,"heal":Effect.HEAL,"shadow_igrit":Effect.SHADOW_IGRIT,"shadow_charger_test":Effect.SHADOW_CHARGER_TEST,"shadow_belion":Effect.SHADOW_BELION,"attack_targets_add":Effect.ATTACK_TARGETS_ADD}

static func shadow_id(effect: int) -> String:
	if effect==Effect.SHADOW_IGRIT: return "igrit"
	if effect==Effect.SHADOW_CHARGER_TEST: return "charger_test"
	if effect==Effect.SHADOW_BELION: return "belion"
	return ""

static func register_schemas(store: CsvDataStore) -> void:
	store.register_schema("choice.csv",{"Id":"String","Name_ko":"String","Effect":{"type":"Enum","values":EFFECTS},"Weight":"Int","Note":"String"})
	store.register_schema("choice_level.csv",{"Id":"String","Choice_id":"String","Level":"Int","Value":"Float","Desc_ko":"String","Note":"String"})
	store.register_schema("choice_rule.csv",{"Id":"String","Reroll_count":"Int","Note":"String"})

static func validate(store: CsvDataStore, base_interval: float) -> String:
	var choices := store.get_table("choice.csv")
	var levels := store.get_table("choice_level.csv")
	var heal_count := 0
	for id in choices:
		var row: Dictionary = choices[id]
		if int(row.Effect)==Effect.HEAL:
			heal_count += 1
			if int(row.Weight)!=0:
				return _error(store,"choice.csv",id,"Weight","heal의 가중치는 0이어야 합니다.")
		elif int(row.Weight)<1:
			return _error(store,"choice.csv",id,"Weight","일반 선택지 가중치는 1 이상이어야 합니다.")
	if heal_count!=1:
		return _error(store,"choice.csv","","Effect","heal 행은 정확히 1개여야 합니다.")
	for id in levels:
		if not choices.has(levels[id].Choice_id):
			return _error(store,"choice_level.csv",id,"Choice_id","참조 선택지가 없습니다.")
	for id in choices:
		var rows: Array = []
		for row in levels.values():
			if row.Choice_id==id: rows.append(row)
		rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.Level)<int(b.Level))
		var heal: bool = int(choices[id].Effect)==Effect.HEAL
		if rows.is_empty() or (heal and rows.size()!=1):
			return _error(store,"choice_level.csv","","Level","일반 레벨 행이 필요하며 heal은 1행이어야 합니다.")
		if not shadow_id(int(choices[id].Effect)).is_empty() and (rows.size()!=1 or float(rows[0].Value)!=1.0):
			return _error(store,"choice_level.csv",rows[0].Id,"Level","종류당 1마리 그림자 카드는 소환 1행(Value 1)이어야 합니다.")
		for i in range(rows.size()):
			var row: Dictionary = rows[i]
			if int(row.Level)!=i+1:
				return _error(store,"choice_level.csv",row.Id,"Level","1부터 빠짐없이 이어져야 합니다.")
			var value := float(row.Value)
			if (heal and (value<=0 or value>100)) or (not heal and value<0):
				return _error(store,"choice_level.csv",row.Id,"Value","일반 값은 0 이상, 회복 비율은 0 초과 100 이하입니다.")
			if int(choices[id].Effect)==Effect.ATTACK_TARGETS_ADD and (value<1 or value!=floorf(value)):
				return _error(store,"choice_level.csv",row.Id,"Value","기본 공격 대상 추가 수는 1 이상의 정수여야 합니다.")
			if int(choices[id].Effect)==Effect.ATTACK_INTERVAL_SUB and base_interval-value<0:
				return _error(store,"choice_level.csv",row.Id,"Value","기본 공격 간격에서 빼면 음수가 됩니다.")
	var rule := store.get_row("choice_rule.csv","choice_rule_01")
	if rule.is_empty() or int(rule.Reroll_count)<0:
		return _error(store,"choice_rule.csv","choice_rule_01","Reroll_count","필수 행과 0 이상 횟수가 필요합니다.")
	return ""

static func _error(store: CsvDataStore, file: String, id: String, column: String, detail: String) -> String:
	return "res://data/%s, 행 %d, 열 %s: %s" % [file,store.get_source_line(file,id),column,detail]
