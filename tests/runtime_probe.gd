extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	var instance := scene.instantiate()
	root.add_child(instance)
	current_scene = instance
	for frame in range(300): await process_frame
	await preload("res://tests/test_exit.gd").finish("runtime_probe",0)
