extends RefCounted

const Base = preload("res://tests/boss_p0.gd")
const Elf = preload("res://tests/elf_boss_p0.gd")
const Data = preload("res://scripts/boss_data.gd")
var t: SceneTree
var base: RefCounted
var elf: RefCounted
var store: CsvDataStore

func run(tree: SceneTree) -> void:
	t = tree
	base = Base.new()
	base.t = t
	store = t._store()
	t.check(store.load_all().is_empty(),"S8-I2-B load current CSV")
	base.store = store
	elf = Elf.new()
	elf.t = t
	elf.helper = base
	elf.store = store
	var before: int = t.checks
	var failed: int = t.failures
	data_checks()
	await bear_push()
	await detection_and_interrupts()
	await presentation()
	print("S8-IMPL-02-B NEW RESULT: %d checks, %d failures" % [t.checks-before,t.failures-failed])

func data_checks() -> void:
	t.check(Data.validate(store).is_empty(),"S8-I2-B actual extended boss tables validate")
	t.check(store.get_row("enemy.csv","boss_ice_bear").Max_hp==1100,"S8-I2-B bear approved HP1100")
	t.check(store.get_row("boss.csv","boss_middle").Detect_range==null and store.get_row("boss.csv","boss_early").Detect_range==416,"S8-I2-B only elf has fixed boss detection416")
	for id in ["ice_elf_basic","ice_elf_burst"]:
		t.check(store.get_row("boss_action.csv",id).Use_range==416,"S8-I2-B action use416 "+id)
	t.check(store.get_row("enemy.csv","boss_ice_elf").Shot_range==416,"S8-I2-B enemy shot range matches416")
	for id in ["elf_arrow","elf_burst_arrow"]:
		var row := store.get_row("projectile.csv",id)
		t.check(row.Speed==585 and row.Max_distance==500,"S8-I2-B arrow585 distance500 "+id)
	for value in [null,0,-1,INF]:
		store.tables["boss.csv"].boss_early.Detect_range = value
		t.check(not Data.validate(store).is_empty(),"S8-I2-B invalid detect rejected "+str(value))
	store.tables["boss.csv"].boss_early.Detect_range = 416.0
	for id in ["ice_bear_dash","ice_bear_slam"]:
		var row := store.get_row("boss_action.csv",id)
		var old: Variant = row.Push_sec
		row.Push_sec = null
		t.check(not Data.validate(store).is_empty(),"S8-I2-B skill push requires duration "+id)
		row.Push_sec = old

func bear_push() -> void:
	for id in ["ice_bear_dash","ice_bear_slam","ice_bear_basic"]:
		var f: Dictionary = base.active_fixture()
		var b: Variant = f.boss
		t.check(b.max_hp==1100,"S8-I2-B real spawned bear HP1100 "+id)
		b.global_position = Vector2.ZERO
		f.player.global_position = Vector2(50 if id=="ice_bear_dash" else 100,0)
		var row := store.get_row("boss_action.csv",id)
		var shadows := preload("res://scripts/shadow_manager.gd").new()
		shadows.configure(f.player,f.manager,store.get_table("shadow.csv"),store.get_table("shadow_attack.csv"),store.get_table("shadow_motion.csv"),3)
		f.host.add_child(shadows)
		shadows.set_physics_process(false)
		var shadow: Node2D = shadows.summon("igrit")
		shadow.position = Vector2(60,0)
		var shadow_position := shadow.global_position
		b.start_action(row,f.player.global_position)
		var hp: int = f.player.hp
		f.manager._elapsed_seconds+=float(row.Telegraph_sec)+(0.1 if id=="ice_bear_dash" else 0)
		b.boss_tick(0)
		t.check(f.player.hp==hp-int(row.Damage),"S8-I2-B skill damage unchanged "+id)
		t.check(shadow.global_position==shadow_position,"S8-I2-B bear never skill-pushes shadow "+id)
		if id=="ice_bear_basic":
			t.check(f.player.boss_push_duration==0,"S8-I2-B basic hit does not push")
		else:
			var distance: float = 180 if id=="ice_bear_dash" else 220
			t.check(f.player.boss_push_direction==b.global_position.direction_to(f.player.global_position),"S8-I2-B direction from boss at hit time "+id)
			var start: Vector2 = f.player.global_position
			var direction: Vector2 = f.player.boss_push_direction
			f.player._physics_process(0.2)
			t.check(f.player.global_position.is_equal_approx(start+direction*distance*0.75),"S8-I2-B first half deceleration "+id)
			f.player._physics_process(0.2)
			t.check(f.player.global_position.is_equal_approx(start+direction*distance),"S8-I2-B full approved push distance "+id)
			# Reuse a real hit near the wall; no direct force setup.
			b.current = {}
			b.global_position = Vector2(-1900 if id=="ice_bear_dash" else 1900,0)
			f.player.global_position = Vector2(-1890 if id=="ice_bear_dash" else 1940,0)
			b.clock = f.manager._elapsed_seconds
			b.start_action(row,f.player.global_position)
			f.manager._elapsed_seconds+=float(row.Telegraph_sec)+(0.02 if id=="ice_bear_dash" else 0)
			b.boss_tick(0)
			f.player._physics_process(0.4)
			t.check(is_equal_approx(f.player.global_position.x,-1992 if id=="ice_bear_dash" else 1992) and f.player.boss_push_elapsed==f.player.boss_push_duration,"S8-I2-B real skill hit force stops at wall "+id)
		await base.cleanup(f)

func detection_and_interrupts() -> void:
	var f: Dictionary = elf.fixture()
	var b: Variant = f.boss
	var e: Variant = b.elf
	f.player.global_position = Vector2(417,0)
	elf.step(f,0)
	t.check(e.hidden and e.last_branch=="stealth" and e.shots_fired==0,"S8-I2-B stealth allowed outside detection")
	var start: Vector2 = b.global_position
	elf.step(f,0.01)
	t.check(e.last_branch=="follow" and b.global_position.x>start.x and e.shots_fired==0 and not e.burst and f.player.boss_push_duration==0,"S8-I2-B outside detection only approaches, no new attacks")
	# Deliberately widen action ranges in the fixture to isolate the detection gate.
	e.rows[3].Use_range = 999
	e.rows[4].Use_range = 999
	e.rows[5].Use_range = 999
	b.global_position = Vector2.ZERO
	elf.step(f,0)
	t.check(e.last_branch=="follow" and not e.burst and f.player.boss_push_duration==0,"S8-I2-B detection gate overrides all attack use ranges")
	e.rows[3].Use_range = 416
	e.rows[4].Use_range = 120
	e.rows[5].Use_range = 416
	f.player.global_position = Vector2(100,0)
	elf.step(f,0)
	t.check(e.last_branch=="push" and f.player.boss_push_duration>0,"S8-I2-B inside detection keeps push first")
	e.cleanup()
	elf.step(f,0)
	t.check(e.last_branch=="stealth","S8-I2-B inside detection keeps stealth second")
	f.player.global_position = Vector2(416,0)
	elf.step(f,0)
	t.check(e.burst,"S8-I2-B inclusive416 starts burst")
	f.player.global_position = Vector2(700,0)
	elf.step(f,0.3)
	t.check(e.burst and e.shots_fired==1 and e.last_branch=="burst","S8-I2-B user clarification active burst continues outside detection")
	var at: float = f.manager._elapsed_seconds
	b.apply_fear(1)
	t.check(not e.burst and e.recovery_until==at and b.ready_at.ice_elf_burst==at+9,"S8-I2-B fear interruption starts immediate cooldown without recovery")
	b.fear_remaining = 0
	f.player.global_position = Vector2(300,0)
	b.ready_at.ice_elf_burst = 0
	elf.step(f,0)
	f.player.stealth_remaining = 1
	elf.step(f,0)
	t.check(not e.burst and e.recovery_until==f.manager._elapsed_seconds and b.ready_at.ice_elf_burst==f.manager._elapsed_seconds+9,"S8-I2-B player stealth interruption starts immediate cooldown")
	f.player.stealth_remaining = 0
	elf.disable_skills(f)
	elf.step(f,0)
	t.check(e.last_branch=="basic","S8-I2-B interrupt adds no global recovery lock")
	await base.cleanup(f)

func presentation() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	t.root.add_child(scene)
	var map: Node = scene.get_child(0)
	for child in map.get_children(): child.set_physics_process(false)
	var manager: EnemyManager = map.get_node("EnemyManager")
	var player: Node2D = manager._player
	var hud: CanvasLayer = map.get_node("TemporaryHud")
	var skills: Node2D = map.get_node("SkillManager")
	var shadow: Node2D = map.get_node("ShadowManager").summon("igrit")
	await t.process_frame
	hud.refresh()
	var ui: Control = skills.ui
	t.check(ui.scale==Vector2(0.75,0.75) and ui.pivot_offset==ui.size,"S8-I2-B skill UI75 percent with bottom-right pivot")
	var local_box: Rect2 = ui.card_rect(3)
	var card: Control = hud.entries[0].icon.get_parent()
	t.check((card.get_global_rect().size-Vector2(108,48)*1.3).abs().x<=1.0 and (card.get_global_rect().size-Vector2(108,48)*1.3).abs().y<=1.0 and hud.entries[0].icon.get_global_rect().size.is_equal_approx(Vector2(30,30)*1.3),"S8-I2-B shadow icon and name card inherit75 percent of the 1.3x size (FIX04)")
	var right: Vector2 = ui.get_global_transform()*local_box.end
	var top: Vector2 = ui.get_global_transform()*local_box.position
	t.check(absf(card.get_global_rect().end.x-right.x)<1 and card.get_global_rect().end.y<top.y,"S8-I2-B scaled roster stays right-aligned above skills")
	# TextureRect can keep the texture minimum, so use its actual pre-transform
	# size rather than the requested ICON_SIZE constant as the baseline.
	t.check(ui.glyphs[0].get_global_rect().size.is_equal_approx(ui.glyphs[0].size*0.75),"S8-I2-B actual skill glyph is75 percent of its unscaled size")
	var enemy_fx: Node2D = map.get_node("HitFx")
	var fx: Node2D = map.get_node("PlayerHitFx")
	fx.set_physics_process(false)
	t.check(fx.spark==enemy_fx.spark and fx.radius==enemy_fx.radius and fx.duration==enemy_fx.duration and fx.outer_color==fx.PLAYER_OUTER_COLOR and fx.core_color==fx.PLAYER_CORE_COLOR,"S8-I2-B player uses same hit shape and timing with blue colors only")
	player.configure_combat(10000,t._attack())
	var count: int = fx.emitted
	player.apply_damage(0)
	player.apply_damage(-1)
	t.check(fx.emitted==count,"S8-I2-B no player icon for zero or rejected damage")
	player.fear_cast_remaining = 1
	player.apply_damage(1)
	t.check(fx.emitted==count,"S8-I2-B immune fear-cast hit has no icon")
	player.fear_cast_remaining = 0
	manager._spawn_from_row({"Spawn_count":1,"Enemy_id":"enemy_01"})
	var enemy: EnemyActor = manager._active_enemies.back()
	enemy.global_position = player.global_position
	manager._apply_contact_damage(enemy)
	t.check(fx.emitted==count+1 and fx.positions[count]==player.global_position,"S8-I2-B real contact hit emits blue icon at player")
	var arrow := preload("res://scripts/projectile.gd").new()
	map.add_child(arrow)
	arrow.configure(store.get_row("projectile.csv","elf_arrow"),player.global_position-Vector2(20,0),player.global_position,Rect2(-2000,-2000,4000,4000),player)
	arrow.advance(0.1)
	t.check(arrow.spent and fx.emitted==count+2,"S8-I2-B real arrow hit emits blue icon")
	# Use the same production director already wired by main.
	var d: Node2D = manager.boss_director
	d.timeline = [{"Id":"b-hit","Time_mmss":0,"Boss_id":"boss_middle"}]
	d.advance(0,0)
	manager._elapsed_seconds = 3.5
	d.advance(3.5,0)
	var b: Variant = d.actor
	b.global_position = player.global_position-Vector2(100,0)
	b.start_action(store.get_row("boss_action.csv","ice_bear_slam"),player.global_position)
	manager._elapsed_seconds+=0.8
	b.boss_tick(0)
	t.check(fx.emitted==count+3,"S8-I2-B real bear slam emits player hit icon")
	var push_rows: Array = []
	for row in store.get_table("boss_action.csv").values():
		if row.Boss_id=="boss_early": push_rows.append(row)
	var middle: Node2D = manager.create_boss("boss_ice_elf",push_rows,d.player_target)
	manager.activate_boss(middle)
	middle.global_position = player.global_position-Vector2(100,0)
	middle.boss_tick(0)
	t.check(fx.emitted==count+3 and player.boss_push_distance==440,"S8-I2-B actual zero-damage elf push emits no blue hit")
	shadow.free()
	scene.queue_free()
	await t.process_frame
