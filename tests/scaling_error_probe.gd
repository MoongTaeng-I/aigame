extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var store := preload("res://scripts/csv_data_store.gd").new()
	var data := preload("res://scripts/combat_data.gd")
	data.register_schemas(store)
	var loaded: String = store.load_all()
	store.tables["enemy_scaling.csv"].erase("scaling_00")
	var error: String = data.validate(store)
	var main: Node = preload("res://main.tscn").instantiate()
	root.add_child(main)
	main._show_data_error(error)
	var found := false
	for label in main.find_children("*","Label",true,false):
		if label.text=="데이터 오류\n\n"+error: found = true
	var file := FileAccess.open("res://.local/s8-impl-04-scaling-error-state.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"message":error,"loaded":loaded.is_empty(),"paused":paused,"label_matches":found}))
	quit(0 if loaded.is_empty() and error.contains("Time_start") and paused and found else 1)
