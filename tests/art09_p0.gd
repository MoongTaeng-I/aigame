extends RefCounted

func run(t: SceneTree) -> void:
	var store: CsvDataStore = t._store()
	t.check(store.load_all().is_empty(),"ART-09 pose data loads")
	for entry in [["player.csv","player_01",Vector2(6500,221),Vector2(260,221),110],["shadow.csv","igrit",Vector2(4631,331),Vector2(421,331),165],["enemy.csv","enemy_01",Vector2(2700,230),Vector2(300,230),115]]:
		var view := SpriteBody.new()
		view.configure(store.get_row(entry[0],entry[1]),16,Color.WHITE,Color.WHITE)
		t.check(view.layout=="pose" and view.texture.get_size()==entry[2] and view.source_rect().size==entry[3] and view.texture.get_image().detect_alpha()!=Image.ALPHA_NONE,"ART-09 transparent SD sheet "+entry[1])
		t.check(absf(view.display_rect().size.y-float(entry[4]))<=1 and view.texture.get_image().has_mipmaps() and view.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"ART-09 height mipmaps linear filter "+entry[1])
		view.free()
	var player := SpriteBody.new()
	var legacy: Dictionary = store.get_row("player.csv","player_01").duplicate()
	legacy.Walk_cols = null
	legacy.Walk_back_cols = null
	player.configure(legacy,16,Color.WHITE,Color.WHITE)
	for entry in [[Vector2.UP,true,1],[Vector2(0.2,-1),true,1],[Vector2(-1,-1),true,0],[Vector2.DOWN,true,0],[Vector2.UP,false,0]]:
		player.advance_pose(entry[0],entry[1],0.05)
		t.check(player.frame_row==0 and player.frame_column==entry[2],"ART-09 player front/back pose "+str(entry))
	player.advance_pose(Vector2.LEFT,true,0.025)
	t.check(player.flip_h,"ART-09 player pose horizontal flip")
	player.advance_pose(Vector2(-0.29,sqrt(1-0.29*0.29)),true,0)
	t.check(player.flip_h,"ART-09 pose deadband retains facing")
	var blank: Dictionary = store.get_row("player.csv","player_01").duplicate(true)
	for key in ["Bob_px","Step_hz","Squash","Tilt_deg","Breath"]: blank[key] = null
	var inert := SpriteBody.new()
	inert.configure(blank,16,Color.WHITE,Color.WHITE)
	inert.advance_pose(Vector2.RIGHT,true,0.037)
	inert.advance_shadow_pose(Vector2.ZERO,false,0,true,Vector2.RIGHT)
	t.check(inert.motion_transform==Transform2D.IDENTITY,"ART-09 blank motion fields preserve identity even at attack")
	inert.free()
	player.free()
	var main: Node = load("res://main.tscn").instantiate()
	t.root.add_child(main)
	for node in main.find_children("*","Node",true,false): node.set_physics_process(false)
	var n: Dictionary = main.round_nodes
	var igrit: Node2D = n.shadows.summon("igrit")
	var image: Node2D = igrit.sprite_body
	var origin: Vector2 = igrit.global_position
	var radius: float = igrit.body_radius
	var shadow_size: Vector2 = image.shadow_size
	image.advance_shadow_pose(Vector2.RIGHT,true,1.0/12,false,Vector2.RIGHT)
	igrit.character_view.sync_pose()
	t.check(image.motion_transform!=Transform2D.IDENTITY and igrit.global_position==origin and igrit.body_radius==radius and image.shadow_size==shadow_size and igrit.character_view.global_position==origin+Vector2(0,8) and image.position==Vector2(0,-8),"ART-09 image-only bob squash tilt preserve body ground shadow and y-sort foot")
	var pivot := Vector2(0,image.foot_y)
	image.configure(store.get_row("shadow.csv","igrit"),16,Color.WHITE,Color.WHITE)
	image.advance_shadow_pose(Vector2.ZERO,false,0,true,Vector2.RIGHT)
	t.check((image.motion_transform*pivot).is_equal_approx(pivot+Vector2(4,0)) and image.frame_column==1,"ART-09 attack edge lunges4px about foot pivot")
	image.advance_shadow_pose(Vector2.ZERO,false,0.1,true,Vector2.LEFT)
	t.check((image.motion_transform*pivot).is_equal_approx(pivot) and image.frame_column==1 and image.flip_h,"ART-09 lunge ends at0.1sec without retrigger while cast active")
	var copy: Node2D = n.shadows.leave_afterimage(origin,igrit.snapshot(),1)
	t.check(copy.sprite_body.image_transform()==image.image_transform() and copy.sprite_body.frame_column==image.frame_column and copy.sprite_body.flip_h==image.flip_h and not copy.sprite_body.show_shadow,"ART-09 afterimage freezes pose flip deformation")
	var captured: Transform2D = copy.sprite_body.image_transform()
	image.advance_shadow_pose(Vector2.ZERO,false,0.12,false,Vector2.RIGHT)
	t.check(image.frame_column==0 and copy.sprite_body.image_transform()==captured,"ART-09 cast end restores basic pose; snapshot remains frozen")
	# Production targeting/attack timing still drives the pose through the entire cast.
	n.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":1})
	var enemy: EnemyActor = n.manager.get_living_enemies()[0]
	igrit.position = Vector2.ZERO
	enemy.position = Vector2(100,0)
	igrit.motion_picker = func(_size: int) -> int: return 0
	igrit.tick(0)
	t.check(igrit.cast_active and image.frame_column==10,"ART-15 production cast starts prep attack pose")
	igrit.tick(float(igrit.motions[igrit.motion_index].Hit_time_sec))
	t.check(igrit.cast_active and igrit.hit_done and image.frame_column==1,"ART-09 pose remains attack after original damage moment")
	igrit.tick(0.06)
	t.check(image.frame_column==(1 if igrit.cast_active else 0),"ART-09 production pose follows cast_active")
	var position_before: Vector2 = enemy.position
	var body_before: float = enemy.get_node("CollisionShape2D").shape.radius
	enemy.apply_damage(1)
	t.check(enemy.hit_flash_remaining==0.08 and enemy.sprite_body.material.get_shader_parameter("hit_flash")==1.0 and enemy.position==position_before and enemy.get_node("CollisionShape2D").shape.radius==body_before,"ART-09 enemy white flash starts without physics change")
	enemy.advance_hit_flash(0.079)
	t.check(enemy.sprite_body.material.get_shader_parameter("hit_flash")==1.0,"ART-09 flash remains through0.079sec")
	enemy.advance_hit_flash(0.001)
	t.check(enemy.sprite_body.material==null and enemy.modulate.a==1,"ART-09 white flash ends at0.08sec preserving alpha")
	for id in ["boss_ice_bear","boss_ice_elf","boss_baruka"]:
		var boss: Node2D = n.manager.create_boss(id,[],func() -> Node2D: return n.player)
		n.manager.activate_boss(boss)
		boss.apply_damage(1)
		t.check(boss.character_view.material.get_shader_parameter("hit_flash")==1.0,"ART-09 procedural boss white flash "+id)
		boss.boss_tick(0.1) # FX05 user-approved boss-only flash duration.
		t.check(boss.character_view.material==null,"ART-09 boss flash clock "+id)
	main.queue_free()
	await t.process_frame
	await t.process_frame
