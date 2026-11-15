extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var store = preload("res://scripts/csv_data_store.gd").new()
	preload("res://scripts/combat_data.gd").register_schemas(store)
	var loaded: String = store.load_all()
	store.get_row("hit_fx.csv","hit_spark").Enabled = 2
	var error: String = preload("res://scripts/hit_fx_data.gd").validate(store)
	var main = preload("res://main.tscn").instantiate()
	root.add_child(main)
	main._show_data_error(error)
	var found := false
	for label in main.find_children("*","Label",true,false):
		if label.text=="데이터 오류\n\n"+error: found = true
	var state := FileAccess.open("res://.local/fx-impl-01-error-state.json",FileAccess.WRITE)
	state.store_string(JSON.stringify({"message":error,"loaded":loaded.is_empty(),"paused":paused,"label_matches":found}))
	state.close()
	await preload("res://tests/test_exit.gd").finish("hit_fx_error_probe",0 if loaded.is_empty() and error.contains("열 Enabled") and paused and found else 1)
