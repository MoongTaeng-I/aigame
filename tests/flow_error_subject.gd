extends "res://scripts/game_flow.gd"

func validate_loaded_data() -> String:
	# Only fixture data changes; use the real loading and validation/error path.
	data_store.tables["region.csv"].erase("region_01")
	return super.validate_loaded_data()
