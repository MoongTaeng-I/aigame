extends RefCounted

# Expectations come only from systems 01 and 02. Numeric fixtures are independent
# of editable CSV. Existing system 3/4 tests and their fixtures remain untouched.
const MainScene = preload("res://main.tscn")
const MapScene = preload("res://scenes/map.tscn")
const PlayerScene = preload("res://scenes/player.tscn")
const Manager = preload("res://scripts/enemy_manager.gd")
const Store = preload("res://scripts/csv_data_store.gd")
const Data = preload("res://scripts/combat_data.gd")
const VIEW := Vector2(1280, 720)
const EPS := 0.2 # Subpixel tolerance includes CharacterBody2D collision recovery.
const S1 := "docs/systems/01_player_and_map.md"
const S2 := "docs/systems/02_enemy_spawn_and_movement.md"
var checks := 0
var failures := 0
var mismatches: Array = []
var results: Array = []
var tree: SceneTree

func expect(ok: bool, id: String, description: String, source: String, expected: Variant, actual: Variant) -> void:
	checks += 1
	var item := {"id":id,"description":description,"source":source,"expected":str(expected),"actual":str(actual),"result":"PASS" if ok else "MISMATCH"}
	results.append(item)
	if not ok:
		mismatches.append(item)
	print(item.result, " ", id, " ", description, "; expected=", expected, "; actual=", actual)

func require(ok: bool, label: String) -> bool:
	checks += 1
	results.append({"id":"SETUP","description":label,"result":"PASS" if ok else "FAIL"})
	if not ok:
		failures += 1
		push_error("FAIL SETUP " + label)
	else:
		print("PASS SETUP ", label)
	return ok

func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	await test_main_and_camera()
	await test_player_motion()
	test_csv_errors()
	await test_spawn_positions()
	await test_spawn_schedule()
	await test_enemy_motion_and_push()
	await test_relocation()
	var covered: Array = []
	for item in results:
		if not covered.has(item.id):
			covered.append(item.id)
	var complete := true
	for pair in [["S1",10],["S2",12]]:
		for number in range(1,int(pair[1])+1):
			complete = complete and covered.has("%s-%02d" % [pair[0],number])
	require(complete,"all 22 requested groups reached a spec verdict; runtime errors cannot silently skip a group")
	var output := FileAccess.open("res://.local/p0-foundation-results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"failures":failures,"mismatches":mismatches,"results":results}, "  "))
	output.close()

func viewport() -> SubViewport:
	var view := SubViewport.new()
	view.size = Vector2i(VIEW)
	view.world_2d = World2D.new()
	tree.root.add_child(view)
	return view

func disable_physics(node: Node) -> void:
	node.set_physics_process(false)
	for child in node.get_children():
		disable_physics(child)

func dispose(view: SubViewport) -> void:
	for action in ["move_up","move_down","move_left","move_right"]:
		Input.action_release(action)
	view.queue_free()
	await tree.process_frame

func test_main_and_camera() -> void:
	var view := viewport()
	var main = MainScene.instantiate()
	view.add_child(main)
	disable_physics(main)
	if not require(main.has_node("Map/Player"), "main scene creates map and player through production CSV initialization"):
		await dispose(view)
		return
	var map = main.get_node("Map")
	var player = main.get_node("Map/Player")
	var rect: Rect2 = map.get_map_rect()
	# Window mode has a documented default; headless cannot display a desktop window.
	expect(Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"),ProjectSettings.get_setting("display/window/size/viewport_height"))==Vector2i(1280,720), "S1-01", "configured viewport size", S1+" rule 1", "1280x720", Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"),ProjectSettings.get_setting("display/window/size/viewport_height")))
	expect(ProjectSettings.get_setting("display/window/size/mode",0)==0 and tree.root.mode==Window.MODE_WINDOWED, "S1-01", "configured and main-initialized window mode", S1+" rule 1", "windowed", tree.root.mode)
	expect(not ProjectSettings.get_setting("display/window/size/resizable",true) and tree.root.unresizable, "S1-01", "window resizing disabled", S1+" rule 1", false, ProjectSettings.get_setting("display/window/size/resizable",true))
	expect(rect.size.x>1280 and rect.size.y>720, "S1-02", "map larger than window", S1+" rule 2", ">1280x720", rect.size)
	expect(player.position.is_equal_approx(rect.get_center()), "S1-02", "main player starts at map center", S1+" rule 3", rect.get_center(), player.position)
	var store := Store.new()
	Data.register_schemas(store)
	if require(store.load_all().is_empty(), "load actual CSV for S1-06 speed reflection only"):
		var speed: float = store.get_row("player.csv","player_01")["Move_speed"]
		expect(is_equal_approx(player.move_speed,speed), "S1-06", "main reflects actual player Move_speed", S1+" rule 6", speed, player.move_speed)
	var camera: Camera2D = player.get_node("Camera2D")
	camera.make_current()
	await tree.physics_frame
	camera.force_update_scroll()
	var center := camera.get_screen_center_position()
	expect(center.distance_to(player.global_position)<EPS, "S1-09", "camera centers on player near map center", S1+" rule 8", player.global_position, center)
	for corner in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
		player.position = Vector2(clampf(corner.x,rect.position.x+player.body_radius,rect.end.x-player.body_radius),clampf(corner.y,rect.position.y+player.body_radius,rect.end.y-player.body_radius))
		camera.force_update_scroll()
		await tree.process_frame
		camera.force_update_scroll()
		center = camera.get_screen_center_position()
		var screen := Rect2(center-VIEW/2.0,VIEW)
		expect(rect.grow(EPS).encloses(screen), "S1-09", "camera view remains in map at corner "+str(corner), S1+" rule 8", rect, screen)
	await dispose(view)

func fixture(cap: int = 10, records: Dictionary = {}, relocate: float = 2.0) -> Dictionary:
	var view := viewport()
	view.canvas_transform = Transform2D(0.0,VIEW/2.0)
	var map = MapScene.instantiate()
	view.add_child(map)
	var player = PlayerScene.instantiate()
	player.get_node("Camera2D").enabled = false
	player.configure_body(10.0,3.0)
	player.move_speed = 180.0
	map.add_child(player)
	player.set_physics_process(false)
	var manager = Manager.new()
	manager.configure(player,map.get_map_rect(),{"test":enemy_record()},records,cap,relocate)
	map.add_child(manager)
	manager.set_physics_process(false)
	manager._random.seed = 20261109
	return {"view":view,"map":map,"player":player,"manager":manager}

func enemy_record() -> Dictionary:
	return {"Id":"test","Move_speed":0.0,"Attack_range_type":0,"Body_radius":10.0,"Push_weight":1.0,"Max_hp":80,"Contact_damage":0,"Contact_rehit_sec":1.0,"Death_fade_sec":1.0}

func row(count: int = 2, start: float = 0.0, end: float = 10.0) -> Dictionary:
	return {"Id":"spawn","Enemy_id":"test","Spawn_count":count,"Spawn_interval":1.0,"Time_start":start,"Time_end":end}

func spawn(f: Dictionary, position: Vector2) -> EnemyActor:
	var previous: int = f.manager.get_alive_count()
	f.manager._spawn_from_row(row(1))
	if not require(f.manager.get_alive_count()==previous+1, "synthetic actor created by production _spawn_from_row"):
		return null
	var enemy: EnemyActor = f.manager._active_enemies.back()
	enemy.position = position
	return enemy

func input_step(player: CharacterBody2D, actions: Array, delta: float) -> void:
	for action in ["move_up","move_down","move_left","move_right"]:
		Input.action_release(action)
	for action in actions:
		Input.action_press(action)
	player._physics_process(delta)

func test_player_motion() -> void:
	var keys := {"move_up":KEY_W,"move_down":KEY_S,"move_left":KEY_A,"move_right":KEY_D}
	for action in keys:
		var found := false
		var arrows := false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				found = found or event.physical_keycode==keys[action] or event.keycode==keys[action]
				arrows = arrows or event.physical_keycode in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT] or event.keycode in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]
		expect(found and not arrows, "S1-03", "WASD binding without arrow keys: "+action, S1+" rule 4", keys[action], InputMap.action_get_events(action))
	var f := fixture()
	await tree.physics_frame
	input_step(f.player,["move_right"],1.0)
	var straight: Vector2 = f.player.position
	expect(straight.distance_to(Vector2(180,0))<EPS, "S1-04", "cardinal speed for one second", S1+" rules 5,6", Vector2(180,0), straight)
	f.player.position = Vector2.ZERO
	input_step(f.player,["move_right","move_down"],1.0)
	var diagonal: Vector2 = f.player.position
	expect(absf(diagonal.length()-180.0)<EPS and diagonal.distance_to(Vector2.ONE.normalized()*180.0)<EPS, "S1-04", "diagonal normalized to same distance", S1+" rule 5", Vector2.ONE.normalized()*180.0, diagonal)
	for opposite in [["move_left","move_right"],["move_up","move_down"]]:
		f.player.position = Vector2.ZERO
		input_step(f.player,opposite,1.0)
		expect(f.player.position.length()<EPS, "S1-05", "opposite input cancels: "+str(opposite), S1+" exception: opposite inputs", Vector2.ZERO, f.player.position)
	var bounds: Rect2 = f.map.get_map_rect()
	var safe := bounds.grow(-10.0)
	var walls := [
		[Vector2(safe.end.x,0),["move_right"],["move_right","move_down"],Vector2.DOWN],
		[Vector2(safe.position.x,0),["move_left"],["move_left","move_down"],Vector2.DOWN],
		[Vector2(0,safe.position.y),["move_up"],["move_up","move_right"],Vector2.RIGHT],
		[Vector2(0,safe.end.y),["move_down"],["move_down","move_right"],Vector2.RIGHT]]
	for wall in walls:
		f.player.position = wall[0]
		await tree.physics_frame
		for frame in range(60):
			input_step(f.player,wall[1],1.0/60.0)
		expect(safe.grow(EPS).has_point(f.player.position), "S1-07", "continuous outward input stays in map "+str(wall[1]), S1+" rule 7", safe, f.player.position)
		var before: Vector2 = f.player.position
		input_step(f.player,wall[1],0.25)
		expect(f.player.position.distance_to(before)<EPS, "S1-08", "perpendicular input stops at wall "+str(wall[1]), S1+" exception: boundary component", before, f.player.position)
		before = f.player.position
		input_step(f.player,wall[2],0.25)
		var expected: Vector2 = wall[3]*(180.0/sqrt(2.0))*0.25
		expect((f.player.position-before).distance_to(expected)<EPS, "S1-08", "wall tangent retains normalized component "+str(wall[2]), S1+" exception: no renormalization", expected, f.player.position-before)
		before = f.player.position
		input_step(f.player,[],1.0/60.0)
		expect(f.player.position.distance_to(before)<EPS, "S1-08", "input release stops next frame", S1+" exception: no inertia", before, f.player.position)
	var corners := [[safe.position,["move_left","move_up"]],[safe.end,["move_right","move_down"]],[Vector2(safe.position.x,safe.end.y),["move_left","move_down"]],[Vector2(safe.end.x,safe.position.y),["move_right","move_up"]]]
	for corner in corners:
		f.player.position = corner[0]
		await tree.physics_frame
		input_step(f.player,corner[1],0.25)
		expect(f.player.position.distance_to(corner[0])<EPS and safe.grow(EPS).has_point(f.player.position), "S1-08", "diagonal into corner stops within map "+str(corner[1]), S1+" rule 7 and boundary exception", corner[0], f.player.position)
	await dispose(f.view)

func test_csv_errors() -> void:
	var missing := Store.new()
	missing.register_schema("ops04_nonexistent.csv",{"Id":"String"})
	var error: String = missing.load_all()
	expect(not error.is_empty() and missing.tables.is_empty(), "S1-10", "missing file rejected without defaults", S1+" CSV exception", "error and no table", error)
	var sources := ["Id\ntest\n","Id,Move_speed\ntest,no_number\n","Id,Move_speed\ntest,10\ntest,20\n"]
	var labels := ["missing required column","wrong numeric type","duplicate Id"]
	for i in range(sources.size()):
		var store := Store.new()
		store.register_schema("player.csv",{"Id":"String","Move_speed":"Float"})
		error = store.load_text("player.csv",sources[i])
		expect(not error.is_empty() and store.tables.is_empty(), "S1-10", labels[i]+" rejected without defaults", S1+" CSV exception", "error and no table", error)
	for kind in ["melee","ranged","other",""]:
		var store := Store.new()
		Data.register_schemas(store)
		var header := "Id,Name_ko,Move_speed,Attack_range_type,Body_radius,Push_weight,Note,Max_hp,Contact_damage,Contact_rehit_sec,Death_fade_sec,Shot_interval_sec,Shot_range,Projectile_id,Xp_value\n"
		error = store.load_text("enemy.csv",header+"test,test,0,"+kind+",10,1,test,80,0,1,1,,,,0\n")
		expect(error.is_empty() if kind in ["melee","ranged"] else not error.is_empty(), "S2-12", "Attack_range_type whitelist: "+kind, S2+" Enum exception", "accepted" if kind in ["melee","ranged"] else "CSV error", error)

func screen_rect(f: Dictionary) -> Rect2:
	# Independent inverse transform of a fixed 1280x720 test viewport.
	var transform: Transform2D = f.view.canvas_transform.affine_inverse()
	return Rect2(transform*Vector2.ZERO,VIEW)

func valid_spawn(pos: Vector2, radius: float, screen: Rect2, bounds: Rect2) -> bool:
	return not screen.grow(radius).has_point(pos) and bounds.grow(-radius+0.001).has_point(pos)

func test_spawn_positions() -> void:
	for index in range(5):
		var f := fixture(250)
		var bounds: Rect2 = f.map.get_map_rect()
		if index>0:
			var corners := [bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]
			f.player.position = corners[index-1].clamp(bounds.position+Vector2(10,10),bounds.end-Vector2(10,10))
			var center: Vector2 = f.player.position.clamp(bounds.position+VIEW/2.0,bounds.end-VIEW/2.0)
			f.view.canvas_transform = Transform2D(0.0,VIEW/2.0-center)
		f.manager._spawn_from_row(row(220))
		var all_valid: bool = f.manager.get_alive_count()==220
		var actual_screen := screen_rect(f)
		var bad: Array = []
		for enemy in f.manager._active_enemies:
			if not valid_spawn(enemy.position,enemy.body_radius,actual_screen,bounds):
				all_valid = false
				bad.append(enemy.position)
		var id := "S2-01" if index==0 else "S2-02"
		expect(all_valid, id, "220 production spawns, fixed seed, location case "+str(index), S2+" rules 1-4", "220 outside screen with full radius inside map", {"count":f.manager.get_alive_count(),"invalid":bad})
		await dispose(f.view)
	var f := fixture(10,{"spawn":row(2)})
	f.manager._map_rect = Rect2(-100,-100,200,200)
	f.manager._physics_process(1.0)
	expect(f.manager.get_alive_count()==0, "S2-03", "no spawnable direction skips period without fallback", S2+" no-space exception", 0, f.manager.get_alive_count())
	await dispose(f.view)

func test_spawn_schedule() -> void:
	var f := fixture(10,{"spawn":row(2)})
	f.manager._physics_process(0.5)
	expect(f.manager.get_alive_count()==0, "S2-04", "waits before one second", S2+" rule 5", 0, f.manager.get_alive_count())
	f.manager._physics_process(0.5)
	expect(f.manager.get_alive_count()==2, "S2-04", "interval 1 count 2 at one second", S2+" rule 5", 2, f.manager.get_alive_count())
	f.manager._physics_process(1.0)
	expect(f.manager.get_alive_count()==4, "S2-04", "four at two seconds", S2+" rule 5", 4, f.manager.get_alive_count())
	await dispose(f.view)
	f = fixture(5)
	f.manager._spawn_from_row(row(4))
	if require(f.manager.get_alive_count()==4,"cap scenario starts with four production enemies"):
		f.manager._spawn_from_row(row(2))
		expect(f.manager.get_alive_count()==5, "S2-05", "M5 C4 S2 adds one", S2+" rule 6", 5, f.manager.get_alive_count())
		f.manager._spawn_from_row(row(2))
		expect(f.manager.get_alive_count()==5, "S2-05", "C equals M adds zero", S2+" rule 6", 5, f.manager.get_alive_count())
	await dispose(f.view)
	f = fixture(0)
	f.manager._spawn_from_row(row(2))
	expect(f.manager.get_alive_count()==0, "S2-05", "zero cap adds zero", S2+" rule 6", 0, f.manager.get_alive_count())
	await dispose(f.view)
	f = fixture(10,{"spawn":row(2)})
	f.manager.set_normal_spawning_stopped(true)
	for i in range(3):
		f.manager._physics_process(1.0)
	expect(f.manager.get_alive_count()==0, "S2-06", "stop signal suppresses future periods", S2+" rule 7", 0, f.manager.get_alive_count())
	await dispose(f.view)
	f = fixture(10,{"a":row(2,0,2),"b":row(1,0,2)})
	f.manager._physics_process(1.0)
	expect(f.manager.get_alive_count()==3, "S2-07", "overlapping rows both spawn", S2+" overlapping time rows exception", 3, f.manager.get_alive_count())
	f.manager._physics_process(2.0)
	expect(f.manager.get_alive_count()==3, "S2-07", "time in no row spawns none", S2+" empty time interval exception", 3, f.manager.get_alive_count())
	await dispose(f.view)

func test_enemy_motion_and_push() -> void:
	var f := fixture()
	var enemy := spawn(f,Vector2(200,200))
	if enemy==null:
		await dispose(f.view)
		return
	enemy.move_speed = 80.0
	await tree.physics_frame
	for kind in [EnemyActor.AttackRangeType.MELEE,EnemyActor.AttackRangeType.RANGED]:
		enemy.attack_range_type = kind
		enemy.position = Vector2(200,200)
		var before := enemy.position
		f.manager._update_active_enemies(0.5)
		var expected := before+before.direction_to(f.player.position)*40.0
		expect(enemy.position.distance_to(expected)<EPS, "S2-08", "both attack types chase at configured speed: "+str(kind), S2+" rules 8,9", expected, enemy.position)
	var bounds: Rect2 = f.map.get_map_rect()
	var safe := bounds.grow(-enemy.body_radius)
	for edge in [Vector2(safe.position.x,0),Vector2(safe.end.x,0),Vector2(0,safe.position.y),Vector2(0,safe.end.y)]:
		enemy.position = edge
		await tree.physics_frame
		enemy.update_actor(1.0,edge*2.0,bounds)
		expect(safe.grow(EPS).has_point(enemy.position), "S2-09", "outward enemy movement clamped "+str(edge), S2+" rule 10", safe, enemy.position)
	# An isolated overlapping pair avoids an undocumented full-separation guarantee.
	enemy.move_speed = 0.0
	enemy.position = Vector2(15,0)
	f.player.position = Vector2.ZERO
	f.manager._resolve_contact_pushes()
	expect(f.player.position.distance_to(Vector2(-1.25,0))<EPS and enemy.position.distance_to(Vector2(18.75,0))<EPS, "S2-10", "player weight 3 enemy weight 1 shares overlap 5 as 1/4 and 3/4", S2+" rules 11-14", "player -1.25, enemy 18.75", [f.player.position,enemy.position])
	var other := spawn(f,Vector2(15,0))
	if other!=null:
		f.player.position = Vector2(400,400)
		enemy.position = Vector2.ZERO
		enemy.push_weight = 1.0
		other.push_weight = 3.0
		f.manager.separation_gap = 4.0
		f.manager._resolve_contact_pushes()
		expect(enemy.position.distance_to(Vector2(-6.75,0))<EPS and other.position.distance_to(Vector2(17.25,0))<EPS, "S2-10", "enemy pair includes gap 4 and inverse weight", S2+" rules 11-14 / S5-FIX-01 change 3", "enemy1 -6.75, enemy2 17.25", [enemy.position,other.position])
		other.position = Vector2(500,500)
		for edge in [Vector2(safe.position.x,0),Vector2(safe.end.x,0),Vector2(0,safe.position.y),Vector2(0,safe.end.y)]:
			enemy.position = edge
			f.player.position = edge-edge.normalized()*15.0
			f.manager._resolve_contact_pushes()
			expect(safe.grow(EPS).has_point(enemy.position), "S2-09", "contact push stays in map "+str(edge), S2+" rule 10", safe, enemy.position)
	await dispose(f.view)

func actor_state(enemy: EnemyActor) -> Array:
	return [enemy.get_instance_id(),enemy.hp,enemy.max_hp,enemy.is_active,enemy.is_logically_dead,enemy.spawn_order,enemy.shot_elapsed,enemy.projectile_id,enemy.contact_rehit_sec,enemy.knockback_direction,enemy.knockback_distance,enemy.knockback_duration,enemy.knockback_elapsed]

func test_relocation() -> void:
	var f := fixture(1,{},2.0)
	var enemy := spawn(f,Vector2(900,0))
	if enemy==null:
		await dispose(f.view)
		return
	enemy.apply_damage(7)
	# Move_speed 0 isolates relocation from chase. A completed knockback plus
	# partially accumulated shooting/contact timers are non-default combat state.
	enemy.start_knockback(Vector2(800,0),20.0,0.5)
	enemy.knockback_elapsed = 0.5
	enemy.shot_elapsed = 0.37
	f.manager._contact_ready_at[enemy.get_instance_id()] = 8.0
	var before := enemy.position
	var state := actor_state(enemy)
	f.manager._update_active_enemies(1.0)
	expect(enemy.position==before and is_equal_approx(enemy.offscreen_seconds,1.0), "S2-11", "outside time accumulates before threshold", S2+" rule 16", "same position, 1 second", [enemy.position,enemy.offscreen_seconds])
	enemy.position = Vector2.ZERO
	f.manager._update_active_enemies(0.25)
	expect(enemy.offscreen_seconds==0.0, "S2-11", "screen reentry resets outside time", S2+" rule 18", 0, enemy.offscreen_seconds)
	enemy.position = before
	f.manager._update_active_enemies(1.5)
	expect(enemy.position==before, "S2-11", "reentry interrupts continuous outside interval", S2+" rules 16,18", before, enemy.position)
	f.manager._update_active_enemies(0.6)
	var current_screen := screen_rect(f)
	var bounds: Rect2 = f.map.get_map_rect()
	expect(enemy.position!=before and valid_spawn(enemy.position,enemy.body_radius,current_screen,bounds), "S2-11", "after threshold relocates outside screen and inside map", S2+" rules 16,17", "new legal spawn location", enemy.position)
	expect(actor_state(enemy)==state and f.manager._contact_ready_at[enemy.get_instance_id()]==8.0, "S2-11", "relocation preserves identity HP and combat state", S2+" rule 19", state, actor_state(enemy))
	expect(f.manager.get_alive_count()==1 and f.manager._active_enemies[0]==enemy and f.manager._spawn_order_counter==1, "S2-11", "relocates at full cap without changing count or spawning", S2+" rule 20", "same one actor at cap 1", f.manager.get_alive_count())
	await dispose(f.view)
