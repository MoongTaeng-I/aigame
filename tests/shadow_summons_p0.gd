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
	t.check(row.Search_radius==280 and row.Chase_leash_distance==560 and row.Follow_distance==200 and row.Move_speed==320 and row.Teleport_distance==900 and row.Afterimage_sec==1,"S7-01 CSV specified movement and afterimage start values")
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
	s.position = Vector2(200,0)
	other.position = Vector2(180,0)
	s.tick(0.1)
	t.check(s.position.distance_to(f.player.position)<=200.0+EPS,"S7-FIX-04 follow arrival is not undone by outward steering")
	await close(f)
	f = fixture()
	f.player.position = Vector2(300,300)
	s = f.summons.summon()
	other = f.summons.summon()
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
	other = f.summons.summon()
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

func distributed_targets() -> void:
	for screen_only in [false,true]:
		var f := fixture()
		f.player.position = Vector2(300,300)
		var shadows: Array = []
		for i in range(3): shadows.append(f.summons.summon())
		var enemies: Array = []
		for x in ([600,640,680] if screen_only else [460,500,540]):
			enemies.append(t._spawn(f,Vector2(x,300)))
		f.summons._physics_process(0.0)
		t.check(shadows[0].target==enemies[0] and shadows[1].target==enemies[1] and shadows[2].target==enemies[2],"S7-FIX2-A three distinct targets in summon order, screen=%s" % str(screen_only))
		t.check(shadows[0].last_node==("screen" if screen_only else "attack") and shadows[2].last_node==shadows[0].last_node,"S7-FIX2-A distribution applies to both BT candidate stages")
		var closer: EnemyActor = t._spawn(f,Vector2(350,300))
		f.summons._physics_process(0.0)
		t.check(shadows[0].target==enemies[0] and shadows[1].target==enemies[1] and shadows[2].target==enemies[2] and not f.summons.claimed_targets(shadows[0]).has(closer),"S7-FIX2-A locked claims survive a new closer candidate")
		await close(f)
		f = fixture()
		f.player.position = Vector2(300,300)
		shadows.clear()
		for i in range(3): shadows.append(f.summons.summon())
		var one: EnemyActor = t._spawn(f,Vector2(600 if screen_only else 460,300))
		var two: EnemyActor = t._spawn(f,Vector2(640 if screen_only else 500,300))
		f.summons._physics_process(0.0)
		t.check(shadows[0].target==one and shadows[1].target==two and shadows[2].target==one,"S7-FIX2-A only insufficient candidates allow nearest-target sharing, screen=%s" % str(screen_only))
		await close(f)
	# Once claimed search candidates are exhausted, node 1 retries locally;
	# an unclaimed screen-only enemy does not override BT priority.
	var f := fixture()
	f.player.position = Vector2(300,300)
	var first = f.summons.summon()
	var second = f.summons.summon()
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
	t.check(s.target==null and not s.cast_active and s.last_node=="follow" and s.position.distance_to(f.player.position)<before.distance_to(f.player.position),"S7-FIX2-B leash releases target, cancels cast and returns")
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
		s.tick(float(motion.Hit_time_sec)-0.01)
		t.check(near(s.facing,Vector2.DOWN) and not s.hit_done and target.hp==100,"S7-FIX2-C follows moving target before hit without early damage")
		var before_hit: Dictionary = s.attack_visual_state()
		t.check(before_hit.direction==Vector2.DOWN and before_hit.range==140 and before_hit.arc_deg==120 and near(before_hit.center,s.global_position) and before_hit.hit_age<0,"S7-FIX2-D live visualization uses actual pre-hit geometry")
		# Mimic a position displacement between cast start and hit; center must
		# be the actor's current center, not the start location.
		s.position = Vector2(310,300)
		target.position = Vector2(210,300)
		s.tick(0.01)
		t.check(s.hit_done and near(s.facing,Vector2.LEFT) and target.hp==90 and old_direction.hp==100,"S7-FIX2-C hit uses target direction at hit, not attack-start direction, motion=%d" % selected)
		t.check(edge.hp==90 and outside.hp==100,"S7-FIX2-C Range140 boundary from hit-time center is inclusive")
		var geometry: Dictionary = s.attack_geometry()
		var state: Dictionary = s.attack_visual_state()
		var same_geometry: bool = true
		for key in ["center","direction","range","arc_deg"]:
			same_geometry = same_geometry and state[key]==geometry[key]
		t.check(same_geometry and state.center==Vector2(310,300) and state.direction==Vector2.LEFT,"S7-FIX2-D visualization and actual hit geometry share all four values")
		var points := Visual.sector_points(state)
		var same_edges: bool = points[0]==state.center
		var half_angle := deg_to_rad(60.0)
		for i in range(1,points.size()):
			var offset: Vector2 = points[i]-Vector2(state.center)
			same_edges = same_edges and absf(offset.length()-140.0)<EPS and absf(wrapf(offset.angle()-PI,-PI,PI))<=half_angle+EPS
		t.check(same_edges and near(points[1],Vector2(310,300)+Vector2.LEFT.rotated(-half_angle)*140) and near(points[-1],Vector2(310,300)+Vector2.LEFT.rotated(half_angle)*140),"S7-FIX2-D renderer vertices use exact hit center, direction, range and arc")
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
		t.check(near(s.facing,Vector2.LEFT) and target.hp==hp_before and Visual.sector_flash(float(s.attack_visual_state().hit_age))<1,"S7-FIX2-C direction stays locked after hit and flash fades without another hit")
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
		t.check(s.facing==Vector2.DOWN,"S7-FIX2-C last valid facing is updated before target release, reason="+reason)
		if reason=="death": target.apply_damage(100)
		else: f.manager.recycle_enemy(target)
		if reason=="reentry": t._spawn(f,Vector2(400,300))
		s.tick(0.05)
		t.check(s.target==null and s.facing==Vector2.DOWN and down.hp==90 and right.hp==100,"S7-FIX2-C released target keeps last facing through hit without redirecting to a new enemy, reason="+reason)
		await close(f)
