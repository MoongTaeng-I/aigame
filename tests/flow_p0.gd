extends RefCounted

const Flow = preload("res://scripts/game_flow.gd")
var t: SceneTree

func run(tree: SceneTree) -> void:
	t = tree
	var before: int = t.checks
	var failed: int = t.failures
	var flow := Flow.new()
	t.root.add_child(flow)
	t.check(flow.state=="loading" and flow.session==null and flow.ui.screen=="loading","S9 loading screen before gameplay")
	var progress := 0.0
	var monotonic := true
	var until := Time.get_ticks_msec()+12000
	while flow.state=="loading" and Time.get_ticks_msec()<until:
		await t.process_frame
		monotonic = monotonic and flow.load_progress>=progress
		progress = flow.load_progress
	t.check(flow.state=="menu" and progress==1 and monotonic,"S9 actual incremental loading/validation reaches menu with monotonic real progress")
	t.check(flow.loading_elapsed>=5 and flow.loading_minimum==5,"S9 Loading_sec minimum5 real seconds respected (FIX02)")
	t.check(flow.regions.size()==2 and flow.ui.region_title.text=="1. 얼음 던전" and flow.ui.best_label.text.ends_with("-"),"S9 first region and no session record")
	flow.change_region(1)
	t.check(flow.ui.start_button.disabled and flow.ui.locked_click.visible and flow.ui.locked_label.text=="추후 업데이트 예정","S9 locked region dark/lock/disabled start with notice target")
	flow.start_region()
	t.check(flow.session==null and flow.ui.hint.text=="추후 업데이트 예정" and flow.ui.hint.visible,"S9 locked entry rejected and toast shown")
	flow.change_region(-1)
	flow.ui.start_button.pressed.emit()
	t.check(flow.state=="menu" and flow.session==null and flow.ui.transition.busy() and flow.ui.transition.rect.visible,"FX06 start button covers before round creation")
	flow.ui.transition._process(flow.ui.transition.cover_sec)
	t.check(flow.state=="playing" and is_instance_valid(flow.session),"S9 actual start button enters region1")
	t.check(flow.ui.transition.mode=="reveal" and flow.ui.transition.rect.visible,"FX06 round ready starts reveal")
	var n: Dictionary = flow.session.round_nodes
	fresh(n)
	n.player.configure_combat(100000,{})
	n.manager._spawn_records = {}
	n.director.timeline = []
	n.director.toast_view.push_message("pause probe")
	await t.create_timer(0.04,true,false,true).timeout
	escape(flow)
	t.check(flow.state=="paused" and t.paused,"S9 ESC opens pause")
	var clock: float = n.manager._elapsed_seconds
	var skill_clock: float = n.skills.clock
	var age: float = n.director.toast_view.entries[0].age
	var remaining: float = n.director.toast_view.entries[0].remaining
	await t.create_timer(0.08,true,false,true).timeout
	t.check(n.manager._elapsed_seconds==clock and n.skills.clock==skill_clock,"S9 pause stops elapsed time and cooldown clock")
	t.check(n.director.toast_view.entries[0].age==age and n.director.toast_view.entries[0].remaining==remaining,"S9 pause stops toast age and remaining")
	escape(flow)
	t.check(flow.state=="playing" and not t.paused,"S9 ESC resumes pause")
	n.player.add_experience(n.player.get_xp_to_next())
	t.check(n.choices.active and t.paused,"S9 actual level-up opens choice pause")
	escape(flow)
	t.check(flow.state=="playing" and n.choices.active and t.paused and not is_instance_valid(flow.ui.modal),"S9 ESC ignored during choice")
	n.choices.select(0)
	t.check(not n.choices.active and not t.paused,"S9 choice finishes with original flow")
	# Stop automatic physics only in this fixture while constructing exact results.
	for child in n.map.get_children(): child.set_physics_process(false)
	if n.shadows.can_summon("igrit"): n.shadows.summon("igrit")
	for i in range(2):
		n.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":1})
		var enemy: Node2D = n.manager.get_living_enemies().back()
		enemy.apply_damage(enemy.hp)
	t.check(flow.session.kills==2,"S9 real death signals count kills once")
	n.manager._spawn_from_row({"Enemy_id":"enemy_test_ranged","Spawn_count":1})
	var ranged: Node2D = n.manager.get_living_enemies().back()
	ranged.global_position = n.player.global_position+Vector2(200,0)
	n.manager._update_enemy_shot(ranged,2)
	t.check(n.manager._projectiles.size()==1,"S9 cleanup fixture includes real projectile")
	n.player.enhancement_points+=1
	t.check(n.skills.try_upgrade("skill_dash") and n.skills.try_use("skill_dash"),"S9 actual dash for afterimage cleanup")
	n.player._physics_process(0.06)
	var trail_count := 0
	for child in n.map.get_children():
		if child.get_script()==preload("res://scripts/shadow_afterimage.gd"): trail_count+=1
	t.check(trail_count>0,"S9 actual dash creates afterimages for cleanup")
	var boss := spawn_final(n)
	var ice: Dictionary = flow.data_store.get_row("boss_action.csv","baruka_ice")
	boss.clock = n.manager._elapsed_seconds
	boss.start_action(ice,n.player.global_position)
	n.manager._elapsed_seconds+=0.801
	boss.boss_tick(0.801)
	t.check(boss.baruka.zones.size()==5,"S9 cleanup fixture includes five real ice zones")
	n.manager._elapsed_seconds = 132.7
	var names: Array[String] = []
	for shadow in n.shadows.actors: names.append(shadow.config.Name_ko)
	var level: int = n.player.level
	var old := descendants(flow.session)
	n.player.apply_damage(n.player.hp)
	if not n.player.death_presentation_complete: await n.player.death_presented
	# death_presented is emitted from inside the death presentation node's _process. Resuming there and
	# then freeing the round (start_region below) would free nodes that are still being processed, which
	# corrupts the heap (CRASH-01). Leave the emission first; the game itself only frees from deferred button calls.
	await t.process_frame
	t.check(flow.state=="result" and t.paused and not flow.result.cleared,"S9 actual death creates failed result and immediate pause")
	t.check(flow.result.seconds==132.7 and flow.result.level==level and flow.result.kills==2 and flow.result.shadows==names,"S9 death summary exact time level kills owned shadow names")
	t.check(flow.ui.result_text.text.contains("02:12") and flow.ui.result_text.text.contains("처치 수  2") and n.player._death_label==null,"S9 MM:SS result replaces standalone death label")
	var locked_result: Dictionary = flow.result.duplicate(true)
	var count: int = n.director.toast_view.entries.size()
	boss.apply_damage(boss.hp)
	n.player.add_experience(9999)
	n.choices._on_level_up(999)
	flow.session._end_round(true)
	escape(flow)
	t.check(flow.result==locked_result and flow.state=="result" and n.player.level==level and not n.choices.active and n.choices.pending==0,"S9 result ignores later completion XP choice events and ESC")
	t.check(n.director.toast_view.entries.size()==count and not n.choices.select(0),"S9 late boss event and choice cannot change result or toast")
	flow.start_region()
	all_freed(old,"retry")
	fresh(flow.session.round_nodes)
	t.check(flow.session.supplied_data==flow.data_store,"S9 retry reuses validated store, not previous round state")
	t.check(flow.session.round_nodes.player.presentation==Engine.get_meta("combat_presentation"),"S9 new round uses loading-screen presentation cache")
	# Pause-to-menu also removes every old node; entry starts clean again.
	old = descendants(flow.session)
	escape(flow)
	flow.show_menu()
	all_freed(old,"pause to menu")
	t.check(flow.state=="menu" and not t.paused and flow.session==null and flow.ui.best_label.text.contains("02:12"),"S9 menu returns with in-memory best survival only")
	flow.start_region()
	n = flow.session.round_nodes
	for child in n.map.get_children(): child.set_physics_process(false)
	boss = spawn_final(n)
	old = descendants(flow.session)
	boss.apply_damage(boss.hp)
	t.check(flow.state=="result" and flow.result.cleared and flow.result.kills==1 and t.paused,"S9 actual final boss death creates clear result including boss kill")
	t.check(n.director.toast_view.completion_label==null and flow.ui.result_text.text.contains("05:33"),"MVP-01 5:30 final clear uses result UI and MM:SS instead of old completion label")
	var toast: Control = n.director.toast_view
	var death_entry: Dictionary = toast.entries[0]
	t.check(death_entry.text=="[보스 몬스터를 처치했습니다]" and toast.get_parent().layer>flow.ui.get_parent().layer,"S9 boss kill toast remains above result")
	toast._process(1.9)
	t.check(death_entry.panel.modulate.a>0 and death_entry.panel.modulate.a<1 and t.paused,"S9 boss kill toast fades while result stays paused")
	toast._process(2)
	t.check(toast.entries.is_empty(),"S9 result toast finishes without resuming combat")
	escape(flow)
	t.check(flow.state=="result" and t.paused,"S9 ESC ignored on clear result")
	var buttons: Array[Node] = flow.ui.modal.find_children("*","Button",true,false)
	t.check(buttons.size()==1 and buttons[0].text=="확인","S9 clear has only confirm")
	buttons[0].pressed.emit()
	await t.process_frame
	all_freed(old,"clear confirm")
	t.check(flow.state=="menu" and flow.ui.best_label.text.contains("05:33"),"MVP-01 confirm returns to menu with new 5:30-flow maximum")
	flow.start_region()
	fresh(flow.session.round_nodes)
	flow.show_menu()
	t.check(t.get_nodes_in_group("combat_toasts").is_empty(),"S9 no old combat toast group members in menu")
	flow.queue_free()
	await t.process_frame
	var second := Flow.new()
	t.root.add_child(second)
	t.check(second.best_times.is_empty(),"S9 new application lifetime has no saved record")
	while second.state=="loading": await t.process_frame
	second.queue_free()
	await t.process_frame
	await data_errors()
	print("S9-IMPL-01 NEW RESULT: %d checks, %d failures" % [t.checks-before,t.failures-failed])

func escape(flow: Node) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	flow._unhandled_input(key)

func fresh(n: Dictionary) -> void:
	t.check(n.player.hp==100 and n.player.level==1 and n.player.experience==0 and n.player.enhancement_points==0,"S9 fresh player base state")
	t.check(n.manager._elapsed_seconds==0 and n.manager.get_alive_count()==0 and n.manager._projectiles.is_empty() and n.director.actor==null and n.director.fired.is_empty(),"S9 fresh time enemies projectiles boss state")
	t.check(n.shadows.actors.is_empty() and n.director.toast_view.entries.is_empty() and n.skills.clock==0 and n.skills.effects.is_empty() and n.choices.pending==0,"S9 fresh shadows toasts skills choices")

func descendants(root: Node) -> Array:
	var output: Array = [root]
	for child in root.get_children(): output.append_array(descendants(child))
	return output

func all_freed(nodes: Array, label: String) -> void:
	var remaining := 0
	for node in nodes:
		if is_instance_valid(node): remaining+=1
	t.check(remaining==0,"S9 old round nodes zero including effects/toasts: "+label)

func spawn_final(n: Dictionary) -> Node2D:
	n.director.timeline = [{"Id":"final_probe","Time_mmss":530,"Boss_id":"boss_final"}]
	n.manager._elapsed_seconds = 330
	n.director.advance(330,0)
	n.manager._elapsed_seconds = 333.5
	n.director.advance(333.5,0)
	return n.director.actor

func data_errors() -> void:
	var store: CsvDataStore = t._store()
	t.check(store.load_all().is_empty() and preload("res://scripts/flow_data.gd").validate(store).is_empty(),"S9 region/presentation actual data validates")
	var row: Dictionary = store.get_row("combat_presentation.csv","Loading_sec")
	for value in ["0","-1","nan","inf","text"]:
		row.Value = value
		t.check(not preload("res://scripts/flow_data.gd").validate(store).is_empty(),"S9 invalid Loading_sec rejected "+value)
	row.Value = "1.5"
	store.get_row("region.csv","region_02").Locked_text = ""
	t.check(not preload("res://scripts/flow_data.gd").validate(store).is_empty(),"S9 missing locked notice rejected")
	var output: Array = []
	var log := "res://.local/godot_logs/s9-impl-01-error-"+str(Time.get_ticks_usec())+".log"
	var code := preload("res://tests/godot_probe_process.gd").execute(PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","tests/flow_error_probe.gd","--log-file",ProjectSettings.globalize_path(log)]),output,log)
	var file := FileAccess.open("res://.local/s9-impl-01-error.out",FileAccess.WRITE)
	file.store_string("\n".join(output))
	file.close()
	var state: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.local/s9-impl-01-error-state.json"))
	t.check(code==0 and state.state=="error" and state.paused and state.no_session and state.no_regions and state.label_matches,"S9 real loading data error never enters menu")
