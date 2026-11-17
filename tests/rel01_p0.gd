extends RefCounted
# REL-01: three cycles of start -> low hp + zoom punch -> death -> "다시 하기" -> pause -> "메인으로" through
# the real buttons. Back at the menu every time: no orphan or leftover nodes, the same audio players,
# BGM low-pass off, Engine.time_scale 1, not paused, title music; every new round starts with the
# default camera zoom.

const Flow = preload("res://scripts/game_flow.gd")
var t: SceneTree

func run(tree: SceneTree) -> void:
	t = tree
	var before: int = t.checks
	var failed: int = t.failures
	var audio: Node = t.root.get_node("GameAudio")
	var flow := Flow.new()
	t.root.add_child(flow)
	var until := Time.get_ticks_msec()+15000
	while (flow.state=="loading" or flow.ui.menu_locked()) and Time.get_ticks_msec()<until: await t.process_frame
	await settle(flow)
	var base := snapshot(flow,audio)
	t.check(flow.state=="menu" and base.orphans>=0,"REL01 menu reached for the baseline: "+str(base))
	var first_zoom := Vector2.ZERO
	for cycle in range(3):
		# Start through the real start button and its cover.
		flow.ui.start_button.pressed.emit()
		flow.ui.transition._process(flow.ui.transition.cover_sec)
		t.check(flow.state=="playing" and is_instance_valid(flow.session),"REL01 cycle %d start button enters the round" % cycle)
		var zoom := camera_zoom(flow)
		if cycle==0: first_zoom = zoom
		t.check(zoom==first_zoom and zoom!=Vector2.ZERO,"REL01 cycle %d round starts with the default camera zoom %s" % [cycle,str(zoom)])
		await dirty_round(flow,audio,cycle)
		await die(flow)
		t.check(flow.state=="result" and t.paused and not flow.result.cleared,"REL01 cycle %d death shows the failed result" % cycle)
		press(flow,"다시 하기")
		await t.process_frame
		await t.process_frame
		t.check(flow.state=="playing" and is_instance_valid(flow.session) and not t.paused and is_equal_approx(Engine.time_scale,1.0),"REL01 cycle %d retry starts a new unpaused round" % cycle)
		t.check(camera_zoom(flow)==first_zoom and audio.lowpass_target==0.0 and audio.lowpass_amount==0.0,"REL01 cycle %d retry resets zoom and the BGM low-pass" % cycle)
		await dirty_round(flow,audio,cycle)
		var key := InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.pressed = true
		flow._unhandled_input(key)
		t.check(flow.state=="paused" and t.paused,"REL01 cycle %d ESC pauses" % cycle)
		press(flow,"메인으로")
		await t.process_frame
		await settle(flow)
		var now := snapshot(flow,audio)
		t.check(now==base,"REL01 cycle %d back at the menu every global state equals the baseline: %s vs %s" % [cycle,str(now),str(base)])
	flow.queue_free()
	await t.process_frame
	print("REL-01 NEW RESULT: %d checks, %d failures" % [t.checks-before,t.failures-failed])

# Low hp (BGM low-pass on), a zoom punch left mid-way, a rapid slash cast and some frames of real play.
func dirty_round(flow: Node, audio: Node, cycle: int) -> void:
	var n: Dictionary = flow.session.round_nodes
	n.player.configure_combat(100000,{})
	n.player.apply_damage(n.player.hp-1)
	for i in range(3): await t.physics_frame
	t.check(audio.lowpass_target==1.0,"REL01 cycle %d low hp turns the BGM low-pass on" % cycle)
	n.skills.skills.skill_rapid_slash.cooldown_until = 0
	n.skills.try_use("skill_rapid_slash")
	if n.skills.screen_fx!=null: n.skills.screen_fx.zoom_punch()
	for i in range(4): await t.physics_frame

func die(flow: Node) -> void:
	var player: Node2D = flow.session.round_nodes.player
	player.apply_damage(player.hp)
	if not player.death_presentation_complete: await player.death_presented
	# Leave the emission before the deferred button frees the round (CRASH-01).
	await t.process_frame

func press(flow: Node, text: String) -> void:
	var found := false
	if is_instance_valid(flow.ui.modal):
		for button in flow.ui.modal.find_children("*","Button",true,false):
			if button.text==text:
				button.pressed.emit()
				found = true
	t.check(found,"REL01 modal button exists: "+text)

func settle(flow: Node) -> void:
	var until := Time.get_ticks_msec()+5000
	while (flow.ui.transition.busy() or flow.ui.menu_locked()) and Time.get_ticks_msec()<until: await t.process_frame
	# Closing windows free themselves after Ui_close_sec of real time; headless frames are much shorter.
	await t.create_timer(0.3,true,false,true).timeout
	while flow.ui.closing_modals.any(func(item) -> bool: return is_instance_valid(item)) and Time.get_ticks_msec()<until: await t.process_frame
	for i in range(3): await t.process_frame

func camera_zoom(flow: Node) -> Vector2:
	var cameras: Array[Node] = flow.session.find_children("*","Camera2D",true,false)
	return cameras[0].zoom if not cameras.is_empty() else Vector2.ZERO

func snapshot(flow: Node, audio: Node) -> Dictionary:
	var bgm := AudioServer.get_bus_index("BGM")
	var index: int = audio.lowpass_index()
	return {
		"state":flow.state,
		"session":is_instance_valid(flow.session),
		"nodes":t.get_node_count(),
		"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"players":t.root.find_children("*","AudioStreamPlayer",true,false).size(),
		"pool":audio.pool.size(),
		"lowpass":[audio.lowpass_target,audio.lowpass_amount,index>=0 and AudioServer.is_bus_effect_enabled(bgm,index)],
		"time_scale":Engine.time_scale,
		"paused":t.paused,
		"music":audio.music_id,
		"cameras":t.root.find_children("*","Camera2D",true,false).size(),
	}
