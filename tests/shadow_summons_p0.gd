extends RefCounted

const Summons = preload("res://scripts/shadow_manager.gd")
const Data = preload("res://scripts/shadow_data.gd")
const Choices = preload("res://scripts/choice_manager.gd")
const Afterimage = preload("res://scripts/shadow_afterimage.gd")
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
	var capacity := 0
	for row in store.get_table("choice_level.csv").values():
		if row.Choice_id=="choice_igrit": capacity = maxi(capacity,int(row.Value))
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
	var row: Dictionary = f.store.get_row("shadow.csv","igrit")
	t.check(row.Search_radius==160 and row.Chase_leash_distance==420 and row.Follow_distance==120 and row.Move_speed==320 and row.Teleport_distance==700 and row.Afterimage_sec==1,"S7-01 CSV specified movement and afterimage start values")
	t.check(row.Body_radius==f.store.get_row("player.csv","player_01").Body_radius and row.Push_weight==f.store.get_row("player.csv","player_01").Push_weight,"S7-01 radius and weight copied from player source")
	t.check(f.store.get_row("shadow_attack.csv","igrit_attack").Damage==f.store.get_row("basic_attack.csv","attack_01").Damage,"S7-01 damage copied from approved basic attack source")
	var choices := Choices.new()
	choices.configure(f.player,f.store.get_table("choice.csv"),f.store.get_table("choice_level.csv"),f.store.get_row("choice_rule.csv","choice_rule_01"),f.summons)
	f.host.add_child(choices)
	choices.random.seed = 20261110
	t.check(choices.candidates().count("choice_igrit")==1 and choices.candidates().size()==4,"S7-02 igrit appears once as fourth general candidate")
	f.player.add_experience(f.player.get_xp_to_next())
	t.check(choices.can_reroll() and t.paused,"S7-02 actual level-up enables reroll rule 13 with four candidates")
	var rerolls: int = choices.rerolls
	choices.reroll()
	t.check(choices.rerolls==rerolls-1 and choices.cards.size()==3,"S7-02 actual paused reroll draws three and consumes a use")
	var attempts := 0
	while f.summons.actors.size()<3 and attempts<20:
		var index := choices.cards.find("choice_igrit")
		var count: int = f.summons.actors.size()
		if index<0: index = 0
		var summoned: bool = choices.cards[index]=="choice_igrit"
		if summoned:
			t.check(choices.card_state(index).summon,"S7-02 igrit UI progression is summon count")
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = choices.ui.card_rect(index).get_center()
		choices.ui._gui_input(event)
		if summoned:
			t.check(f.summons.actors.size()==count+1,"S7-02 real card click summons exactly one entity")
		attempts += 1
		if f.summons.actors.size()<3:
			f.player.add_experience(f.player.get_xp_to_next()-f.player.experience)
	t.check(f.summons.actors.size()==3 and not choices.candidates().has("choice_igrit") and f.summons.summon()==null,"S7-02 capacity three removes candidate and refuses fourth")
	f.player.add_experience(f.player.get_xp_to_next()-f.player.experience)
	t.check(not choices.can_reroll() and choices.candidates().size()<=3,"S7-02 after cap <=3 general candidates disables reroll rule 13")
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
	t.check(s.target==nearest,"S7-03 nearer search candidate wins")
	nearest.apply_damage(100)
	s.cancel_attack()
	s.tick(0.0)
	t.check(s.target==early and s.target!=later,"S7-03 logical death excluded from search")
	await close(f)
	f = fixture()
	f.player.position = Vector2(300,300)
	s = f.summons.summon()
	var enemy: EnemyActor = t._spawn(f,Vector2(450,300))
	s.tick(1.0)
	t.check(near(s.global_position,Vector2(360,300)) and s.cast_active,"S7-04 approach clamps at Range 90 then attacks without overshoot")
	var stopped: Vector2 = s.position
	s.tick(0.1)
	t.check(near(s.position,stopped),"S7-04 holds position during attack at Range")
	await close(f)
	f = fixture()
	f.player.position = Vector2(300,300)
	s = f.summons.summon()
	enemy = t._spawn(f,Vector2(500,300))
	s.tick(0.1)
	t.check(s.target==enemy and s.last_node=="screen" and near(s.position,Vector2(332,300)),"S7-05 outside search selects nearest current-screen enemy")
	await close(f)
	for offset in [10,200]:
		f = fixture()
		f.player.position = Vector2.ZERO
		s = f.summons.summon()
		s.position = Vector2(500,100)
		enemy = t._spawn(f,s.position+Vector2(offset,0))
		var initial: Vector2 = s.position
		s.tick(0.1)
		t.check(s.last_node=="follow" and s.target==null and not s.cast_active and s.position.distance_to(f.player.position)<initial.length(),"S7-06 leash >420 rejects node %s and returns" % ("1" if offset==10 else "2"))
		await close(f)
	f = fixture()
	s = f.summons.summon()
	s.position = Vector2(100,0)
	s.tick(1.0)
	t.check(s.position==Vector2(100,0) and not s.cast_active,"S7-07 no candidate waits inside Follow_distance")
	s.position = Vector2(200,0)
	s.tick(1.0)
	t.check(near(s.position,Vector2(120,0)),"S7-07 follow approaches and stops exactly at 120")
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
		var outside_range: EnemyActor = t._spawn(f,Vector2(100,0))
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
	s.position = Vector2(999.99,300)
	s.tick(0.0)
	t.check(images(f).is_empty(),"S7-10 no teleport below distance 700")
	s.position = Vector2(1000,300)
	var enemy: EnemyActor = t._spawn(f,Vector2(470,300))
	s.tick(0.0)
	t.check(near(s.position,Vector2(420,300)) and near(s.position-f.player.position,Vector2(120,0)),"S7-10 distance 700 teleports onto Follow_distance circle")
	t.check(s.target==enemy and s.last_node=="attack","S7-10 teleport immediately re-evaluates BT from search")
	var copy: Node2D = images(f)[0]
	copy.set_physics_process(false)
	t.check(near(copy.global_position,Vector2(1000,300)) and copy.pose.radius==s.body_radius and copy.modulate.a<1.0,"S7-11 translucent pose copy stays at departure")
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
	var other = f.summons.summon()
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
	t.check(near(s.position,Vector2(1144,704)) and screen.has_point(s.position),"S7-16 actual map-edge camera keeps inward teleported shadow visible")
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
	var other = f.summons.summon()
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
	s.position = Vector2(120,0)
	other.position = Vector2(100,0)
	s.tick(0.1)
	t.check(s.position.distance_to(f.player.position)<=120.0+EPS,"S7-FIX-04 follow arrival is not undone by outward steering")
	await close(f)
	f = fixture()
	f.player.position = Vector2(300,300)
	s = f.summons.summon()
	other = f.summons.summon()
	s.position = Vector2(300,300)
	other.position = Vector2(320,300)
	var enemy: EnemyActor = t._spawn(f,Vector2(390,300))
	s.motion_picker = func(_count: int) -> int: return 0
	s.ready_at = 100.0
	s.tick(0.1)
	t.check(s.target==enemy and s.position.distance_to(enemy.position)<=90.0+EPS,"S7-FIX-04 Range destination and arrival survive outward steering")
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
	other = f.summons.summon()
	other.position = Vector2(280,300)
	enemy = t._spawn(f,Vector2(500,300))
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
