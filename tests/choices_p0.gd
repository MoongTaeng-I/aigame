extends RefCounted

const Choices = preload("res://scripts/choice_manager.gd")
const Data = preload("res://scripts/choice_data.gd")
const Store = preload("res://scripts/csv_data_store.gd")
var t: SceneTree

func run(runner: SceneTree) -> void:
	t = runner
	validate_csv()
	await queue_and_pause()
	await composition_and_weights()
	await rerolls()
	await effects()
	await healing()
	await death_and_main()

func check(ok: bool, label: String) -> void:
	t.check(ok,label)

func choice_records(count: int) -> Dictionary:
	var records := {}
	for i in range(count):
		var id := "c%d" % i
		var effect: int = [Data.Effect.ATTACK_RANGE_ADD,Data.Effect.PICKUP_RADIUS_ADD,Data.Effect.ATTACK_INTERVAL_SUB][i%3]
		records[id] = {"Id":id,"Name_ko":id,"Effect":effect,"Weight":3 if i==1 else 1}
	records["heal"] = {"Id":"heal","Name_ko":"heal","Effect":Data.Effect.HEAL,"Weight":0}
	return records

func choice_levels(count: int) -> Dictionary:
	var rows := {}
	for i in range(count):
		for level in range(1,4):
			var id := "c%d_%d" % [i,level]
			rows[id] = {"Id":id,"Choice_id":"c%d"%i,"Level":level,"Value":float(level)*(10.0 if i%3==0 else (25.0 if i%3==1 else 0.05)),"Desc_ko":"c%d level %d" % [i,level]}
	rows["h"] = {"Id":"h","Choice_id":"heal","Level":1,"Value":30.0,"Desc_ko":"heal 30 percent"}
	return rows

func fixture(count: int = 3) -> Dictionary:
	var f: Dictionary = t._s5_fixture()
	f.manager._offscreen_relocate_seconds = 1000.0
	var choices := Choices.new()
	choices.configure(f.player,choice_records(count),choice_levels(count),{"Reroll_count":3})
	f.host.add_child(choices)
	choices.random.seed = 20261109
	f.q = choices
	return f

func close(f: Dictionary) -> void:
	t.paused = false
	f.host.queue_free()
	await t.process_frame

func click(f: Dictionary, index: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = f.q.ui.card_rect(index).get_center()
	f.q.ui._gui_input(event)

func reroll_click(f: Dictionary) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = f.q.ui.reroll_rect().get_center()
	f.q.ui._gui_input(event)

func snapshot(f: Dictionary, enemy: EnemyActor) -> Array:
	var projectile: Node2D = f.manager._projectiles[0]
	return [enemy.position,enemy.hp,projectile.position,f.manager._elapsed_seconds,f.player._remaining_hits,f.player._next_hit_at,f.skills.clock,f.skills.skills.skill_rapid_slash.hits_done]

func queue_and_pause() -> void:
	var f := fixture()
	var enemy: EnemyActor = t._spawn(f,Vector2(70,0))
	enemy.move_speed = 12.0
	enemy.projectile_id = "shot"
	enemy.shot_interval_sec = 0.5
	enemy.shot_range = 1000
	f.manager._update_enemy_shot(enemy,0.5)
	f.player.update_basic_attack(0.0,f.manager.get_living_enemies())
	t._s5_press(f)
	f.manager.set_physics_process(true)
	f.player.set_physics_process(true)
	f.skills.set_physics_process(true)
	var before := snapshot(f,enemy)
	f.player.add_experience(26)
	check(f.player.level==4 and f.player.enhancement_points==3 and f.q.pending==3 and f.q.active and t.paused,"S6-01 three real level signals queue three choices and pause")
	for frame in range(5): await t.physics_frame
	check(snapshot(f,enemy)==before,"S6-02 paused tree freezes enemies projectiles basic attack skill ticks and cooldown")
	var previous_level: int = f.skills.skills.skill_rapid_slash.level
	t._s5_click(f)
	check(f.player.enhancement_points==3 and f.skills.skills.skill_rapid_slash.level==previous_level,"S6-03 skill icon click blocked during selection")
	var key := InputEventAction.new()
	key.action = "skill_stealth"
	key.pressed = true
	f.q.ui._gui_input(key)
	check(f.q.pending==3,"S6-03 skill action cannot select a card")
	click(f,0)
	check(f.q.pending==2 and f.q.active and t.paused,"S6-01 first click advances without unpause")
	for frame in range(3): await t.physics_frame
	check(snapshot(f,enemy)==before,"S6-02 between-choice frames do not advance gameplay")
	click(f,0)
	check(f.q.pending==1 and t.paused,"S6-01 second click keeps game paused")
	click(f,0)
	check(f.q.pending==0 and not f.q.active and not t.paused,"S6-01 third click resumes game")
	check(is_equal_approx(f.player._attack_data.Range,120.0) and f.q.levels.c0==3,"S6-04 level three range is base plus cumulative 30, not summed rows")
	await close(f)

func composition_and_weights() -> void:
	for count in range(6):
		var f := fixture(count)
		var cards: Array = f.q.draw_cards()
		var unique := {}
		var heals := 0
		var correct_order := true
		for id in cards:
			if id=="heal": heals+=1
			else:
				correct_order = correct_order and heals==0
				unique[id] = true
		check(cards.size()==3 and unique.size()==mini(count,3) and heals==maxi(0,3-count) and correct_order,"S6-05 candidate count %d gives unique general cards then heal fillers" % count)
		await close(f)
	var f := fixture(4)
	f.q.random.seed = 20261109
	var first := {"c0":0,"c1":0,"c2":0,"c3":0}
	var legal := true
	for sample in range(20000):
		var cards: Array = f.q.draw_cards()
		first[cards[0]] += 1
		legal = legal and cards.size()==3 and not cards.has("heal") and cards[0]!=cards[1] and cards[0]!=cards[2] and cards[1]!=cards[2]
	var ratio := float(first.c1)/float(first.c0)
	check(legal,"S6-06 twenty thousand weighted draws have no duplicate general or heal")
	check(absf(ratio-3.0)<0.2,"S6-06 fixed-seed first-card ratio 1:3 tolerance 0.2; actual "+str(ratio))
	await close(f)
	f = fixture(1)
	f.player.add_experience(26)
	for i in range(3): click(f,0)
	check(f.q.candidates().is_empty() and f.q.draw_cards()==["heal","heal","heal"],"S6-07 actually selected max-level choice excluded from candidates")
	await close(f)

func rerolls() -> void:
	var f := fixture(4)
	f.q.random.seed = 19
	f.player.add_experience(5)
	var original: Array = f.q.cards.duplicate()
	var points: int = f.player.enhancement_points
	f.q.random.seed = 19
	reroll_click(f)
	check(f.q.rerolls==2 and f.q.cards==original and f.player.enhancement_points==points and t.paused,"S6-08 reroll works while paused costs one use not points and allows exact repeat")
	reroll_click(f)
	reroll_click(f)
	var last: Array = f.q.cards.duplicate()
	reroll_click(f)
	check(f.q.rerolls==0 and not f.q.can_reroll() and f.q.cards==last,"S6-08 exhausted reroll is disabled and cannot decrement or change cards")
	click(f,0)
	f.player.add_experience(8)
	check(f.q.rerolls==0 and f.q.pending==1,"S6-08 next level does not replenish rerolls")
	await close(f)
	for count in range(4):
		f = fixture(count)
		f.player.add_experience(5)
		reroll_click(f)
		check(f.q.rerolls==3 and not f.q.can_reroll(),"S6-08 <=3 candidates disables reroll without consuming: "+str(count))
		await close(f)

func effects() -> void:
	var f := fixture(1)
	var enemy: EnemyActor = t._spawn(f,Vector2(40,0))
	f.player.update_basic_attack(0.0,f.manager.get_living_enemies())
	enemy.position = Vector2(95,0)
	f.player.add_experience(5)
	click(f,0)
	f.player.update_basic_attack(0.15,f.manager.get_living_enemies())
	check(enemy.hp==90,"S6-09 ongoing attack second hit uses pre-choice range")
	f.player.update_basic_attack(0.95,f.manager.get_living_enemies())
	check(enemy.hp==80,"S6-09 next basic attack uses increased range")
	await close(f)
	f = fixture(3)
	enemy = t._spawn(f,Vector2(50,0))
	f.player.update_basic_attack(0.0,f.manager.get_living_enemies())
	f.player.add_experience(13)
	click(f,2)
	click(f,2)
	f.player.update_basic_attack(0.15,f.manager.get_living_enemies())
	check(is_equal_approx(f.player._attack_data.Interval_sec,0.5) and is_equal_approx(f.player._attack_ready_at,0.85),"S6-10 interval level two subtracts cumulative 0.1 at next wait calculation")
	var hp: int = enemy.hp
	f.player.update_basic_attack(0.849999,f.manager.get_living_enemies())
	check(enemy.hp==hp,"S6-10 reduced interval still waits until boundary")
	f.player.update_basic_attack(0.85,f.manager.get_living_enemies())
	check(enemy.hp==hp-10,"S6-10 next attack starts at reduced waiting boundary")
	await close(f)
	f = fixture(3)
	f.player.add_experience(5)
	var state: Dictionary = f.q.card_state(1)
	check(state.description=="c1 level 1" and state.level==0 and state.next==1 and state.max==3,"S6-11 card shows next row description current and highlighted next level")
	var motion := InputEventMouseMotion.new()
	motion.position = f.q.ui.card_rect(1).get_center()
	f.q.ui._gui_input(motion)
	check(f.q.ui.hovered==1,"S6-11 actual mouse motion selects highlighted card border")
	click(f,1)
	check(is_equal_approx(f.player.pickup_radius,125.0),"S6-12 pickup radius adds 25 immediately")
	f.player.add_experience(8)
	check(f.q.card_state(1).description=="c1 level 2" and f.q.card_state(1).level==1,"S6-11 next screen advances card description and level state")
	await close(f)

func healing() -> void:
	for sample in [[100,50,80],[100,90,100],[100,100,100],[75,40,62]]:
		var f := fixture(0)
		f.player.configure_combat(sample[0],t._attack())
		f.player.hp = sample[1]
		f.player.add_experience(5)
		var state: Dictionary = f.q.card_state(0)
		check(state.heal and state.hp_before==sample[1] and state.hp_after==sample[2] and state.max_hp==sample[0],"S6-13 heal card previews clamped and floored result: "+str(sample))
		click(f,0)
		check(f.player.hp==sample[2] and not f.q.levels.has("heal") and f.player.enhancement_points==1,"S6-13 heal applies once without level or point cost: "+str(sample))
		await close(f)

func death_and_main() -> void:
	var f := fixture()
	f.player.apply_damage(100)
	f.player.leveled_up.emit(2)
	check(f.q.pending==1 and not f.q.active and not f.q.ui.visible and t.paused,"S6-14 dead player signal queues but cannot open or unpause death")
	await close(f)
	f = fixture()
	f.player.add_experience(5)
	f.player.apply_damage(100)
	await t.process_frame
	check(not f.q.active and not f.q.ui.visible and t.paused and not f.q.select(0),"S6-14 death takes priority over an existing choice screen")
	await close(f)
	var main = preload("res://main.tscn").instantiate()
	t.root.add_child(main)
	var player = main.get_node("Map/Player")
	var choices = main.get_node("Map/ChoiceManager")
	player.add_experience(player.get_xp_to_next())
	check(t.paused and choices.active and choices.pending==1 and player.level==2,"S6-15 actual main scene connects S4 level-up to paused choice UI")
	main.queue_free()
	t.paused = false
	await t.process_frame

func sources() -> Dictionary:
	return {"choice.csv":"Id,Name_ko,Effect,Weight,Note\nr,range,attack_range_add,1,test\ni,interval,attack_interval_sub,1,test\nh,heal,heal,0,test\n",
		"choice_level.csv":"Id,Choice_id,Level,Value,Desc_ko,Note\nr1,r,1,10,range,test\nr2,r,2,20,range,test\ni1,i,1,0.1,interval,test\nh1,h,1,30,heal,test\n",
		"choice_rule.csv":"Id,Reroll_count,Note\nchoice_rule_01,3,test\n"}

func csv_error(changes: Dictionary) -> String:
	var store := Store.new()
	Data.register_schemas(store)
	var text := sources()
	text.merge(changes,true)
	for file in text:
		var error := store.load_text(file,text[file])
		if not error.is_empty(): return error
	return Data.validate(store,0.6)

func validate_csv() -> void:
	var text := sources()
	check(csv_error({}).is_empty(),"S6-16 valid synthetic choice CSV")
	for pair in [["attack_range_add","invalid"],["h,heal,heal,0,test\n",""],["h,heal,heal,0,test\n","h,heal,heal,0,test\nh2,heal,heal,0,test\n"],["h,heal,heal,0","h,heal,heal,1"],["r,range,attack_range_add,1","r,range,attack_range_add,0"]]:
		check(not csv_error({"choice.csv":text["choice.csv"].replace(pair[0],pair[1])}).is_empty(),"S6-16 choice Effect heal count or weight rejects: "+pair[1])
	for pair in [["r1,r,1,10","r1,unknown,1,10"],["r1,r,1,10,range,test\nr2,r,2,20,range,test\n",""],["r1,r,1,10","r1,r,0,10"],["r2,r,2,20","r2,r,3,20"],["h1,h,1,30,heal,test\n",""],["h1,h,1,30,heal,test\n","h1,h,1,30,heal,test\nh2,h,2,30,heal,test\n"],["h1,h,1,30","h1,h,2,30"],["h1,h,1,30","h1,h,1,0"],["h1,h,1,30","h1,h,1,101"],["r1,r,1,10","r1,r,1,-1"],["i1,i,1,0.1","i1,i,1,0.61"]]:
		check(not csv_error({"choice_level.csv":text["choice_level.csv"].replace(pair[0],pair[1])}).is_empty(),"S6-17 invalid choice reference level value or interval rejects: "+pair[1])
	check(csv_error({"choice_level.csv":text["choice_level.csv"].replace("i1,i,1,0.1","i1,i,1,0.6").replace("h1,h,1,30","h1,h,1,100").replace("r1,r,1,10","r1,r,1,0")}).is_empty(),"S6-17 zero general value zero resulting interval and 100 percent heal accepted")
	for rule in ["Id,Reroll_count,Note\n","Id,Reroll_count,Note\nchoice_rule_01,-1,test\n"]:
		check(not csv_error({"choice_rule.csv":rule}).is_empty(),"S6-18 missing rule or negative reroll rejected")
	check(csv_error({"choice_rule.csv":"Id,Reroll_count,Note\nchoice_rule_01,0,test\n"}).is_empty(),"S6-18 zero rerolls allowed")
	var store = t._store()
	var error: String = store.load_all()
	check(error.is_empty() and Data.validate(store,float(store.get_row("basic_attack.csv","attack_01").Interval_sec)).is_empty(),"S6-19 all actual CSV load and choices validate")
