extends RefCounted

enum Shape { FAN, DASH_THROUGH, SWEEP }
const SHAPES := {"fan":Shape.FAN,"dash_through":Shape.DASH_THROUGH,"sweep":Shape.SWEEP}

static func register_schemas(store: CsvDataStore) -> void:
	store.register_schema("shadow.csv",{"Id":"String","Search_radius":"Float","Chase_leash_distance":"Float","Follow_distance":"Float","Move_speed":"Float","Teleport_distance":"Float","Afterimage_sec":"Float","Body_radius":"Float","Push_weight":"Float","Attack_id":"String","Enemy_push_share":"Float","Sprite_path":{"type":"Optional","inner":"Path"},"Sprite_layout":{"type":"Optional","inner":"String"},"Sprite_cols":{"type":"Optional","inner":"Int"},"Sprite_rows":{"type":"Optional","inner":"Int"},"Sprite_cell_height":{"type":"Optional","inner":"Float"},"Sprite_baseline":{"type":"Optional","inner":"Float"},"Sprite_foot_y":{"type":"Optional","inner":"Float"},"Anim_fps":{"type":"Optional","inner":"Float"},"Idle_fps":{"type":"Optional","inner":"Float"},"Attack_after_frame_sec":{"type":"Optional","inner":"Float"}})
	store.register_schema("shadow_attack.csv",{"Id":"String","Damage":"Int","Range":"Float","Arc_deg":{"type":"Optional","inner":"Float"},"Interval_sec":"Float","Shape":{"type":"Enum","values":SHAPES},"Dash_speed":{"type":"Optional","inner":"Float"},"Dash_distance":{"type":"Optional","inner":"Float"},"Dash_hit_radius":{"type":"Optional","inner":"Float"},"Dash_min_distance":{"type":"Optional","inner":"Float"},"Aim_turn_deg_per_sec":{"type":"Optional","inner":"Float"},"Aim_deadband_deg":{"type":"Optional","inner":"Float"},"Windup_sec":{"type":"Optional","inner":"Float"},"Sweep_sec":{"type":"Optional","inner":"Float"}})
	store.register_schema("shadow_motion.csv",{"Id":"String","Attack_id":"String","Motion_sec":"Float","Hit_time_sec":{"type":"Optional","inner":"Float"}})
	store.schemas["shadow.csv"]["Name_ko"] = "String"
	store.schemas["shadow.csv"]["Icon"] = {"type":"Optional","inner":"Path"}
	for column in ["Shadow_w","Shadow_h"]:
		store.schemas["shadow.csv"][column] = {"type":"Optional","inner":"Float"}
	for column in ["Chain_hand_x","Chain_hand_y","Sprite_anchor_x"]:
		store.schemas["shadow.csv"][column] = {"type":"Optional","inner":"Float"}
	for column in ["Bob_px","Step_hz","Squash","Tilt_deg","Breath"]:
		store.schemas["shadow.csv"][column] = {"type":"Optional","inner":"Float"}

	for column in ["Prep_col","Finish_col"]:
		store.schemas["shadow.csv"][column] = {"type":"Optional","inner":"Int"}

static func validate(store: CsvDataStore) -> String:
	if store.tables.has("combat_presentation.csv"):
		var width := store.get_row("combat_presentation.csv","Belion_chain_width")
		if width.is_empty() or not String(width.Value).is_valid_float() or not is_finite(float(width.Value)) or float(width.Value)<=0:
			return error(store,"combat_presentation.csv","Belion_chain_width","Value","Belion_chain_width는 유한한 양수여야 합니다.")
	var attacks := store.get_table("shadow_attack.csv")
	var motions := store.get_table("shadow_motion.csv")
	if store.get_row("shadow.csv","igrit").is_empty():
		return error(store,"shadow.csv","igrit","Id","이그리트 행이 필요합니다.")
	for id in store.get_table("shadow.csv"):
		var row := store.get_row("shadow.csv",id)
		if row.get("Sprite_anchor_x")!=null and (not is_finite(float(row.Sprite_anchor_x)) or float(row.Sprite_anchor_x)<0): return error(store,"shadow.csv",id,"Sprite_anchor_x","유한한 비음수여야 합니다.")
		for column in ["Chain_hand_x","Chain_hand_y"]:
			if row.get(column)!=null and not is_finite(float(row[column])): return error(store,"shadow.csv",id,column,"유한한 좌표여야 합니다.")
		if (row.get("Chain_hand_x")==null)!=(row.get("Chain_hand_y")==null):
			return error(store,"shadow.csv",id,"Chain_hand_x" if row.get("Chain_hand_x")==null else "Chain_hand_y","손 좌표는 두 열을 함께 지정하거나 함께 비워야 합니다.")
		for column in ["Shadow_w","Shadow_h"]:
			if row.get(column)!=null and (not is_finite(float(row[column])) or float(row[column])<=0): return error(store,"shadow.csv",id,column,"유한한 양수여야 합니다.")
		var sprite_columns := ["Sprite_layout","Sprite_cols","Sprite_rows","Sprite_cell_height","Sprite_baseline","Sprite_foot_y","Anim_fps","Idle_fps","Attack_after_frame_sec"]
		if row.Sprite_path==null:
			for column in sprite_columns:
				if row[column]!=null: return error(store,"shadow.csv",id,column,"Sprite_path가 비면 이미지 열도 비워야 합니다.")
		else:
			var sprite_path := String(row.Sprite_path)
			if not ResourceLoader.exists(sprite_path,"Texture2D") or not (ResourceLoader.load(sprite_path,"Texture2D") is Texture2D):
				return error(store,"shadow.csv",id,"Sprite_path","사용 가능한 이미지 경로가 아닙니다.")
			for column in sprite_columns:
				if row[column]==null: return error(store,"shadow.csv",id,column,"이미지 경로가 있으면 필수입니다.")
			if not (String(row.Sprite_layout) in ["state3","pose"]) or (row.Sprite_layout=="pose" and int(row.Sprite_rows)!=1): return error(store,"shadow.csv",id,"Sprite_layout","그림자 시트는 state3 또는1행 pose이어야 합니다.")
			if int(row.Sprite_cols)<1 or int(row.Sprite_rows)<1: return error(store,"shadow.csv",id,"Sprite_cols","칸 수는 1 이상이어야 합니다.")
			for column in ["Sprite_cell_height","Anim_fps","Idle_fps","Attack_after_frame_sec"]:
				if not is_finite(float(row[column])) or float(row[column])<=0: return error(store,"shadow.csv",id,column,"유한한 양수여야 합니다.")
			if not is_finite(float(row.Sprite_baseline)) or float(row.Sprite_baseline)<0: return error(store,"shadow.csv",id,"Sprite_baseline","유한한 비음수여야 합니다.")
			if not is_finite(float(row.Sprite_foot_y)): return error(store,"shadow.csv",id,"Sprite_foot_y","유한한 값이어야 합니다.")
		if row.get("Icon")!=null:
			var path := String(row.Icon)
			if not ResourceLoader.exists(path) or not (load(path) is Texture2D):
				return error(store,"shadow.csv",id,"Icon","사용 가능한 이미지 경로가 아닙니다.")
		if float(row.Enemy_push_share)<0.0 or float(row.Enemy_push_share)>1.0:
			return error(store,"shadow.csv",id,"Enemy_push_share","0 이상 1 이하이어야 합니다.")
		for key in ["Search_radius","Chase_leash_distance","Follow_distance","Move_speed","Teleport_distance","Afterimage_sec","Body_radius","Push_weight"]:
			if float(row[key])<=0.0:
				return error(store,"shadow.csv",id,key,"0보다 큰 값이어야 합니다.")
		if not attacks.has(row.Attack_id):
			return error(store,"shadow.csv",id,"Attack_id","공격 참조가 없습니다.")
	for id in attacks:
		var row: Dictionary = attacks[id]
		if int(row.Damage)<0 or float(row.Range)<=0 or float(row.Interval_sec)<=0:
			return error(store,"shadow_attack.csv",id,"Damage","공격 수치가 올바르지 않습니다.")
		if int(row.Shape)==Shape.FAN:
			if row.Aim_deadband_deg==null or not is_finite(float(row.Aim_deadband_deg)) or float(row.Aim_deadband_deg)<0.0:
				return error(store,"shadow_attack.csv",id,"Aim_deadband_deg","fan 방향 데드존에는 0 이상의 유한한 값이 필요합니다.")
			if row.Aim_turn_deg_per_sec==null or not is_finite(float(row.Aim_turn_deg_per_sec)) or float(row.Aim_turn_deg_per_sec)<=0.0:
				return error(store,"shadow_attack.csv",id,"Aim_turn_deg_per_sec","fan 방향 갱신 속도에는 유한한 양수가 필요합니다.")
			if row.Arc_deg==null or float(row.Arc_deg)<=0 or float(row.Arc_deg)>360:
				return error(store,"shadow_attack.csv",id,"Arc_deg","fan 각도는 0 초과 360 이하이어야 합니다.")
		elif int(row.Shape)==Shape.DASH_THROUGH:
			for key in ["Dash_speed","Dash_distance","Dash_hit_radius","Dash_min_distance"]:
				if row[key]==null or float(row[key])<=0.0:
					return error(store,"shadow_attack.csv",id,key,"dash_through에는 양수가 필요합니다.")
		else:
			if row.Arc_deg==null or not is_finite(float(row.Arc_deg)) or float(row.Arc_deg)<=0.0 or float(row.Arc_deg)>360.0:
				return error(store,"shadow_attack.csv",id,"Arc_deg","sweep 각도는 0 초과 360 이하이어야 합니다.")
			for key in ["Windup_sec","Sweep_sec"]:
				if row[key]==null or not is_finite(float(row[key])) or float(row[key])<=0.0:
					return error(store,"shadow_attack.csv",id,key,"sweep에는 유한한 양수가 필요합니다.")
		if int(row.Shape)!=Shape.SWEEP and (row.Windup_sec!=null or row.Sweep_sec!=null):
			return error(store,"shadow_attack.csv",id,"Windup_sec","sweep 외 공격은 Windup_sec와 Sweep_sec를 비워야 합니다.")
		var count := 0
		for motion in motions.values():
			if motion.Attack_id==id: count += 1
		if int(row.Shape)!=Shape.SWEEP and count==0:
			return error(store,"shadow_motion.csv","","Attack_id","공격의 모션이 없습니다.")
	for id in motions:
		var row: Dictionary = motions[id]
		if not attacks.has(row.Attack_id) or float(row.Motion_sec)<=0:
			return error(store,"shadow_motion.csv",id,"Motion_sec","공격 참조와 양수 모션/후딜을 확인하세요.")
		# fan: scheduled hit within its motion. dash_through: Motion_sec is
		# recovery; Hit_time_sec is unused, movement segments supply damage.
		if int(attacks[row.Attack_id].Shape)==Shape.FAN and (row.Hit_time_sec==null or float(row.Hit_time_sec)<0 or float(row.Hit_time_sec)>float(row.Motion_sec)):
			return error(store,"shadow_motion.csv",id,"Hit_time_sec","참조와 모션 안의 피해 시점을 확인하세요.")
	return ""

static func error(store: CsvDataStore, file: String, id: String, column: String, detail: String) -> String:
	return "res://data/%s, 행 %d, 열 %s: %s" % [file,store.get_source_line(file,id),column,detail]
