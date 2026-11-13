extends RefCounted

static func register_schemas(store: CsvDataStore) -> void:
	store.register_schema("combat_presentation.csv",{"Id":"String","Value":"String"})
	store.register_schema("boss.csv",{"Id":"String","Enemy_id":"String","Is_final":"Bool","Note":"String","Detect_range":{"type":"Optional","inner":"Float"}})
	store.schemas["boss.csv"]["Move_speed_ref_enemy"] = {"type":"Optional","inner":"String"}
	store.schemas["boss.csv"]["Move_speed_mult"] = {"type":"Optional","inner":"Float"}
	store.register_schema("stage_timeline.csv",{"Id":"String","Time_mmss":"Int","Boss_id":"String","Note":"String"})
	var action := {"Id":"String","Boss_id":"String","Kind":{"type":"Enum","values":{"basic":0,"dash":1,"slam":2,"ranged_basic":3,"push":4,"burst":5,"stealth":6,"tri_dash":7,"blink_strike":8,"chase":9,"ice_zone":10}},"Use_range":"Float","Damage":"Int","Telegraph_sec":"Float","Recovery_sec":"Float","Cooldown_sec":"Float","Note":"String"}
	for field in ["Tri_width","Tri_length","Area_radius","Strike_interval_sec","Strike_min_distance","Zone_radius","Zone_life_sec","Freeze_sec","Flee_trigger_range","Flee_speed","Flee_distance"]:
		action[field] = {"type":"Optional","inner":"Float"}
	for field in ["Strike_count","Zone_count"]:
		action[field] = {"type":"Optional","inner":"Int"}
	for field in ["Range","Arc_deg","Dash_speed","Dash_distance","Slam_radius"]:
		action[field] = {"type":"Optional","inner":"Float"}
	action["Pick_weight"] = {"type":"Optional","inner":"Int"}
	action["Projectile_id"] = {"type":"Optional","inner":"String"}
	for field in ["Shot_interval_sec","Duration_sec","Push_distance","Push_sec"]:
		action[field] = {"type":"Optional","inner":"Float"}
	store.register_schema("boss_action.csv",action)
	store.register_schema("boss_rule.csv",{"Id":"String","Warn_sec":"Float","Emerge_sec":"Float","Gate_radius":"Float","Toast_text":"String","Note":"String"})

static func mmss_seconds(value: int) -> int:
	if value<0 or value%100>59: return -1
	return (value/100)*60+value%100

static func validate(store: CsvDataStore) -> String:
	var bosses := store.get_table("boss.csv")
	for row in store.get_table("boss_action.csv").values():
		if int(row.Kind) not in range(11): return error(store,"boss_action.csv",row.Id,"Kind","등록된 행동 종류가 아닙니다.")
	for id in bosses:
		var boss: Dictionary = bosses[id]
		if not store.get_table("enemy.csv").has(boss.Enemy_id): return error(store,"boss.csv",id,"Enemy_id","참조하는 적이 없습니다.")
		var counts := [0,0,0,0,0,0,0,0,0,0,0]
		for row in store.get_table("boss_action.csv").values():
			if row.Boss_id==id: counts[int(row.Kind)]+=1
		var expected: Array = [0,0,0,0,0,0,0,1,1,1,1] if counts[7]>0 else ([0,0,0,1,1,1,1,0,0,0,0] if counts[3]>0 else [1,1,1,0,0,0,0,0,0,0,0])
		if counts!=expected: return error(store,"boss_action.csv","","Kind","보스 행동 구성의 누락·중복 또는 서로 다른 BT 종류 혼합입니다.")
		if counts[7]>0:
			var ref: String = String(boss.get("Move_speed_ref_enemy", ""))
			if not store.get_table("enemy.csv").has(ref): return error(store,"boss.csv",id,"Move_speed_ref_enemy","참조 적이 없습니다.")
			if not positive(boss.get("Move_speed_mult")): return error(store,"boss.csv",id,"Move_speed_mult","유한한 양수 배율이 필요합니다.")
			if not positive(store.get_row("enemy.csv",ref).Move_speed): return error(store,"boss.csv",id,"Move_speed_ref_enemy","참조 속도는 양수여야 합니다.")
		else:
			for field in ["Move_speed_ref_enemy","Move_speed_mult"]:
				if boss.get(field)!=null: return error(store,"boss.csv",id,field,"기존 프로필에서는 사용하지 않습니다.")
		if counts[3]>0:
			if not positive(boss.Detect_range): return error(store,"boss.csv",id,"Detect_range","원거리 보스 인식 범위는 유한한 양수입니다.")
		elif boss.Detect_range!=null: return error(store,"boss.csv",id,"Detect_range","초반 보스는 인식 범위를 사용하지 않습니다.")
	for id in store.get_table("stage_timeline.csv"):
		var row := store.get_row("stage_timeline.csv",id)
		if mmss_seconds(int(row.Time_mmss))<0: return error(store,"stage_timeline.csv",id,"Time_mmss","음수 또는 초 부분이 59를 넘습니다.")
		if not bosses.has(row.Boss_id): return error(store,"stage_timeline.csv",id,"Boss_id","보스 참조가 없습니다.")
	for id in store.get_table("boss_action.csv"):
		var row := store.get_row("boss_action.csv",id)
		for field in ["Flee_trigger_range","Flee_speed","Flee_distance"]:
			if int(row.Kind)==3:
				if not positive(row.get(field)): return error(store,"boss_action.csv",id,field,"기본 화살 도주에 필요한 양수입니다.")
			elif row.get(field)!=null: return error(store,"boss_action.csv",id,field,"기본 화살 외 행동은 비웁니다.")
		if not bosses.has(row.Boss_id): return error(store,"boss_action.csv",id,"Boss_id","보스 참조가 없습니다.")
		if int(row.Kind)>=7:
			var detail := validate_baruka(store,id,row)
			if not detail.is_empty(): return detail
			continue
		for field in ["Tri_width","Tri_length","Area_radius","Strike_count","Strike_interval_sec","Strike_min_distance","Zone_count","Zone_radius","Zone_life_sec","Freeze_sec"]:
			if row.get(field)!=null: return error(store,"boss_action.csv",id,field,"기존 프로필에서는 사용하지 않습니다.")
		if int(row.Kind)>=3:
			var detail := validate_ranged(store,id,row)
			if not detail.is_empty(): return detail
			continue
		for field in ["Projectile_id","Shot_interval_sec","Duration_sec"]:
			if row.get(field)!=null: return error(store,"boss_action.csv",id,field,"초반 보스에서 쓰지 않는 열은 비워야 합니다.")
		for field in ["Push_distance","Push_sec"]:
			if int(row.Kind) in [1,2]:
				if not positive(row.get(field)): return error(store,"boss_action.csv",id,field,"스킬 피격 밀기에 필요한 양수를 입력하세요.")
			elif row.get(field)!=null: return error(store,"boss_action.csv",id,field,"기본 공격은 밀기를 사용하지 않습니다.")
		for field in ["Use_range","Telegraph_sec","Recovery_sec","Cooldown_sec"]:
			if not positive(row[field]): return error(store,"boss_action.csv",id,field,"유한한 양수가 필요합니다.")
		if int(row.Damage)<0: return error(store,"boss_action.csv",id,"Damage","0 이상이어야 합니다.")
		var used: Array = ["Range","Arc_deg"] if int(row.Kind)==0 else ["Dash_speed","Dash_distance","Pick_weight"] if int(row.Kind)==1 else ["Slam_radius","Pick_weight"]
		for field in ["Range","Arc_deg","Dash_speed","Dash_distance","Pick_weight","Slam_radius"]:
			if field in used:
				if not positive(row[field]): return error(store,"boss_action.csv",id,field,"행동에 필요한 양수를 입력하세요.")
			elif row[field]!=null: return error(store,"boss_action.csv",id,field,"사용하지 않는 열은 비워야 합니다.")
		if int(row.Kind)==0 and float(row.Arc_deg)>360: return error(store,"boss_action.csv",id,"Arc_deg","360 이하여야 합니다.")
	var rule := store.get_row("boss_rule.csv","boss_rule_01")
	if rule.is_empty(): return error(store,"boss_rule.csv","boss_rule_01","Id","필수 행이 없습니다.")
	for field in ["Warn_sec","Emerge_sec","Gate_radius"]:
		if not positive(rule[field]): return error(store,"boss_rule.csv","boss_rule_01",field,"유한한 양수가 필요합니다.")
	if String(rule.Toast_text).is_empty(): return error(store,"boss_rule.csv","boss_rule_01","Toast_text","문구가 필요합니다.")
	return ""

static func positive(value: Variant) -> bool:
	return value!=null and is_finite(float(value)) and float(value)>0

static func validate_baruka(store: CsvDataStore, id: String, row: Dictionary) -> String:
	for field in ["Use_range","Telegraph_sec","Cooldown_sec"]:
		if not positive(row.get(field)): return error(store,"boss_action.csv",id,field,"유한한 양수가 필요합니다.")
	if not is_finite(float(row.Recovery_sec)) or float(row.Recovery_sec)<0: return error(store,"boss_action.csv",id,"Recovery_sec","유한한 비음수가 필요합니다.")
	if int(row.Damage)<0 or (int(row.Kind)==10 and int(row.Damage)!=0): return error(store,"boss_action.csv",id,"Damage","빙결 피해는 0, 나머지는 비음수입니다.")
	var used: Array
	match int(row.Kind):
		7: used = ["Dash_speed","Dash_distance","Tri_width","Tri_length"]
		8: used = ["Dash_speed","Area_radius","Strike_count","Strike_interval_sec","Strike_min_distance","Pick_weight"]
		9: used = ["Dash_speed","Dash_distance","Duration_sec","Strike_interval_sec","Pick_weight"]
		10: used = ["Area_radius","Zone_count","Zone_radius","Zone_life_sec","Freeze_sec","Pick_weight"]
	for field in ["Range","Arc_deg","Dash_speed","Dash_distance","Slam_radius","Pick_weight","Projectile_id","Shot_interval_sec","Duration_sec","Push_distance","Push_sec","Tri_width","Tri_length","Area_radius","Strike_count","Strike_interval_sec","Strike_min_distance","Zone_count","Zone_radius","Zone_life_sec","Freeze_sec"]:
		if field in used:
			if not positive(row.get(field)): return error(store,"boss_action.csv",id,field,"행동 필수 양수가 필요합니다.")
		elif row.get(field)!=null: return error(store,"boss_action.csv",id,field,"사용하지 않는 열은 빈칸입니다.")
	if int(row.Kind)==8 and float(row.Strike_min_distance)>float(row.Area_radius): return error(store,"boss_action.csv",id,"Strike_min_distance","첫 이동을 위해 원 반경 이하여야 합니다.")
	return ""

static func validate_ranged(store: CsvDataStore, id: String, row: Dictionary) -> String:
	var kind := int(row.Kind)
	for field in ["Use_range","Cooldown_sec"]:
		if not positive(row[field]): return error(store,"boss_action.csv",id,field,"유한한 양수가 필요합니다.")
	for field in ["Telegraph_sec","Recovery_sec"]:
		if not is_finite(float(row[field])) or float(row[field])<0: return error(store,"boss_action.csv",id,field,"0 이상의 유한값이 필요합니다.")
	if int(row.Damage)<0: return error(store,"boss_action.csv",id,"Damage","0 이상이어야 합니다.")
	if kind==5 and not is_equal_approx(float(row.Telegraph_sec),0.3): return error(store,"boss_action.csv",id,"Telegraph_sec","연발 준비 동작은 0.3초입니다.")
	if kind!=5 and float(row.Telegraph_sec)!=0: return error(store,"boss_action.csv",id,"Telegraph_sec","즉시 행동은 준비 시간이 0입니다.")
	var used: Array = ["Projectile_id","Shot_interval_sec"] if kind==3 else ["Push_distance","Push_sec"] if kind==4 else ["Projectile_id","Shot_interval_sec","Duration_sec"] if kind==5 else ["Duration_sec"]
	for field in ["Range","Arc_deg","Dash_speed","Dash_distance","Slam_radius","Pick_weight","Projectile_id","Shot_interval_sec","Duration_sec","Push_distance","Push_sec"]:
		if field in used:
			if field=="Projectile_id":
				var projectile := store.get_row("projectile.csv",String(row[field]))
				if projectile.is_empty(): return error(store,"boss_action.csv",id,field,"투사체 참조가 없습니다.")
				if int(projectile.Damage)!=int(row.Damage): return error(store,"boss_action.csv",id,"Damage","투사체 피해와 같아야 합니다.")
			elif not positive(row[field]): return error(store,"boss_action.csv",id,field,"사용 행동의 양수가 필요합니다.")
		elif row.get(field)!=null: return error(store,"boss_action.csv",id,field,"사용하지 않는 열은 비워야 합니다.")
	if kind in [4,6] and int(row.Damage)!=0: return error(store,"boss_action.csv",id,"Damage","비공격 스킬 피해는 0입니다.")
	return ""

static func error(store: CsvDataStore, file: String, id: String, field: String, detail: String) -> String:
	return "res://data/%s, 행 %d, 열 %s: %s" % [file,maxi(1,store.get_source_line(file,id)),field,detail]
