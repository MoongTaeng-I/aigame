extends RefCounted

const Base = preload("res://tests/boss_p0.gd")
const Data = preload("res://scripts/boss_data.gd")
var t: SceneTree
var base: RefCounted
var store: CsvDataStore

func run(tree: SceneTree) -> void:
	t = tree
	base = Base.new()
	base.t = t
	store = t._store()
	t.check(store.load_all().is_empty(),"S8-I3 actual CSV loads")
	base.store = store
	var before: int = t.checks
	var failed: int = t.failures
	data_checks()
	await triangle_and_pass_through()
	await blink_randomness()
	await chase_aim()
	await zones_and_inputs()
	await interventions_and_selection()
	await timeline()
	print("S8-IMPL-03 NEW RESULT: %d checks, %d failures" % [t.checks-before,t.failures-failed])

func fixture() -> Dictionary:
	var f: Dictionary = base.fixture({"final":{"Id":"final","Time_mmss":0,"Boss_id":"boss_final"}})
	base.tick(f,0)
	base.tick(f,3.5)
	f.boss = f.director.actor
	f.boss.global_position = Vector2.ZERO
	f.boss.planned = {}
	f.player.global_position = Vector2(1000,0)
	return f

func step(f: Dictionary, delta: float) -> void:
	f.manager._elapsed_seconds+=delta
	f.boss.boss_tick(delta)

func start(f: Dictionary, id: String) -> void:
	f.boss.start_action(store.get_row("boss_action.csv",id),f.player.global_position)

func data_checks() -> void:
	t.check(Data.validate(store).is_empty(),"S8-I3 all three profiles validate")
	t.check(store.get_row("enemy.csv","boss_ice_bear").Max_hp==1100 and store.get_row("enemy.csv","boss_ice_elf").Max_hp==525 and store.get_row("enemy.csv","boss_baruka").Max_hp==1750,"S8-I3 all three exact test HP values")
	t.check(store.get_row("stage_timeline.csv","timeline_final_boss").Time_mmss==500 and store.get_row("boss.csv","boss_final").Is_final,"S8-I3 5:00 final boss data")
	for pair in [["baruka_basic","Tri_width"],["baruka_basic","Tri_length"],["baruka_blink","Area_radius"],["baruka_blink","Strike_count"],["baruka_blink","Strike_min_distance"],["baruka_chase","Duration_sec"],["baruka_chase","Strike_interval_sec"],["baruka_ice","Zone_count"],["baruka_ice","Zone_radius"],["baruka_ice","Zone_life_sec"],["baruka_ice","Freeze_sec"]]:
		var row := store.get_row("boss_action.csv",pair[0])
		var old: Variant = row[pair[1]]
		for value in [null,0,-1]:
			row[pair[1]] = value
			t.check(not Data.validate(store).is_empty(),"S8-I3 invalid required value rejected "+pair[0]+"."+pair[1]+" "+str(value))
		row[pair[1]] = old
	var config := store.get_row("boss.csv","boss_final")
	config.Move_speed_ref_enemy = "missing"
	t.check(not Data.validate(store).is_empty(),"S8-I3 unresolved speed reference rejected")
	config.Move_speed_ref_enemy = "enemy_01"
	for value in [null,0,-1,INF]:
		config.Move_speed_mult = value
		t.check(not Data.validate(store).is_empty(),"S8-I3 invalid speed multiplier rejected "+str(value))
	config.Move_speed_mult = 1.3
	store.tables["boss_action.csv"].baruka_basic.Zone_count = 5
	t.check(not Data.validate(store).is_empty(),"S8-I3 unused kind-specific value rejected")
	store.tables["boss_action.csv"].baruka_basic.Zone_count = null
	var row: Dictionary = store.tables["boss_action.csv"].baruka_ice
	row.Damage = 1
	t.check(not Data.validate(store).is_empty(),"S8-I3 ice damage must be zero")
	row.Damage = 0
	t.check(Data.validate(store).is_empty(),"S8-I3 validation fixtures restore unchanged actual data")

func triangle_and_pass_through() -> void:
	var f := fixture()
	var b: Variant = f.boss
	var v: Variant = b.baruka
	t.check(is_equal_approx(b.move_speed,156) and b.body_radius==30 and b.push_weight==20,"S8-I3 runtime derived speed156 and approved body")
	f.player.global_position = Vector2(250,0)
	start(f,"baruka_basic")
	var g: Dictionary = b.telegraph_geometry()
	t.check(g.points.size()==3 and g.points.has(Vector2(190,80)) and g.points.has(Vector2(190,-80)) and g.points.has(Vector2(330,0)),"S8-I3 triangle wide base attached ahead of destination body, tip forward")
	for point in [Vector2(190,80),Vector2(190,-80),Vector2(330,0),Vector2(260,40),Vector2(260,0)]:
		t.check(v.triangle_contains(point),"S8-I3 triangle inclusive interior/edge "+str(point))
	for point in [Vector2(189.99,0),Vector2(330.01,0),Vector2(260,40.01),Vector2(260,-40.01)]:
		t.check(not v.triangle_contains(point),"S8-I3 triangle outside "+str(point))
	var hp: int = f.player.hp
	step(f,0.154)
	t.check(f.player.hp==hp and b.global_position==Vector2.ZERO,"S8-I3 triangle preview does not deal early damage")
	f.player.global_position = Vector2(0,500)
	step(f,0.001)
	t.check(b.facing==Vector2.RIGHT and b.is_boss_dashing(),"S8-I3 tri dash direction fixed at preview start")
	var normal: EnemyActor = t._spawn(f,Vector2(60,0))
	var position: Vector2 = normal.global_position
	f.manager._resolve_contact_pair(b,normal)
	f.manager._resolve_contact_pushes()
	t.check(normal.global_position==position,"S8-I3 high-speed body excluded from both push paths")
	f.player.global_position = Vector2(250,0)
	step(f,160.0/2340.0)
	t.check(f.player.hp==hp-15 and b.current.is_empty() and b.global_position.is_equal_approx(Vector2(160,0)),"S8-I3 arrival triangle deals15 once")
	t.check(is_equal_approx(b.ready_at.baruka_basic,3.5+0.155+160.0/2340.0+0.63),"S8-I3 basic cooldown from arrival")
	b.global_position = Vector2(1900,0)
	f.player.global_position = Vector2(2500,0)
	start(f,"baruka_basic")
	t.check(b.dash_end==Vector2(1970,0),"S8-I3 tri dash stops at radius-adjusted wall")
	step(f,1)
	t.check(b.global_position==Vector2(1970,0),"S8-I3 wall arrival no slide")
	await base.cleanup(f)

func blink_randomness() -> void:
	var paths: Array = []
	for player_position in [Vector2(50,0),Vector2(-700,900)]:
		var f := fixture()
		var b: Variant = f.boss
		var v: Variant = b.baruka
		b.rng.seed = 12345
		f.player.global_position = player_position
		start(f,"baruka_blink")
		t.check(v.area_center==Vector2.ZERO,"S8-I3 blink circle centered only on boss")
		step(f,10)
		paths.append(v.destinations.duplicate())
		t.check(paths.back().size()==20 and b.current.is_empty(),"S8-I3 blink completes twenty moves even across large frame")
		var previous := Vector2.ZERO
		for point in paths.back():
			t.check(point.length()<=894.40001 and point.distance_to(previous)>=119.99999,"S8-I3 blink destination inside fixed circle and minimum120")
			previous = point
		t.check(not v.trails.is_empty(),"S8-I3 blink uses visual trails")
		for copy in v.trails:
			t.check(not copy is CollisionObject2D and not f.manager.get_living_enemies().has(copy),"S8-I3 reused afterimage has no collider or enemy target registration")
		await base.cleanup(f)
	t.check(paths[0]==paths[1],"S8-I3 same seed different player positions yield identical full destinations")
	var f := fixture()
	var b: Variant = f.boss
	b.rng.seed = 20
	start(f,"baruka_blink")
	step(f,0.8)
	var midpoint: Vector2 = (b.origin+b.dash_end)*0.5
	f.player.global_position = midpoint
	var hp: int = f.player.hp
	step(f,b.dash_length/8064.0*0.6)
	t.check(f.player.hp==hp-15,"S8-I3 blink path hit remains enabled")
	step(f,0)
	t.check(f.player.hp==hp-15,"S8-I3 each blink movement hits same target once")
	await base.cleanup(f)

func chase_aim() -> void:
	var f := fixture()
	var b: Variant = f.boss
	f.player.global_position = Vector2(400,0)
	start(f,"baruka_chase")
	t.check(b.facing==Vector2.RIGHT and b.dash_end==Vector2(300,0),"S8-I3 chase takes current player position and caps300")
	step(f,0.25)
	f.player.global_position = Vector2(0,500)
	step(f,0.1)
	t.check(b.facing==Vector2.RIGHT and b.global_position.is_equal_approx(Vector2(110,0)),"S8-I3 chase has no in-move homing")
	step(f,300.0/1100.0-0.1)
	var end: Vector2 = b.global_position
	t.check(end==Vector2(300,0),"S8-I3 chase reaches frozen endpoint")
	step(f,0.4)
	var direction: Vector2 = end.direction_to(f.player.global_position)
	t.check(b.phase=="telegraph" and b.facing.is_equal_approx(direction),"S8-I3 next chase attack reacquires changed player position")
	step(f,0.25)
	f.player.global_position = b.origin+b.facing*100
	var hp: int = f.player.hp
	step(f,0.1)
	t.check(f.player.hp==hp-12,"S8-I3 chase path damage12")
	step(f,0)
	t.check(f.player.hp==hp-12,"S8-I3 chase attack single hit")
	# A fresh action with successive attacks beyond Duration_sec checks the tail.
	b.baruka.interrupt()
	b.global_position = Vector2.ZERO
	f.player.global_position = Vector2(1500,0)
	start(f,"baruka_chase")
	var started: float = f.manager._elapsed_seconds
	step(f,2.9)
	t.check(not b.current.is_empty(),"S8-I3 chase still active just before duration limit")
	step(f,0.15)
	t.check(not b.current.is_empty(),"S8-I3 duration boundary preserves attack already in progress")
	step(f,1)
	t.check(b.current.is_empty() and b.ready_at.baruka_chase>=started+3+12,"S8-I3 chase finishes current attack then cooldown")
	await base.cleanup(f)

func zones_and_inputs() -> void:
	var f := fixture()
	var b: Variant = f.boss
	var v: Variant = b.baruka
	b.rng.seed = 7
	f.player.global_position = Vector2(300,0)
	start(f,"baruka_ice")
	var centers: Array = v.preview_zones.duplicate()
	t.check(centers.size()==5 and v.area_center==f.player.global_position,"S8-I3 five ice previews around cast-time player center")
	for center in centers: t.check(center.distance_to(Vector2(300,0))<=350,"S8-I3 zone sample within creation circle")
	f.player.global_position = centers[0]
	step(f,0.799)
	t.check(not f.player.is_frozen() and v.zones.is_empty(),"S8-I3 preview does not freeze")
	var hp: int = f.player.hp
	step(f,0.001)
	t.check(v.zones.size()==5 and is_equal_approx(f.player.freeze_remaining,1.5) and f.player.hp==hp,"S8-I3 activation entry freezes1.5, no damage")
	f.player._physics_process(0.5)
	step(f,0.5)
	t.check(is_equal_approx(f.player.freeze_remaining,1),"S8-I3 standing inside does not reapply")
	var new_center: Vector2 = centers[0]
	for zone in v.zones:
		if not zone.inside:
			new_center = zone.center
			break
	t.check(new_center!=centers[0],"S8-I3 fixture includes distinct unentered ice zone")
	f.player.global_position = new_center
	step(f,0)
	t.check(is_equal_approx(f.player.freeze_remaining,1.5),"S8-I3 another zone refreshes to1.5 without stacking")
	f.player._physics_process(1.5)
	step(f,0)
	t.check(not f.player.is_frozen(),"S8-I3 exactly1.5 seconds expires even standing on ice")
	f.player.global_position = Vector2(-1000,-1000)
	step(f,0)
	f.player.global_position = new_center
	step(f,0)
	t.check(f.player.is_frozen(),"S8-I3 leave and reenter has no freeze immunity window")
	f.manager._elapsed_seconds = 3.5+0.8+4
	b.boss_tick(0)
	t.check(v.zones.is_empty(),"S8-I3 zones expire exactly4 seconds after activation")
	await base.cleanup(f)
	f = fixture()
	b = f.boss
	f.player.global_position = Vector2.ZERO
	b.global_position = Vector2(60,0)
	f.skills.skills.skill_rapid_slash.level = 1
	f.skills.skills.skill_dash.level = 1
	f.player.enhancement_points = 3
	t.check(f.skills.try_use("skill_rapid_slash"),"S8-I3 real existing slash started before freeze")
	var before: int = b.hp
	f.player.apply_freeze(1.5)
	Input.action_press("move_right")
	var position: Vector2 = f.player.global_position
	f.player._physics_process(0.5)
	Input.action_release("move_right")
	t.check(f.player.global_position==position and f.player.is_frozen(),"S8-I3 freeze blocks real input movement")
	for id in f.skills.SkillData.IDS:
		t.check(not f.skills.try_use(id),"S8-I3 freeze rejects skill input "+id)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = f.skills.ui.card_rect(0).get_center()
	var points: int = f.player.enhancement_points
	var level: int = f.skills.skills.skill_dash.level
	f.skills.ui._gui_input(event)
	t.check(f.player.enhancement_points==points and f.skills.skills.skill_dash.level==level,"S8-I3 real icon click blocked without spending points")
	f.skills._physics_process(0.1)
	t.check(b.hp<before,"S8-I3 already-started slash continues while frozen")
	f.player.cancel_basic_attack()
	before = b.hp
	f.player.update_basic_attack(100,[b])
	t.check(b.hp==before and f.player._remaining_hits==0,"S8-I3 no new automatic basic attacks while frozen")
	var player_hp: int = f.player.hp
	f.player.apply_damage(10)
	t.check(f.player.hp==player_hp-10,"S8-I3 frozen player receives ordinary damage")
	f.player.freeze_remaining = 0
	f.player.update_basic_attack(101,[b])
	before = b.hp
	f.player.apply_freeze(1.5)
	f.player.update_basic_attack(101.15,[b])
	t.check(b.hp==before-10,"S8-I3 already-started basic remaining hit completes during freeze")
	var shadows := preload("res://scripts/shadow_manager.gd").new()
	shadows.configure(f.player,f.manager,store.get_table("shadow.csv"),store.get_table("shadow_attack.csv"),store.get_table("shadow_motion.csv"),3)
	f.host.add_child(shadows)
	shadows.set_physics_process(false)
	var shadow: Node2D = shadows.summon("igrit")
	shadow.global_position = Vector2.ZERO
	before = b.hp
	shadow.tick(0)
	shadow.tick(0.3)
	t.check(shadow.target==b and b.hp==before-10,"S8-I3 shadow continues attacking during player freeze")
	await base.cleanup(f)

func interventions_and_selection() -> void:
	for id in ["baruka_basic","baruka_blink","baruka_chase","baruka_ice"]:
		var f := fixture()
		var b: Variant = f.boss
		start(f,id)
		var at: float = f.manager._elapsed_seconds
		b.apply_fear(1)
		t.check(b.current.is_empty() and b.telegraph_geometry().is_empty() and b.is_feared(),"S8-I3 immediate fear cancels "+id)
		t.check(is_equal_approx(b.ready_at[id],at+float(store.get_row("boss_action.csv",id).Cooldown_sec)),"S8-I3 fear cooldown begins at cancellation "+id)
		await base.cleanup(f)
	for id in ["baruka_blink","baruka_chase","baruka_ice"]:
		var f := fixture()
		var b: Variant = f.boss
		start(f,id)
		f.player.stealth_remaining = 100
		step(f,0.1)
		t.check(b.current.is_empty() if id=="baruka_chase" else not b.current.is_empty(),"S8-I3 stealth cancels chase only "+id)
		if id!="baruka_chase": step(f,10)
		step(f,0.01)
		t.check(b.baruka.last_branch=="wander","S8-I3 stealth wanders after current action "+id)
		await base.cleanup(f)
	var f := fixture()
	var b: Variant = f.boss
	b.boss_tick(0)
	var chosen: String = b.planned.Id
	for i in range(20): b.boss_tick(0)
	t.check(b.planned.Id==chosen,"S8-I3 weighted planned skill remains fixed")
	f.player.apply_freeze(1.5)
	f.player.global_position = Vector2(100,0)
	b.boss_tick(0)
	t.check(not b.current.is_empty() and int(b.current.Kind)==7 and b.planned.Id==chosen,"S8-I3 frozen player permits basic but blocks prepared new skill")
	b.baruka.interrupt()
	f.player.freeze_remaining = 0
	start(f,"baruka_ice")
	step(f,0.8)
	t.check(b.baruka.zones.size()==5,"S8-I3 real ice zones exist before death")
	start(f,"baruka_blink")
	b.apply_damage(b.hp)
	t.check(b.baruka.zones.is_empty() and b.current.is_empty() and b.baruka.preview_zones.is_empty(),"S8-I3 death clears current action and all existing zones")
	t.check(f.director.completed and t.paused,"S8-I3 actual final actor death completes run")
	await base.cleanup(f)

func timeline() -> void:
	var f: Dictionary = base.fixture(store.get_table("stage_timeline.csv"))
	base.tick(f,60)
	base.tick(f,3.5)
	base.tick(f,236.5)
	t.check(f.director.pending==["boss_middle","boss_final"] and f.director.active_id=="boss_early","S8-I3 actual 5:00 queues final behind living bosses")
	t.check(not f.director.completed,"S8-I3 time alone never completes run")
	f.director.actor.apply_damage(f.director.actor.hp)
	base.tick(f,3.5)
	t.check(f.director.active_id=="boss_middle","S8-I3 queue respects middle before final")
	f.director.actor.apply_damage(f.director.actor.hp)
	t.check(f.director.active_id=="boss_final" and f.director.phase=="warn" and f.manager._stop_normal_spawning,"S8-I3 final uses common warning and continuous spawn stop")
	base.tick(f,2)
	t.check(not f.director.actor.is_active and f.director.phase=="emerge","S8-I3 final emerges inactive through common gate")
	base.tick(f,1.5)
	t.check(f.director.actor.is_active and f.director.actor.enemy_id=="boss_baruka" and f.director.actor.hp==1750,"S8-I3 final activates real Baruka data")
	f.director.actor.apply_damage(f.director.actor.hp)
	t.check(f.director.completed and t.paused,"S8-I3 queued final death completes with Is_final")
	await base.cleanup(f)
