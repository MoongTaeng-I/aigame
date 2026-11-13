extends RefCounted

const Base = preload("res://tests/boss_p0.gd")
const ShadowManager = preload("res://scripts/shadow_manager.gd")
var t: SceneTree
var helper: RefCounted
var store: CsvDataStore

func run(tree: SceneTree) -> void:
	t = tree
	helper = Base.new()
	helper.t = t
	store = t._store()
	t.check(store.load_all().is_empty(),"S8-I2 load expanded actual CSV schemas")
	helper.store = store
	var before: int = t.checks
	var failed: int = t.failures
	validate_data()
	await priority_and_timing()
	await concealment_and_damage()
	await push_and_arrows()
	await timeline()
	print("S8-IMPL-02 NEW RESULT: %d checks, %d failures" % [t.checks-before,t.failures-failed])

func fixture() -> Dictionary:
	var f: Dictionary = helper.fixture({"middle":{"Id":"middle","Time_mmss":0,"Boss_id":"boss_middle"}})
	# The ordinary production configure supplies arrow records as in main.
	var enemies: Dictionary = store.get_table("enemy.csv").duplicate(true)
	enemies.test = t._enemy()
	f.manager.configure(f.player,Rect2(-2000,-2000,4000,4000),enemies,{},1000,0,store.get_table("projectile.csv"),t._attack())
	f.player.global_position = Vector2(1000,0)
	helper.tick(f,0)
	helper.tick(f,3.5)
	f.boss = f.director.actor
	f.boss.global_position = Vector2.ZERO
	f.boss.elf.cleanup()
	f.player.global_position = Vector2(300,0)
	f.boss.elf.recovery_until = 0
	return f

func step(f: Dictionary, delta: float) -> void:
	f.manager._elapsed_seconds+=delta
	f.boss.boss_tick(delta)

func disable_skills(f: Dictionary) -> void:
	for kind in [4,5,6]: f.boss.ready_at[f.boss.elf.rows[kind].Id] = 99999

func validate_data() -> void:
	var data = preload("res://scripts/boss_data.gd")
	t.check(data.validate(store).is_empty(),"S8-I2 middle and early profiles validate together")
	t.check(store.get_row("enemy.csv","boss_ice_elf").Max_hp>store.get_row("enemy.csv","boss_ice_bear").Max_hp,"S8-I2 draft elf HP above early boss")
	var basic := store.get_row("boss_action.csv","ice_elf_basic")
	t.check(basic.Shot_interval_sec<store.get_row("enemy.csv","enemy_test_ranged").Shot_interval_sec,"S8-I2 basic faster interval than normal ranged")
	for id in ["elf_arrow","elf_burst_arrow"]:
		t.check(store.get_row("projectile.csv",id).Speed==585,"S8-I2-B approved arrow speed "+id)
	var row := store.get_row("boss_action.csv","ice_elf_burst")
	for col in ["Shot_interval_sec","Duration_sec"]:
		var old: Variant = row[col]
		row[col] = 0
		t.check(not data.validate(store).is_empty(),"S8-I2 reject invalid "+col)
		row[col] = old
	var projectile: Variant = row.Projectile_id
	row.Projectile_id = "missing"
	t.check(not data.validate(store).is_empty(),"S8-I2 unresolved arrow reference rejected")
	row.Projectile_id = projectile

func priority_and_timing() -> void:
	var f := fixture()
	var b: Variant = f.boss
	var e: Variant = b.elf
	f.player.global_position = Vector2(100,0)
	var hp: int = f.player.hp
	step(f,0)
	t.check(e.last_branch=="push" and f.player.boss_push_duration>0 and f.player.hp==hp,"S8-I2 immediate zero-damage push has highest priority")
	t.check(is_equal_approx(b.ready_at.ice_elf_push,f.manager._elapsed_seconds+8) and e.push_effect_until>f.manager._elapsed_seconds,"S8-I2 push cooldown from instant use and post effect")
	step(f,0)
	t.check(e.hidden and e.last_branch=="stealth","S8-I2 stealth second priority")
	f.player.global_position = Vector2(300,0)
	step(f,0)
	t.check(e.burst and e.last_branch=="burst_start" and e.hidden,"S8-I2 burst third priority and does not end concealment")
	var shots: int = e.shots_fired
	var begin: float = f.manager._elapsed_seconds
	step(f,0.299)
	t.check(e.shots_fired==shots,"S8-I2 no shot before 0.3 preparation")
	f.manager._elapsed_seconds = begin+0.3
	b.boss_tick(0)
	t.check(e.shots_fired==shots+1,"S8-I2 first shot exactly at preparation end")
	var first: Vector2 = f.manager._projectiles.back().direction
	f.player.global_position = Vector2(0,300)
	f.manager._elapsed_seconds = begin+0.45
	b.boss_tick(0)
	t.check(first==Vector2.RIGHT and f.manager._projectiles.back().direction==Vector2.DOWN,"S8-I2 every burst shot reacquires current player, old arrow stays straight")
	var position: Vector2 = b.global_position
	f.manager._elapsed_seconds = begin+2.7
	b.boss_tick(0)
	t.check(e.shots_fired==shots+17 and not e.burst,"S8-I2 inclusive end shot yields 17 shots over 2.4 seconds")
	t.check(b.global_position==position,"S8-I2 stationary throughout burst")
	t.check(is_equal_approx(b.ready_at.ice_elf_burst,begin+2.7+0.6+9),"S8-I2 burst cooldown starts only after recovery")
	e.recovery_until = 0
	disable_skills(f)
	step(f,0)
	t.check(e.last_branch=="basic" and e.hidden,"S8-I2 basic shot during concealment does not reveal boss")
	await helper.cleanup(f)
	f = fixture()
	b = f.boss
	e = b.elf
	disable_skills(f)
	step(f,0)
	t.check(e.last_branch=="basic" and e.shots_fired==1,"S8-I2 basic when higher skills unavailable")
	position = b.global_position
	step(f,0.4)
	t.check(e.shots_fired==1 and b.global_position==position,"S8-I2 stops in range while basic cooldown runs")
	step(f,0.4)
	t.check(e.shots_fired==2,"S8-I2 basic interval firing")
	f.player.global_position = Vector2(900,0)
	step(f,0.1)
	t.check(e.last_branch=="follow" and b.global_position.x>position.x,"S8-I2 outside basic range approaches without retreat")
	await helper.cleanup(f)

func concealment_and_damage() -> void:
	var f := fixture()
	var b: Variant = f.boss
	var e: Variant = b.elf
	var shadows := ShadowManager.new()
	shadows.configure(f.player,f.manager,store.get_table("shadow.csv"),store.get_table("shadow_attack.csv"),store.get_table("shadow_motion.csv"),3)
	f.host.add_child(shadows)
	shadows.set_physics_process(false)
	var shadow: Node2D = shadows.summon("igrit")
	shadow.global_position = Vector2(0,100)
	f.player.global_position = Vector2(0,100)
	shadow.tick(0)
	t.check(shadow.target==b and shadow.cast_active,"S8-I2 real shadow begins attack on visible boss")
	var hp: int = b.hp
	e.start_stealth()
	t.check(shadow.target==null and shadow.cast_active,"S8-I2 concealment immediately releases retained target without cancelling cast")
	t.check(f.player.choose_target([b],1000)==null and shadow.nearest([b],1000)==null,"S8-I2 hidden boss excluded from player/shadow searches")
	t.check(b.is_active and b.collision_layer==2 and b.collision_mask==0,"S8-I2 concealment preserves active body and collisions")
	shadow.tick(0.25)
	t.check(b.hp==hp-10 and not e.hidden,"S8-I2 already-started shadow fan still damages and breaks concealment")
	var at: float = f.manager._elapsed_seconds
	t.check(is_equal_approx(b.ready_at.ice_elf_stealth,at+12),"S8-I2 hit break starts stealth cooldown at hit time")
	e.start_stealth()
	b.apply_fear(1)
	t.check(e.hidden and b.is_feared(),"S8-I2 fear applies without breaking stealth")
	step(f,1)
	t.check(e.hidden,"S8-I2 concealment continues during fear")
	f.manager._elapsed_seconds = e.hidden_until
	disable_skills(f)
	b.boss_tick(0)
	t.check(not e.hidden and is_equal_approx(b.ready_at.ice_elf_stealth,f.manager._elapsed_seconds+12),"S8-I2 natural end starts stealth cooldown at expiration")
	e.start_stealth()
	preload("res://scripts/skill_area.gd").damage_circle(b.global_position,100,1,f.manager.get_living_enemies())
	t.check(not e.hidden,"S8-I2 ordinary area damage still hits hidden boss")
	b.fear_remaining = 0
	e.start_stealth()
	f.player.global_position = Vector2(300,0)
	b.ready_at.ice_elf_burst = 0
	# The earlier close-range basic shot committed a flee; finish it before
	# checking the unchanged offensive-skill concealment rule.
	if e.fleeing: step(f,1)
	step(f,0)
	t.check(e.burst and e.hidden,"S8-I2 offensive skill keeps stealth")
	step(f,0.3)
	var arrow: Node2D = f.manager._projectiles.back()
	f.player.stealth_remaining = 2
	step(f,0)
	t.check(not e.burst and e.last_branch=="wander" and is_instance_valid(arrow),"S8-I2 player stealth immediately stops burst and leaves arrows")
	f.player.stealth_remaining = 0
	e.recovery_until = 0
	b.ready_at.ice_elf_burst = 0
	step(f,0)
	b.apply_fear(1)
	t.check(not e.burst and e.hidden,"S8-I2 fear interrupts burst without breaking boss stealth")
	b.fear_remaining = 0
	e.recovery_until = 0
	b.ready_at.ice_elf_burst = 0
	step(f,0)
	b.apply_damage(b.hp)
	t.check(b.is_logically_dead and not e.hidden and not e.burst and is_instance_valid(arrow),"S8-I2 death clears skills but leaves emitted arrows")
	await helper.cleanup(f)

func push_and_arrows() -> void:
	var f := fixture()
	var b: Variant = f.boss
	disable_skills(f)
	f.player.global_position = Vector2(100,0)
	b.ready_at.ice_elf_push = 0
	step(f,0)
	var hp: int = f.player.hp
	var start: Vector2 = f.player.global_position
	f.player._physics_process(0.2)
	t.check(absf(f.player.global_position.x-start.x-330)<0.01,"S8-I2 push uses integrated deceleration first half distance")
	f.player._physics_process(0.2)
	t.check(absf(f.player.global_position.x-start.x-440)<0.01 and f.player.hp==hp,"S8-I2 full push distance 440, zero damage")
	f.player.global_position = Vector2(1950,0)
	f.player.start_boss_push(Vector2.ZERO,440,0.4,Rect2(-2000,-2000,4000,4000))
	f.player._physics_process(0.4)
	t.check(is_equal_approx(f.player.global_position.x,1992) and f.player.boss_push_elapsed==f.player.boss_push_duration,"S8-I2 push stops at wall considering player radius")
	var shadows := ShadowManager.new()
	shadows.configure(f.player,f.manager,store.get_table("shadow.csv"),store.get_table("shadow_attack.csv"),store.get_table("shadow_motion.csv"),3)
	f.host.add_child(shadows)
	shadows.set_physics_process(false)
	var shadow: Node2D = shadows.summon("igrit")
	shadow.global_position = Vector2(100,0)
	var position: Vector2 = shadow.global_position
	f.player.global_position = Vector2(100,0)
	b.ready_at.ice_elf_push = 0
	step(f,0)
	t.check(shadow.global_position==position,"S8-I2 push skill does not push shadows")
	f.player.global_position = Vector2(300,0)
	b.elf.fire(b.elf.rows[3],f.player)
	var arrow: Node2D = f.manager._projectiles.back()
	hp = f.player.hp
	arrow.advance(0.4)
	t.check(not arrow.spent and f.player.hp==hp,"S8-I2 arrow passes through shadow without damage or consumption")
	arrow.advance(0.6)
	t.check(arrow.spent and f.player.hp==hp-12,"S8-I2 straight arrow hits player once then expires")
	arrow.advance(1)
	t.check(f.player.hp==hp-12,"S8-I2 spent arrow cannot deal repeated damage")
	await helper.cleanup(f)

func timeline() -> void:
	var f: Dictionary = helper.fixture(store.get_table("stage_timeline.csv"))
	helper.tick(f,59.9)
	t.check(f.director.active_id.is_empty(),"S8-I2 no boss before early time")
	helper.tick(f,0.1)
	helper.tick(f,3.5)
	t.check(f.director.active_id=="boss_early","S8-I2 early timeline unchanged")
	helper.tick(f,56.5)
	t.check(f.director.pending==["boss_middle"] and f.director.active_id=="boss_early","S8-I2 2:00 middle boss queues while early alive")
	f.director.actor.apply_damage(f.director.actor.hp)
	t.check(f.director.active_id=="boss_middle" and f.director.phase=="warn" and f.manager._stop_normal_spawning,"S8-I2 common queue/gate/spawn stop immediately starts middle warning")
	await helper.cleanup(f)
