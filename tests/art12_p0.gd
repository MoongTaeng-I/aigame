extends RefCounted

var t: SceneTree
var store: CsvDataStore
var base: RefCounted

func run(tree: SceneTree) -> void:
	t = tree
	var first: int = t.checks
	var failures: int = t.failures
	store = t._store()
	t.check(store.load_all().is_empty(),"ART12 actual data loads")
	base = preload("res://tests/boss_p0.gd").new()
	base.t = t
	base.store = store
	await bear()
	await elf()
	await baruka()
	print("ART12 RESULT: %d checks, %d failures" % [t.checks-first,t.failures-failures])

func step(f: Dictionary, seconds: float) -> void:
	f.manager._elapsed_seconds += seconds
	f.boss.boss_tick(seconds)

func artwork(b: Node, expected: Vector2, height: float, shadow: Vector2) -> void:
	t.check(b.has_boss_sprite() and b.sprite_body.texture.get_size()==expected and b.sprite_body.columns==(11 if b.enemy_id=="boss_baruka" else 3) and b.sprite_body.rows==1,"ART12 boss sheet "+b.enemy_id)
	t.check(absf(b.sprite_body.display_rect().size.y-height)<=1 and b.sprite_body.shadow_size==shadow,"ART12 size and foot shadow "+b.enemy_id)
	t.check(is_equal_approx(b.health_bar_y(),b.sprite_body.display_rect().position.y-8),"ART12 health bar above sprite "+b.enemy_id)
	var source := FileAccess.get_file_as_string("res://scripts/boss_actor.gd")
	t.check(b.has_boss_sprite() and source.contains("func draw_body(canvas: Node2D) -> void:\n\tif has_boss_sprite(): return"),"ART12 sprite suppresses original body "+b.enemy_id)
	b.apply_fear(1)
	step({"manager":b.manager,"boss":b},0.01)
	t.check(b.sprite_body.frame_column==0 and b.sprite_body.sprite_tint==Color.WHITE.lerp(preload("res://scripts/skill_ui.gd").FEAR_COLOR,0.5),"ART12 fear idle and tint "+b.enemy_id)
	b.fear_remaining = 0
	var fallback: Dictionary = b.visual_record.duplicate()
	fallback.Sprite_path = "res://assets/art/sd/missing-art12.png"
	b.configure(fallback)
	t.check(not b.has_boss_sprite() and not b.sprite_body.visible,"ART12 missing image keeps original body "+b.enemy_id)

func bear() -> void:
	var f: Dictionary = base.active_fixture()
	var b: Node = f.boss
	f.player.global_position = Vector2(100,0)
	b.start_action(store.get_row("boss_action.csv","ice_bear_dash"),f.player.global_position)
	step(f,0)
	t.check(b.sprite_body.frame_column==1,"ART12 bear telegraph1")
	step(f,0.81)
	t.check(b.sprite_body.frame_column==2 and b.phase=="dash","ART12 bear dash2")
	b.finish_action(b.clock)
	b.start_action(store.get_row("boss_action.csv","ice_bear_basic"),f.player.global_position)
	step(f,0)
	var hp: int = f.player.hp
	step(f,0.4)
	t.check(b.sprite_body.frame_column==2 and f.player.hp==hp-12,"ART12 bear basic damage unchanged and strike2")
	step(f,0.249)
	t.check(b.sprite_body.frame_column==2,"ART12 bear strike held through .249")
	step(f,0.002)
	t.check(b.sprite_body.frame_column==0,"ART12 bear strike returns0 after .25")
	var pos: Vector2 = b.global_position
	var radius: float = b.body_radius
	b.sprite_body.advance_explicit_pose(2,Vector2.LEFT,false,0.01,true)
	t.check(b.sprite_body.flip_h and is_equal_approx(b.sprite_body._lunge_remaining,0.1),"ART12 strike entry lunges once and locks facing")
	b.sprite_body.advance_explicit_pose(2,Vector2.LEFT,false,0.02,true)
	t.check(is_equal_approx(b.sprite_body._lunge_remaining,0.08) and b.global_position==pos and b.body_radius==radius,"ART12 held strike does not relunge or move hitbox")
	artwork(b,Vector2(918,410),205,Vector2(118,36))
	await base.cleanup(f)

func elf() -> void:
	var helper := preload("res://tests/elf_boss_p0.gd").new()
	helper.t = t
	helper.helper = base
	helper.store = store
	var f: Dictionary = helper.fixture()
	var b: Node = f.boss
	helper.disable_skills(f)
	f.player.global_position = Vector2(-300,0)
	b.ready_at[b.elf.rows[3].Id] = 0
	var shots: int = b.elf.shots_fired
	step(f,0)
	t.check(b.sprite_body.frame_column==1 and b.sprite_body.flip_h and b.elf.shots_fired==shots+1,"ART12 elf arrow1 and actual shot count")
	step(f,0.201)
	t.check(b.sprite_body.frame_column==0,"ART12 elf arrow pose expires .2")
	b.ready_at[b.elf.rows[5].Id] = 0
	step(f,0)
	t.check(b.elf.burst and b.sprite_body.frame_column==1 and b.clock<b.elf.burst_first,"ART12 elf burst prep1")
	step(f,0.31)
	t.check(b.sprite_body.frame_column==1,"ART12 elf burst firing1")
	b.elf.interrupt_burst()
	b.elf.recovery_until = 0
	b.ready_at[b.elf.rows[4].Id] = 0
	f.player.global_position = Vector2(50,0)
	step(f,0)
	t.check(b.elf.last_branch=="push" and b.sprite_body.frame_column==2,"ART12 elf push2")
	b.elf.start_stealth()
	b.update_boss_visual(0,false)
	t.check(not b.sprite_body.visible,"ART12 hidden elf sprite and attached shadow invisible")
	b.elf.end_stealth(b.clock)
	b.update_boss_visual(0,false)
	t.check(b.sprite_body.visible,"ART12 elf reappears")
	artwork(b,Vector2(873,336),168,Vector2(56,18))
	await base.cleanup(f)

func baruka() -> void:
	var helper := preload("res://tests/baruka_boss_p0.gd").new()
	helper.t = t
	helper.base = base
	helper.store = store
	var f: Dictionary = helper.fixture()
	var b: Node = f.boss
	b.start_action(store.get_row("boss_action.csv","baruka_basic"),f.player.global_position)
	step(f,0)
	t.check(b.sprite_body.frame_column==1,"ART12 baruka telegraph1")
	step(f,0.19)
	t.check(b.sprite_body.frame_column==2 and b.phase=="dash","ART12 baruka dash2")
	b.baruka.interrupt()
	b.start_action(store.get_row("boss_action.csv","baruka_ice"),f.player.global_position)
	step(f,0)
	t.check(b.sprite_body.frame_column==1,"ART12 ice telegraph1")
	step(f,float(b.current.Telegraph_sec))
	t.check(b.sprite_body.frame_column==2 and not b.baruka.zones.is_empty(),"ART12 ice activation2 and actual zones")
	b.start_action(store.get_row("boss_action.csv","baruka_blink"),f.player.global_position)
	step(f,0)
	step(f,float(b.current.Telegraph_sec)+0.15)
	t.check(not b.baruka.trails.is_empty() and b.baruka.trails[0].sprite_body!=null and b.baruka.trails[0].sprite_body.frame_column==2,"ART12 blink trails use dash snapshot")
	if not b.current.is_empty():
		b.phase = "interval"
		b.phase_end = b.clock+1
		var previous: int = b.sprite_body.frame_column
		step(f,0)
		t.check(b.sprite_body.frame_column==previous,"ART12 baruka interval holds pose")
	artwork(b,Vector2(4202,339),170,Vector2(70,22))
	await base.cleanup(f)
