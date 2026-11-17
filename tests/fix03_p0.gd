extends RefCounted
# FIX-03: Baruka telegraph values, settings/notice/locked card text, toast step-back, boss health bar,
# entry sounds.
const UI = preload("res://scripts/system_ui.gd")

func run(t: SceneTree) -> void:
	var store: CsvDataStore = t._store()
	t.check(store.load_all().is_empty(),"FIX03 actual data loads")
	await baruka(t,store)
	await toasts(t)
	await boss_bar(t)
	await flow(t,store)

func boss_rows(store: CsvDataStore, boss_id: String) -> Array:
	var rows: Array = []
	for row in store.get_table("boss_action.csv").values():
		if row.Boss_id==boss_id: rows.append(row)
	return rows

func baruka(t: SceneTree, store: CsvDataStore) -> void:
	var basic: Dictionary = store.get_row("boss_action.csv","baruka_basic")
	var chase: Dictionary = store.get_row("boss_action.csv","baruka_chase")
	t.check(is_equal_approx(float(basic.Telegraph_sec),0.184) and is_equal_approx(float(basic.Dash_speed),1560) and is_equal_approx(float(basic.Dash_distance),160) and is_equal_approx(float(basic.Cooldown_sec),0.63) and int(basic.Damage)==15,"FIX03 baruka_basic Telegraph_sec .184 with other cells unchanged")
	t.check(is_equal_approx(float(chase.Telegraph_sec),0.125) and is_equal_approx(float(chase.Dash_speed),1100) and is_equal_approx(float(chase.Dash_distance),300) and is_equal_approx(float(chase.Duration_sec),3) and is_equal_approx(float(chase.Strike_interval_sec),0.4) and int(chase.Damage)==12,"FIX03 baruka_chase Telegraph_sec .125 with other cells unchanged")
	var n: Dictionary = preload("res://tests/fx03_p0.gd").new().fixture(t)
	var boss: Node2D = n.manager.create_boss("boss_baruka",boss_rows(store,"boss_final"),func() -> Node2D: return n.player)
	boss.position = Vector2.ZERO
	n.player.position = Vector2(250,0)
	n.manager.activate_boss(boss)
	boss.clock = 10
	boss.start_action(basic,n.player.position)
	t.check(boss.phase=="telegraph" and is_equal_approx(boss.phase_end-boss.clock,0.184),"FIX03 basic preview and pre-dash wait share one .184 timer")
	boss.clock = boss.phase_end-0.001
	boss.baruka.advance()
	var waiting: bool = boss.phase=="telegraph"
	boss.clock = boss.phase_end
	boss.baruka.advance()
	t.check(waiting and boss.phase=="dash","FIX03 basic dash starts exactly when the .184 telegraph ends")
	boss.baruka.interrupt()
	boss.global_position = Vector2.ZERO
	boss.clock = 20
	boss.start_action(chase,n.player.position)
	t.check(boss.phase=="telegraph" and is_equal_approx(boss.phase_end-boss.clock,0.125),"FIX03 chase telegraph lasts .125")
	boss.baruka.interrupt()
	n.host.free()
	await t.process_frame

func toasts(t: SceneTree) -> void:
	var n: Dictionary = preload("res://tests/fx03_p0.gd").new().fixture(t)
	var view: Control = n.director.toast_view
	view.set_process(false)
	var values: Dictionary = view.presentation
	t.check(is_equal_approx(values.Toast_old_alpha,0.6) and is_equal_approx(values.Toast_old_fade_sec,0.12) and is_equal_approx(values.Toast_old_scale,0.85) and is_equal_approx(values.Toast_old_shrink_sec,0.12) and is_equal_approx(values.Toast_gap_px,4),"FIX03 toast keys old alpha .6 fade .12 scale .85 shrink .12 gap 4")
	t.check(is_equal_approx(values.Toast_sec,2) and int(values.Toast_max)==4 and is_equal_approx(view.FADE_IN_SEC,0.16) and is_equal_approx(view.FADE_OUT_SEC,0.2),"FIX03 toast time, maximum and fades unchanged")
	view.push_message("first")
	view._process(0.4)
	var first: PanelContainer = view.entries[0].panel
	t.check(is_equal_approx(first.modulate.a,1) and first.scale.is_equal_approx(Vector2.ONE),"FIX03 a single toast stays at full alpha and size")
	view.push_message("second")
	var second: PanelContainer = view.entries[0].panel
	view._process(0.06)
	t.check(is_equal_approx(first.modulate.a,0.8) and is_equal_approx(first.scale.x,1),"FIX03 older toast dims first while keeping its size")
	view._process(0.06)
	t.check(is_equal_approx(first.modulate.a,0.6) and is_equal_approx(first.scale.x,1),"FIX03 older toast reaches alpha .6 after .12 before shrinking")
	view._process(0.06)
	t.check(is_equal_approx(first.modulate.a,0.6) and is_equal_approx(first.scale.x,0.925),"FIX03 older toast shrinks after the fade")
	view._process(0.06)
	t.check(is_equal_approx(first.modulate.a,0.6) and first.scale.is_equal_approx(Vector2.ONE*0.85) and first.pivot_offset.y==0 and is_equal_approx(first.pivot_offset.x,first.size.x/2),"FIX03 older toast ends at scale .85 anchored on its top edge")
	t.check(is_equal_approx(second.modulate.a,1) and second.scale.is_equal_approx(Vector2.ONE),"FIX03 newest toast stays at 100 percent")
	var height := maxf(second.custom_minimum_size.y,second.get_combined_minimum_size().y)
	var B := float(values.Ui_window_border_px)
	t.check(is_equal_approx(second.offset_top,view.first_top(values)) and is_equal_approx(first.offset_top,second.offset_top+height-B+6-B*0.85) and is_equal_approx(first.position.y,first.offset_top),"FIX03 newest toast on top and the older one below it (JUICE01 drawn border gap 6)")
	view.push_message("third")
	view._process(0.3)
	var third: PanelContainer = view.entries[0].panel
	var second_height := maxf(second.custom_minimum_size.y,second.get_combined_minimum_size().y)
	var third_height := maxf(third.custom_minimum_size.y,third.get_combined_minimum_size().y)
	t.check(is_equal_approx(second.offset_top,third.offset_top+third_height-B+6-B*0.85) and is_equal_approx(first.offset_top,second.offset_top+(second_height-B)*0.85+6-B*0.85) and is_equal_approx(second.scale.x,0.85) and is_equal_approx(first.scale.x,0.85) and is_equal_approx(third.scale.x,1),"FIX03 three toasts restack by the shrunken heights (JUICE01 drawn border gap 6)")
	n.host.free()
	await t.process_frame

func spawn(n: Dictionary, boss_id: String, at: float) -> Node2D:
	n.director.timeline = [{"Id":"fix03_"+boss_id+str(at),"Time_mmss":0,"Boss_id":boss_id}]
	n.manager._elapsed_seconds = at
	n.director.advance(at,0)
	n.manager._elapsed_seconds = at+3.5
	n.director.advance(at+3.5,0)
	return n.director.actor

func boss_bar(t: SceneTree) -> void:
	var n: Dictionary = preload("res://tests/fx03_p0.gd").new().fixture(t)
	var bar: Control = n.director.boss_bar
	var view: Control = n.director.toast_view
	var values: Dictionary = view.presentation
	t.check(bar!=null and not bar.visible and view.stack_offset==0 and not bar.is_processing() and not bar.is_physics_processing(),"FIX03 boss bar hidden and idle before any boss")
	var bear: Node2D = spawn(n,"boss_middle",100)
	await t.process_frame
	t.check(is_instance_valid(bear) and bear.is_active and bar.visible and bar.name_label.text==String(n.manager._enemy_records[bear.enemy_id].Name_ko) and is_equal_approx(bar.ratio(),1),"FIX03 boss bar shows the boss name and a full bar once the boss is active")
	t.check(bar.fill.size.is_equal_approx(Vector2(435.2,22)) and bar.fill.texture==load("res://assets/ui/ui_boss_bar_fill.png") and bar.frame is NinePatchRect and bar.fill.get_index()>bar.frame.get_index(),"FIX03 boss bar fill inside the textured frame as separate nodes (FIX05 480 frame, 435.2x22 fill)")
	var hud: CanvasLayer = n.host.find_child("TopExperienceBar",true,false).get_parent().get_parent() if n.host.find_child("TopExperienceBar",true,false)!=null else null
	var xp: Control = n.host.find_child("TopExperienceBar",true,false)
	var level: Control = n.host.find_child("PlayerLevel",true,false)
	var timer: Control = n.host.find_child("ElapsedTime",true,false)
	var amount: Control = n.host.find_child("ExperienceAmount",true,false)
	var box: Rect2 = bar.get_global_rect()
	t.check(hud!=null and box.position.y>=xp.get_global_rect().end.y and is_equal_approx(box.get_center().x,640) and not box.intersects(level.get_global_rect()) and not box.intersects(timer.get_global_rect()) and not box.intersects(amount.get_global_rect()),"FIX03 boss bar sits top centre below the experience bar clear of level, xp amount and time")
	view.set_process(false)
	view.push_message("probe")
	view._process(0.3)
	var toast: PanelContainer = view.entries[0].panel
	var drawn_top: float = toast.offset_top+float(values.Ui_window_border_px)
	t.check(view.stack_offset>0 and is_equal_approx(drawn_top,box.end.y+float(values.Boss_bar_toast_gap_px)),"FIX03 toasts stack below the boss bar while it is shown")
	var updates: int = bar.updates
	for i in range(5): await t.process_frame
	t.check(bar.updates==updates and not bar.is_processing(),"FIX03 boss bar does no per-frame update while hp is unchanged")
	bear.apply_damage(275)
	t.check(bar.updates==updates+1 and is_equal_approx(bar.ratio(),float(bear.hp)/bear.max_hp) and is_equal_approx(bar.fill.size.x,435.2*bear.hp/bear.max_hp) and is_equal_approx(bar.fill.size.y,22),"FIX03 boss bar fill follows hp on the damage signal only (FIX05 435.2 fill)")
	t.paused = true
	t.check(bar.visible,"FIX03 boss bar stays visible while paused")
	t.paused = false
	t.check(bear.has_method("draw_health_bar"),"FIX03 small overhead boss hp bar code is kept")
	bear.apply_damage(bear.hp)
	t.check(not bar.visible and bar.boss==null and view.stack_offset==0,"FIX03 boss bar hides when the boss is killed and toasts return to the top")
	var baruka: Node2D = spawn(n,"boss_final",200)
	t.check(is_instance_valid(baruka) and bar.visible and bar.boss==baruka and bar.name_label.text=="바루카" and is_equal_approx(bar.ratio(),1),"FIX03 boss bar switches to the next boss at full")
	baruka.apply_damage(100)
	var partial: float = bar.ratio()
	n.host._end_round(false)
	t.check(partial<1 and not bar.visible and bar.boss==null,"FIX03 boss bar hides on the result screen")
	baruka.apply_damage(50)
	t.check(not bar.visible,"FIX03 released boss bar ignores later damage")
	t.paused = false
	n.host.free()
	await t.process_frame

func count(audio: Node, id: String) -> int:
	return int(audio.request_counts.get(id,0))

func flow(t: SceneTree, store: CsvDataStore) -> void:
	var region: Dictionary = store.get_row("region.csv","region_02")
	t.check(bool(region.Locked) and String(region.Locked_text).is_empty() and preload("res://scripts/flow_data.gd").validate(store).is_empty(),"FIX03 region_02 stays locked with an empty Locked_text that validates")
	var audio: Node = t.root.get_node("GameAudio")
	t.check(audio.sounds.has("transition_menu") and audio.sounds.has("transition_stage") and int(audio.sounds.transition_menu.max)==1 and is_equal_approx(audio.sounds.transition_stage.pitch,0) and is_equal_approx(audio.sounds.transition_menu.volume,0),"FIX03 transition sounds registered with volume 0 one voice no pitch spread")
	var menu_before := count(audio,"transition_menu")
	var stage_before := count(audio,"transition_stage")
	var game := preload("res://scripts/game_flow.gd").new()
	t.root.add_child(game)
	var transition: CanvasLayer = game.ui.transition
	var early := false
	var until := Time.get_ticks_msec()+15000
	while game.state=="loading" and Time.get_ticks_msec()<until:
		if transition.mode=="idle" and count(audio,"transition_menu")!=menu_before: early = true
		await t.process_frame
	t.check(not early and count(audio,"transition_menu")==menu_before+1 and count(audio,"transition_stage")==stage_before,"FIX03 transition_menu requested once when the loading cover starts")
	while game.ui.menu_locked(): await t.process_frame
	var ui: Control = game.ui
	t.check(ui.settings.find_child("Notice",true,false)==null and ui.settings.find_children("*","Label",true,false).filter(func(label: Label) -> bool: return label.text==UI.NOTICE).is_empty(),"FIX03 settings window has no copyright notice")
	var size: int = ui.notice.get_theme_font_size("font_size")
	t.check(ui.notice.visible and ui.notice.text==UI.NOTICE and size==13 and size==roundi(11*1.2),"FIX03 menu bottom notice remains at 13px (11 x1.2)")
	var notice_box := Rect2(ui.notice.global_position,Vector2(ui.notice.size.x,UI.BOLD.get_height(size)))
	var text_width: float = UI.BOLD.get_string_size(UI.NOTICE,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	t.check(is_equal_approx(notice_box.end.y,720) and ui.notice.vertical_alignment==VERTICAL_ALIGNMENT_TOP and text_width<=notice_box.size.x and not notice_box.intersects(ui.start_button.get_global_rect()) and not notice_box.intersects(Rect2(260,650,760,20)) and not notice_box.intersects(Rect2(100,674,1080,26)),"FIX03 notice text line ends on the screen bottom, fits one line and overlaps no button, bar or caption")
	game.change_region(1)
	t.check(game.regions[game.region_index].Id=="region_02" and ui.locked_label.text.is_empty() and ui.start_button.disabled and ui.locked_click.visible and ui.cards[1].get_node("Lock").visible,"FIX03 second region card has no text but keeps the lock and disabled start")
	game.start_region()
	t.check(game.session==null and game.state=="menu" and not ui.hint.visible and count(audio,"transition_stage")==stage_before,"FIX03 locked region still rejects entry without a notice or entry sound")
	game.change_region(-1)
	ui.start_button.pressed.emit()
	t.check(transition.busy() and count(audio,"transition_stage")==stage_before+1,"FIX03 transition_stage requested once when the stage cover starts")
	transition._process(transition.cover_sec)
	t.check(game.state=="playing" and transition.mode=="reveal" and count(audio,"transition_stage")==stage_before+1,"FIX03 reveal after a cover does not request the sound again")
	transition._process(transition.reveal_sec)
	game.session.round_ended.emit({"seconds":12.0,"level":1,"kills":0,"shadows":[],"cleared":false})
	game.start_region()
	t.check(game.state=="playing" and transition.mode=="reveal" and count(audio,"transition_stage")==stage_before+2,"FIX03 retry entry reveal requests transition_stage once")
	transition._process(transition.reveal_sec)
	game.show_menu()
	transition._process(transition.reveal_sec)
	t.check(count(audio,"transition_stage")==stage_before+2 and count(audio,"transition_menu")==menu_before+1,"FIX03 returning to the menu requests no entry sound")
	transition.enabled = false
	ui.enter_menu(func() -> void: pass)
	ui.start_button.pressed.emit()
	t.check(game.state=="playing" and transition.mode=="idle" and count(audio,"transition_stage")==stage_before+2 and count(audio,"transition_menu")==menu_before+1,"FIX03 Ui_fx_enabled 0 switches at once with no entry sound")
	game.session.round_ended.emit({"seconds":3.0,"level":1,"kills":0,"shadows":[],"cleared":false})
	game.start_region()
	t.check(game.state=="playing" and count(audio,"transition_stage")==stage_before+2,"FIX03 retry without effects requests no entry sound")
	game.free()
	t.paused = false
	await t.process_frame
