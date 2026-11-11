extends RefCounted

static func register_schemas(store: CsvDataStore) -> void:
	store.register_schema("hit_fx.csv",{"Id":"String","Enabled":"Int","Duration_sec":"Float","Radius":"Float","Core_radius":"Float","Max_active":"Int","Outer_color":"String","Core_color":"String"})

static func validate(store: CsvDataStore) -> String:
	var row: Dictionary = store.get_row("hit_fx.csv","hit_spark")
	if row.is_empty(): return error(store,"Id","hit_spark 행이 없습니다.")
	if int(row.Enabled) not in [0,1]: return error(store,"Enabled","0 또는 1이어야 합니다.")
	for field in ["Duration_sec","Radius","Core_radius"]:
		if not is_finite(float(row[field])) or float(row[field])<=0.0:
			return error(store,field,"유한한 양수이어야 합니다.")
	if float(row.Core_radius)>float(row.Radius): return error(store,"Core_radius","Radius 이하여야 합니다.")
	if int(row.Max_active)<1: return error(store,"Max_active","1 이상이어야 합니다.")
	for field in ["Outer_color","Core_color"]:
		if not Color.html_is_valid(String(row[field])): return error(store,field,"HTML 색상이어야 합니다.")
	return ""

static func error(store: CsvDataStore, field: String, message: String) -> String:
	return "res://data/hit_fx.csv, 행 %d, 열 %s: %s" % [maxi(1,store.get_source_line("hit_fx.csv","hit_spark")),field,message]
