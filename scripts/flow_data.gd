extends RefCounted

static func register_schemas(store: CsvDataStore) -> void:
	store.register_schema("region.csv",{"Id":"String","Name_ko":"String","Locked":"Bool","Locked_text":"String","Note":"String"})

static func validate(store: CsvDataStore) -> String:
	for id in ["region_01","region_02"]:
		if store.get_row("region.csv",id).is_empty(): return "res://data/region.csv, 열 Id: 필요한 지역 %s가 없습니다." % id
	for row in store.get_table("region.csv").values():
		if String(row.Name_ko).strip_edges().is_empty():
			return "res://data/region.csv, 행 %d: 지역 이름과 잠금 안내를 확인하세요." % store.get_source_line("region.csv",row.Id)
	var loading: Dictionary = store.get_row("combat_presentation.csv","Loading_sec")
	if loading.is_empty() or not String(loading.Value).is_valid_float() or not is_finite(float(loading.Value)) or float(loading.Value)<=0:
		return "res://data/combat_presentation.csv, 열 Value: Loading_sec는 유한한 양수여야 합니다."
	return ""
