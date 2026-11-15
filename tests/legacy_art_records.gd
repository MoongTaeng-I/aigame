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

static func shadow(row: Dictionary) -> Dictionary:
	var result := row.duplicate(true)
	for key in ["Bob_px","Step_hz","Squash","Tilt_deg","Breath"]: result[key] = null
	if row.Id=="charger_test":
		result.merge({"Sprite_path":"res://assets/art/shadow/beru_sheet.png","Sprite_layout":"state3","Sprite_cols":4,"Sprite_rows":3,"Sprite_cell_height":180,"Sprite_baseline":376,"Sprite_anchor_x":279,"Shadow_w":52,"Shadow_h":18},true)
	else:
		result.merge({"Sprite_path":"res://assets/art/shadow/belion_sheet.png","Sprite_layout":"state3","Sprite_cols":4,"Sprite_rows":3,"Sprite_cell_height":195,"Sprite_baseline":363,"Sprite_anchor_x":200,"Shadow_w":60,"Shadow_h":22,"Chain_hand_x":15,"Chain_hand_y":-95},true)
	return result

static func elf(row: Dictionary) -> Dictionary:
	var result := row.duplicate(true)
	for key in ["Bob_px","Step_hz","Squash","Tilt_deg","Breath"]: result[key] = null
	result.merge({"Sprite_path":"res://assets/art/enemy/elf_sheet.png","Sprite_layout":"walk_shoot","Sprite_cols":4,"Sprite_rows":2,"Sprite_cell_height":97,"Sprite_baseline":424,"Sprite_anchor_x":144,"Shadow_w":36,"Shadow_h":13,"Sprite_tint":"#d0d8f0"},true)
	return result
