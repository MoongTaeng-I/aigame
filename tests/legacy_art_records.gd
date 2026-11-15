extends RefCounted

# Retained layouts still have coverage after production records switch to SD pose.
static func player(row: Dictionary) -> Dictionary:
	var result := row.duplicate(true)
	for key in ["Bob_px","Step_hz","Squash","Tilt_deg","Breath"]: result[key] = null
	result.merge({"Sprite_path":"res://assets/art/player/player_move_sheet.png","Idle_sprite_path":"res://assets/art/player/player_idle_sheet.png","Sprite_layout":"dir3","Sprite_cols":4,"Sprite_rows":3,"Sprite_cell_height":87,"Sprite_baseline":368,"Sprite_anchor_x":185},true)
	return result

static func igrit(row: Dictionary) -> Dictionary:
	var result := row.duplicate(true)
	for key in ["Bob_px","Step_hz","Squash","Tilt_deg","Breath"]: result[key] = null
	result.merge({"Sprite_path":"res://assets/art/shadow/igris_sheet.png","Sprite_layout":"state3","Sprite_cols":4,"Sprite_rows":3,"Sprite_cell_height":211,"Sprite_baseline":410,"Sprite_anchor_x":170},true)
	return result
