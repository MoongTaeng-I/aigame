extends RefCounted

const Helper = preload("res://tests/belion_sweep_p0.gd")

func damage_trace(t: SceneTree) -> Array:
	var traces: Array = []
	for facing_angle in [0.0,0.63,PI,-2.4]:
		for forward in [true,false]:
			for hitch in [false,true]:
				var helper := Helper.new()
				helper.t = t
				var f: Dictionary = helper.fixture()
				var actor: Node2D = f.summons.summon("belion")
				actor.global_position = Vector2.ZERO
				actor.sweep_forward = forward
				var events: Array = []
				var targets: Array = []
				var offsets := [0.0,-PI/4,PI/4,-PI*0.49,PI*0.49,PI*0.6]
				for index in range(offsets.size()+2):
					var angle: float = facing_angle+offsets[index] if index<offsets.size() else facing_angle
					# S7-FIX-05 expands only radial positions by the approved1.5 ratio.
					var distance := 150.0 if index==0 else (450.0 if index==6 else (451.5 if index==7 else 270.0))
					var enemy: EnemyActor = t._spawn(f,Vector2.RIGHT.rotated(angle)*distance,100)
					targets.append(enemy)
					enemy.damaged.connect(func(_point: Vector2) -> void: events.append([index,snappedf(actor.clock,0.000001),enemy.hp]))
				actor.tick(0.0)
				# Move the original target after windup starts: aim must remain frozen.
				targets[0].position = Vector2.RIGHT.rotated(facing_angle+PI/6)*165
				if hitch:
					for step in [0.2,0.2,0.075,0.075,0.15,0.2]: actor.tick(step)
				else:
					for step in range(36): actor.tick(0.025)
				var hp: Array = []
				for enemy in targets: hp.append(enemy.hp)
				traces.append({"angle":facing_angle,"forward":forward,"hitch":hitch,"events":events,"hp":hp,"ready_at":snappedf(actor.ready_at,0.000001),"next_forward":actor.sweep_forward})
				await helper.close(f)
	return traces

func run(t: SceneTree) -> void:
	var before: int = t.checks
	var failed: int = t.failures
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/belion_damage_trace.json"))
	var actual := await damage_trace(t)
	t.check(JSON.parse_string(JSON.stringify(actual))==expected,"S7-F5 all16 radially scaled inputs match approved Range450 baseline (enemy,time,hp,cooldown)")
	await visual_checks(t)
	await range_and_width_checks(t)
	print("S7-FIX-04 NEW RESULT: %d checks, %d failures" % [t.checks-before,t.failures-failed])

func visual_checks(t: SceneTree) -> void:
	var helper := Helper.new()
	helper.t = t
	var f: Dictionary = helper.fixture()
	var b: Node2D = f.summons.summon("belion")
	b.global_position = Vector2(40,25)
	var target: EnemyActor = t._spawn(f,b.global_position+Vector2(100,0),100)
	b.tick(0.0)
	var state: Dictionary = b.sweep_visual_state()
	t.check(state.hand==b.global_position+Vector2(15,-87),"S7-F4 right hand is foot plus15,-95")
	t.check(state.windup and b.sprite_body.frame_row==2 and b.sprite_body.frame_column==0,"S7-F4 windup holds attack frame1")
	await t.process_frame
	# The same state.hand drives windup glow and chain geometry.
	t.check(state.hand==b.chain_hand_position(),"S7-F4 windup glow anchor equals chain hand anchor")
	target.position.x = b.position.x-200
	b.tick(0.2)
	t.check(not b.sprite_body.flip_h and b.chain_hand_position()==state.hand,"S7-F4 attack facing stays frozen when target crosses actor")
	b.tick(0.2)
	t.check(b.sprite_body.frame_column==1,"S7-F4 sweep starts attack frame2")
	await t.process_frame
	var visual = preload("res://scripts/shadow_visual.gd")
	for progress in [0.0,0.25,0.5,0.75,1.0]:
		# Visual sampling does not advance combat or change any facing state.
		state = b.sweep_visual_state()
		state.direction = Vector2.RIGHT.rotated(lerpf(-PI/2,PI/2,progress))
		var geometry: Dictionary = visual.belion_chain_geometry(state,12)
		t.check(geometry.points[0]==state.hand and geometry.points[12]==state.center+state.direction*450.0,"S7-F5 curve endpoints match hand and ground Range450 tip at "+str(progress))
		t.check(geometry.diamonds.size()==12 and geometry.points.size()==13,"S7-F4 configured12 diamond pieces at "+str(progress))
		var grounded := true
		var previous_height := INF
		for index in range(13):
			var fraction := float(index)/12
			var ground: Vector2 = Vector2(state.hand.x,state.foot.y).lerp(geometry.tip,fraction)
			var height: float = ground.y-geometry.points[index].y
			grounded = grounded and height>=-0.00001 and height<=previous_height+0.00001
			previous_height = height
		t.check(grounded and absf(previous_height)<0.00001,"S7-F4 chain height monotonically descends to ground at "+str(progress))
		var widths := true
		for diamond: PackedVector2Array in geometry.diamonds:
			widths = widths and is_equal_approx(diamond[1].distance_to(diamond[3]),24.0)
		t.check(widths,"S7-F5 diamond thickness24 at "+str(progress))
	b.tick(0.15)
	t.check(b.sprite_body.frame_column==1,"S7-F4 second half still attack frame2")
	b.tick(0.15)
	t.check(not b.cast_active and b.sprite_body.frame_column==2,"S7-F4 completed sweep immediately shows frame3")
	b.tick(0.099)
	t.check(b.sprite_body.frame_column==2,"S7-F4 frame3 lasts first0.1 seconds")
	b.tick(0.001)
	t.check(b.sprite_body.frame_column==3,"S7-F4 frame4 starts after0.1 seconds")
	b.tick(0.099)
	t.check(b.sprite_body.frame_column==3,"S7-F4 frame4 lasts second0.1 seconds")
	b.tick(0.001)
	t.check(b.sprite_body.frame_row!=2,"S7-F4 returns to locomotion after0.2 seconds")
	# Mirror image offsets only; preserve original full-vector aim and alternation.
	b.facing = Vector2.LEFT
	b.cast_active = true
	b.cast_started_at = b.clock
	b.update_sprite_visual(Vector2.ZERO,0)
	t.check(b.sprite_body.flip_h and b.chain_hand_position()==b.global_position+Vector2(-15,-87),"S7-F4 left hand mirrors x and preserves foot height")
	var right_state := {"hand":Vector2(15,-87),"foot":Vector2(0,8),"center":Vector2.ZERO,"direction":Vector2(1,0.3).normalized(),"range":450.0,"chain_width":24.0}
	var left_state := right_state.duplicate()
	left_state.hand.x = -15
	left_state.direction.x *= -1
	var right: Dictionary = visual.belion_chain_geometry(right_state,12)
	var left: Dictionary = visual.belion_chain_geometry(left_state,12)
	var mirrored := true
	for index in range(13): mirrored = mirrored and Vector2(-right.points[index].x,right.points[index].y).is_equal_approx(left.points[index])
	t.check(mirrored,"S7-F4 chain curve mirrors left and right without changing damage geometry")
	var live_state: Dictionary = b.sweep_visual_state()
	var live_geometry: Dictionary = visual.belion_chain_geometry(live_state,12)
	b.add_sweep_trail_tip()
	t.check(live_geometry.tip==b.sweep_trail.back().point,"S7-F4 drawn tip equals actual angle Range endpoint and trail point")
	b.sprite_body.free()
	b.sprite_body = null
	t.check(not b.sweep_visual_state().has("hand"),"S7-F4 image-free procedural chain and windup keep legacy path")
	var store: CsvDataStore = f.store
	var row: Dictionary = store.get_row("shadow.csv","belion")
	t.check(row.Chain_hand_x==15.0 and row.Chain_hand_y==-95.0 and store.get_row("shadow.csv","igrit").Chain_hand_x==null and store.get_row("shadow.csv","charger_test").Chain_hand_y==null,"S7-F4 approved hand CSV values and other shadows empty")
	for column in ["Chain_hand_x","Chain_hand_y"]:
		var old: Variant = row[column]
		row[column] = INF
		t.check(preload("res://scripts/shadow_data.gd").validate(store).contains(column),"S7-F4 rejects infinite hand coordinate "+column)
		row[column] = old
	row.Chain_hand_y = null
	t.check(preload("res://scripts/shadow_data.gd").validate(store).contains("Chain_hand_y"),"S7-F4 rejects incomplete hand coordinate pair")
	row.Chain_hand_y = -95.0
	await helper.close(f)

func range_and_width_checks(t: SceneTree) -> void:
	var helper := Helper.new()
	helper.t = t
	var f: Dictionary = helper.fixture()
	var actor: Node2D = f.summons.summon("belion")
	actor.global_position = Vector2.ZERO
	t._spawn(f,Vector2(100,0),100)
	actor.tick(0.0)
	var inside: EnemyActor = t._spawn(f,Vector2(449.99,0),100)
	var edge: EnemyActor = t._spawn(f,Vector2(450,0),100)
	var outside: EnemyActor = t._spawn(f,Vector2(450.01,0),100)
	t.check(actor.config.Search_radius==360.0 and actor.attack.Range==450.0,"S7-F5 Search360 retained while hit Range is450")
	actor.tick(0.4)
	var state: Dictionary = actor.sweep_visual_state()
	var visual = preload("res://scripts/shadow_visual.gd")
	var geometry: Dictionary = visual.belion_chain_geometry(state,12)
	t.check(state.chain_width==24.0 and is_equal_approx(geometry.tip.distance_to(actor.global_position),450.0),"S7-F5 CSV width24 and tip exactly450 from center")
	t.check(geometry.glow_width==18.0 and geometry.edge_width==4.5,"S7-F5 glow and border scale3x with24px blade")
	actor.tick(0.3)
	t.check(inside.hp==88 and edge.hp==88 and outside.hp==100,"S7-F5 production sweep hits449.99 and450 but excludes450.01")
	actor.tick(0.2)
	t.check(inside.hp==88 and edge.hp==88 and outside.hp==100,"S7-F5 expanded boundary still damages once")
	var store: CsvDataStore = f.store
	var row: Dictionary = store.get_row("combat_presentation.csv","Belion_chain_width")
	t.check(row.Value=="24","S7-F5 actual presentation CSV contains width24")
	for invalid in ["0","-1","nan","inf","text",""]:
		row.Value = invalid
		var error: String = preload("res://scripts/shadow_data.gd").validate(store)
		t.check(error.contains("Belion_chain_width") and error.contains("Value"),"S7-F5 invalid width returns data error: "+invalid)
	row.Value = "48"
	t.check(preload("res://scripts/shadow_data.gd").validate(store).is_empty(),"S7-F5 finite positive width configuration validates")
	preload("res://scripts/shadow_afterimage.gd").cache_presentation(store.get_table("combat_presentation.csv"))
	var custom: Dictionary = helper.fixture()
	var wider: Node2D = custom.summons.summon("belion")
	t._spawn(custom,wider.position+Vector2(100,0),100)
	wider.tick(0.0)
	var wider_state: Dictionary = wider.sweep_visual_state()
	var wider_geometry: Dictionary = visual.belion_chain_geometry(wider_state,12)
	t.check(wider_state.chain_width==48.0 and is_equal_approx(wider_geometry.diamonds[0][1].distance_to(wider_geometry.diamonds[0][3]),48.0),"S7-F5 presentation cache feeds CSV width into actor and diamond geometry")
	t.check(wider_geometry.glow_width==36.0 and wider_geometry.edge_width==9.0,"S7-F5 glow and border follow configured width proportionally")
	await helper.close(custom)
	row.Value = "24"
	preload("res://scripts/shadow_afterimage.gd").cache_presentation(store.get_table("combat_presentation.csv"))
	store.tables["combat_presentation.csv"].erase("Belion_chain_width")
	t.check(preload("res://scripts/shadow_data.gd").validate(store).contains("Belion_chain_width"),"S7-F5 missing required width row returns data error")
	store.tables["combat_presentation.csv"]["Belion_chain_width"] = row
	await helper.close(f)
