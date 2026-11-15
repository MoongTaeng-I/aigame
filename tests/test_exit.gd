extends RefCounted

# Callers close result files before entering this test-only exit.
static func finish(name: String, code: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var done := FileAccess.open("res://.local/"+name+"-done.json",FileAccess.WRITE)
	if done == null:
		push_error("Cannot write test completion file: "+name)
		OS.kill(OS.get_process_id())
		return
	done.store_string(JSON.stringify({"name":name,"code":code}))
	done.close()
	tree.paused = false
	tree.current_scene = null
	# Probes attach their scene directly to root; include those scenes too.
	for scene in tree.root.get_children():
		tree.root.remove_child(scene)
		scene.queue_free()
	await tree.process_frame
	await tree.process_frame
	OS.kill(OS.get_process_id())
