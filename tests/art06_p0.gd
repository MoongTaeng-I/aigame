extends RefCounted

func run(t: SceneTree) -> void:
	var before: int = t.checks
	var failed: int = t.failures
	var store: CsvDataStore = t._store()
	t.check(store.load_all().is_empty(),"ART-06 real data loads with new optional columns")
	for entry in [["player.csv","player_01",101.0],["shadow.csv","igrit",155.0],["shadow.csv","belion",255.0],["shadow.csv","charger_test",224.0]]:
		var row: Dictionary = store.get_row(entry[0],entry[1])
		var view := preload("res://scripts/sprite_body.gd").new()
		t.root.add_child(view)
		view.configure(row,16,Color.WHITE,Color.WHITE)
		var rect: Rect2 = view.display_rect()
		var scale: float = rect.size.y/view.source_rect().size.y
		var anchor: float = entry[2]
		for mirrored in [false,true]:
			view.flip_h = mirrored
			var foot: Vector2 = view.image_transform()*(rect.position+Vector2(anchor,float(row.Sprite_baseline))*scale)
			var sample: Vector2 = view.image_transform()*(rect.position+Vector2(anchor+10,float(row.Sprite_baseline))*scale)
			t.check(absf(foot.x)<0.0001 and absf(foot.y-float(row.Sprite_foot_y))<0.0001,"ART-06 anchor projects to body x and foot baseline "+entry[1]+str(mirrored))
			t.check(absf(sample.x-10*scale*(-1 if mirrored else 1))<0.0001,"ART-06 actual draw transform mirrors around anchor "+entry[1]+str(mirrored))
		var snapshot := preload("res://scripts/sprite_body.gd").new()
		snapshot.configure_snapshot(view.pose_snapshot())
		t.check(snapshot.anchor_x==anchor and snapshot.display_rect()==view.display_rect() and snapshot.image_transform()==view.image_transform(),"ART-06 afterimage pose retains anchor and mirror "+entry[1])
		snapshot.free()
		var blank: Dictionary = row.duplicate()
		blank.Sprite_anchor_x = null
		view.configure(blank,16,Color.WHITE,Color.WHITE)
		t.check(is_equal_approx(view.display_rect().position.x,-view.display_rect().size.x*0.5),"ART-06 blank anchor preserves previous cell-center position "+entry[1])
		view.free()
	await enemies(t,store)
	print("ART-06 NEW RESULT: %d checks, %d failures" % [t.checks-before,t.failures-failed])

func enemies(t: SceneTree, store: CsvDataStore) -> void:
	var main: Node = load("res://main.tscn").instantiate()
	t.root.add_child(main)
	for node in main.find_children("*","Node",true,false): node.set_physics_process(false)
	var n: Dictionary = main.round_nodes
	n.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":2})
	var a: EnemyActor = n.manager.get_living_enemies()[0]
	var b: EnemyActor = n.manager.get_living_enemies()[1]
	b.position = Vector2(700,500)
	a.position = Vector2(300,0)
	# Let deferred collision activation enter the space without disabling bodies.
	await t.physics_frame
	await t.physics_frame
	var image: Node2D = a.sprite_body
	t.check(image!=null and image.texture.get_size()==Vector2(2700,230) and image.source_rect().size==Vector2(300,230),"ART-09 bear237x222 single pose")
	t.check(image.texture.get_image().detect_alpha()!=Image.ALPHA_NONE and image.texture.get_image().has_mipmaps(),"ART-06 bear transparency and mipmaps")
	t.check(image.texture==b.sprite_body.texture,"ART-06 bear actors share one cached texture")
	t.check(image.layout=="pose" and image.anchor_x==150 and image.cell_height==115 and image.shadow_size==Vector2(64,20),"ART-10 bear pose dimensions anchor ground64x20")
	t.check(a.enemy_id=="enemy_01" and a.body_radius==16 and a.move_speed==120 and a.contact_damage==5 and a.push_weight==1 and a.max_hp==30,"ART-06 bear preserves identity and physical/combat values")
	a.update_actor(1.0/13,Vector2(400,0),n.map.get_map_rect())
	t.check(image.frame_row==0 and image.frame_column==1 and not image.flip_h,"ART-14 moving bear starts walking cell1")
	a.update_walk_visual(a.global_position+Vector2(-100,0),true,0,false)
	t.check(image.flip_h,"ART-06 player left flips bear")
	a.update_walk_visual(a.global_position+Vector2(0,100),true,0,false)
	t.check(image.flip_h,"ART-06 player vertical preserves previous flip")
	var base := Color.WHITE
	t.check(image.sprite_tint==base and a.modulate==Color.WHITE and image.modulate==Color.WHITE,"ART-06 tint applies to texture only, not actor fade or ground shadow")
	a.apply_fear(1)
	a.update_actor(0.1,Vector2(400,0),n.map.get_map_rect())
	t.check(image.frame_column==0 and image.sprite_tint==base.lerp(preload("res://scripts/skill_ui.gd").FEAR_COLOR,0.5),"ART-06 fear stops at first cell and mixes existing fear color50percent")
	t.check(b.sprite_body.sprite_tint==base,"ART-06 shared texture keeps each actor fear tint independent")
	a.fear_remaining = 0
	image.flip_h = false
	a.start_knockback(a.global_position+Vector2(-10,0),20,0.5)
	a.update_actor(0.1,a.global_position+Vector2(-100,0),n.map.get_map_rect())
	t.check(not image.flip_h,"ART-06 knockback preserves facing even when player crosses")
	n.manager.recycle_enemy(a)
	n.manager._spawn_from_row({"Enemy_id":"enemy_test_ranged","Spawn_count":1})
	var reused: EnemyActor = n.manager.get_living_enemies().back()
	t.check(reused==a and reused.sprite_body.visible and reused.enemy_id=="enemy_test_ranged" and reused.sprite_body.layout=="pose" and reused.sprite_body.cell_height==118,"ART-10 pooled bear resets to elf pose row")
	reused.character_view.sync_pose()
	t.check(reused.character_view.global_position==reused.global_position+Vector2(0,8),"ART-08 pooled elf uses configured sprite foot offset")
	n.manager.recycle_enemy(reused)
	n.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":1})
	reused = n.manager.get_living_enemies().back()
	t.check(reused==a and reused.sprite_body.visible and reused.sprite_body.texture==b.sprite_body.texture and not reused.sprite_body.flip_h and reused.sprite_body.frame_column==0 and reused.fear_remaining==0 and reused.sprite_body.sprite_tint==base,"ART-06 pooled bear reactivation resets texture parameters animation flip fear tint")
	reused.apply_damage(reused.hp)
	reused.update_actor(0.2,Vector2.ZERO,n.map.get_map_rect())
	reused.character_view.sync_pose()
	t.check(reused.is_logically_dead and reused.collision_layer==0 and is_equal_approx(reused.modulate.a,0.5) and is_equal_approx(reused.character_view.modulate.a,0.5) and reused.sprite_body.modulate.a==1,"ART-06 original death fade and collision removal remain effective")
	for id in ["boss_ice_bear","boss_ice_elf","boss_baruka"]:
		var boss: EnemyActor = n.manager.create_boss(id,[],func() -> Node2D: return n.player)
		t.check(boss.sprite_body!=null and not boss.sprite_body.using_fallback,"ART-12 configured boss pose replaces procedural body "+id)
	var row: Dictionary = store.get_row("enemy.csv","enemy_01")
	row.Sprite_tint = "bad-color"
	t.check(preload("res://scripts/combat_data.gd").validate(store).contains("Sprite_tint"),"ART-06 malformed image tint rejected")
	row.Sprite_tint = "#d0d8f0"
	row.Sprite_anchor_x = -1
	t.check(preload("res://scripts/combat_data.gd").validate(store).contains("Sprite_anchor_x"),"ART-06 invalid enemy anchor rejected")
	row.Sprite_anchor_x = 150
	main.queue_free()
	await t.process_frame
	await t.process_frame
