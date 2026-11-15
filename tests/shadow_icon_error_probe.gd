extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var store := preload("res://scripts/csv_data_store.gd").new()
	preload("res://scripts/combat_data.gd").register_schemas(store)
	var loaded := store.load_all()
	store.get_row("shadow.csv","igrit").Icon = "res://missing-shadow-icon.png"
	var error: String = preload("res://scripts/shadow_data.gd").validate(store)
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	main._show_data_error(error)
	var found := false
	for label in main.find_children("*","Label",true,false):
		if label.text=="데이터 오류\n\n"+error: found = true
	var state := FileAccess.open("res://.local/s8-impl-01-b-icon-error-state.json",FileAccess.WRITE)
	state.store_string(JSON.stringify({"message":error,"loaded":loaded.is_empty(),"paused":paused,"label_matches":found}))
	state.close()
	# Dispose the paused fixture before SceneTree shutdown, allowing queued cleanup.
	root.remove_child(main)
	main.free()
	for frame in range(4):
		await process_frame
	quit(0 if loaded.is_empty() and error.contains("열 Icon") and paused and found else 1)
