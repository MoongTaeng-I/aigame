extends RefCounted

var t: SceneTree
var store: CsvDataStore

func run(tree: SceneTree) -> void:
	t = tree
	var before: int = t.checks
	var failures: int = t.failures
	store = t._store()
	t.check(store.load_all().is_empty(),"S8-I3-D role CSV load")
	t.check(preload("res://scripts/boss_data.gd").validate(store).is_empty(),"S8-I3-D Kind-based profile validation after role swap")
	await timeline(false)
	await timeline(true)
	await profile_checks()
	print("S8-IMPL-03-D ROLE RESULT: %d checks, %d failures" % [t.checks-before,t.failures-failures])

func fixture() -> Dictionary:
	var scene: Node = load("res://main.tscn").instantiate()
	t.root.add_child(scene)
	var map: Node = scene.get_child(0)
	for child in map.get_children(): child.set_physics_process(false)
	var manager: EnemyManager = map.get_node("EnemyManager")
	var player: Node2D = manager._player
	# Isolate boss behavior without ordinary mobs or automatic player damage.
	player.configure_combat(100000,{})
	return {"host":scene,"manager":manager,"player":player,"skills":map.get_node("SkillManager"),"director":manager.boss_director}

func at(f: Dictionary, seconds: float) -> void:
	f.manager._elapsed_seconds = seconds
	f.director.advance(seconds,0)

func cleanup(f: Dictionary) -> void:
	t.paused = false
	f.host.queue_free()
	await t.process_frame

func timeline(queued: bool) -> void:
	var f := fixture()
	var d: Variant = f.director
	at(f,59.999)
	t.check(d.active_id.is_empty(),"S8-I3-D no boss before1:00")
	at(f,60)
	t.check(d.active_id=="boss_early" and d.toast_text.contains("'아이스 엘프 정예병'이"),"S8-I3-D 1:00 elf warning and correct subject")
	at(f,63.5)
	var first: Variant = d.actor
	t.check(first.enemy_id=="boss_ice_elf" and first.hp==525 and first.elf!=null and first.baruka==null,"S8-I3-D actual first elf525 with ranged Kind profile")
	if not queued: first.apply_damage(first.hp)
	at(f,179.999)
	t.check(d.active_id==("boss_early" if queued else ""),"S8-I3-D middle not early")
	at(f,180)
	if queued:
		t.check(d.pending==["boss_middle"] and d.actor==first,"S8-I3-D living elf queues bear")
		at(f,300)
		t.check(d.pending==["boss_middle","boss_final"] and not d.completed,"S8-I3-D living first queues final after bear")
		first.apply_damage(first.hp)
	t.check(d.active_id=="boss_middle" and d.toast_text.contains("'아이스 베어 우두머리'가") and f.manager._stop_normal_spawning,"S8-I3-D bear warning subject and spawning stop")
	var bear_at := 303.5 if queued else 183.5
	at(f,bear_at)
	var second: Variant = d.actor
	t.check(second.enemy_id=="boss_ice_bear" and second.hp==1100 and second.elf==null and second.baruka==null,"S8-I3-D actual second bear1100 with melee Kind profile")
	second.apply_damage(second.hp)
	if not queued:
		at(f,299.999)
		t.check(d.active_id.is_empty(),"S8-I3-D final not early")
		at(f,300)
	t.check(d.active_id=="boss_final" and not d.completed,"S8-I3-D final is Baruka, time never completes run")
	at(f,(bear_at if queued else 300)+3.5)
	var final: Variant = d.actor
	t.check(final.enemy_id=="boss_baruka" and final.baruka!=null and final.hp==1750,"S8-I3-D final profile and unchanged HP1750")
	t.check(d.fired.size()==3 and d.pending.is_empty(),"S8-I3-D all three actual timeline rows fire once")
	at(f,f.manager._elapsed_seconds+0.01)
	t.check(d.fired.size()==3 and d.actor==final,"S8-I3-D timeline never duplicates actors")
	final.apply_damage(final.hp)
	t.check(d.completed and t.paused,"S8-I3-D only actual final death completes and pauses")
	await cleanup(f)

func profile_checks() -> void:
	var f := fixture()
	at(f,60)
	at(f,63.5)
	var elf: Variant = f.director.actor
	elf.global_position = Vector2.ZERO
	f.player.global_position = Vector2(700,0)
	elf.ready_at.ice_elf_stealth = 9999
	elf.boss_tick(0.1)
	t.check(elf.elf.detect_range==416 and elf.elf.last_branch=="follow" and elf.elf.shots_fired==0 and elf.global_position.x>0,"S8-I3-D elf416 applies to boss_early")
	elf.apply_damage(elf.hp)
	at(f,180)
	at(f,183.5)
	var bear: Variant = f.director.actor
	bear.global_position = Vector2.ZERO
	f.player.global_position = Vector2(1000,0)
	for row in bear.actions: bear.ready_at[row.Id] = 9999
	bear.boss_tick(0.1)
	t.check(bear.global_position.is_equal_approx(Vector2(9,0)) and bear.current.is_empty(),"S8-I3-D bear map-wide pursuit90 beyond416")
	await cleanup(f)
	var helper := preload("res://tests/baruka_boss_p0.gd").new()
	helper.t = t
	helper.store = store
	helper.base = preload("res://tests/boss_p0.gd").new()
	helper.base.t = t
	helper.base.store = store
	f = helper.fixture()
	f.player.global_position = Vector2(250,0)
	helper.start(f,"baruka_basic")
	t.check(is_equal_approx(f.boss.phase_end-f.boss.clock,0.155) and f.boss.facing==Vector2.RIGHT,"S8-I3-D basic telegraph0.155 locks direction at start")
	f.player.global_position = Vector2(0,500)
	helper.step(f,0.154)
	t.check(f.boss.phase=="telegraph" and f.boss.global_position==Vector2.ZERO,"S8-I3-D basic waits full reduced telegraph")
	helper.step(f,0.001)
	t.check(f.boss.is_boss_dashing() and f.boss.facing==Vector2.RIGHT,"S8-I3-D basic starts at0.155 without reaim")
	t.check(store.get_row("boss_action.csv","baruka_blink").Dash_speed==8064,"S8-I3-D blink fixed speed8064")
	await cleanup(f)
