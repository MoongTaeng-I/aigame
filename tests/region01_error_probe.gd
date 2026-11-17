extends SceneTree
# REGION-01: an invalid open region stops at the data error screen and never reaches the menu.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var flow := preload("res://tests/region01_error_subject.gd").new()
	root.add_child(flow)
	var until := Time.get_ticks_msec()+5000
	while flow.state=="loading" and Time.get_ticks_msec()<until: await process_frame
	var found := false
	for label in flow.find_children("*","Label",true,false):
		if label.text.begins_with("데이터 오류

") and label.text.contains("region.csv") and label.text.contains("Ground_texture"): found = true
	var state := {"state":flow.state,"paused":paused,"no_session":flow.session==null,"no_regions":flow.regions.is_empty(),"label_matches":found}
	var file := FileAccess.open("res://.local/region01-error-state.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(state))
	file.close()
	await preload("res://tests/test_exit.gd").finish("region01_error_probe",0 if flow.state=="error" and paused and flow.session==null and found and flow.regions.is_empty() else 1)
