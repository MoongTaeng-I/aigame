extends RefCounted

# REGION-01: per-region content and look. Locked regions may leave these blank; an open region must
# fill every one of them (validate below).
const REGION_COLUMNS := {
	"Card_image":"Path","Ground_texture":"Path","Ground_brightness":"Float","Props_texture":"Path","Props_cols":"Int",
	"World_tint":"String","Weather":"String","Snow_alpha":"Float","Fog_strength":"Float","Bgm_stage":"String","Bgm_boss":"String","Forest_seed":"Int",
}
const WEATHERS := ["snow","none"]
# The first four prop columns are trees (map edge rows); more columns are inner props.
const MIN_PROPS_COLS := 4
const REGION_TABLES := ["spawn.csv","stage_timeline.csv","enemy_scaling.csv"]

static func register_schemas(store: CsvDataStore) -> void:
	var schema := {"Id":"String","Name_ko":"String","Locked":"Bool","Locked_text":"String","Note":"String"}
	for column in REGION_COLUMNS: schema[column] = {"type":"Optional","inner":REGION_COLUMNS[column]}
	store.register_schema("region.csv",schema)

static func validate(store: CsvDataStore) -> String:
	for id in ["region_01","region_02"]:
		if store.get_row("region.csv",id).is_empty(): return "res://data/region.csv, 열 Id: 필요한 지역 %s가 없습니다." % id
	for row in store.get_table("region.csv").values():
		if String(row.Name_ko).strip_edges().is_empty():
			return "res://data/region.csv, 행 %d: 지역 이름과 잠금 안내를 확인하세요." % store.get_source_line("region.csv",row.Id)
		if not row.Locked:
			var error := _validate_open_region(store,row)
			if not error.is_empty(): return error
	var region_error := validate_region_rows(store)
	if not region_error.is_empty(): return region_error
	var loading: Dictionary = store.get_row("combat_presentation.csv","Loading_sec")
	if loading.is_empty() or not String(loading.Value).is_valid_float() or not is_finite(float(loading.Value)) or float(loading.Value)<=0:
		return "res://data/combat_presentation.csv, 열 Value: Loading_sec는 유한한 양수여야 합니다."
	return ""

static func _validate_open_region(store: CsvDataStore, row: Dictionary) -> String:
	for column in REGION_COLUMNS:
		if row.get(column)==null or (row[column] is String and String(row[column]).strip_edges().is_empty()):
			return _error(store,"region.csv",row.Id,column,"열린 지역은 값이 필요합니다.")
	for column in ["Card_image","Ground_texture","Props_texture"]:
		if not ResourceLoader.exists(row[column],"Texture2D"): return _error(store,"region.csv",row.Id,column,"사용 가능한 이미지가 필요합니다.")
	for column in ["Ground_brightness","Snow_alpha","Fog_strength"]:
		var value := float(row[column])
		if not is_finite(value) or value<0 or value>1: return _error(store,"region.csv",row.Id,column,"0~1의 유한한 값이어야 합니다.")
	if int(row.Props_cols)<MIN_PROPS_COLS: return _error(store,"region.csv",row.Id,"Props_cols","%d 이상이어야 합니다(앞 4칸은 나무)." % MIN_PROPS_COLS)
	if not Color.html_is_valid(String(row.World_tint)): return _error(store,"region.csv",row.Id,"World_tint","HTML 색이 필요합니다.")
	if not (String(row.Weather) in WEATHERS): return _error(store,"region.csv",row.Id,"Weather","snow 또는 none이어야 합니다.")
	for column in ["Bgm_stage","Bgm_boss"]:
		if store.get_row("sound.csv",String(row[column])).is_empty(): return _error(store,"region.csv",row.Id,column,"sound.csv에 ID가 없습니다: %s" % row[column])
	return ""

# Every Region_id must name a region; each open region needs spawn rows, exactly one scaling row at
# time 0 (uniqueness per region is checked in CombatData) and a final-boss timeline row.
static func validate_region_rows(store: CsvDataStore) -> String:
	var regions := store.get_table("region.csv")
	for file in REGION_TABLES:
		for row in store.get_table(file).values():
			if not regions.has(String(row.get("Region_id",""))): return _error(store,file,row.Id,"Region_id","region.csv에 지역이 없습니다: %s" % row.get("Region_id",""))
	for region in regions.values():
		if region.Locked: continue
		var id := String(region.Id)
		if rows_for(store.get_table("spawn.csv"),id).is_empty(): return "res://data/spawn.csv, 열 Region_id: 열린 지역 %s의 생성 행이 없습니다." % id
		var zero := 0
		for row in rows_for(store.get_table("enemy_scaling.csv"),id).values():
			if float(row.Time_start)==0.0: zero+=1
		if zero!=1: return "res://data/enemy_scaling.csv, 열 Region_id: 열린 지역 %s에는 시각0 강화 행이 정확히 1개 필요합니다." % id
		var final := 0
		for row in rows_for(store.get_table("stage_timeline.csv"),id).values():
			if bool(store.get_row("boss.csv",String(row.Boss_id)).get("Is_final",false)): final+=1
		if final<1: return "res://data/stage_timeline.csv, 열 Region_id: 열린 지역 %s에는 최종 보스 행이 필요합니다." % id
	return ""

# Rows of one region in file order. Rows without a Region_id column (synthetic test tables) belong to every region.
static func rows_for(table: Dictionary, region_id: String) -> Dictionary:
	var rows := {}
	for id in table:
		var row: Dictionary = table[id]
		if not row.has("Region_id") or String(row.Region_id)==region_id: rows[id] = row
	return rows

# The first open region by Id; used when a round is created without a chosen region (main.tscn alone).
static func default_region(store: CsvDataStore) -> String:
	var ids: Array = store.get_table("region.csv").keys()
	ids.sort()
	for id in ids:
		if not store.get_row("region.csv",id).Locked: return String(id)
	return ""

static func _error(store: CsvDataStore, file: String, row_id: String, column: String, message: String) -> String:
	return "res://data/%s, 행 %d, 열 %s: %s" % [file,store.get_source_line(file,row_id),column,message]
