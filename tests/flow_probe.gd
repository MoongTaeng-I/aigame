extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var flow: Node = load("res://scenes/flow.tscn").instantiate()
	root.add_child(flow)
	var until := Time.get_ticks_msec()+12000
	while flow.state=="loading" and Time.get_ticks_msec()<until: await process_frame
	var loaded: bool = flow.state=="menu"
	var playing := false
	var result := false
	if loaded:
		flow.start_region()
		playing = flow.state=="playing" and is_instance_valid(flow.session)
		if playing:
			flow.session._end_round(false)
			result = flow.state=="result" and paused
	var file := FileAccess.open("res://.local/flow-measure-state.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"menu":loaded,"playing":playing,"result":result,"paused":paused,"state":flow.state}))
	file.close()
	print("FLOW MEASUREMENT COMPLETE menu=",loaded," playing=",playing," result=",result)
	await preload("res://tests/test_exit.gd").finish("flow_probe",0 if loaded and playing and result else 1)
