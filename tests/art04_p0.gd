extends RefCounted

func run(t: SceneTree) -> void:
	var before: int = t.checks
	var failures: int = t.failures
	var main: Node = load("res://main.tscn").instantiate()
	t.root.add_child(main)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var n: Dictionary = main.round_nodes
	var p: Node2D = n.player
	var store = t._store()
	t.check(store.load_all().is_empty(),"ART-04 production CSV loads")
	var igrit: Node2D = n.shadows.summon("igrit")
	var belion: Node2D = n.shadows.summon("belion")
	var texture: Texture2D = belion.sprite_body.texture
	t.check(texture.get_size()==Vector2(1816,1131) and belion.sprite_body.source_rect().size==Vector2(454,377),"ART-04 Belion1816x1131 4x3 cells454x377")
	t.check(texture.get_image().detect_alpha()!=Image.ALPHA_NONE and texture.get_image().has_mipmaps(),"ART-04 Belion transparency and mipmaps retained")
	for entry in [[igrit,211.0,Vector2(56,20)],[belion,195.0,Vector2(60,22)]]:
		var actor: Node2D = entry[0]
		var view: Node2D = actor.sprite_body
		t.check(absf(view.display_rect().size.y-float(entry[1]))<=1.0,"ART-04 approved display height "+actor.config.Id)
		t.check(view.shadow_size==entry[2],"ART-04 ground ellipse dimensions "+actor.config.Id)
		t.check(actor.body_radius==16.0 and actor.push_weight==3.0 and actor.enemy_push_share==0.1 and actor.config.Move_speed==320.0,"ART-04 collision push movement unchanged "+actor.config.Id)
		var copy: Node2D = n.shadows.leave_afterimage(actor.global_position,actor.snapshot(),1.0)
		t.check(copy.sprite_body.display_rect()==view.display_rect() and not copy.sprite_body.show_shadow,"ART-04 teleport afterimage retains new size "+actor.config.Id)
	t.check(p.body_radius==16.0 and p.get_node("CollisionShape2D").shape.radius==16.0 and p.move_speed==250.0,"ART-04 player collision and movement unchanged")
	t.check(p.sprite_body.shadow_size==Vector2(32,12),"ART-04 player ground ellipse32x12")
	var ber_view := preload("res://scripts/sprite_body.gd").new()
	# Optional dimensions also default independently when omitted by fixtures.
	ber_view.configure_snapshot({})
	t.check(ber_view.shadow_size==Vector2(32,12),"ART-04 omitted ground dimensions default32x12")
	ber_view.free()
	var ber: Dictionary = store.get_row("shadow.csv","charger_test")
	t.check(ber.Shadow_w==52.0 and ber.Shadow_h==18.0,"ART-05 Ber ground dimensions52x18")
	var copy := preload("res://scripts/shadow_afterimage.gd").new()
	copy.configure({"sprite_pose":p.sprite_body.pose_snapshot()},1)
	n.map.add_child(copy)
	t.check(copy.sprite_body.cell_height==87 and copy.sprite_body.display_rect()==p.sprite_body.display_rect(),"ART-04 player dash snapshot size preserved")
	n.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":1})
	var enemy: Node2D = n.manager.get_living_enemies().back()
	var boss: Node2D = n.manager.create_boss("boss_ice_bear",[],func() -> Node2D: return p)
	n.manager.activate_boss(boss)
	var bodies: Node2D = n.map.get_node("CharacterBodies")
	t.check(bodies.y_sort_enabled,"ART-04 common artwork root enables native y sorting")
	var actors := [p,igrit,belion,enemy,boss]
	for index in range(actors.size()):
		var actor: Node2D = actors[index]
		actor.global_position = Vector2(index*10,index*20-40)
		actor.character_view.sync_pose()
		var foot_offset := Vector2(0,actor.sprite_body.foot_y) if actor.get("sprite_body")!=null else Vector2.ZERO
		t.check(actor.character_view.get_parent()==bodies and actor.character_view.z_index==0 and actor.character_view.global_position==actor.to_global(foot_offset),"ART-04 production common y-sort placement "+str(index))
	p.global_position.y = 100
	boss.global_position.y = -100
	p.character_view.sync_pose()
	boss.character_view.sync_pose()
	t.check(p.character_view.position.y>boss.character_view.position.y,"ART-04 crossing feet reverses native sort key")
	p.global_position.y = -100
	boss.global_position.y = 100
	p.character_view.sync_pose()
	boss.character_view.sync_pose()
	t.check(p.character_view.position.y<boss.character_view.position.y,"ART-04 crossing back reverses sort key again")
	enemy.global_position.y = -20
	enemy.character_view.sync_pose()
	var enemy_copy_y: float = enemy.character_view.global_position.y
	n.map.position.y = 120
	for actor in actors: actor.character_view.sync_pose()
	t.check(is_equal_approx(enemy.character_view.global_position.y,enemy_copy_y+120),"ART-04 transformed map preserves world feet")
	n.manager._projectile_records["art04"] = {"Id":"art04","Speed":1.0,"Damage":1,"Body_radius":2.0,"Expire_rule":1,"Max_lifetime_sec":10.0,"Max_distance":null}
	# Production shot path preserves its original manager and z placement.
	enemy.projectile_id = "art04"
	enemy.shot_range = 10000
	enemy.shot_interval_sec = 0.1
	n.manager._update_enemy_shot(enemy,1.0)
	t.check(not n.manager._projectiles.is_empty() and n.manager._projectiles.back().get_parent()==n.manager and n.manager._projectiles.back().z_index==0,"ART-04 projectiles retain manager and original z order")
	t.check(belion.get_parent()==n.shadows and belion.sprite_body.get_parent()==belion.character_view and n.shadows.get_index()>bodies.get_index(),"ART-04 chain and range draw after all body artwork")
	belion.cast_active = true
	belion.cast_started_at = belion.clock
	belion.update_sprite_visual(Vector2.ZERO,0)
	t.check(belion.sprite_body.frame_row==2 and belion.sprite_body.frame_column==0,"ART-04 Belion windup frame1")
	belion.clock += 0.45
	belion.update_sprite_visual(Vector2.ZERO,0)
	t.check(belion.sprite_body.frame_column==1,"ART-04 Belion first sweep half frame2")
	belion.clock += 0.15
	belion.update_sprite_visual(Vector2.ZERO,0)
	t.check(belion.sprite_body.frame_column==1,"S7-F4 Belion whole sweep holds frame2")
	belion.cast_active = false
	belion.sprite_hit_at = belion.clock
	belion.update_sprite_visual(Vector2.ZERO,0)
	t.check(belion.sprite_body.frame_column==2,"S7-F4 Belion immediate post sweep frame3")
	# Validate dimensions without weakening any combat-data checks.
	for file in ["player.csv","shadow.csv"]:
		var id := "player_01" if file=="player.csv" else "belion"
		var row: Dictionary = store.get_row(file,id)
		for column in ["Shadow_w","Shadow_h"]:
			var old: Variant = row[column]
			row[column] = -1.0
			var error: String = preload("res://scripts/combat_data.gd").validate(store) if file=="player.csv" else preload("res://scripts/shadow_data.gd").validate(store)
			t.check(error.contains(column),"ART-04 rejects negative "+file+" "+column)
			row[column] = old
	main.queue_free()
	await t.process_frame
	await t.process_frame
	print("ART-04 NEW RESULT: %d checks, %d failures" % [t.checks-before,t.failures-failures])
