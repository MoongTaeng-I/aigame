extends RefCounted

const Summons = preload("res://scripts/shadow_manager.gd")
const Data = preload("res://scripts/shadow_data.gd")
const Choices = preload("res://scripts/choice_manager.gd")
const Afterimage = preload("res://scripts/shadow_afterimage.gd")
const Visual = preload("res://scripts/shadow_visual.gd")
var t: SceneTree
const EPS := 0.001

func run(tree: SceneTree) -> void:
	t = tree
	var before: int = t.checks
	var failures: int = t.failures
	await data_and_cards()
	await targeting_and_bt()
	await attacks()
	await teleport_and_afterimage()
	await immunity_and_push()
	await actual_chase_and_camera()
	print("S7 NEW RESULT: %d checks, %d failures; pre-S7 baseline %d" % [t.checks-before,t.failures-failures,before])
	var fix_before: int = t.checks
	var fix_failures: int = t.failures
	await push_share_fixes()
	await steering_fixes()
	share_validation()
	print("S7-FIX NEW RESULT: %d checks, %d failures" % [t.checks-fix_before,t.failures-fix_failures])
	var fix2_before: int = t.checks
	var fix2_failures: int = t.failures
	await distributed_targets()
	await retained_targets()
	await hit_direction_and_visuals()
	await last_direction_after_release()
	await aim_deadband_rules()
	await fan_player_push_exclusion()
	await fan_leash_completion()
	print("S7-FIX-02 NEW RESULT: %d checks, %d failures; previous baseline %d" % [t.checks-fix2_before,t.failures-fix2_failures,fix2_before])

func fixture() -> Dictionary:
	var f: Dictionary = t._xp_fixture()
	var view := SubViewport.new()
	view.size = Vector2i(1280,720)
	view.world_2d = World2D.new()
	t.root.add_child(view)
	f.host.reparent(view)
	f.view = view
	var store = t._store()
	var error: String = store.load_all()
	t.check(error.is_empty(),"SETUP S7 real CSV loads: "+error)
	f.store = store
	var manager := Summons.new()
	var capacity: int = Summons.MAX_TYPES
	manager.configure(f.player,f.manager,store.get_table("shadow.csv"),store.get_table("shadow_attack.csv"),store.get_table("shadow_motion.csv"),capacity)
	f.host.add_child(manager)
	manager.set_physics_process(false)
	f.summons = manager
	f.manager._offscreen_relocate_seconds = 1000.0
	return f

func close(f: Dictionary) -> void:
	t.paused = false
	f.view.queue_free()
	await t.process_frame

func near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b)<=EPS

func data_and_cards() -> void:
	var f := fixture()
	t.check(Data.validate(f.store).is_empty(),"S7-01 shadow tables validate")
	t.check(Summons.MAX_TYPES==2 and f.summons.capacity==2,"MVP-01 production shadow recruitment limit is two types")
	var row: Dictionary = f.store.get_row("shadow.csv","igrit")
	t.check(row.Search_radius==280 and row.Chase_leash_distance==560 and row.Follow_distance==200 and row.Move_speed==320 and row.Teleport_distance==900 and row.Afterimage_sec==1,"S7-01 CSV specified movement and afterimage start values")
	t.check(row.Body_radius==f.store.get_row("player.csv","player_01").Body_radius and row.Push_weight==f.store.get_row("player.csv","player_01").Push_weight,"S7-01 radius and weight copied from player source")
	t.check(f.store.get_row("shadow_attack.csv","igrit_attack").Damage==f.store.get_row("basic_attack.csv","attack_01").Damage,"S7-01 damage copied from approved basic attack source")
	var choices := Choices.new()
	choices.configure(f.player,f.store.get_table("choice.csv"),f.store.get_table("choice_level.csv"),f.store.get_row("choice_rule.csv","choice_rule_01"),f.summons)
	f.host.add_child(choices)
	choices.random.seed = 20261110
	t.check(choices.candidates().count("choice_igrit")==1 and choices.candidates().count("choice_charger_test")==1 and choices.candidates().count("choice_belion")==1 and choices.candidates().size()==9,"S7-I4 three distinct shadow cards each appear once among nine candidates with heal (FIX05)")
	f.player.add_experience(f.player.get_xp_to_next())
	t.check(choices.can_reroll() and t.paused,"S7-02 actual level-up enables reroll rule 13 with five candidates")
	var rerolls: int = choices.rerolls
	choices.reroll()
	t.check(choices.rerolls==rerolls-1 and choices.cards.size()==3,"S7-02 actual paused reroll draws three and consumes a use")
	var attempts := 0
	while f.summons.actors.size()<2 and attempts<20:
		var index := choices.cards.find("choice_igrit")
		if index<0: index = choices.cards.find("choice_charger_test")
		var count: int = f.summons.actors.size()
		if index<0: index = 0
		var summoned: bool = choices.cards[index] in ["choice_igrit","choice_charger_test"]
		if summoned:
			t.check(choices.card_state(index).summon and choices.card_state(index).max==1,"S7-02 each shadow card is one summon, not repeated growth")
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = choices.ui.card_rect(index).get_center()
		choices.ui._gui_input(event)
		if summoned:
			t.check(f.summons.actors.size()==count+1,"S7-02 real card click summons exactly one entity")
		attempts += 1
		if f.summons.actors.size()<2:
			f.player.add_experience(f.player.get_xp_to_next()-f.player.experience)
	t.check(f.summons.actors.size()==2 and f.summons.capacity==2 and not choices.candidates().has("choice_igrit") and not choices.candidates().has("choice_charger_test") and not choices.candidates().has("choice_belion") and f.summons.summon()==null and f.summons.summon("charger_test")==null and f.summons.summon("belion")==null,"S7-I4 two owned types fill capacity; third recruitment draw excludes all three shadow cards")
	f.player.add_experience(f.player.get_xp_to_next()-f.player.experience)
	t.check(choices.cards.size()==3 and not choices.cards.has("choice_igrit") and not choices.cards.has("choice_charger_test") and not choices.cards.has("choice_belion"),"S7-I4 third recruitment draw keeps three cards but excludes all shadow candidates at capacity")
	t.check(choices.can_reroll() and choices.candidates().size()==6,"S7-02 after both one-time summons six candidates with heal keep reroll by rule 13 (FIX05)")
	await close(f)

func targeting_and_bt() -> void:
	var f := fixture()
	f.player.position = Vector2(300,300)
	var s = f.summons.summon()
	s.position = Vector2(300,300)
	var early: EnemyActor = t._spawn(f,Vector2(400,300))
	var later: EnemyActor = t._spawn(f,Vector2(200,300))
	s.tick(0.0)
	t.check(s.target==early,"S7-03 equal center distances choose earlier spawn")
	var nearest: EnemyActor = t._spawn(f,Vector2(380,300))
	s.tick(0.0)
	t.check(s.target==early,"S7-03 locked target retained when a nearer candidate appears")
	early.apply_damage(100)
	s.cancel_attack()
	s.tick(0.0)
	t.check(s.target==nearest and s.target!=later,"S7-03 logical death releases lock and chooses nearest living enemy")
	await close(f)
	f = fixture()
	f.player.position = Vector2(300,300)
	s = f.summons.summon()
	var enemy: EnemyActor = t._spawn(f,Vector2(450,300))
	s.tick(1.0)
	t.check(near(s.global_position,Vector2(310,300)) and s.cast_active,"S7-04 approach clamps at Range 140 then attacks without overshoot")
	var stopped: Vector2 = s.position
	s.tick(0.1)
	t.check(near(s.position,stopped),"S7-04 holds position during attack at Range")
	await close(f)
	f = fixture()
	f.player.position = Vector2(300,300)
	s = f.summons.summon()
	enemy = t._spawn(f,Vector2(600,300))
	s.tick(0.1)
	t.check(s.target==enemy and s.last_node=="screen" and near(s.position,Vector2(332,300)),"S7-05 outside search selects nearest current-screen enemy")
	await close(f)
	for offset in [10,300]:
		f = fixture()
		f.player.position = Vector2.ZERO
		s = f.summons.summon()
		s.position = Vector2(600,100)
		enemy = t._spawn(f,s.position+Vector2(offset,0))
		var initial: Vector2 = s.position
		s.tick(0.1)
		t.check(s.last_node=="follow" and s.target==null and not s.cast_active and s.position.distance_to(f.player.position)<initial.length(),"S7-06 leash >560 rejects node %s and returns" % ("1" if offset==10 else "2"))
		await close(f)
	f = fixture()
	s = f.summons.summon()
	s.position = Vector2(100,0)
	s.tick(1.0)
	t.check(s.position==Vector2(100,0) and not s.cast_active,"S7-07 no candidate waits inside Follow_distance")
	s.position = Vector2(300,0)
	s.tick(1.0)
	t.check(near(s.position,Vector2(200,0)),"S7-07 follow approaches and stops exactly at 200")
	enemy = t._spawn(f,s.position+Vector2(50,0))
	s.tick(0.0)
	t.check(s.cast_active and s.target==enemy,"S7-07 candidate appearing after empty wait attacks immediately")
	await close(f)

func attacks() -> void:
	for selected in [0,1]:
		var f := fixture()
		f.player.position = Vector2(-100,0)
		var s = f.summons.summon()
		s.position = Vector2.ZERO
		var fixed: int = selected
		s.motion_picker = func(_count: int) -> int: return fixed
		var target: EnemyActor = t._spawn(f,Vector2(50,0))
		var inside: EnemyActor = t._spawn(f,Vector2(70,40))
		var outside_angle: EnemyActor = t._spawn(f,Vector2(0,80))
		var outside_range: EnemyActor = t._spawn(f,Vector2(150,0))
		s.tick(0.0)
		t.check(s.motion_index==selected and s.cast_active,"S7-08 injected random selector chooses motion %d" % selected)
		var motion: Dictionary = s.motions[selected]
		s.tick(float(motion.Hit_time_sec)-0.00001)
		t.check(target.hp==100 and inside.hp==100,"S7-08 no damage before motion hit time %d" % selected)
		s.tick(0.00001)
		t.check(target.hp==90 and inside.hp==90 and outside_angle.hp==100 and outside_range.hp==100,"S7-08 both motions share Damage 10 and same sector geometry %d" % selected)
		s.tick(float(motion.Motion_sec)-float(motion.Hit_time_sec))
		t.check(not s.cast_active and is_equal_approx(s.ready_at,float(motion.Motion_sec)+1.2),"S7-09 interval starts at motion end %d" % selected)
		s.tick(1.2-0.00001)
		t.check(not s.cast_active,"S7-09 no early next attack %d" % selected)
		s.tick(0.00001)
		t.check(s.cast_active and s.motion_index==selected,"S7-09 exact interval allows same random motion consecutively %d" % selected)
		await close(f)

func images(f: Dictionary) -> Array:
	var result: Array = []
	for child in f.summons.get_children():
		if child is Afterimage: result.append(child)
	return result

func teleport_and_afterimage() -> void:
	var f := fixture()
	f.player.position = Vector2(300,300)
	var s = f.summons.summon()
	s.angle_picker = func() -> float: return 0.0
	s.position = Vector2(1199.99,300)
	s.tick(0.0)
	t.check(images(f).is_empty(),"S7-10 no teleport below distance 900")
	s.position = Vector2(1200,300)
	var enemy: EnemyActor = t._spawn(f,Vector2(550,300))
	s.tick(0.0)
	t.check(near(s.position,Vector2(500,300)) and near(s.position-f.player.position,Vector2(200,0)),"S7-10 distance 900 teleports onto Follow_distance circle")
	t.check(s.target==enemy and s.last_node=="attack","S7-10 teleport immediately re-evaluates BT from search")
	var copy: Node2D = images(f)[0]
	copy.set_physics_process(false)
	t.check(near(copy.global_position,Vector2(1200,300)) and copy.pose.radius==s.body_radius and copy.modulate.a<1.0,"S7-11 translucent pose copy stays at departure")
	t.check(not copy is CollisionObject2D and f.manager.get_alive_count()==1 and f.summons.actors.size()==1,"S7-11 afterimage enters no enemy or summon count and has no collider")
	var before: Vector2 = copy.position
	f.manager._resolve_contact_pushes()
	t.check(copy.position==before and s.nearest([enemy],160)==enemy,"S7-11 afterimage unaffected by pushes and target search")
	copy._physics_process(0.5)
	t.check(is_equal_approx(copy.modulate.a,0.225) and not copy.is_queued_for_deletion(),"S7-11 copy fades by half at 0.5 second")
	copy._physics_process(0.5)
	t.check(copy.is_queued_for_deletion() and copy.modulate.a==0.0,"S7-11 copy expires at one second")
	s.target = enemy
	s.teleport()
	t.check(s.target==null and not s.cast_active,"S7-12 direct teleport clears target and cast before next BT")
	f.player.position = Vector2(3990,3990)
	s.angle_picker = func() -> float: return PI/4.0
	s.teleport()
	t.check(near(s.position,Vector2(3984,3984)),"S7-12 teleport destination clamps by Body_radius at map corner")
	await close(f)

func immunity_and_push() -> void:
	var f := fixture()
	f.player.position = Vector2(100,0)
	var s = f.summons.summon()
	s.position = Vector2(30,0)
	var enemy: EnemyActor = t._spawn(f,Vector2.ZERO)
	enemy.shot_range = 200
	enemy.shot_interval_sec = 0.5
	enemy.projectile_id = "shot"
	f.manager._update_enemy_shot(enemy,0.5)
	f.manager._update_projectiles(0.5)
	var shot: CombatProjectile = f.manager._projectiles[0]
	t.check(not shot.spent and near(shot.position,Vector2(50,0)) and not s.apply_damage(100),"S7-13 real shadow immune and projectile passes through")
	f.manager._update_projectiles(0.5)
	t.check(shot.spent and f.player.hp==92,"S7-13 projectile hits player after crossing shadow")
	s.position = enemy.position
	f.manager._update_contact_damage()
	t.check(f.player.hp==92 and f.manager.get_alive_count()==1,"S7-13 shadow overlap causes no contact damage or enemy count")
	await close(f)
	f = fixture()
	f.player.position = Vector2(500,500)
	s = f.summons.summon()
	s.position = Vector2.ZERO
	enemy = t._spawn(f,Vector2(20,0))
	f.manager.separation_gap = 8
	f.manager.push_iterations = 1
	f.manager._resolve_contact_pushes()
	t.check(near(s.position,Vector2(-0.4,0)) and near(enemy.position,Vector2(23.6,0)),"S7-14 real shadow-enemy gap zero, Enemy_push_share 0.1 and remainder 0.9")
	enemy.position = Vector2(300,0)
	f.player.position = Vector2.ZERO
	s.position = Vector2(12,0)
	f.player.dash_pass_through = true
	f.manager._resolve_contact_pushes()
	t.check(f.player.position==Vector2.ZERO and s.position==Vector2(12,0),"S7-14 dash excludes real player-shadow pair")
	f.player.dash_pass_through = false
	f.manager._resolve_contact_pushes()
	t.check(near(f.player.position,Vector2(-6,0)) and near(s.position,Vector2(18,0)),"S7-14 after dash real player-shadow push resumes")
	f.player.position = Vector2(500,500)
	s.position = Vector2.ZERO
	var other = f.summons.summon("charger_test")
	other.position = Vector2(20,0)
	f.manager._resolve_contact_pushes()
	t.check(near(s.position,Vector2(-6,0)) and near(other.position,Vector2(26,0)),"S7-14 real shadows push each other to radius sum")
	other.position = Vector2(200,200)
	s.position = Vector2(3999,100)
	f.player.position = Vector2(3900,100)
	enemy.position = Vector2.ZERO
	s.tick(0.0)
	t.check(s.position.x<=3984,"S7-14 real isolated shadow obeys radius-aware map boundary")
	await close(f)

func actual_chase_and_camera() -> void:
	var f := fixture()
	f.player.position = Vector2(100,100)
	var enemy: EnemyActor = t._spawn(f,Vector2.ZERO)
	enemy.move_speed = 60.0
	var s = f.summons.summon()
	s.position = Vector2(-20,0)
	for frame in range(2): await t.physics_frame
	f.manager._update_active_enemies(0.1)
	t.check(near(enemy.position,Vector2.ONE.normalized()*6.0),"S7-15 SHADOW-07 two physics frames with actual shadow: enemy moves to player")
	await close(f)
	var view := SubViewport.new()
	view.size = Vector2i(1280,720)
	view.world_2d = World2D.new()
	t.root.add_child(view)
	var main = preload("res://main.tscn").instantiate()
	view.add_child(main)
	var player = main.get_node("Map/Player")
	var manager = main.get_node("Map/ShadowManager")
	var enemies = main.get_node("Map/EnemyManager")
	player.set_physics_process(false)
	manager.set_physics_process(false)
	enemies.set_physics_process(false)
	player.position = Vector2(1264,704)
	var camera: Camera2D = player.get_node("Camera2D")
	camera.force_update_scroll()
	await t.process_frame
	camera.force_update_scroll()
	s = manager.summon()
	s.angle_picker = func() -> float: return PI
	s.teleport()
	var screen: Rect2 = enemies._get_screen_world_rect()
	t.check(near(s.position,Vector2(1064,704)) and screen.has_point(s.position),"S7-16 actual map-edge camera keeps inward teleported shadow visible")
	print("S7 CAMERA edge player=",player.global_position," shadow=",s.global_position," screen=",screen)
	# Near map center a permitted leash position may be offscreen vertically.
	player.position = Vector2.ZERO
	camera.force_update_scroll()
	await t.process_frame
	camera.force_update_scroll()
	s.position = Vector2(0,410)
	s.tick(0.0)
	screen = enemies._get_screen_world_rect()
	t.check(not screen.has_point(s.position) and s.position==Vector2(0,410),"S7-16 screen exit within leash is allowed and not forcibly clamped")
	print("S7 CAMERA center player=",player.global_position," shadow=",s.global_position," screen=",screen)
	view.queue_free()
	await t.process_frame

func push_share_fixes() -> void:
	for share in [0.0,0.1,1.0]:
		for direct in [false,true]:
			var f := fixture()
			f.player.position = Vector2(500,500)
			var s = f.summons.summon()
			s.position = Vector2.ZERO
			s.enemy_push_share = share
			# Deliberately different weights prove this pair ignores Push_weight.
			s.push_weight = 20.0
			var enemy: EnemyActor = t._spawn(f,Vector2(20,0))
			enemy.push_weight = 5.0
			f.manager.push_iterations = 1
			if direct: f.manager._resolve_contact_pair(s,enemy)
			else: f.manager._resolve_contact_pushes()
			t.check(near(s.position,Vector2(-4.0*share,0)) and near(enemy.position,Vector2(20.0+4.0*(1.0-share),0)),"S7-FIX-01 enemy-shadow split share=%s reverse-direct=%s ignores weights" % [str(share),str(direct)])
			await close(f)
	# Compare frozen pre-change equations and production pushes on identical
	# genuinely spawned eight-enemy enclosures, without steering or movement.
	var old := enclosure()
	var current := enclosure()
	for iteration in range(4): legacy_shadow_pass(old)
	current.manager._resolve_contact_pushes()
	var old_distance: float = old.s.position.length()
	var new_distance: float = current.s.position.length()
	print("S7-FIX ENCLOSURE ",JSON.stringify({"enemies":8,"iterations":4,"before_displacement":old_distance,"after_displacement":new_distance,"before_position":[old.s.position.x,old.s.position.y],"after_position":[current.s.position.x,current.s.position.y]}))
	t.check(new_distance<old_distance,"S7-FIX-02 surrounded shadow displacement smaller than frozen weight-based result")
	await close(old)
	await close(current)

func enclosure() -> Dictionary:
	var f := fixture()
	f.player.position = Vector2(500,500)
	f.s = f.summons.summon()
	f.s.position = Vector2.ZERO
	f.manager.push_iterations = 4
	f.manager.separation_gap = 8
	for y in [-1,0,1]:
		for x in [-1,0,1]:
			if x==0 and y==0: continue
			t._spawn(f,Vector2(x*18,y*18))
	return f

func legacy_shadow_pass(f: Dictionary) -> void:
	# Same original grid and order as frozen Reference.resolve, extending its
	# participant list with registered shadows. Reference.pair is unmodified.
	var bodies: Array = [f.player]
	bodies.append_array(f.manager.get_living_enemies())
	bodies.append_array(f.summons.actors)
	var radius := float(f.player.body_radius)
	for body in bodies: radius = maxf(radius,float(body.body_radius))
	var size := maxf(64.0,radius*2.0+float(f.manager.separation_gap))
	var grid := {}
	var cells: Array[Vector2i] = []
	for i in range(bodies.size()):
		var point: Vector2 = bodies[i].global_position
		var cell := Vector2i(floori(point.x/size),floori(point.y/size))
		cells.append(cell)
		if not grid.has(cell): grid[cell] = []
		grid[cell].append(i)
	for i in range(bodies.size()):
		for x in range(-1,2):
			for y in range(-1,2):
				for j in grid.get(cells[i]+Vector2i(x,y),[]):
					if int(j)>i:
						preload("res://tests/push_reference.gd").pair(f.manager,bodies[i],bodies[int(j)])

func steering_fixes() -> void:
	var f := fixture()
	var s = f.summons.summon()
	var other = f.summons.summon("charger_test")
	s.position = Vector2(80,0)
	other.position = Vector2(120,0)
	t.check(s.separation_velocity().x<0 and other.separation_velocity().x>0,"S7-FIX-03 below 16px body-edge gap gives mutual away components")
	var before_s: Vector2 = s.position
	var before_other: Vector2 = other.position
	f.summons._physics_process(0.01)
	t.check(s.position.distance_to(other.position)>before_s.distance_to(before_other),"S7-FIX-03 actual idle follow-area movement separates shadows")
	t.check(s.position.distance_to(before_s)<=3.2+EPS and other.position.distance_to(before_other)<=3.2+EPS,"S7-FIX-03 steering and total displacement capped by Move_speed")
	s.position = Vector2(80,0)
	other.position = Vector2(128,0)
	t.check(s.separation_velocity()==Vector2.ZERO and other.separation_velocity()==Vector2.ZERO,"S7-FIX-03 at 16px body-edge gap no steering influence")
	other.position = Vector2(140,0)
	s.tick(0.1)
	t.check(s.position==Vector2(80,0),"S7-FIX-03 outside spacing preserves original stopped follow behavior")
	s.position = Vector2(200,0)
	other.position = Vector2(180,0)
	s.tick(0.1)
	t.check(s.position.distance_to(f.player.position)<=200.0+EPS,"S7-FIX-04 follow arrival is not undone by outward steering")
	await close(f)
	f = fixture()
	f.player.position = Vector2(300,300)
	s = f.summons.summon()
	other = f.summons.summon("charger_test")
	s.position = Vector2(300,300)
	other.position = Vector2(320,300)
	var enemy: EnemyActor = t._spawn(f,Vector2(440,300))
	s.motion_picker = func(_count: int) -> int: return 0
	s.ready_at = 100.0
	s.tick(0.1)
	t.check(s.target==enemy and s.position.distance_to(enemy.position)<=140.0+EPS,"S7-FIX-04 Range destination and arrival survive outward steering")
	s.ready_at = 0.0
	s.tick(0.0)
	t.check(s.cast_active,"S7-FIX-04 arrived Range still starts attack")
	var cast_position: Vector2 = s.position
	other.position = s.position+Vector2(10,0)
	s.tick(0.05)
	t.check(s.cast_active and s.separation_velocity()==Vector2.ZERO and s.position==cast_position,"S7-FIX-05 active attack motion receives no steering")
	await close(f)
	f = fixture()
	f.player.position = Vector2(300,300)
	s = f.summons.summon()
	other = f.summons.summon("charger_test")
	other.position = Vector2(280,300)
	enemy = t._spawn(f,Vector2(600,300))
	var initial: Vector2 = s.position
	s.tick(0.1)
	t.check(s.target==enemy and s.last_node=="screen" and s.position.x>initial.x and s.position.distance_to(initial)<=32.0+EPS,"S7-FIX-05 chase goal retained and combined motion speed limited")
	await close(f)

func share_validation() -> void:
	for value in [0.0,0.1,1.0,-0.01,1.01]:
		var store = t._store()
		var loaded: String = store.load_all()
		var record: Dictionary = store.get_row("shadow.csv","igrit")
		record.Enemy_push_share = value
		var error := Data.validate(store)
		var valid: bool = value>=0.0 and value<=1.0
		t.check(loaded.is_empty() and (error.is_empty() if valid else error.contains("Enemy_push_share")),"S7-FIX-06 Enemy_push_share validation value="+str(value))

func summon_test_type(f: Dictionary, index: int) -> Node2D:
	if index==0: return f.summons.summon("igrit")
	if index==1: return f.summons.summon("charger_test")
	# Test-only third type for the two-slot rejection rule; never game data.
	var record: Dictionary = f.store.get_row("shadow.csv","igrit").duplicate(true)
	record.Id = "p0_third_type"
	f.summons.records[record.Id] = record
	return f.summons.summon(record.Id)

func distributed_targets() -> void:
	for screen_only in [false,true]:
		var f := fixture()
		f.player.position = Vector2(300,300)
		var shadows: Array = []
		for i in range(2): shadows.append(summon_test_type(f,i))
		var enemies: Array = []
		for x in ([600,640] if screen_only else [460,500]):
			enemies.append(t._spawn(f,Vector2(x,300)))
		f.summons._physics_process(0.0)
		t.check(shadows[0].target==enemies[0] and shadows[1].target==enemies[1],"MVP-01 two shadows claim distinct targets in summon order, screen=%s" % str(screen_only))
		t.check(shadows[0].last_node==("screen" if screen_only else "attack") and shadows[1].last_node==shadows[0].last_node,"S7-FIX2-A distribution applies to both BT candidate stages")
		var closer: EnemyActor = t._spawn(f,Vector2(350,300))
		f.summons._physics_process(0.0)
		t.check(shadows[0].target==enemies[0] and shadows[1].target==enemies[1] and not f.summons.claimed_targets(shadows[0]).has(closer),"S7-FIX2-A locked claims survive a new closer candidate")
		await close(f)
		f = fixture()
		f.player.position = Vector2(300,300)
		shadows.clear()
		for i in range(2): shadows.append(summon_test_type(f,i))
		var one: EnemyActor = t._spawn(f,Vector2(600 if screen_only else 460,300))
		f.summons._physics_process(0.0)
		t.check(shadows[0].target==one and shadows[1].target==one,"S7-FIX2-A only insufficient candidates allow nearest-target sharing, screen=%s" % str(screen_only))
		await close(f)
	# Once claimed search candidates are exhausted, node 1 retries locally;
	# an unclaimed screen-only enemy does not override BT priority.
	var f := fixture()
	f.player.position = Vector2(300,300)
	var first = f.summons.summon()
	var second = f.summons.summon("charger_test")
	var near_enemy: EnemyActor = t._spawn(f,Vector2(460,300))
	t._spawn(f,Vector2(650,300))
	f.summons._physics_process(0.0)
	t.check(first.target==near_enemy and second.target==near_enemy,"S7-FIX2-A per-stage fallback preserves search-before-screen priority")
	await close(f)

func retained_targets() -> void:
	var f := fixture()
	f.player.position = Vector2(300,300)
	var s = f.summons.summon()
	s.ready_at = 100.0
	var original: EnemyActor = t._spawn(f,Vector2(500,300))
	s.tick(0.0)
	var closer: EnemyActor = t._spawn(f,Vector2(380,300))
	s.tick(0.0)
	t.check(s.target==original,"S7-FIX2-B retains live target despite a nearer enemy")
	original.position = Vector2(600,300)
	s.tick(0.0)
	t.check(s.target==original and s.last_node=="screen","S7-FIX2-B outside search but onscreen keeps target and pursues node 2")
	original.position = Vector2(1600,300)
	s.tick(0.0)
	t.check(s.target==closer,"S7-FIX2-B outside both search and screen releases and reselects")
	closer.apply_damage(100)
	s.tick(0.0)
	t.check(s.target==null and s.last_node=="follow","S7-FIX2-B logical death clears target with no eligible alternative")
	var pooled: EnemyActor = t._spawn(f,Vector2(500,300))
	s.tick(0.0)
	t.check(s.target==pooled,"S7-FIX2-B new living target selected after empty wait")
	f.manager.recycle_enemy(pooled)
	s.tick(0.0)
	t.check(s.target==null and not pooled.is_active,"S7-FIX2-B inactive pooled target releases immediately")
	var reused: EnemyActor = t._spawn(f,Vector2(500,300))
	s.tick(0.0)
	var old_order: int = s.target_spawn_order
	f.manager.recycle_enemy(reused)
	var reentered: EnemyActor = t._spawn(f,Vector2(500,300))
	var alternative: EnemyActor = t._spawn(f,Vector2(470,300))
	t.check(reentered==reused and reentered.spawn_order>old_order and not s.target_is_live(),"S7-FIX2-B pooled reentry before a tick is not the old locked target")
	s.tick(0.0)
	t.check(s.target==alternative and s.target_spawn_order==alternative.spawn_order,"S7-FIX2-B reentry triggers a fresh nearest choice")
	s.ready_at = 0.0
	alternative.position = s.position+Vector2(100,0)
	s.tick(0.0)
	t.check(s.cast_active,"S7-FIX2-B leash release fixture starts real cast")
	s.position = f.player.position+Vector2(561,0)
	var before: Vector2 = s.position
	s.tick(0.1)
	t.check(s.cast_active and s.last_node=="attack" and s.position==before,"S7-FIX2-B active fan remains in place beyond leash until completion")
	await close(f)
	f = fixture()
	f.player.position = Vector2(100,300)
	s = f.summons.summon()
	s.ready_at = 100.0
	var offscreen: EnemyActor = t._spawn(f,Vector2(-20,300))
	s.tick(0.0)
	offscreen.position = Vector2(-180,300)
	s.tick(0.0)
	t.check(s.target==offscreen and s.last_node=="attack","S7-FIX2-B offscreen at exact Search_radius remains locked")
	offscreen.position.x = -180.01
	s.tick(0.0)
	t.check(s.target==null and s.last_node=="follow","S7-FIX2-B outside both boundaries releases without screen-exit clamping")
	await close(f)

func hit_direction_and_visuals() -> void:
	for selected in [0,1]:
		var f := fixture()
		f.player.position = Vector2(300,300)
		var s = f.summons.summon()
		var fixed: int = selected
		s.motion_picker = func(_count: int) -> int: return fixed
		var target: EnemyActor = t._spawn(f,Vector2(400,300))
		var old_direction: EnemyActor = t._spawn(f,Vector2(420,300))
		var edge: EnemyActor = t._spawn(f,Vector2(170,300))
		var outside: EnemyActor = t._spawn(f,Vector2(169.9,300))
		t.check(s.attack_visual_state().is_empty(),"S7-FIX2-D no attack sector outside cast")
		t.check(Data.validate(f.store).is_empty() and s.attack.Range==140 and s.config.Search_radius==280,"S7-FIX2-D Range140 and Search280 pass real CSV validation")
		s.tick(0.0)
		var motion: Dictionary = s.motions[selected]
		t.check(s.cast_active and near(s.facing,Vector2.RIGHT),"S7-FIX2-C attack begins toward original target")
		target.position = Vector2(300,400)
		var expected_pre := Vector2.RIGHT.rotated(deg_to_rad(180.0*(float(motion.Hit_time_sec)-0.01)))
		var expected_hit := Vector2.RIGHT.rotated(deg_to_rad(180.0*float(motion.Hit_time_sec)))
		s.tick(float(motion.Hit_time_sec)-0.01)
		t.check(near(s.facing,expected_pre) and not s.hit_done and target.hp==100,"S7-FIX2-C follows moving target within approved180deg/sec without early damage")
		var before_hit: Dictionary = s.attack_visual_state()
		t.check(near(before_hit.direction,expected_pre) and before_hit.range==140 and before_hit.arc_deg==120 and near(before_hit.center,s.global_position) and before_hit.hit_age<0,"S7-FIX2-D live visualization uses actual pre-hit geometry")
		# Mimic a position displacement between cast start and hit; center must
		# be the actor's current center, not the start location.
		s.position = Vector2(310,300)
		target.position = Vector2(210,300)
		edge.position = Vector2(450,300)
		outside.position = Vector2(450.1,300)
		s.tick(0.01)
		t.check(s.hit_done and near(s.facing,expected_hit) and target.hp==100 and old_direction.hp==90,"S7-FIX2-C hit locks limited direction and its actual sector, motion=%d" % selected)
		t.check(edge.hp==90 and outside.hp==100,"S7-FIX2-C Range140 boundary from hit-time center is inclusive")
		var geometry: Dictionary = s.attack_geometry()
		var state: Dictionary = s.attack_visual_state()
		var same_geometry: bool = true
		for key in ["center","direction","range","arc_deg"]:
			same_geometry = same_geometry and state[key]==geometry[key]
		t.check(same_geometry and state.center==Vector2(310,300) and near(state.direction,expected_hit),"S7-FIX2-D visualization and actual hit geometry share all four values")
		var points := Visual.sector_points(state)
		var same_edges: bool = points[0]==state.center
		var half_angle := deg_to_rad(60.0)
		for i in range(1,points.size()):
			var offset: Vector2 = points[i]-Vector2(state.center)
			same_edges = same_edges and absf(offset.length()-140.0)<EPS and absf(wrapf(offset.angle()-expected_hit.angle(),-PI,PI))<=half_angle+EPS
		t.check(same_edges and near(points[1],Vector2(310,300)+expected_hit.rotated(-half_angle)*140) and near(points[-1],Vector2(310,300)+expected_hit.rotated(half_angle)*140),"S7-FIX2-D renderer vertices use exact hit center, direction, range and arc")
		t.check(is_equal_approx(Visual.sector_flash(float(state.hit_age)),1.0),"S7-FIX2-D sector flashes once at hit")
		var hp_before: int = target.hp
		var position_before: Vector2 = s.position
		var claimed: Array = f.summons.claimed_targets(null)
		for i in range(3):
			Visual.sector_points(s.attack_visual_state())
			s.queue_redraw()
		await t.process_frame
		t.check(target.hp==hp_before and s.position==position_before and f.summons.claimed_targets(null)==claimed and not s is CollisionObject2D,"S7-FIX2-D visualization has no damage, movement, claim or collider side effects")
		target.position = Vector2(310,400)
		s.tick(0.05)
		t.check(near(s.facing,expected_hit) and target.hp==hp_before and Visual.sector_flash(float(s.attack_visual_state().hit_age))<1,"S7-FIX2-C direction stays locked after hit and flash fades without another hit")
		s.tick(float(motion.Motion_sec)-float(motion.Hit_time_sec)-0.05)
		t.check(not s.cast_active and s.attack_visual_state().is_empty(),"S7-FIX2-D sector disappears at exact motion end")
		await close(f)

func last_direction_after_release() -> void:
	for reason in ["death","inactive","reentry"]:
		var f := fixture()
		f.player.position = Vector2(300,300)
		var s = f.summons.summon()
		s.motion_picker = func(_count: int) -> int: return 0
		var target: EnemyActor = t._spawn(f,Vector2(400,300))
		var down: EnemyActor = t._spawn(f,Vector2(300,420))
		var right: EnemyActor = t._spawn(f,Vector2(420,300))
		s.tick(0.0)
		target.position = Vector2(300,400)
		s.tick(0.1)
		var last_valid := Vector2.RIGHT.rotated(deg_to_rad(18.0))
		t.check(near(s.facing,last_valid),"S7-FIX2-C last valid facing is limited to18deg before target release, reason="+reason)
		if reason=="death": target.apply_damage(100)
		else: f.manager.recycle_enemy(target)
		if reason=="reentry": t._spawn(f,Vector2(400,300))
		s.tick(0.05)
		t.check(s.target==null and near(s.facing,last_valid) and down.hp==100 and right.hp==90,"S7-FIX2-C released target keeps last facing through hit without redirecting to a new enemy, reason="+reason)
		await close(f)

func aim_deadband_rules() -> void:
	var store = t._store()
	t.check(store.load_all().is_empty(),"S7-D-CSV actual deadband column loads")
	t.check(store.get_row("shadow_attack.csv","igrit_attack").Aim_deadband_deg==10.0 and store.get_row("shadow_attack.csv","charger_attack").Aim_deadband_deg==null,"S7-D-CSV proposed fan10/dash blank")
	var fan: Dictionary = store.get_row("shadow_attack.csv","igrit_attack")
	for value in [null,-10.0,INF,NAN,0.0,5.0,10.0,15.0]:
		fan.Aim_deadband_deg = value
		var error: String = Data.validate(store)
		var valid: bool = value!=null and is_finite(float(value)) and float(value)>=0.0
		t.check(error.is_empty() if valid else (error.contains("shadow_attack.csv") and error.contains("행 2") and error.contains("Aim_deadband_deg")),"S7-D-CSV finite nonnegative fan deadband "+str(value))
	for selected in [0,1]:
		for side in [-1.0,1.0]:
			var f := fixture()
			f.player.position = Vector2(300,300)
			var s = f.summons.summon()
			s.motion_picker = func(_count: int) -> int: return selected
			var target: EnemyActor = t._spawn(f,Vector2(400,300))
			s.tick(0.0)
			t.check(s.facing==Vector2.RIGHT,"S7-D-AIM initial target direction unchanged")
			target.position = s.position+Vector2.RIGHT.rotated(deg_to_rad(side*5.0))*100.0
			s.tick(1.0/60.0)
			t.check(s.facing==Vector2.RIGHT,"S7-D-AIM inside10 holds exactly without turning")
			target.position = s.position+Vector2.RIGHT.rotated(deg_to_rad(side*10.0))*100.0
			s.tick(1.0/60.0)
			t.check(near(s.facing,Vector2.RIGHT),"S7-D-AIM inclusive10 boundary holds within float tolerance")
			target.position = s.position+Vector2.RIGHT.rotated(deg_to_rad(side*15.0))*100.0
			s.tick(1.0/60.0)
			t.check(near(s.facing,Vector2.RIGHT.rotated(deg_to_rad(side*3.0))),"S7-D-AIM error15 subtracts10 and respects3deg budget")
			s.tick(1.0/60.0)
			t.check(near(s.facing,Vector2.RIGHT.rotated(deg_to_rad(side*5.0))),"S7-D-AIM next turn is remaining2deg, not another3 or snap15")
			var held: Vector2 = s.facing
			target.position = s.position+held.rotated(deg_to_rad(side*5.0))*100.0
			s.tick(1.0/60.0)
			t.check(s.facing==held,"S7-D-AIM small reversal within band holds exact prior facing")
			s.tick(float(s.motions[selected].Hit_time_sec)-s.clock)
			t.check(s.hit_done and s.facing==held and target.hp==90 and s.attack_visual_state().direction==s.attack_geometry().direction,"S7-D-HIT limited/deadband direction locks with shared damage/display geometry")
			target.position = s.position-Vector2.RIGHT*100.0
			s.tick(1.0/60.0)
			t.check(s.facing==held and target.hp==90,"S7-D-HIT no post-hit tracking or second damage")
			await close(f)
	var f := fixture()
	f.player.position = Vector2(300,300)
	var s = f.summons.summon()
	s.attack.Aim_deadband_deg = 0.0
	var target: EnemyActor = t._spawn(f,Vector2(400,300))
	s.tick(0.0)
	target.position = s.position+Vector2.RIGHT.rotated(deg_to_rad(15.0))*100.0
	s.tick(1.0/60.0)
	t.check(near(s.facing,Vector2.RIGHT.rotated(deg_to_rad(3.0))),"S7-D-ZERO zero deadband keeps original180deg/sec tracking")
	await close(f)
	f = fixture()
	f.player.position = Vector2(300,300)
	s = f.summons.summon()
	target = t._spawn(f,s.position+Vector2.RIGHT.rotated(deg_to_rad(175.0))*100.0)
	s.tick(0.0)
	target.position = s.position+Vector2.RIGHT.rotated(deg_to_rad(-175.0))*100.0
	s.tick(1.0/60.0)
	t.check(near(s.facing,Vector2.RIGHT.rotated(deg_to_rad(175.0))),"S7-D-WRAP PI crossing10 boundary uses shortest difference")
	target.position = s.position+Vector2.RIGHT.rotated(deg_to_rad(-170.0))*100.0
	s.tick(1.0/60.0)
	t.check(near(s.facing,Vector2.RIGHT.rotated(deg_to_rad(178.0))),"S7-D-WRAP outside band turns short way across PI within3deg")
	await close(f)

func fan_player_push_exclusion() -> void:
	for selected in [0,1]:
		var results: Array = []
		for path in ["optimized","direct","reverse"]:
			var f := fixture()
			f.player.position = Vector2(300,300)
			var s = f.summons.summon()
			s.position = Vector2(500,300)
			s.motion_picker = func(_count: int) -> int: return selected
			var enemy: EnemyActor = t._spawn(f,Vector2(520,300))
			s.tick(0.0)
			f.manager.recycle_enemy(enemy)
			f.player.position = Vector2(490,300)
			f.manager.push_iterations = 1
			if path=="optimized": f.manager._resolve_contact_pushes()
			elif path=="direct": f.manager._resolve_contact_pair(f.player,s)
			else: f.manager._resolve_contact_pair(s,f.player)
			t.check(s.cast_active and s.position==Vector2(500,300) and f.player.position==Vector2(490,300),"S7-E-PUSH player-fan pair skips during cast even without enemies: "+path)
			f.player.dash_pass_through = true
			f.manager._resolve_contact_pushes()
			t.check(f.player.dash_pass_through and s.position==Vector2(500,300) and f.player.position==Vector2(490,300),"S7-E-DASH fan exclusion leaves player dash flag and skip unchanged")
			f.player.dash_pass_through = false
			s.tick(float(s.motions[selected].Motion_sec))
			if path=="optimized": f.manager._resolve_contact_pushes()
			elif path=="direct": f.manager._resolve_contact_pair(f.player,s)
			else: f.manager._resolve_contact_pair(s,f.player)
			t.check(not s.cast_active and near(s.position,Vector2(507,300)) and near(f.player.position,Vector2(483,300)),"S7-E-END player-fan split restores immediately at motion end: "+path)
			results.append([f.player.position,s.position])
			await close(f)
		t.check(results[0]==results[1] and results[1]==results[2],"S7-E-EQUAL optimized/direct/reverse restore same weighted positions")
	var f := fixture()
	f.player.position = Vector2(300,300)
	var beru = f.summons.summon("charger_test")
	t._spawn(f,Vector2(480,300))
	beru.tick(0.0)
	beru.tick(0.1)
	f.player.position = beru.position-Vector2(10,0)
	var before: Vector2 = beru.position
	f.manager._resolve_contact_pair(f.player,beru)
	t.check(beru.dash_through_active and beru.position!=before,"S7-E-BERU player pair still pushes during Beru dash")
	f.player.position = beru.position-Vector2(10,0)
	before = beru.position
	var player_before: Vector2 = f.player.position
	f.player.dash_pass_through = true
	f.manager._resolve_contact_pushes()
	t.check(beru.position==before and f.player.position==player_before and beru.dash_through_active,"S7-E-BERU player dash still excludes player-Beru pair")
	await close(f)

func fan_leash_completion() -> void:
	for selected in [0,1]:
		var f := fixture()
		f.player.position = Vector2(-300,0)
		var s = f.summons.summon()
		s.position = Vector2(-100,0)
		s.motion_picker = func(_count: int) -> int: return selected
		var enemy: EnemyActor = t._spawn(f,Vector2(0,0))
		s.tick(0.0)
		var started: float = s.cast_started_at
		var origin: Vector2 = s.position
		f.player.position = Vector2(500,0)
		s.tick(float(s.motions[selected].Hit_time_sec))
		t.check(s.cast_active and s.hit_done and s.cast_started_at==started and s.position==origin,"S7-G-CAST fan continues and hits beyond leash, motion "+str(selected))
		f.manager.recycle_enemy(enemy)
		s.tick(0.0)
		t.check(s.cast_active and not s.target_is_live(),"S7-G-TARGET invalid target keeps active fan beyond leash")
		s.tick(float(s.motions[selected].Motion_sec)-float(s.motions[selected].Hit_time_sec))
		var expected_ready: float = started+float(s.motions[selected].Motion_sec)+float(s.attack.Interval_sec)
		t.check(not s.cast_active and absf(s.ready_at-expected_ready)<0.000001 and s.position==origin,"S7-G-END fan completes normally and sets normal Interval cooldown")
		var old_position: Vector2 = s.position
		s.tick(1.0/60.0)
		t.check(not s.cast_active and s.last_node=="follow" and s.target==null and s.position.distance_to(f.player.position)<old_position.distance_to(f.player.position) and s.ready_at==s.clock,"S7-G-RETURN next outside-cast tick restores existing leash return and cooldown reset")
		await close(f)
		f = fixture()
		f.player.position = Vector2(-300,0)
		s = f.summons.summon()
		s.position = Vector2(-100,0)
		s.motion_picker = func(_count: int) -> int: return selected
		t._spawn(f,Vector2(0,0))
		s.tick(0.0)
		f.player.position = Vector2(500,0)
		s.tick(float(s.motions[selected].Motion_sec))
		f.player.position = Vector2(-300,0)
		expected_ready = s.ready_at
		s.tick(float(s.attack.Interval_sec)/2.0)
		t.check(not s.cast_active and s.ready_at==expected_ready,"S7-G-COOLDOWN inside leash waits normal cooldown after extended cast")
		s.tick(float(s.attack.Interval_sec)/2.0)
		t.check(s.cast_active,"S7-G-READY normal cooldown expiry permits next cast")
		var events: Array = []
		s.diagnostic_sink = func(event: String, details: Dictionary) -> void: events.append({"event":event,"details":details})
		f.player.position = s.position+Vector2(float(s.config.Teleport_distance),0)
		s.angle_picker = func() -> float: return PI
		s.tick(0.0)
		var cancelled := false
		for event in events:
			if event.event=="cancel" and event.details.reason=="teleport" and event.details.had_cast: cancelled = true
		t.check(cancelled and not s.cast_active,"S7-G-TELEPORT exact threshold still cancels active fan")
		await close(f)
