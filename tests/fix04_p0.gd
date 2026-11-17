extends RefCounted
# FIX-04: boss bar textures, superseded toast lifetime, 1.3x HUD badge/roster, clear time record,
# max hp choice, rapid slash 3-beat combo (picture/sound only).
const Store = preload("res://scripts/csv_data_store.gd")
const ChoiceData = preload("res://scripts/choice_data.gd")
const UI = preload("res://scripts/system_ui.gd")

func run(t: SceneTree) -> void:
	var store: CsvDataStore = t._store()
	t.check(store.load_all().is_empty(),"FIX04 actual data loads")
	await boss_bar(t)
	await toast_life(t)
	await hud(t)
	await clear_time(t)
	max_hp_data(t,store)
	await max_hp(t)
	await rapid_combo(t)

func fixture(t: SceneTree) -> Dictionary:
	return preload("res://tests/fx03_p0.gd").new().fixture(t)

func spawn(n: Dictionary, boss_id: String, at: float) -> Node2D:
	return preload("res://tests/fix03_p0.gd").new().spawn(n,boss_id,at)

func boss_bar(t: SceneTree) -> void:
	var n := fixture(t)
	var bar: Control = n.director.boss_bar
	t.check(bar.frame is NinePatchRect and bar.frame.texture==load("res://assets/ui/ui_boss_bar_frame.png") and bar.frame.patch_margin_left==22 and bar.frame.patch_margin_top==22 and bar.frame.patch_margin_right==22 and bar.frame.patch_margin_bottom==22,"FIX04 boss bar frame is the 9-slice ui_boss_bar_frame with patch 22")
	t.check(bar.fill.texture==load("res://assets/ui/ui_boss_bar_fill.png") and bar.trail.texture==load("res://assets/ui/ui_boss_bar_trail.png") and bar.trail.get_index()<bar.fill.get_index() and bar.frame.get_index()<bar.trail.get_index(),"FIX04 fill and trail use their textures, trail behind fill, both over the frame")
	t.check(is_equal_approx(bar.frame.size.x,600) and is_equal_approx(bar.frame.size.y,60) and bar.fill.position.is_equal_approx(bar.frame.position+Vector2(28,16)) and bar.fill.size.is_equal_approx(Vector2(544,28)),"FIX04 frame 600 wide, fill 28 high inside border line 12 + pad 16/4")
	var crest_bottom: float = bar.crest.position.y+bar.crest.size.y
	t.check(bar.crest.texture==UI.CREST and bar.crest.size.is_equal_approx(Vector2(144,51)) and is_equal_approx(bar.crest.get_rect().get_center().x,300) and is_equal_approx(crest_bottom,bar.frame.position.y+12) and crest_bottom<=bar.fill.position.y,"FIX04 crest 1.5x centred and resting on the frame without covering the fill")
	t.check(bar.name_label.get_rect().end.y<=bar.crest.position.y+0.01 and bar.name_label.get_theme_font("font")==UI.BLACK and bar.name_label.get_theme_font_size("font_size")==28 and bar.name_label.get_theme_color("font_outline_color")==Color("#1a1240"),"FIX04 Black name keeps 28px with a 1a1240 outline above the crest")
	var bear: Node2D = spawn(n,"boss_middle",100)
	var box: Rect2 = bar.get_global_rect()
	for id in ["PlayerLevel","ElapsedTime","ExperienceAmount","TopExperienceBar"]:
		var other: Control = n.host.find_child(id,true,false)
		t.check(other!=null and not box.intersects(other.get_global_rect()),"FIX04 boss bar, crest and name clear of "+id)
	var view: Control = n.director.toast_view
	t.check(bar.visible and is_equal_approx(view.stack_offset,bar.bottom_px()+6-float(view.presentation.Toast_top_px)),"FIX04 toasts still start below the taller bar")
	bear.apply_damage(330)
	t.check(is_equal_approx(bar.ratio(),float(bear.hp)/bear.max_hp) and is_equal_approx(bar.fill.size.x,544.0*bear.hp/bear.max_hp) and is_equal_approx(bar.fill.size.y,28) and is_equal_approx(bar.trail_ratio(),1) and bar.is_processing(),"FIX04 fill width follows hp only; trail waits")
	bar._process(0.25)
	bar._process(0.35)
	t.check(is_equal_approx(bar.trail.size.x,bar.fill.size.x) and is_equal_approx(bar.trail.size.y,28) and not bar.is_processing(),"FIX04 trail texture drains with the JUICE01 timing")
	var updates: int = bar.updates
	for i in range(3): await t.process_frame
	t.check(bar.updates==updates and not bar.is_processing(),"FIX04 idle textured bar does no per-frame work")
	bear.apply_damage(bear.hp)
	var elf: Node2D = spawn(n,"boss_early",200)
	elf.elf.start_stealth()
	t.check(not bar.visible,"FIX04 textured bar hides during elf stealth")
	elf.elf.end_stealth(n.manager._elapsed_seconds)
	t.check(bar.visible and bar.boss==elf,"FIX04 textured bar returns after stealth")
	n.host.free()
	await t.process_frame

func toast_life(t: SceneTree) -> void:
	var n := fixture(t)
	var view: Control = n.director.toast_view
	view.set_process(false)
	t.check(is_equal_approx(view.presentation.Toast_superseded_life_sec,1) and is_equal_approx(view.presentation.Toast_sec,2) and is_equal_approx(view.FADE_OUT_SEC,0.2),"FIX04 superseded life 1s, normal 2s, fade .2")
	view.push_message("alone")
	var alone: Dictionary = view.entries[0]
	var fade_at := -1.0
	for i in range(200):
		view._process(0.01)
		if fade_at<0 and float(alone.remaining)<=0.2+0.000001: fade_at = alone.age
		if view.entries.is_empty(): break
	t.check(is_equal_approx(fade_at,1.8) and view.entries.is_empty(),"FIX04 a toast with no newer message fades at 1.8s and is gone at 2s")
	view.push_message("first")
	var first: Dictionary = view.entries[0]
	view._process(0.4)
	view.push_message("second")
	t.check(is_equal_approx(first.remaining,0.8),"FIX04 older toast now fades at created + 1s (.6s from now)")
	var second: Dictionary = view.entries[0]
	view._process(0.7)
	t.check(float(first.remaining)<0.2 and float(first.remaining)>0 and first.panel.modulate.a<0.6,"FIX04 the older toast is fading at created + 1.1s")
	view._process(0.4)
	view.push_message("third")
	t.check(is_equal_approx(second.remaining,0.2) and not view.entries.has(first),"FIX04 a toast older than 1s starts fading at once when a newer one arrives")
	var third: Dictionary = view.entries[0]
	t.check(is_equal_approx(third.remaining,2.0) and is_equal_approx(third.panel.modulate.a,0) and is_equal_approx(view.entries[1].panel.scale.x,1),"FIX04 the new toast keeps the normal 2s")
	view.push_message("warning",5.0,true)
	var warning: Dictionary = view.entries[0]
	view._process(1.5)
	view.push_message("after warning")
	t.check(not warning.retiring and float(warning.remaining)>1,"FIX04 the boss arrival warning keeps its own timing")
	n.host.free()
	await t.process_frame

func hud(t: SceneTree) -> void:
	var n := fixture(t)
	n.shadows.summon("igrit")
	n.shadows.summon("charger_test")
	await t.process_frame
	await t.process_frame
	var hud_node: Node = n.host.find_child("TemporaryHud",true,false)
	var skill_ui: Control = n.skills.ui
	var badge: Rect2 = skill_ui.points_rect()
	t.check(badge.size.is_equal_approx(Vector2(312,104)) and is_equal_approx(badge.end.y,skill_ui.card_rect(0).position.y-16),"FIX04 points badge 1.3x (312x104) still 16px above the cards")
	var cards: Array = hud_node.roster.get_children()
	var label: Label = cards[0].get_child(2)
	t.check(cards.size()==2 and cards[0].custom_minimum_size.is_equal_approx(Vector2(144,64)*1.3) and cards[0].get_child(0).size.is_equal_approx(Vector2(52,52)) and label.get_theme_font_size("font_size")==21,"FIX04 owned shadow cards, icons and names 1.3x")
	var roster: Rect2 = Rect2(hud_node.roster.position,hud_node.roster.size)
	var row := Rect2(skill_ui.card_rect(0).position,Vector2.ZERO).merge(skill_ui.card_rect(3))
	t.check(not roster.intersects(badge) and not roster.intersects(row) and not badge.intersects(row) and is_equal_approx(roster.end.x,row.end.x),"FIX04 roster right-aligned above the cards and clear of the badge")
	var screen := Rect2(Vector2.ZERO,Vector2(1280,720))
	var transform: Transform2D = skill_ui.get_global_transform_with_canvas()
	t.check(screen.encloses(transform*badge) and screen.encloses(transform*roster) and screen.encloses(transform*row),"FIX04 badge, roster and cards stay inside the screen")
	n.player.enhancement_points = 1
	var level: int = n.skills.skills.skill_rapid_slash.level
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = transform*skill_ui.card_rect(1).get_center()
	event.global_position = event.position
	n.host.get_viewport().push_input(event)
	var release := event.duplicate()
	release.pressed = false
	n.host.get_viewport().push_input(release)
	t.check(n.skills.skills.skill_rapid_slash.level==level+1 and n.player.enhancement_points==0,"FIX04 a click on the drawn rapid slash card still upgrades it")
	n.host.free()
	await t.process_frame

func clear_time(t: SceneTree) -> void:
	var flow := preload("res://scripts/game_flow.gd").new()
	t.root.add_child(flow)
	while flow.state=="loading": await t.process_frame
	while flow.ui.menu_locked(): await t.process_frame
	t.check(flow.ui.best_label.text=="최고 클리어 타임  -","FIX04 region screen shows 최고 클리어 타임 with no record")
	flow.start_region()
	flow.session.round_nodes.manager._elapsed_seconds = 300.0
	flow.session.round_nodes.player.apply_damage(100000)
	await t.process_frame
	flow.session.round_nodes.player.finish_death_presentation()
	t.check(flow.state=="result" and not flow.result.cleared and not flow.best_times.has("region_01"),"FIX04 death records nothing")
	flow.show_menu()
	flow.start_region()
	flow.session.round_nodes.manager._elapsed_seconds = 120.0
	flow.toggle_pause()
	flow.show_menu()
	t.check(not flow.best_times.has("region_01") and flow.ui.best_label.text.ends_with("-"),"FIX04 quitting to the menu records nothing")
	flow.start_region()
	flow.session.round_nodes.manager._elapsed_seconds = 333.4
	flow.session._end_round(true)
	t.check(flow.state=="result" and flow.result.cleared and is_equal_approx(flow.best_times.region_01,333.4) and flow.ui.result_text.text.contains("05:33"),"FIX04 clear records the elapsed time at the clear and the result shows the same time")
	flow.show_menu()
	t.check(flow.ui.best_label.text=="최고 클리어 타임  05:33","FIX04 region screen shows the clear time")
	flow.start_region()
	flow.session.round_nodes.manager._elapsed_seconds = 400.0
	flow.session._end_round(true)
	t.check(is_equal_approx(flow.best_times.region_01,333.4),"FIX04 a slower clear keeps the faster record")
	flow.show_menu()
	flow.start_region()
	flow.session.round_nodes.manager._elapsed_seconds = 250.0
	flow.session._end_round(true)
	flow.show_menu()
	t.check(is_equal_approx(flow.best_times.region_01,250.0) and flow.ui.best_label.text=="최고 클리어 타임  04:10","FIX04 a faster clear replaces the record")
	flow.free()
	t.paused = false
	await t.process_frame

func choice_error(level_rows: String) -> String:
	var store := Store.new()
	ChoiceData.register_schemas(store)
	var text := {"choice.csv":"Id,Name_ko,Effect,Weight,Note\nm,maxhp,max_hp_pct_add,1,test\nh,heal,heal,0,test\n",
		"choice_level.csv":"Id,Choice_id,Level,Value,Desc_ko,Note\n"+level_rows+"h1,h,1,30,heal,test\n",
		"choice_rule.csv":"Id,Reroll_count,Note\nchoice_rule_01,3,test\n"}
	for file in text:
		var error := store.load_text(file,text[file])
		if not error.is_empty(): return error
	return ChoiceData.validate(store,0.6)

func max_hp_data(t: SceneTree, store: CsvDataStore) -> void:
	var row: Dictionary = store.get_row("choice.csv","choice_max_hp")
	t.check(row.Name_ko=="최대 체력" and int(row.Effect)==ChoiceData.Effect.MAX_HP_PCT_ADD and int(row.Weight)==10 and row.Note=="FIX-04 사용자 결정","FIX04 choice_max_hp row")
	var ok := true
	for i in range(1,6):
		var level: Dictionary = store.get_row("choice_level.csv","choice_max_hp_%02d" % i)
		ok = ok and level.Choice_id=="choice_max_hp" and int(level.Level)==i and is_equal_approx(float(level.Value),3*i) and level.Desc_ko=="최대 체력 +%d%%" % (3*i)
	t.check(ok,"FIX04 choice_max_hp levels 1-5 give 3 6 9 12 15 percent")
	t.check(choice_error("m1,m,1,3,a,test\nm2,m,2,6,b,test\n").is_empty(),"FIX04 max_hp_pct_add passes schema and validation")
	for value in ["0","-3","nan","inf"]:
		t.check(not choice_error("m1,m,1,"+value+",a,test\n").is_empty(),"FIX04 max_hp_pct_add Value must be a finite positive: "+value)

func max_hp(t: SceneTree) -> void:
	var n := fixture(t)
	var player: Node2D = n.player
	var choices: Node = n.choices
	t.check(player.max_hp==100 and player._base_max_hp==100,"FIX04 player.csv Max_hp 100 is the base")
	player.hp = 60
	var results: Array = []
	for level in range(1,6):
		player.add_experience(player.get_xp_to_next())
		choices.cards = ["choice_max_hp",choices.heal_id,choices.heal_id]
		var state: Dictionary = choices.card_state(0)
		var before: int = player.hp
		var max_before: int = player.max_hp
		choices.select(0)
		while choices.active: choices.select(1)
		results.append([state.description,player.max_hp,player.hp-before,player.max_hp-max_before])
	t.check(results[0][0]=="최대 체력 +3%" and results[0][1]==103 and results[0][2]==3,"FIX04 +3% gives max 103 and raises current hp by 3")
	t.check(results[4][0]=="최대 체력 +15%" and results[4][1]==115 and results.all(func(r: Array) -> bool: return r[2]==r[3]),"FIX04 +15% gives max 115; current hp rises with every step")
	t.check(player.hp<=player.max_hp and not choices.candidates().has("choice_max_hp"),"FIX04 hp never above max and the card leaves the pool at level 5")
	player.heal_percent(100)
	t.check(player.hp==115,"FIX04 healing uses the new maximum")
	player._base_max_hp = 250
	player.max_hp = 250
	player.hp = 200
	player.apply_max_hp_percent(3)
	t.check(player.max_hp==258 and player.hp==208,"FIX04 257.5 rounds half up to 258 and hp rises by 8")
	player._base_max_hp = 50
	player.apply_max_hp_percent(3)
	t.check(player.max_hp==52 and player.hp==52,"FIX04 51.5 rounds to 52 and current hp is capped at the max")
	player._base_max_hp = 100
	player.max_hp = 100
	player.hp = 30
	player.apply_max_hp_percent(0)
	t.check(player.max_hp==100 and player.hp==30,"FIX04 no change keeps current hp")
	t.paused = false
	n.host.free()
	await t.process_frame

func count(audio: Node, id: String) -> int:
	return int(audio.request_counts.get(id,0))

func active_fx(player: Node2D) -> Array:
	return player.basic_fx_pool.filter(func(item: Node2D) -> bool: return item.active)

# Runs one rapid slash cast and records enemy hp and pose column every 1/60s.
func cast(t: SceneTree, n: Dictionary, enemy: Node2D) -> Dictionary:
	var skills: Node2D = n.skills
	var slash = skills.skills.skill_rapid_slash
	slash.cooldown_until = 0
	enemy.hp = enemy.max_hp
	skills.try_use("skill_rapid_slash")
	var trace: Array = []
	var columns: Array = []
	for i in range(60):
		trace.append([snappedf(skills.clock-slash.started_at,0.0001),enemy.hp,slash.hits_done])
		columns.append(n.player.rapid_pose_column())
		skills._physics_process(1.0/60.0)
		if not slash.active: break
	return {"trace":trace,"columns":columns,"end":slash.completed_at-slash.started_at}

func rapid_combo(t: SceneTree) -> void:
	var n := fixture(t)
	var audio: Node = t.root.get_node("GameAudio")
	var skills: Node2D = n.skills
	var player: Node2D = n.player
	t.check(int(skills.presentation.Rapid_combo_beats)==3 and skills.combo_cols==PackedInt32Array([23,24,3]),"FIX04 combo keys 3 beats with columns 23 24 3")
	n.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":1})
	var enemy: Node2D = n.manager.get_living_enemies().back()
	enemy.global_position = player.global_position+Vector2(40,0)
	enemy.max_hp = 100000
	player.last_move_direction = Vector2.RIGHT
	for item in player.basic_fx_pool: item.finish()
	var before := {"slash":count(audio,"slash"),"thrust":count(audio,"thrust"),"rapid_slash":count(audio,"rapid_slash")}
	var slash = skills.skills.skill_rapid_slash
	slash.cooldown_until = 0
	skills.try_use("skill_rapid_slash")
	var stats: Dictionary = slash.snapshot
	var beat := int(stats.Hits)*float(stats.Hit_interval_sec)/3.0
	var first_fx: Array = active_fx(player)
	t.check(player.rapid_pose_column()==23 and first_fx.size()==1 and not first_fx[0].thrust and first_fx[0].facing==Vector2.RIGHT and count(audio,"slash")==before.slash+1 and count(audio,"rapid_slash")==before.rapid_slash,"FIX04 beat 1 slash pose 23, one slash effect toward the facing and one slash sound")
	player.sprite_body.advance_player_skill_pose(Vector2.ZERO,false,0.0,false,false,true,Vector2.ZERO,player.presentation,player.rapid_pose_column())
	t.check(player.sprite_body.frame_column==23,"FIX04 the player sprite shows column 23 in beat 1")
	var columns: Array = []
	var sounds_at_beat2 := {}
	while slash.active:
		skills._physics_process(1.0/60.0)
		if slash.active: columns.append(player.rapid_pose_column())
		if skills.combo_beat==1 and sounds_at_beat2.is_empty():
			sounds_at_beat2 = {"thrust":count(audio,"thrust"),"fx":active_fx(player).filter(func(item: Node2D) -> bool: return item.thrust).size()}
	var sequence: Array = [23]
	for c in columns:
		if c!=sequence.back(): sequence.append(c)
	t.check(sequence==[23,24,3],"FIX04 beats show 23 then 24 then 3 in order: "+str(sequence))
	t.check(sounds_at_beat2.get("thrust",0)==before.thrust+1 and sounds_at_beat2.get("fx",0)==1,"FIX04 beat 2 thrust pose with one thrust effect and sound")
	t.check(count(audio,"slash")==before.slash+1 and count(audio,"thrust")==before.thrust+1 and count(audio,"rapid_slash")==before.rapid_slash+1,"FIX04 one cast plays slash, thrust and the rapid slash sound once each")
	t.check(player.rapid_pose_column()==3 and skills.combo_beat==-1,"FIX04 pose returns to the existing state when the cast ends")
	var with_combo := cast(t,n,enemy)
	skills.presentation.Rapid_combo_beats = 0
	var without := cast(t,n,enemy)
	skills.presentation.Rapid_combo_beats = 3
	t.check(with_combo.trace==without.trace and is_equal_approx(with_combo.end,without.end) and without.columns.all(func(c: int) -> bool: return c==3),"FIX04 damage, hit count and hit times are identical with and without the combo")
	var expected_beats := [0.0,beat,beat*2]
	t.check(is_equal_approx(expected_beats[2],float(stats.Hits)*float(stats.Hit_interval_sec)*2.0/3.0) and with_combo.columns[0]==23,"FIX04 beat length is Hits x Hit_interval_sec / 3")
	slash.cooldown_until = 0
	skills.try_use("skill_rapid_slash")
	player.freeze_remaining = 1.0
	t.check(slash.active and player.rapid_pose_column()==3,"FIX04 freeze returns the pose to the existing rapid slash pose at once")
	player.freeze_remaining = 0.0
	t.check(player.rapid_pose_column()==23,"FIX04 the beat pose resumes after the freeze while the cast continues")
	player.apply_damage(100000)
	t.check(player.is_dead and player.rapid_pose_column()==3,"FIX04 death drops the combo pose at once")
	t.paused = false
	n.host.free()
	await t.process_frame
