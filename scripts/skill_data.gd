extends RefCounted

const IDS := ["skill_dash","skill_rapid_slash","skill_stealth","skill_dragon_fear"]

static func register_schemas(store: CsvDataStore) -> void:
	store.register_schema("skill.csv", {"Id":"String","Name_ko":"String","Key":"String","Initially_unlocked":"Bool","Note":"String"})
	store.register_schema("skill_rapid_slash_level.csv", {"Id":"String","Level":"Int","Damage":"Int","Hits":"Int","Hit_interval_sec":"Float","Range":"Float","Cooldown_sec":"Float","Note":"String"})

static func standard_key(name: String) -> int:
	var code := OS.find_keycode_from_string(name)
	return code if code != KEY_NONE and OS.get_keycode_string(code) == name else KEY_NONE

static func validate(store: CsvDataStore) -> String:
	var skills := store.get_table("skill.csv")
	for id in IDS:
		if not skills.has(id):
			return _error(store,"skill.csv",id,"Id","필수 스킬이 없습니다: "+id)
	var used: Array = []
	for id in skills:
		var key: String = skills[id]["Key"]
		if standard_key(key)==KEY_NONE:
			return _error(store,"skill.csv",id,"Key","Godot 표준 키 이름과 정확히 일치해야 합니다: "+key)
		if key in ["W","A","S","D"] or used.has(key):
			return _error(store,"skill.csv",id,"Key","이동 키 또는 중복 키입니다: "+key)
		used.append(key)
	var levels: Array = store.get_table("skill_rapid_slash_level.csv").values()
	if levels.is_empty():
		return _error(store,"skill_rapid_slash_level.csv","","Level","레벨 행이 없습니다.")
	levels.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.Level)<int(b.Level))
	for i in range(levels.size()):
		var row: Dictionary = levels[i]
		if int(row.Level)!=i+1:
			return _error(store,"skill_rapid_slash_level.csv",row.Id,"Level","1부터 빠짐없이 이어져야 합니다.")
		for col in ["Damage","Hits"]:
			if int(row[col])<1:
				return _error(store,"skill_rapid_slash_level.csv",row.Id,col,"1 이상이어야 합니다.")
		for col in ["Range","Cooldown_sec"]:
			if float(row[col])<=0.0:
				return _error(store,"skill_rapid_slash_level.csv",row.Id,col,"0보다 커야 합니다.")
		if int(row.Hits)>=2 and float(row.Hit_interval_sec)<=0.0:
			return _error(store,"skill_rapid_slash_level.csv",row.Id,"Hit_interval_sec","여러 타격에는 0보다 큰 간격이 필요합니다.")
	return ""

static func _error(store: CsvDataStore, file: String, id: String, col: String, detail: String) -> String:
	return "res://data/%s, 행 %d, 열 %s: %s" % [file,store.get_source_line(file,id),col,detail]
