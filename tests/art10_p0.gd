extends RefCounted

func run(t: SceneTree) -> void:
	var store: CsvDataStore = t._store()
	t.check(store.load_all().is_empty(),"ART-10 SD phase2 data loads")
	for entry in [["shadow.csv","charger_test",Vector2(1440,289),144,224,Vector2(48,16)],["shadow.csv","belion",Vector2(1500,315),158,255,Vector2(56,18)],["enemy.csv","enemy_test_ranged",Vector2(394,237),118,75,Vector2(34,12)]]:
		var view := SpriteBody.new()
		var row: Dictionary = store.get_row(entry[0],entry[1])
		view.configure(row,16,Color.WHITE,Color.WHITE)
		t.check(view.layout=="pose" and view.columns==(2 if entry[1]=="enemy_test_ranged" else 3) and view.rows==1 and view.texture.get_size()==entry[2] and view.source_rect().size==entry[2]/Vector2(view.columns,1),"ART-10 two-column sheet "+entry[1])
		t.check(view.texture.get_image().detect_alpha()!=Image.ALPHA_NONE and view.texture.get_image().has_mipmaps() and absf(view.display_rect().size.y-float(entry[3]))<=1 and view.anchor_x==entry[4] and view.shadow_size==entry[5],"ART-10 transparent mipmapped height anchor shadow "+entry[1])
		view.free()
	for file in ["player.csv","enemy.csv","shadow.csv"]:
		for row in store.get_table(file).values():
			if row.get("Sprite_path")!=null: t.check(String(row.Sprite_path).begins_with("res://assets/art/sd/"),"ART-10 no old-sheet runtime reference "+str(row.Id))
	var helper := preload("res://tests/belion_sweep_p0.gd").new()
	helper.t = t
	var f: Dictionary = helper.fixture()
	var actor: Node2D = f.summons.summon("charger_test")
	actor.position = Vector2.ZERO
	var enemy: EnemyActor = t._spawn(f,Vector2(-100,0),100)
	actor.tick(0)
	t.check(actor.dash_through_active and actor.sprite_body.frame_column==1 and actor.sprite_body.flip_h,"ART-10 Beru attack pose starts with left dash")
	enemy.position = Vector2(100,100)
	for delta in [0.499,0.001,0.299]:
		actor.tick(delta)
		t.check(actor.cast_active and actor.sprite_body.frame_row==0 and actor.sprite_body.frame_column==(1 if actor.dash_through_active else 2) and actor.sprite_body.flip_h,"ART-10 Beru pose/flip throughout dash and recovery "+str(delta))
	actor.tick(0.001)
	t.check(not actor.cast_active and actor.sprite_body.frame_column==0,"ART-10 Beru recovery end restores basic pose")
	for copy in f.helper.images(f):
		if copy.has_meta("beru_dash_trail"): t.check(copy.sprite_body.frame_row==0 and copy.sprite_body.frame_column==1 and copy.sprite_body.flip_h,"ART-10 Beru dash snapshot uses pose sheet")
	await helper.close(f)
	f = helper.fixture()
	actor = f.summons.summon("belion")
	actor.position = Vector2.ZERO
	enemy = t._spawn(f,Vector2(100,0),100)
	actor.tick(0)
	t.check(actor.cast_active and actor.sprite_body.frame_column==2 and actor.chain_hand_position()==Vector2(8,-54),"ART-10 Belion windup pose hand foot8 plus8,-62")
	actor.tick(0.4)
	t.check(actor.cast_active and actor.sprite_body.frame_column==1 and actor.sweep_visual_state().hand==actor.chain_hand_position(),"ART-10 Belion sweep pose and chain hand match")
	actor.tick(0.3)
	t.check(not actor.cast_active and actor.sprite_body.frame_column==0,"ART-10 Belion cast end restores basic pose")
	actor.visual_hitstop_remaining = 0 # Isolate the mirror check after FX04's completed hit freeze.
	actor.facing = Vector2.LEFT
	actor.cast_active = true
	actor.update_sprite_visual(Vector2.ZERO,0)
	t.check(actor.sprite_body.flip_h and actor.chain_hand_position()==Vector2(-8,-54),"ART-10 Belion hand mirrors about foot")
	await helper.close(f)
	var main: Node = load("res://main.tscn").instantiate()
	t.root.add_child(main)
	for node in main.find_children("*","Node",true,false): node.set_physics_process(false)
	var n: Dictionary = main.round_nodes
	n.manager._spawn_from_row({"Enemy_id":"enemy_test_ranged","Spawn_count":1})
	enemy = n.manager.get_living_enemies()[0]
	enemy.position = Vector2.ZERO
	n.player.position = Vector2(400,0)
	var clock := 0.0
	for sample in [[1.69,0,0],[1.7,1,0],[1.85,1,0],[2.0,1,1],[2.149,1,1],[2.15,0,1],[3.7,1,1],[4.0,1,2]]:
		n.manager._update_enemy_shot(enemy,float(sample[0])-clock)
		clock = float(sample[0])
		t.check(enemy.sprite_body.frame_row==0 and enemy.sprite_body.frame_column==sample[1] and n.manager._projectiles.size()==sample[2],"ART-10 elf pose/firing boundary "+str(clock))
	for reason in ["range","stealth","fear"]:
		enemy.shot_elapsed = 1.8
		enemy.shot_visual_age = 1
		n.manager._update_enemy_shot(enemy,0)
		t.check(enemy.sprite_body.frame_column==1,"ART-10 elf cancellation setup "+reason)
		if reason=="range": n.player.position = Vector2(401,0)
		elif reason=="stealth": n.player.stealth_remaining = 1
		else: enemy.apply_fear(1)
		n.manager._update_enemy_shot(enemy,0.05)
		t.check(enemy.sprite_body.frame_column==0 and enemy.shot_elapsed==1.8 and n.manager._projectiles.size()==2,"ART-10 elf immediate basic pose no shot/timer change "+reason)
		n.player.position = Vector2(400,0)
		n.player.stealth_remaining = 0
		enemy.fear_remaining = 0
	main.queue_free()
	await t.process_frame
	await t.process_frame
