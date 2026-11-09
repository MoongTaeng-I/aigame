extends RefCounted

const Extensions = preload("res://tests/skill_extensions_p0.gd")
const Crowd = preload("res://tests/crowd_measurement.gd")
const Main = preload("res://scripts/main.gd")
var t: SceneTree

func run(tree: SceneTree) -> void:
	t = tree
	await dash_blocks_fear()
	await compressed_line()
	for value in ["","0","-1"]:
		t.check(not iterations_error(value).is_empty(),"CROWD-04 invalid Push_iterations rejected: "+value)
	t.check(iterations_error("1").is_empty(),"CROWD-04 Push_iterations 1 accepted")
	var store = t._store()
	var error: String = store.load_all()
	t.check(error.is_empty(),"CROWD-05 actual CSV with Push_iterations loads")
	var rule: Dictionary = store.get_row("spawn_rule.csv","rule_01")
	var helper := Crowd.new()
	var result := helper.simulate(t,int(rule.Push_iterations))
	t.check(result.p95<=1.0 and result.overlap_pairs==0 and result.player_alive,"CROWD-05 actual CSV 100 initial enemies 600 frames meets p95 and no-body-overlap criterion: "+JSON.stringify(result))

func dash_blocks_fear() -> void:
	var helper := Extensions.new()
	helper.t = t
	var f: Dictionary = helper.fixture()
	# F is the user's requested test key. Actual CSV keeps fear=2 and slash=F.
	var records: Dictionary = f.skills.records.duplicate(true)
	records.skill_rapid_slash.Key = "Q"
	records.skill_dragon_fear.Key = "F"
	var extras := {}
	for id in ["skill_dash","skill_stealth","skill_dragon_fear"]:
		var rows := {}
		for row in f.skills.skills[id].levels: rows[row.Id] = row
		extras[id] = rows
	f.skills.configure(f.player,f.manager,records,t._s5_levels(),extras)
	var enemy: EnemyActor = t._spawn(f,Vector2(60,0))
	helper.press(f,"skill_dash")
	helper.advance(f,0.05)
	var fear = f.skills.skills.skill_dragon_fear
	var before: Dictionary = f.skills.icon_state("skill_dragon_fear")
	var cooldown: float = fear.cooldown_until
	key_f(true)
	t.check(not fear.active and not enemy.is_feared() and not f.player.is_fear_casting(),"CROWD-01 F during dash causes no fear or cast")
	t.check(fear.cooldown_until==cooldown and f.skills.icon_state("skill_dragon_fear")==before,"CROWD-01 blocked F leaves cooldown and icon unchanged")
	helper.advance(f,0.15)
	t.check(f.player.position.distance_to(Vector2(80,0))<0.2 and not f.skills.skills.skill_dash.active,"CROWD-01 blocked fear preserves complete dash distance")
	helper.advance(f,0.05)
	t.check(not fear.active and not enemy.is_feared(),"CROWD-01 held blocked input is not queued after dash")
	key_f(false)
	key_f(true)
	key_f(false)
	t.check(fear.active and enemy.is_feared() and f.player.is_fear_casting(),"CROWD-02 fresh F after dash starts normal fear")
	await helper.close(f)

func key_f(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func line_fixture() -> Dictionary:
	var f: Dictionary = t._fixture()
	f.player.position = Vector2(1000,1000)
	f.manager.separation_gap = 8
	for x in [0,10,20]: t._spawn(f,Vector2(x,0))
	return f

func compressed_line() -> void:
	var helper := Crowd.new()
	var f := line_fixture()
	f.manager.push_iterations = 1
	f.manager._resolve_contact_pushes()
	var old_positions: Array[Vector2] = []
	for enemy in f.manager.get_living_enemies(): old_positions.append(enemy.position)
	var first := helper.deficits(f.manager.get_living_enemies(),8)
	t.check(first.p95>1.0,"CROWD-03 compressed three-enemy line has remaining deficit at N=1")
	for i in range(3): f.manager._active_enemies[i].position = Vector2(i*10,0)
	f.manager._resolve_contact_push_pass()
	var same := true
	for i in range(3): same = same and f.manager._active_enemies[i].position==old_positions[i]
	t.check(same and old_positions[0].distance_to(Vector2(-7,0))<0.001 and old_positions[1].distance_to(Vector2(6.5,0))<0.001 and old_positions[2].distance_to(Vector2(30.5,0))<0.001,"CROWD-03 N=1 matches legacy single-pass weighted pair result")
	var store = t._store()
	store.load_all()
	for i in range(3): f.manager._active_enemies[i].position = Vector2(i*10,0)
	f.manager.push_iterations = int(store.get_row("spawn_rule.csv","rule_01").Push_iterations)
	f.manager._resolve_contact_pushes()
	var repeated := helper.deficits(f.manager.get_living_enemies(),8)
	t.check(repeated.p95<=1.0 and repeated.overlap_pairs==0,"CROWD-03 configured N meets compressed-line criterion: "+JSON.stringify(repeated))
	f.host.queue_free()
	await t.process_frame

func iterations_error(value: String) -> String:
	var store = t._store()
	var error: String = store.load_text("spawn_rule.csv","Id,Max_alive,Offscreen_relocate_sec,Note,Separation_gap,Push_iterations\nrule_01,200,3,test,8,"+value+"\n")
	if not error.is_empty(): return error
	var main := Main.new()
	error = main._validate_gameplay_data(store,{"Id":"test","Body_radius":16,"Push_weight":3},{},{},store.get_row("spawn_rule.csv","rule_01"))
	main.free()
	return error
