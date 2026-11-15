extends RefCounted

const Helper = preload("res://tests/belion_sweep_p0.gd")

func damage_trace(t: SceneTree) -> Array:
	var records: Array = []
	for angle in [0.0,0.63,PI,-2.4]:
		for hitch in [false,true]:
			var helper := Helper.new()
			helper.t = t
			var f: Dictionary = helper.fixture()
			var actor: Node2D = f.summons.summon("charger_test")
			actor.global_position = Vector2.ZERO
			var events: Array = []
			var targets: Array = []
			var direction := Vector2.RIGHT.rotated(angle)
			var offsets := [Vector2(100,0),Vector2(160,0),Vector2(220,40),Vector2(220,40.1),Vector2(350,0),Vector2(0,40)]
			for index in range(offsets.size()):
				var enemy: EnemyActor = t._spawn(f,offsets[index].rotated(angle),100)
				targets.append(enemy)
				enemy.damaged.connect(func(_point: Vector2) -> void: events.append([index,snappedf(actor.clock,0.000001),enemy.hp]))
				if index==0: actor.tick(0.0)
			targets[0].position = direction*100+direction.orthogonal()*200
			if hitch:
				for delta in [0.2,0.3,0.3]: actor.tick(delta)
			else:
				for frame in range(16): actor.tick(0.05)
			var hp: Array = []
			for enemy in targets: hp.append(enemy.hp)
			records.append({"angle":angle,"hitch":hitch,"events":events,"hp":hp,"position":[snappedf(actor.position.x,0.000001),snappedf(actor.position.y,0.000001)],"ready_at":snappedf(actor.ready_at,0.000001),"cast":actor.cast_active,"dash":actor.dash_through_active})
			await helper.close(f)
	return records

func run(t: SceneTree) -> void:
	var before: int = t.checks
	var failures: int = t.failures
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/beru_damage_trace.json"))
	var actual := await damage_trace(t)
	t.check(JSON.parse_string(JSON.stringify(actual))==expected,"ART-05 all8 damage/time/position/cooldown traces match6c54e4a")
	await sprite_and_trail(t)
	await landing_without_recovery(t)
	await fallback(t)
	print("ART-05 NEW RESULT: %d checks, %d failures" % [t.checks-before,t.failures-failures])

func sprite_and_trail(t: SceneTree) -> void:
	var helper := Helper.new()
	helper.t = t
	var f: Dictionary = helper.fixture()
	var actor: Node2D = f.summons.summon("charger_test")
	actor.global_position = Vector2.ZERO
	var image: Node2D = actor.sprite_body
	var texture: Texture2D = image.texture
	t.check(texture.get_size()==Vector2(1928,1170) and image.source_rect().size==Vector2(482,390),"ART-05 Beru sheet1928x1170 4x3 cells482x390")
	t.check(texture.get_image().detect_alpha()!=Image.ALPHA_NONE and texture.get_image().has_mipmaps(),"ART-05 transparent sheet with mipmaps")
	var rect: Rect2 = image.display_rect()
	t.check(absf(rect.size.y-180.0)<=1 and is_equal_approx(rect.position.y+376*(rect.size.y/390),8.0),"ART-05 display height180 and baseline376 meets foot8")
	t.check(image.shadow_size==Vector2(52,18) and image.layout=="state3" and image.animation_fps==8 and image.idle_fps==6,"ART-05 ground52x18 state3 animation8 idle6")
	t.check(actor.config.Id=="charger_test" and actor.body_radius==16 and actor.push_weight==3 and actor.config.Move_speed==320 and actor.attack.Dash_speed==600 and actor.attack.Dash_distance==300 and actor.attack.Dash_hit_radius==40,"ART-05 internal identity collision movement and dash values preserved")
	var target: EnemyActor = t._spawn(f,Vector2(100,0),100)
	actor.tick(0.0)
	t.check(actor.dash_through_active and image.frame_row==2 and image.frame_column==1 and not image.flip_h,"ART-05 immediate right dash shows attack2 without windup")
	actor.tick(0.099)
	t.check(image.frame_column==1,"ART-05 leap frame2 holds before0.1 seconds")
	var trails := dash_images(f)
	t.check(trails.size()==3,"ART-05 dash samples at0,0.045,0.09")
	t.check(trails[1].global_position.is_equal_approx(Vector2(27,0)) and trails[2].global_position.is_equal_approx(Vector2(54,0)),"ART-05 trail positions follow fixed600 speed and0.045 interval")
	var pose_ok := true
	for copy: Node2D in trails:
		pose_ok = pose_ok and copy.lifetime==0.3 and copy.opacity==0.45 and copy.sprite_body.frame_row==2 and copy.sprite_body.frame_column==1 and not copy.sprite_body.flip_h and not copy.sprite_body.show_shadow and copy.sprite_body.cell_height==180
	t.check(pose_ok,"ART-05 dash afterimages preserve sampled leap pose flip size lifetime alpha")
	trails[0]._physics_process(0.15)
	t.check(is_equal_approx(trails[0].modulate.a,0.225),"ART-05 existing linear afterimage fade retained")
	target.position = Vector2(-100,100)
	actor.tick(0.001)
	t.check(image.frame_column==2 and not image.flip_h and actor.dash_direction==Vector2.RIGHT,"ART-05 frame3 at0.1 and facing remains locked despite target crossing")
	actor.tick(0.399)
	t.check(image.frame_column==2 and actor.dash_through_active,"ART-05 rest of dash holds attack3")
	actor.tick(0.001)
	t.check(image.frame_column==3 and actor.hit_done and actor.cast_active,"ART-05 dash completion begins landing4 during recovery")
	actor.tick(0.299)
	t.check(image.frame_column==3,"ART-05 landing4 covers0.3 recovery")
	actor.tick(0.001)
	t.check(not actor.cast_active and image.frame_row!=2,"ART-05 recovery end returns to idle or movement without extra delay")
	await helper.close(f)
	f = helper.fixture()
	actor = f.summons.summon("charger_test")
	actor.global_position = Vector2.ZERO
	target = t._spawn(f,Vector2(-100,0),100)
	actor.tick(0.0)
	t.check(actor.sprite_body.flip_h and actor.sprite_body.frame_column==1,"ART-05 left dash starts mirrored leap2")
	target.position = Vector2(100,100)
	actor.tick(0.12)
	t.check(actor.sprite_body.flip_h and actor.sprite_body.frame_column==2,"ART-05 left dash flip remains fixed while target crosses")
	pose_ok = true
	for copy: Node2D in dash_images(f): pose_ok = pose_ok and copy.sprite_body.flip_h
	t.check(pose_ok,"ART-05 left dash trail snapshots preserve flip")
	var departure: Vector2 = actor.global_position
	actor.angle_picker = func() -> float: return 0.0
	actor.teleport()
	var teleports: Array = helper_images(f).filter(func(copy: Node) -> bool: return not copy.has_meta("beru_dash_trail"))
	t.check(teleports.size()==1 and teleports[0].global_position==departure and teleports[0].sprite_body.frame_column==2 and teleports[0].sprite_body.flip_h,"ART-05 teleport departure captures current attack3 and left flip")
	t.check(teleports[0].lifetime==1.0 and teleports[0].opacity==0.45 and not teleports[0].sprite_body.show_shadow,"ART-05 teleport lifetime1 alpha0.45 and no duplicated ground shadow")
	await t.process_frame
	await helper.close(f)

func landing_without_recovery(t: SceneTree) -> void:
	var helper := Helper.new()
	helper.t = t
	var f: Dictionary = helper.fixture()
	var actor: Node2D = f.summons.summon("charger_test")
	actor.global_position = Vector2.ZERO
	# Presentation-only synthetic edge case; production recovery remains0.3.
	actor.motions[0].Motion_sec = 0.0
	t._spawn(f,Vector2(100,0),100)
	actor.tick(0.0)
	actor.tick(0.5)
	t.check(not actor.cast_active and actor.sprite_body.frame_column==3,"ART-05 zero-recovery presentation still starts landing4")
	t.check(actor.snapshot().sprite_pose.frame_column==3,"ART-05 zero-recovery snapshot has no division by zero")
	actor.tick(0.099)
	t.check(actor.sprite_body.frame_column==3,"ART-05 zero-recovery landing holds Attack_after_frame_sec")
	actor.tick(0.001)
	t.check(actor.sprite_body.frame_row!=2,"ART-05 zero-recovery landing ends after0.1 without changing cooldown")
	await helper.close(f)

func fallback(t: SceneTree) -> void:
	var helper := Helper.new()
	helper.t = t
	var f: Dictionary = helper.fixture()
	var row: Dictionary = f.summons.records.charger_test
	for column in ["Sprite_path","Sprite_layout","Sprite_cols","Sprite_rows","Sprite_cell_height","Sprite_baseline","Sprite_foot_y","Anim_fps","Idle_fps","Attack_after_frame_sec"]: row[column] = null
	var actor: Node2D = f.summons.summon("charger_test")
	actor.global_position = Vector2.ZERO
	t._spawn(f,Vector2(100,0),100)
	actor.tick(0.0)
	actor.tick(0.1)
	t.check(actor.sprite_body==null and actor.snapshot().kind=="charger_test" and not actor.snapshot().has("sprite_pose"),"ART-05 image-empty Ber keeps original procedural body and snapshot")
	var copy: Node2D = f.summons.leave_afterimage(actor.global_position,actor.snapshot(),1.0)
	t.check(copy.sprite_body==null and dash_images(f).is_empty(),"ART-05 image-empty fallback retains procedural departure without new sprite trails")
	await t.process_frame
	await helper.close(f)

func helper_images(f: Dictionary) -> Array:
	return f.helper.images(f)

func dash_images(f: Dictionary) -> Array:
	return helper_images(f).filter(func(copy: Node) -> bool: return copy.has_meta("beru_dash_trail"))
