extends RefCounted

const Toast = preload("res://scripts/boss_toast.gd")
const Geometry = preload("res://scripts/combat_geometry.gd")
const Afterimage = preload("res://scripts/shadow_afterimage.gd")
var t: SceneTree

func run(tree: SceneTree) -> void:
	t = tree
	var before: int = t.checks
	var failed: int = t.failures
	for pair in [["난도","난도를"],["은신","은신을"],["질주","질주를"],["드래곤 피어","드래곤 피어를"],["이그리트","이그리트를"],["베르","베르를"]]:
		t.check(Toast.particle(pair[0],"을","를")==pair[1],"S8-I3-B particle "+pair[1])
	t.check(Toast.particle("바루카","이","가")=="바루카가" and Toast.particle("정예병","이","가")=="정예병이","S8-I3-B subject particles")
	var store: CsvDataStore = t._store()
	t.check(store.load_all().is_empty(),"S8-I3-B real data load")
	var basic := store.get_row("boss_action.csv","baruka_basic")
	var blink := store.get_row("boss_action.csv","baruka_blink")
	t.check(basic.Cooldown_sec==0.63 and basic.Telegraph_sec==0.23 and basic.Dash_speed==1560 and basic.Dash_distance==160 and basic.Recovery_sec==0,"S8-I3-B exact fixed basic values (BAL02 telegraph .23 speed 1560)")
	t.check(blink.Strike_interval_sec==0.04 and blink.Dash_speed==8064 and blink.Cooldown_sec==10,"S8-I3-B blink changes interval rather than cooldown")
	t.check(store.get_row("projectile.csv","elf_arrow").Speed==585 and store.get_row("projectile.csv","elf_burst_arrow").Speed==585 and store.get_row("projectile.csv","proj_test_01").Speed==300,"S8-I3-B only two projectile speeds changed")
	await flee_checks()
	await triangle_checks()
	await toast_and_visual_checks()
	await death_checks()
	await visual_equivalence()
	print("S8-IMPL-03-B NEW RESULT: %d checks, %d failures" % [t.checks-before,t.failures-failed])

func flee_checks() -> void:
	var helper = preload("res://tests/elf_boss_p0.gd").new()
	helper.t = t
	helper.helper = preload("res://tests/boss_p0.gd").new()
	helper.helper.t = t
	helper.store = t._store()
	helper.store.load_all()
	helper.helper.store = helper.store
	var f: Dictionary = helper.fixture()
	helper.disable_skills(f)
	f.player.global_position = Vector2(200,0)
	helper.step(f,0)
	var e: Variant = f.boss.elf
	t.check(e.fleeing and e.shots_fired==1 and e.flee_direction==Vector2.LEFT,"S8-I3-B basic shot triggers fixed away direction")
	var cooldown: float = f.boss.ready_at.ice_elf_basic
	f.player.global_position = Vector2(0,50)
	for kind in [4,5,6]: f.boss.ready_at[e.rows[kind].Id] = 0
	for i in range(3):
		helper.step(f,0.1)
		t.check(e.last_branch=="flee" and not e.burst and not e.hidden and e.flee_direction==Vector2.LEFT,"S8-I3-B committed flee does not switch or reaim")
	helper.step(f,1)
	t.check(not e.fleeing and f.boss.global_position.is_equal_approx(Vector2(-100,0)) and is_equal_approx(e.flee_travelled,100) and f.boss.ready_at.ice_elf_basic==cooldown,"S8-I3-B stops at100 preserves shot deadline")
	f.boss.global_position = Vector2(-1970,0)
	f.player.global_position = Vector2(-1900,0)
	helper.disable_skills(f)
	f.boss.ready_at.ice_elf_basic = 0
	helper.step(f,0)
	helper.step(f,0.1)
	t.check(e.fleeing and e.flee_direction.x==0,"S8-I3-C wall normal selects an open parallel direction")
	e.fleeing = false
	f.boss.global_position = Vector2(-1972,0)
	f.player.global_position = Vector2(-1900,-100)
	f.boss.ready_at.ice_elf_basic = 0
	helper.step(f,0)
	var fixed: Vector2 = e.flee_direction
	helper.step(f,0.1)
	t.check(e.fleeing and f.boss.global_position.x==-1972 and f.boss.global_position.y>0 and e.flee_direction==fixed,"S8-I3-B wall retains parallel component and fixed direction")
	for i in range(30):
		if not e.fleeing: break
		helper.step(f,0.1)
	t.check(not e.fleeing and is_equal_approx(e.flee_travelled,100),"S8-I3-B wall sliding ends after actual distance100")
	f.boss.global_position = Vector2.ZERO
	f.player.global_position = Vector2(100,0)
	f.boss.ready_at.ice_elf_basic = 0
	helper.step(f,0)
	f.boss.apply_fear(1)
	helper.step(f,0.1)
	t.check(not e.fleeing and e.last_branch=="fear","S8-I3-B fear interrupts flee")
	f.boss.fear_remaining = 0
	f.boss.ready_at.ice_elf_basic = 0
	helper.step(f,0)
	f.player.stealth_remaining = 1
	helper.step(f,0)
	t.check(not e.fleeing and e.last_branch=="stealth_wait","S8-I3-B player stealth interrupts flee")
	f.player.stealth_remaining = 0
	f.boss.global_position = Vector2.ZERO
	f.player.global_position = Vector2(100,0)
	f.boss.ready_at.ice_elf_basic = 9999
	f.boss.ready_at.ice_elf_burst = 0
	helper.step(f,0)
	helper.step(f,3)
	t.check(not e.fleeing and not e.burst and e.shots_fired==22,"S8-I3-B burst never triggers flee")
	await helper.helper.cleanup(f)

func triangle_checks() -> void:
	var f: Dictionary = t._fixture()
	var target: EnemyActor = t._spawn(f,Vector2(70,0))
	var second: EnemyActor = t._spawn(f,Vector2(40,10))
	var outside: EnemyActor = t._spawn(f,Vector2(60,60))
	target.hp = 50
	f.player.update_basic_attack(0,[target,second,outside])
	t.check(target.hp==40 and second.hp==90 and outside.hp==100,"S8-I3-B triangle damages all inside enemies once")
	t.check(f.player._remaining_hits==1 and f.player.global_position==Vector2.ZERO,"S8-I3-B two hits retained without player dash")
	target.global_position = Vector2(500,0)
	second.global_position = Vector2(0,60)
	f.player.update_basic_attack(0.15,[target,second])
	t.check(second.hp==80 and f.player._remaining_hits==0,"S8-I3-B second hit reacquires direction")
	f.player.update_basic_attack(1.0,[target])
	t.check(f.player._remaining_hits==0,"S8-I3-B no target skips attack")
	var base := Vector2(18,0)
	var width := 90.0*0.381
	for point in [base,base+Vector2(90,0),base+Vector2(45,width/4)]:
		t.check(Geometry.in_triangle(point,base,Vector2.RIGHT,90,width),"S8-I3-B triangle inclusive edge "+str(point))
	for point in [base-Vector2(0.01,0),base+Vector2(90.01,0),base+Vector2(45,width/4+0.01)]:
		t.check(not Geometry.in_triangle(point,base,Vector2.RIGHT,90,width),"S8-I3-B triangle excludes outside "+str(point))
	f.host.queue_free()
	await t.process_frame

func toast_and_visual_checks() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	t.root.add_child(scene)
	var map: Node = scene.get_child(0)
	for node in map.get_children(): node.set_physics_process(false)
	var manager: EnemyManager = map.get_node("EnemyManager")
	var skills: Node2D = map.get_node("SkillManager")
	var shadows: Node2D = map.get_node("ShadowManager")
	var d: Node2D = manager.boss_director
	var view: Control = d.toast_view
	t.check(skills.try_use("skill_dash") and view.entries.size()==1 and view.entries[0].text=="[스킬 : 질주를 사용합니다]","S8-I3-B successful player cast emits exactly once")
	t.check(not skills.try_use("skill_dash") and view.entries.size()==1,"S8-I3-B rejected cast has no toast")
	var a: Node2D = shadows.summon("igrit")
	t.check(view.entries.size()==1,"S8-I3-B non-selection summon silent")
	a.free()
	# Use production choice selection, including its summon bridge.
	var choices: Node = map.get_node("ChoiceManager")
	manager._player.add_experience(manager._player.get_xp_to_next())
	var summon_index := -1
	for i in range(choices.cards.size()):
		if choices.card_state(i).get("summon",false): summon_index = i
	if summon_index<0:
		# Draw from production candidates until the actual summon card is offered.
		for i in range(100):
			choices.cards = choices.draw_cards()
			for j in range(choices.cards.size()):
				if choices.card_state(j).get("summon",false): summon_index = j
			if summon_index>=0: break
	t.check(summon_index>=0 and choices.select(summon_index) and view.entries.size()==2 and view.entries[0].text.begins_with("[그림자 병사 "),"S8-I3-B actual selection summon notifies once")
	t.paused = false
	for i in range(5): view.push_message("message%d" % i)
	var active: Array = view.entries.filter(func(entry: Dictionary) -> bool: return not entry.retiring)
	t.check(active.size()==4 and active[0].text=="message4" and active[3].text=="message1","S8-I3-B newest first with oldest retiring at fifth")
	t.check(active[1].panel.offset_top-active[0].panel.offset_bottom==8,"S8-I3-B toast gap8")
	view._process(0.21)
	t.check(view.entries.size()==4,"S8-I3-B overflow fade removes oldest")
	d.timeline = [{"Id":"test_final","Time_mmss":0,"Boss_id":"boss_final"}]
	d.advance(0,0)
	d.advance(3.5,0)
	var boss: EnemyActor = d.actor
	var count: int = view.entries.size()
	boss.apply_damage(boss.hp)
	t.check(d.completed and t.paused and view.entries[0].text=="[보스 몬스터를 처치했습니다]" and view.entries.size()==count+1,"S8-I3-B final death toast and immediate completion pause")
	d._boss_died(boss)
	t.check(view.entries.filter(func(entry: Dictionary) -> bool: return entry.text=="[보스 몬스터를 처치했습니다]").size()==1,"S8-I3-B repeated death callback cannot duplicate toast")
	view._process(0.2)
	t.check(view.entries[0].age>=0.2 and view.entries[0].panel.modulate.a==1 and view.process_mode==Node.PROCESS_MODE_ALWAYS and view.get_parent().layer>0,"S8-I3-B toast fades above completion while paused")
	t.paused = false
	var records: Array = []
	for enabled in [false,true]:
		skills.visuals_enabled = enabled
		manager._player.visuals_enabled = enabled
		manager._spawn_from_row({"Spawn_count":1,"Enemy_id":"enemy_01"})
		var enemy: EnemyActor = manager._active_enemies.back()
		enemy.global_position = manager._player.global_position+Vector2(50,0)
		var hp: int = enemy.hp
		skills._slash_tick({"Range":100,"Damage":2,"Hit_interval_sec":0.1},skills.clock)
		manager._player.begin_dash(80,0.2)
		manager._player._physics_process(0.1)
		records.append(hp-enemy.hp)
		enemy.apply_damage(enemy.hp)
	t.check(records==[2,2],"S8-I3-B dash trails and slash visuals add zero damage")
	scene.queue_free()
	await t.process_frame

func death_checks() -> void:
	var base = preload("res://tests/boss_p0.gd").new()
	base.t = t
	base.store = t._store()
	base.store.load_all()
	for id in ["boss_early","boss_middle","boss_final"]:
		var f: Dictionary = base.fixture({"one":{"Id":"one","Time_mmss":0,"Boss_id":id}})
		base.tick(f,0)
		base.tick(f,3.5)
		var boss: EnemyActor = f.director.actor
		boss.apply_damage(boss.hp)
		boss.apply_damage(1)
		f.manager._elapsed_seconds+=1
		f.director.advance(f.manager._elapsed_seconds,1)
		boss.update_actor(1,Vector2.ZERO,boss.map_bounds)
		var messages: Array = f.director.toast_view.entries.filter(func(entry: Dictionary) -> bool: return entry.text=="[보스 몬스터를 처치했습니다]")
		t.check(messages.size()==1,"S8-I3-B death event stays once through fade "+id)
		t.check(f.director.completed==(id=="boss_final") and t.paused==(id=="boss_final"),"S8-I3-B completion timing unchanged "+id)
		await base.cleanup(f)

func visual_equivalence() -> void:
	var logs: Array = []
	for enabled in [false,true]:
		var scene: Node = load("res://main.tscn").instantiate()
		t.root.add_child(scene)
		var map: Node = scene.get_child(0)
		for node in map.get_children(): node.set_physics_process(false)
		var manager: EnemyManager = map.get_node("EnemyManager")
		var skills: Node2D = map.get_node("SkillManager")
		var player: Node2D = manager._player
		skills.visuals_enabled = enabled
		player.visuals_enabled = enabled
		player.last_move_direction = Vector2.RIGHT
		manager._spawn_from_row({"Spawn_count":1,"Enemy_id":"enemy_01"})
		var enemy: EnemyActor = manager._active_enemies.back()
		enemy.global_position = player.global_position+Vector2(60,0)
		var hits: Array = []
		enemy.damaged.connect(func(_point: Vector2) -> void: hits.append(enemy.hp))
		t.check(skills.try_use("skill_rapid_slash") and skills.try_use("skill_dash"),"S8-I3-B real slash and dash start visuals="+str(enabled))
		for i in range(6):
			player._physics_process(0.1)
			skills._physics_process(0.1)
		logs.append(hits.duplicate())
		t.check(skills.skills.skill_rapid_slash.hits_done==int(skills.skills.skill_rapid_slash.snapshot.Hits),"S8-I3-B visuals do not add scheduled slash hits")
		for node in map.get_children():
			if node is Afterimage:
				t.check(not node is CollisionObject2D and not manager.get_living_enemies().has(node),"S8-I3-B player trail has no collider or target entry")
		scene.queue_free()
		await t.process_frame
	t.check(not logs[0].is_empty() and logs[0]==logs[1],"S8-I3-B full real cast damage records identical with visuals enabled and disabled")
