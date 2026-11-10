extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var store = preload("res://scripts/csv_data_store.gd").new()
	preload("res://scripts/combat_data.gd").register_schemas(store)
	var loaded: String = store.load_all()
	var text := FileAccess.get_file_as_string("res://data/shadow_attack.csv")
	var error: String = store.load_text("shadow_attack.csv",text.replace(",fan,",",invalid_shape,"))
	var main = preload("res://main.tscn").instantiate()
	root.add_child(main)
	main._show_data_error(error)
	var found := false
	for label in main.find_children("*","Label",true,false):
		if label.text=="데이터 오류\n\n"+error: found = true
	var state := FileAccess.open("res://.local/s7-impl-02-data-error-state.json",FileAccess.WRITE)
	state.store_string(JSON.stringify({"message":error,"loaded":loaded.is_empty(),"paused":paused,"label_matches":found}))
	if loaded.is_empty() and error.contains("열 Shape") and paused and found:
		print("S7-ERROR-SCREEN PASS")
		quit(0)
	else:
		print("S7-ERROR-SCREEN FAIL")
		quit(1)
