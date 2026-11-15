extends RefCounted

func run(t: SceneTree) -> void:
	var store: CsvDataStore = t._store()
	t.check(store.load_all().is_empty(),"ART-08 data loads")
	var row: Dictionary = store.get_row("enemy.csv","enemy_test_ranged")
	t.check(row.Name_ko=="아이스 엘프" and row.Note=="정식 원거리 적(ART-08)" and row.Id=="enemy_test_ranged","ART-08 formal elf name and stable ID")
	var main: Node = load("res://main.tscn").instantiate()
	t.root.add_child(main)
	for node in main.find_children("*","Node",true,false): node.set_physics_process(false)
	var n: Dictionary = main.round_nodes
	n.manager._spawn_from_row({"Enemy_id":"enemy_test_ranged","Spawn_count":1})
	var enemy: EnemyActor = n.manager.get_living_enemies()[0]
	enemy.position = Vector2.ZERO
	n.player.position = Vector2(400,0)
	var image: Node2D = enemy.sprite_body
	t.check(image.texture.get_size()==Vector2(1604,872) and image.source_rect().size==Vector2(401,436) and image.texture.get_image().detect_alpha()!=Image.ALPHA_NONE,"ART-08 transparent1604x872 cells401x436")
	t.check(absf(image.display_rect().size.y-97)<=1 and image.anchor_x==144 and image.baseline==424 and image.foot_y==8 and image.shadow_size==Vector2(36,13),"ART-08 height97 anchor baseline ground ellipse")
	t.check(enemy.body_radius==16 and enemy.move_speed==100 and enemy.contact_damage==5 and enemy.shot_range==400 and enemy.shot_interval_sec==2 and enemy.projectile_id=="proj_test_01","ART-08 ranged combat fields unchanged")
	for i in range(5):
		enemy.update_walk_visual(n.player.position,true,0.001 if i==0 else 0.125,false)
		t.check(image.frame_row==0 and image.frame_column==i%4,"ART-08 walk8fps "+str(i))
	var clock := 0.0
	for sample in [[1.69,0,-1,0],[1.7,1,0,0],[1.71,1,0,0],[1.85,1,1,0],[1.86,1,1,0],[2.0,1,2,1],[2.099,1,2,1],[2.1,1,3,1],[2.101,1,3,1],[2.2,0,-1,1],[2.201,0,-1,1],[3.71,1,0,1],[3.86,1,1,1],[4.0,1,2,2]]:
		n.manager._update_enemy_shot(enemy,float(sample[0])-clock)
		clock = float(sample[0])
		t.check(image.frame_row==sample[1] and (sample[2]==-1 or image.frame_column==sample[2]),"ART-08 aim/release cell time "+str(clock))
		t.check(n.manager._projectiles.size()==sample[3],"ART-08 unchanged actual firing at2sec intervals "+str(clock))
	var projectile: CombatProjectile = n.manager._projectiles[0]
	var record: Dictionary = store.get_row("projectile.csv","proj_test_01")
	t.check(projectile.global_position==enemy.global_position and projectile.direction==Vector2.RIGHT and projectile.speed==float(record.Speed) and projectile.damage==int(record.Damage) and projectile.body_radius==float(record.Body_radius) and projectile.expire_rule==int(record.Expire_rule) and projectile.max_distance==float(record.Max_distance),"ART-08 launch position direction projectile configuration unchanged")
	for reason in ["range","stealth","fear"]:
		# Cancel an actual just-fired release pose as well as a new aiming pose.
		for age in [0.0,1.0]:
			enemy.shot_elapsed = 1.8
			enemy.shot_visual_age = age
			n.manager._update_enemy_shot(enemy,0)
			t.check(image.frame_row==1,"ART-08 cancellation setup "+reason+str(age))
			if reason=="range": n.player.position = Vector2(401,0)
			elif reason=="stealth": n.player.stealth_remaining = 1
			else: enemy.apply_fear(1)
			enemy.update_walk_visual(n.player.position,true,0.02,false)
			n.manager._update_enemy_shot(enemy,0.02)
			t.check(image.frame_row==0 and (reason!="fear" or image.frame_column==0) and enemy.shot_elapsed==1.8 and n.manager._projectiles.size()==2,"ART-08 immediate walking cancellation without firing/timer advance "+reason+str(age))
			n.player.position = Vector2(400,0)
			n.player.stealth_remaining = 0
			enemy.fear_remaining = 0
	for x in [-0.29,-0.31,0.29,0.31]:
		n.player.position = Vector2(x,sqrt(1-x*x))*300
		enemy.update_walk_visual(n.player.position,true,0,false)
		n.manager._update_enemy_shot(enemy,0)
		t.check(image.flip_h==(x<0 and absf(x)>0.3 or x>0 and absf(x)<0.3),"ART-08 elf deadband "+str(x))
	main.queue_free()
	await t.process_frame
	await t.process_frame
