extends RefCounted
# BAL-02: balance data, Baruka telegraph/walk, basic attack extra targets, ice bear telegraph extras,
# loading -> menu entry cover.
const Store = preload("res://scripts/csv_data_store.gd")
const ChoiceData = preload("res://scripts/choice_data.gd")

func run(t: SceneTree) -> void:
	var store: CsvDataStore = t._store()
	t.check(store.load_all().is_empty(),"BAL02 actual data loads")
	data(t,store)
	choice_schema(t)
	await baruka(t,store)
	await targets(t)
	await bear(t,store)
	await menu_entry(t)

func column(store: CsvDataStore, file: String, ids: Array, key: String) -> Array:
	var result: Array = []
	for id in ids: result.append(float(store.get_row(file,id)[key]))
	return result

func near(a: Array, b: Array) -> bool:
	if a.size()!=b.size(): return false
	for i in range(a.size()):
		if not is_equal_approx(float(a[i]),float(b[i])): return false
	return true

func data(t: SceneTree, store: CsvDataStore) -> void:
	t.check(near(column(store,"skill_rapid_slash_level.csv",["rapid_slash_01","rapid_slash_02","rapid_slash_03","rapid_slash_04","rapid_slash_05"],"Cooldown_sec"),[4.8,4.8,4.4,4,3.6]),"BAL02 rapid slash cooldown x0.8 is 4.8 4.8 4.4 4 3.6")
	t.check(near(column(store,"skill_dragon_fear_level.csv",["fear_01","fear_02","fear_03","fear_04","fear_05"],"Cooldown_sec"),[19.5,18.2,16.9,15.6,13]),"BAL02 dragon fear cooldown x1.3 is 19.5 18.2 16.9 15.6 13")
	var ids: Array = []
	for i in range(1,11): ids.append("level_%02d" % i)
	t.check(near(column(store,"level.csv",ids,"Xp_to_next"),[7,12,16,20,25,29,35,40,46,52]),"BAL02 Xp_to_next is 7 12 16 20 25 29 35 40 46 52")
	var basic: Dictionary = store.get_row("boss_action.csv","baruka_basic")
	t.check(is_equal_approx(float(basic.Telegraph_sec),0.23) and is_equal_approx(float(basic.Dash_speed),1560) and is_equal_approx(float(basic.Tri_width),160) and is_equal_approx(float(basic.Tri_length),140) and is_equal_approx(float(basic.Dash_distance),160),"BAL02 baruka_basic telegraph .23 speed 1560 with triangle and dash distance unchanged")
	var enemy: Dictionary = store.get_row("enemy.csv","boss_baruka")
	t.check(int(enemy.Sprite_cols)==11 and String(enemy.Walk_cols)=="3-10" and is_equal_approx(float(enemy.Walk_fps),11),"BAL02 boss_baruka Sprite_cols 11 Walk_cols 3-10 Walk_fps 11")
	for id in ["boss_ice_bear","boss_ice_elf"]:
		var other: Dictionary = store.get_row("enemy.csv",id)
		t.check(int(other.Sprite_cols)==3 and (other.Walk_cols==null or String(other.Walk_cols).is_empty()),"BAL02 Walk_cols stays empty for "+id)
	var choice: Dictionary = store.get_row("choice.csv","choice_attack_targets")
	t.check(choice.Name_ko=="기본 공격 대상" and int(choice.Effect)==ChoiceData.Effect.ATTACK_TARGETS_ADD and int(choice.Weight)==10,"BAL02 choice_attack_targets row name effect weight")
	var level_ok := true
	for i in range(1,4):
		var row: Dictionary = store.get_row("choice_level.csv","choice_attack_targets_%02d" % i)
		level_ok = level_ok and row.Choice_id=="choice_attack_targets" and int(row.Level)==i and is_equal_approx(float(row.Value),i) and row.Desc_ko=="기본 공격 대상 +%d" % i
	t.check(level_ok,"BAL02 choice_attack_targets levels 1-3 give +1 +2 +3")
	t.check(ChoiceData.validate(store,float(store.get_row("basic_attack.csv","attack_01").Interval_sec)).is_empty(),"BAL02 actual choice data validates with the new Effect")
	var values: Dictionary = preload("res://scripts/shadow_afterimage.gd").compile_values(presentation(store))
	t.check(values.Blink_warn_outline==Color("#3a8dff") and values.Blink_warn_color==Color("#5ab4ff") and is_equal_approx(values.Blink_warn_alpha,0.18) and is_equal_approx(values.Blink_warn_deep_alpha,0.32),"BAL02 blink warning is blue outline 3a8dff fill 5ab4ff .18 deep .32")
	t.check(values.Boss_warn_outline==Color("#c81e32") and values.Boss_warn_color==Color("#ff3c50") and is_equal_approx(values.Boss_warn_alpha,0.18) and is_equal_approx(values.Boss_warn_deep_alpha,0.32),"BAL02 other boss warnings keep the red FX05 colours")
	t.check(int(values.Bear_fan_arc_count)==3 and is_equal_approx(values.Bear_fan_blink_from,0.7) and is_equal_approx(values.Bear_fan_blink_hz,2) and int(values.Bear_dash_chevron_count)==5 and int(values.Bear_slam_crack_count)==6 and is_equal_approx(values.Bear_slam_flash_sec,0.15),"BAL02 bear telegraph keys three arcs blink .7/2Hz five chevrons six cracks .15 flash")

func presentation(store: CsvDataStore) -> Dictionary:
	var raw := {}
	for row in store.get_table("combat_presentation.csv").values(): raw[row.Id] = row.Value
	return raw

func choice_error(level_rows: String, effect: String = "attack_targets_add") -> String:
	var store := Store.new()
	ChoiceData.register_schemas(store)
	var text := {"choice.csv":"Id,Name_ko,Effect,Weight,Note\nm,targets,"+effect+",1,test\nh,heal,heal,0,test\n",
		"choice_level.csv":"Id,Choice_id,Level,Value,Desc_ko,Note\n"+level_rows+"h1,h,1,30,heal,test\n",
		"choice_rule.csv":"Id,Reroll_count,Note\nchoice_rule_01,3,test\n"}
	for file in text:
		var error := store.load_text(file,text[file])
		if not error.is_empty(): return error
	return ChoiceData.validate(store,0.6)

func choice_schema(t: SceneTree) -> void:
	t.check(choice_error("m1,m,1,1,one,test\nm2,m,2,2,two,test\n").is_empty(),"BAL02 attack_targets_add Effect passes schema and validation")
	t.check(not choice_error("m1,m,1,1,one,test\n","attack_targets").is_empty(),"BAL02 unknown Effect name still rejected")
	for value in ["0","1.5"]:
		t.check(not choice_error("m1,m,1,"+value+",one,test\n").is_empty(),"BAL02 attack_targets_add Value must be a whole number of at least 1: "+value)

func boss_rows(store: CsvDataStore, boss_id: String) -> Array:
	var rows: Array = []
	for row in store.get_table("boss_action.csv").values():
		if row.Boss_id==boss_id: rows.append(row)
	return rows

func baruka(t: SceneTree, store: CsvDataStore) -> void:
	var n: Dictionary = preload("res://tests/fx03_p0.gd").new().fixture(t)
	var fx: Node2D = n.manager.boss_fx
	var boss: Node2D = n.manager.create_boss("boss_baruka",boss_rows(store,"boss_final"),func() -> Node2D: return n.player)
	boss.position = Vector2.ZERO
	n.player.position = Vector2(500,0)
	var body: SpriteBody = boss.sprite_body
	t.check(body.columns==11 and body.walk_cols==Vector2i(3,10) and is_equal_approx(body.walk_fps,11) and is_equal_approx(body.source_rect().size.x,382) and is_equal_approx(body.source_rect().size.y,339),"BAL02 baruka sheet has eleven 382x339 cells and walk span 3-10")
	# Gate walk-out (FX05) uses the walk cells while the picture is still emerging.
	fx.schedule_gate("bal02",boss.position,0)
	n.manager.activate_boss(boss)
	fx.advance(0)
	var gate_columns: Array = []
	for i in range(4):
		fx.advance(0.1)
		gate_columns.append(body.frame_column)
	t.check(gate_columns==[4,5,6,7] and body.presentation_alpha<1,"BAL02 gate walk-out cycles the walk cells: "+str(gate_columns))
	fx.advance(1)
	boss.clock = 0
	boss.update_boss_visual(0.1,false)
	t.check(body.frame_column==0,"BAL02 standing baruka rests on column 0")
	var seen: Array = []
	for i in range(9):
		boss.update_boss_visual(1.0/11.0,true)
		seen.append(body.frame_column)
	t.check(seen==[4,5,6,7,8,9,10,3,4],"BAL02 moving baruka with no action cycles columns 3-10 at 11fps: "+str(seen))
	boss.update_boss_visual(0.1,false)
	t.check(body.frame_column==0,"BAL02 baruka returns to column 0 when it stops")
	var basic: Dictionary = store.get_row("boss_action.csv","baruka_basic")
	boss.start_action(basic,n.player.position)
	boss.update_boss_visual(0.1,true)
	t.check(boss.phase=="telegraph" and body.frame_column==1 and is_equal_approx(boss.phase_end-boss.clock,0.23),"BAL02 telegraph pose 1 wins over walking and lasts .23")
	var points: PackedVector2Array = boss.baruka.triangle_points()
	var length: float = boss.dash_length
	boss.clock = boss.phase_end
	boss.baruka.advance()
	boss.update_boss_visual(0.01,true)
	t.check(boss.phase=="dash" and body.frame_column==2 and is_equal_approx(length/float(boss.current.Dash_speed),length/1560.0),"BAL02 dash pose 2 wins over walking and travels at 1560")
	boss.baruka.interrupt()
	boss.global_position = Vector2.ZERO
	boss.clock = 50
	var old := basic.duplicate(true)
	old.Telegraph_sec = 0.155
	old.Dash_speed = 2340
	boss.start_action(old,n.player.position)
	t.check(boss.baruka.triangle_points()==points and points.size()==3 and is_equal_approx(boss.dash_length,length),"BAL02 triangle and dash corridor geometry equal the pre-change row")
	boss.baruka.interrupt()
	var blink: Dictionary = store.get_row("boss_action.csv","baruka_blink")
	boss.start_action(blink,n.player.position)
	boss.queue_redraw()
	await t.process_frame
	await t.process_frame
	t.check(int(boss.current.Kind)==8 and boss.warning_extra==0 and boss.visual_settings.Blink_warn_color==Color("#5ab4ff"),"BAL02 blink telegraph draws from the blue keys without bear extras")
	boss.baruka.interrupt()
	for pair in [["boss_ice_bear","boss_middle"],["boss_ice_elf","boss_early"]]:
		var other: Node2D = n.manager.create_boss(pair[0],boss_rows(store,pair[1]),func() -> Node2D: return n.player)
		other.position = Vector2(-300,0)
		n.manager.activate_boss(other)
		fx.advance(2)
		other.update_boss_visual(0.1,true)
		other.update_boss_visual(0.1,true)
		t.check(other.sprite_body.walk_cols.x<0 and other.sprite_body.frame_column==0,"BAL02 boss without Walk_cols keeps column 0 while moving: "+pair[0])
	n.host.free()
	await t.process_frame

func strike(n: Dictionary, enemies: Array, places: Array, extra: int, now: float) -> Array:
	var player: Node2D = n.player
	for i in range(enemies.size()):
		enemies[i].global_position = player.global_position+places[i]
		enemies[i].hp = enemies[i].max_hp
	for item in player.basic_fx_pool: item.finish()
	player.apply_choice_modifiers(0,0,0,extra)
	player.cancel_basic_attack()
	player._attack_ready_at = 0
	player.update_basic_attack(now,enemies)
	return losses(enemies)

func losses(enemies: Array) -> Array:
	var result: Array = []
	for enemy in enemies: result.append(enemy.max_hp-enemy.hp)
	return result

func active_fx(player: Node2D) -> int:
	return player.basic_fx_pool.filter(func(item: Node2D) -> bool: return item.active).size()

func targets(t: SceneTree) -> void:
	var n: Dictionary = preload("res://tests/fx03_p0.gd").new().fixture(t)
	var player: Node2D = n.player
	var damage := int(player._attack_data.Damage)
	var enemies: Array = []
	for i in range(4):
		n.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":1})
		enemies.append(n.manager.get_living_enemies().back())
	# Four separate directions: no triangle contains a second enemy.
	var cross: Array = [Vector2(50,0),Vector2(0,-60),Vector2(-70,0),Vector2(0,80)]
	t.check(player.basic_extra_targets==0 and strike(n,enemies,cross,0,1000)==[damage,0,0,0] and active_fx(player)==1,"BAL02 N0 strikes only the first target with one effect")
	t.check(strike(n,enemies,cross,1,2000)==[damage,damage,0,0] and active_fx(player)==2,"BAL02 N1 strikes the two nearest targets with two effects")
	t.check(strike(n,enemies,cross,2,3000)==[damage,damage,damage,0] and active_fx(player)==3,"BAL02 N2 strikes three targets with three effects")
	t.check(strike(n,enemies,cross,3,4000)==[damage,damage,damage,damage] and active_fx(player)==4,"BAL02 N3 strikes four targets with four effects")
	player.update_basic_attack(4000+float(player._attack_data.Hit_gap_sec),enemies)
	t.check(losses(enemies)==[damage*2,damage*2,damage*2,damage*2],"BAL02 the second hit of the same attack also strikes every picked target once")
	# Two enemies in one line: each lies inside both triangles but is damaged once per strike.
	var pair: Array = [enemies[0],enemies[1]]
	var first_place: Vector2 = Vector2(40,0)
	t.check(strike(n,pair,[first_place,Vector2(70,4)],1,5000)==[damage,damage] and active_fx(player)==2,"BAL02 an enemy inside several triangles takes damage once")
	var moved: Vector2 = pair[0].global_position-player.global_position
	t.check(is_equal_approx(pair[0].knockback_distance,float(player._attack_data.Knockback_distance)) and is_equal_approx(pair[0].knockback_duration,float(player._attack_data.Knockback_sec)) and pair[0].knockback_elapsed==0 and moved.is_equal_approx(first_place),"BAL02 overlapped enemy holds one unadvanced knockback of the normal distance")
	t.check(strike(n,pair,[Vector2(50,0),Vector2(0,-60)],3,6000)==[damage,damage] and active_fx(player)==2,"BAL02 fewer targets than 1+N strikes only those present")
	t.check(strike(n,pair,[Vector2(50,0),Vector2(0,-200)],3,7000)==[damage,0] and active_fx(player)==1,"BAL02 extra targets obey the same attack range")
	enemies[1].hp = enemies[1].max_hp
	enemies[1].global_position = player.global_position+Vector2(0,-60)
	enemies[1].hp -= 1
	enemies[0].global_position = player.global_position+Vector2(50,0)
	enemies[0].hp = enemies[0].max_hp
	enemies[2].global_position = player.global_position+Vector2(-70,0)
	enemies[2].hp = enemies[2].max_hp
	for item in player.basic_fx_pool: item.finish()
	player.apply_choice_modifiers(0,0,0,1)
	player.cancel_basic_attack()
	player._attack_ready_at = 0
	player.update_basic_attack(8000,[enemies[0],enemies[1],enemies[2]])
	t.check(enemies[1].max_hp-enemies[1].hp==damage+1 and enemies[0].max_hp-enemies[0].hp==damage and enemies[2].hp==enemies[2].max_hp,"BAL02 extra pick follows the first-target priority (lowest hp, then nearest)")
	player.apply_choice_modifiers(0,0,0,0)
	player.cancel_basic_attack()
	# Real selection path: the card raises the extra target count by level.
	var choices: Node = n.choices
	var id := "choice_attack_targets"
	var shown: Array = []
	var counts: Array = []
	for level in range(1,4):
		player.add_experience(player.get_xp_to_next())
		choices.cards = [id,choices.heal_id,choices.heal_id]
		var state: Dictionary = choices.card_state(0)
		shown.append([state.name,state.description,state.next,state.max])
		choices.select(0)
		while choices.active: choices.select(1)
		counts.append(player.basic_extra_targets)
	t.check(counts==[1,2,3] and not choices.candidates().has(id),"BAL02 selecting the card three times gives +1 +2 +3 and then leaves the pool: "+str(counts))
	t.check(shown==[["기본 공격 대상","기본 공격 대상 +1",1,3],["기본 공격 대상","기본 공격 대상 +2",2,3],["기본 공격 대상","기본 공격 대상 +3",3,3]] and preload("res://scripts/system_ui.gd").icon(id)==null,"BAL02 choice card shows name and +N text with no icon")
	t.paused = false
	n.host.free()
	await t.process_frame

func bear(t: SceneTree, store: CsvDataStore) -> void:
	var n: Dictionary = preload("res://tests/fx03_p0.gd").new().fixture(t)
	var boss: Node2D = n.manager.create_boss("boss_ice_bear",boss_rows(store,"boss_middle"),func() -> Node2D: return n.player)
	boss.position = Vector2.ZERO
	n.manager.activate_boss(boss)
	n.manager.boss_fx.advance(2)
	n.player.position = Vector2(2000,0)
	var children: int = boss.get_child_count()
	var expected := {"ice_bear_basic":[1,0.4,150.0],"ice_bear_dash":[2,0.8,400.0],"ice_bear_slam":[3,0.8,320.0]}
	for id in expected:
		var row: Dictionary = store.get_row("boss_action.csv",id)
		boss.global_position = Vector2.ZERO
		boss.clock = 100
		boss.start_action(row,boss.global_position+Vector2(100,0))
		var size: float = float(row.Range) if id=="ice_bear_basic" else (boss.dash_length if id=="ice_bear_dash" else float(row.Slam_radius))
		t.check(is_equal_approx(boss.phase_end-boss.clock,expected[id][1]) and is_equal_approx(size,expected[id][2]),"BAL02 bear telegraph time and size unchanged: "+id)
		var drawn: Array = []
		for progress in [0.1,0.75,0.95]:
			boss.clock = 100+float(row.Telegraph_sec)*progress
			boss.queue_redraw()
			await t.process_frame
			await t.process_frame
			drawn.append(boss.warning_extra)
		t.check(drawn==[expected[id][0],expected[id][0],expected[id][0]] and boss.get_child_count()==children,"BAL02 bear telegraph extra drawn through the telegraph without new nodes: "+id)
		boss.clock = boss.phase_end
		boss.advance_action()
		boss.queue_redraw()
		await t.process_frame
		await t.process_frame
		t.check(boss.warning_extra==0 and boss.phase!="telegraph","BAL02 bear telegraph extra cleared when the telegraph ends: "+id)
		boss.finish_action(boss.clock)
		boss.global_position = Vector2.ZERO
	n.host.free()
	await t.process_frame

func menu_entry(t: SceneTree) -> void:
	var flow := preload("res://scripts/game_flow.gd").new()
	t.root.add_child(flow)
	var transition: CanvasLayer = flow.ui.transition
	var early_cover := false
	var cover_seen := false
	var blocked_during_cover := false
	var until := Time.get_ticks_msec()+15000
	while flow.state=="loading" and Time.get_ticks_msec()<until:
		await t.process_frame
		if flow.state!="loading": break
		var elapsed: float = (Time.get_ticks_msec()-flow.loading_started)/1000.0
		if transition.mode!="idle":
			cover_seen = true
			blocked_during_cover = transition.blocking and transition.rect.mouse_filter==Control.MOUSE_FILTER_STOP and flow.ui.screen=="loading"
			if elapsed<flow.loading_minimum or flow.loading_elapsed<flow.loading_minimum: early_cover = true
	t.check(cover_seen and not early_cover and blocked_during_cover and flow.loading_elapsed>=5,"BAL02 cover starts only after the 5s loading hold and blocks input while loading is still shown")
	var covered_for: float = (Time.get_ticks_msec()-flow.loading_started)/1000.0-flow.loading_elapsed
	t.check(flow.state=="menu" and flow.ui.screen=="menu" and transition.mode=="reveal" and transition.blocking and covered_for>=transition.cover_sec-0.05 and is_equal_approx(transition.cover_sec,0.5) and is_equal_approx(transition.reveal_sec,0.6),"BAL02 menu appears after the .5 cover and the .6 reveal starts")
	var index: int = flow.region_index
	flow.ui.start_button.pressed.emit()
	flow.change_region(1)
	flow.ui.toggle_settings()
	t.check(flow.state=="menu" and transition.mode=="reveal" and flow.region_index==index and not flow.ui.settings.visible and transition.rect.mouse_filter==Control.MOUSE_FILTER_STOP,"BAL02 start, region change and settings are blocked during the reveal")
	until = Time.get_ticks_msec()+3000
	while transition.mode!="idle" and Time.get_ticks_msec()<until: await t.process_frame
	t.check(transition.mode=="idle" and not transition.blocking and not transition.rect.visible and transition.rect.mouse_filter==Control.MOUSE_FILTER_IGNORE,"BAL02 entry effect ends hidden and releases input")
	flow.change_region(1)
	flow.ui.toggle_settings()
	t.check(flow.region_index!=index and flow.ui.settings.visible,"BAL02 menu input works after the reveal")
	flow.ui.toggle_settings()
	flow.free()
	t.paused = false
	await t.process_frame
