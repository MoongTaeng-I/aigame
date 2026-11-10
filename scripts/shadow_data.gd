extends RefCounted

static func register_schemas(store: CsvDataStore) -> void:
	store.register_schema("shadow.csv",{"Id":"String","Search_radius":"Float","Chase_leash_distance":"Float","Follow_distance":"Float","Move_speed":"Float","Teleport_distance":"Float","Afterimage_sec":"Float","Body_radius":"Float","Push_weight":"Float","Attack_id":"String","Enemy_push_share":"Float"})
	store.register_schema("shadow_attack.csv",{"Id":"String","Damage":"Int","Range":"Float","Arc_deg":"Float","Interval_sec":"Float"})
	store.register_schema("shadow_motion.csv",{"Id":"String","Attack_id":"String","Motion_sec":"Float","Hit_time_sec":"Float"})

static func validate(store: CsvDataStore) -> String:
	var attacks := store.get_table("shadow_attack.csv")
	var motions := store.get_table("shadow_motion.csv")
	if store.get_row("shadow.csv","igrit").is_empty():
		return error(store,"shadow.csv","igrit","Id","이그리트 행이 필요합니다.")
	for id in store.get_table("shadow.csv"):
		var row := store.get_row("shadow.csv",id)
		if float(row.Enemy_push_share)<0.0 or float(row.Enemy_push_share)>1.0:
			return error(store,"shadow.csv",id,"Enemy_push_share","0 이상 1 이하이어야 합니다.")
		for key in ["Search_radius","Chase_leash_distance","Follow_distance","Move_speed","Teleport_distance","Afterimage_sec","Body_radius","Push_weight"]:
			if float(row[key])<=0.0:
				return error(store,"shadow.csv",id,key,"0보다 큰 값이어야 합니다.")
		if not attacks.has(row.Attack_id):
			return error(store,"shadow.csv",id,"Attack_id","공격 참조가 없습니다.")
	for id in attacks:
		var row: Dictionary = attacks[id]
		if int(row.Damage)<0 or float(row.Range)<=0 or float(row.Arc_deg)<=0 or float(row.Arc_deg)>360 or float(row.Interval_sec)<=0:
			return error(store,"shadow_attack.csv",id,"Damage","공격 수치가 올바르지 않습니다.")
		var count := 0
		for motion in motions.values():
			if motion.Attack_id==id: count += 1
		if count==0:
			return error(store,"shadow_motion.csv","","Attack_id","공격의 모션이 없습니다.")
	for id in motions:
		var row: Dictionary = motions[id]
		if not attacks.has(row.Attack_id) or float(row.Motion_sec)<=0 or float(row.Hit_time_sec)<0 or float(row.Hit_time_sec)>float(row.Motion_sec):
			return error(store,"shadow_motion.csv",id,"Hit_time_sec","참조와 모션 안의 피해 시점을 확인하세요.")
	return ""

static func error(store: CsvDataStore, file: String, id: String, column: String, detail: String) -> String:
	return "res://data/%s, 행 %d, 열 %s: %s" % [file,store.get_source_line(file,id),column,detail]
