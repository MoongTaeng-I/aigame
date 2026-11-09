extends RefCounted

const Extensions = preload("res://tests/skill_extensions_p0.gd")
const Main = preload("res://scripts/main.gd")
var t: SceneTree
var helper: RefCounted

func run(runner: SceneTree) -> void:
	t = runner
	helper = Extensions.new()
	helper.t = t
	await stealth()
	await fear()
	await separation()
	tables()

func check(ok: bool, label: String) -> void:
	t.check(ok,label)

func stealth() -> void:
	var f: Dictionary = helper.fixture()
	var enemy: EnemyActor = t._spawn(f,Vector2(50,0))
	f.player.configure_combat(100,t._attack())
	f.player.update_basic_attack(0.0,f.manager.get_living_enemies())
	helper.press(f,"skill_rapid_slash")
	helper.advance(f,0.1)
	var before := enemy.hp
	helper.press(f,"skill_stealth")
	var cast = f.skills.skills.skill_rapid_slash
	check(before==74 and f.player._remaining_hits==0 and not cast.active,"FIX-01 stealth cancels pending basic and rapid slash hits")
	check(is_equal_approx(cast.completed_at,0.1) and is_equal_approx(cast.cooldown_until,6.1),"FIX-01 canceled slash completes now and starts snapshot cooldown")
	f.player.update_basic_attack(0.15,f.manager.get_living_enemies())
	helper.advance(f,0.9)
	f.player.update_basic_attack(1.0,f.manager.get_living_enemies())
	check(enemy.hp==before and f.player.is_stealthed(),"FIX-01 stealth has no remaining basic or slash damage")
	helper.advance(f,0.1)
	f.player.update_basic_attack(1.1,f.manager.get_living_enemies())
	check(not f.player.is_stealthed() and enemy.hp==before-10,"FIX-01 basic attack resumes by normal readiness after stealth expires")
	await helper.close(f)
	f = helper.fixture()
	helper.press(f,"skill_stealth")
	for id in ["skill_dash","skill_rapid_slash","skill_dragon_fear"]:
		helper.press(f,id)
		check(not f.skills.skills[id].active and f.player.is_stealthed() and f.skills.icon_state(id).phase=="ready","FIX-02 stealth ignores other skill key without new icon state: "+id)
	f.player.move_speed = 120
	Input.action_press("move_right")
	helper.advance(f,0.1)
	helper.release()
	check(is_equal_approx(f.player.position.x,12.0) and f.player.is_stealthed(),"FIX-03 stealth keeps movement")
	f.player.enhancement_points = 1
	t._s5_click(f)
	check(f.skills.skills.skill_rapid_slash.level==2 and f.player.enhancement_points==0,"FIX-03 stealth permits skill icon upgrade")
	var choice_helper = preload("res://tests/choices_p0.gd").new()
	var manager = preload("res://scripts/choice_manager.gd").new()
	manager.configure(f.player,choice_helper.choice_records(3),choice_helper.choice_levels(3),{"Reroll_count":3})
	f.host.add_child(manager)
	f.q = manager
	f.player.add_experience(5)
	check(t.paused and manager.active and f.player.is_stealthed(),"FIX-03 stealth permits level-up choices")
	choice_helper.click(f,0)
	check(not t.paused and f.player.is_stealthed(),"FIX-03 selecting growth resumes existing stealth")
	await helper.close(f)
	f = helper.fixture()
	helper.press(f,"skill_dash")
	helper.advance(f,0.05)
	helper.press(f,"skill_stealth")
	helper.advance(f,0.15)
	check(f.player.position.distance_to(Vector2(80,0))<0.2 and f.player.is_stealthed() and not f.skills.skills.skill_dash.active,"FIX-04 stealth leaves already started dash moving to full distance")
	await helper.close(f)

func fear() -> void:
	var f: Dictionary = helper.fixture()
	var edge: EnemyActor = t._spawn(f,Vector2(100,0))
	var outside: EnemyActor = t._spawn(f,Vector2(100.01,0))
	f.player.move_speed = 120
	helper.press(f,"skill_dragon_fear")
	var cast = f.skills.skills.skill_dragon_fear
	var state: Dictionary = f.skills.icon_state("skill_dragon_fear")
	check(edge.is_feared() and not outside.is_feared() and cast.active and state.active_border and not state.show_gauge and state.cooldown_text=="","FIX-05 fear applies once immediately and uses existing active presentation")
	Input.action_press("move_right")
	helper.advance(f,0.25,true)
	check(f.player.position.length()<0.2 and is_equal_approx(edge.fear_remaining,0.75),"FIX-05 cast locks movement while fear duration already decreases")
	for id in ["skill_dash","skill_rapid_slash","skill_stealth"]:
		helper.press(f,id)
		check(not f.skills.skills[id].active and not f.player.is_stealthed(),"FIX-06 fear cast blocks other skill key: "+id)
	var newcomer: EnemyActor = t._spawn(f,Vector2(30,0))
	f.player.configure_combat(100,t._attack())
	f.player.update_basic_attack(0.25,f.manager.get_living_enemies())
	f.player.update_basic_attack(0.4,f.manager.get_living_enemies())
	check(newcomer.hp==80 and cast.active,"FIX-07 basic two-hit attack continues during fear cast")
	newcomer.position = Vector2(16,0)
	f.manager._update_contact_damage()
	f.manager._update_contact_damage()
	check(f.player.hp==100 and not f.manager._contact_ready_at.has(newcomer.get_instance_id()),"FIX-08 invulnerable contact causes no damage and no rehit timer")
	var shot = t._new_projectile(f,t._projectile(),Vector2(100,0),f.player.position)
	shot.advance(1.0)
	check(f.player.hp==100 and shot.spent and shot.is_queued_for_deletion(),"FIX-08 invulnerable projectile is spent and removed with zero damage")
	f.player.apply_damage(50)
	check(f.player.hp==100,"FIX-08 every player damage path respects cast invulnerability")
	outside.position = Vector2.ZERO
	helper.advance(f,0.249999,true)
	check(cast.active and f.player.is_fear_casting() and not outside.is_feared(),"FIX-09 before Cast_sec ends cast remains active without retargeting")
	helper.advance(f,0.000001,true)
	helper.release()
	state = f.skills.icon_state("skill_dragon_fear")
	check(not cast.active and not f.player.is_fear_casting() and is_equal_approx(cast.completed_at,0.5) and is_equal_approx(cast.cooldown_until,5.5) and state.phase=="cooldown","FIX-09 Cast_sec boundary completes and starts cooldown")
	check(is_equal_approx(edge.fear_remaining,0.5),"FIX-09 fear duration starts at initial press independently of cast")
	outside.position = Vector2(500,0)
	newcomer.position = f.player.position+Vector2(16,0)
	f.manager._update_contact_damage()
	check(f.player.hp==95 and f.manager._contact_ready_at.has(newcomer.get_instance_id()),"FIX-10 first post-cast contact damages immediately and starts restriction")
	shot = t._new_projectile(f,t._projectile(),Vector2(100,0),f.player.position)
	shot.advance(1.0)
	check(f.player.hp==87 and shot.spent,"FIX-10 projectile damages normally after cast")
	await helper.close(f)

func separation() -> void:
	for gap in [0.0,4.0]:
		var f: Dictionary = t._fixture()
		f.manager.separation_gap = gap
		f.player.position = Vector2(1000,1000)
		var first: EnemyActor = t._spawn(f,Vector2.ZERO)
		var second: EnemyActor = t._spawn(f,Vector2(10,0))
		second.push_weight = 3
		f.manager._resolve_contact_pushes()
		var overlap: float = 16.0+gap-10.0
		check(first.position.distance_to(Vector2(-overlap*0.75,0))<0.02 and second.position.distance_to(Vector2(10.0+overlap*0.25,0))<0.02 and absf(first.position.distance_to(second.position)-(16.0+gap))<0.02,"FIX-11 inverse weights separate enemy pair by radius sum plus gap: "+str(gap))
		await helper.close(f)
	var f: Dictionary = t._fixture()
	f.manager.separation_gap = 4
	var enemy: EnemyActor = t._spawn(f,Vector2(12,0))
	enemy.apply_fear(1.0)
	f.manager._resolve_contact_pushes()
	check(f.player.position.distance_to(Vector2(-1,0))<0.02 and enemy.position.distance_to(Vector2(15,0))<0.02,"FIX-12 player-enemy pushes keep original radius sum including feared enemy")
	enemy.fear_remaining = 0
	enemy.position = Vector2(16,0)
	f.player.position = Vector2.ZERO
	f.manager._update_contact_damage()
	check(f.player.hp==95,"FIX-12 separation does not remove ordinary contact damage")
	await helper.close(f)
	f = t._fixture()
	f.player.position = Vector2(3000,3000)
	f.manager.separation_gap = 200
	var first: EnemyActor = t._spawn(f,Vector2.ZERO)
	var second: EnemyActor = t._spawn(f,Vector2(180,0))
	f.manager._resolve_contact_pushes()
	check(absf(first.position.distance_to(second.position)-216.0)<0.02,"FIX-13 spatial grid includes large valid gap across old cell boundaries")
	first.apply_damage(100)
	second.position = Vector2(10,0)
	f.manager._resolve_contact_pushes()
	check(second.position==Vector2(10,0),"FIX-13 dead enemies remain excluded from separation")
	await helper.close(f)

func tables() -> void:
	var sources: Dictionary = t._s5_extension_sources()
	var text: String = sources["skill_dragon_fear_level.csv"]
	for value in ["0",""]:
		check(not helper.table_error("skill_dragon_fear_level.csv",text.replace("test,0.5","test,"+value)).is_empty(),"FIX-14 invalid Cast_sec rejected: "+value)
	for value in ["-1",""]:
		check(not gap_error(value).is_empty(),"FIX-14 invalid Separation_gap rejected: "+value)
	check(gap_error("0").is_empty(),"FIX-14 zero Separation_gap allowed")
	var store = t._store()
	var error: String = store.load_all()
	check(error.is_empty() and t.SkillDataScript.validate(store).is_empty(),"FIX-15 all actual CSV read and skill data validates")

func gap_error(value: String) -> String:
	var store = t._store()
	var error: String = store.load_text("spawn_rule.csv","Id,Max_alive,Offscreen_relocate_sec,Note,Separation_gap\nrule_01,10,3,test,"+value+"\n")
	if not error.is_empty(): return error
	var main := Main.new()
	error = main._validate_gameplay_data(store,{"Id":"test","Body_radius":8,"Push_weight":3},{},{},store.get_row("spawn_rule.csv","rule_01"))
	main.free()
	return error
