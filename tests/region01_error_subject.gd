extends "res://scripts/game_flow.gd"

func validate_loaded_data() -> String:
	# Only fixture data changes: an open region with a missing ground image, through the real validation/error path.
	data_store.tables["region.csv"]["region_01"]["Ground_texture"] = "res://assets/art/env/missing_ground.png"
	return super.validate_loaded_data()
