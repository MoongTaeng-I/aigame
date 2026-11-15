extends RefCounted

func run(t: SceneTree) -> void:
	var store: CsvDataStore = t._store()
	t.check(store.load_all().is_empty(),"ART-11 actual data loads")
	var row: Dictionary = store.get_row("player.csv","player_01")
	var view := SpriteBody.new()
	view.configure(row,16,Color.WHITE,Color.WHITE)
	t.check(view.texture.get_size()==Vector2(4641,221) and view.columns==21 and view.rows==1 and view.source_rect().size==Vector2(221,221) and view.cell_height==110 and view.baseline==202 and view.anchor_x==101,"ART-13 player21 columns retains original five poses")
	t.check(view.texture.get_image().detect_alpha()!=Image.ALPHA_NONE and view.texture.get_image().has_mipmaps(),"ART-11 player alpha and mipmaps")
	var dragon: Texture2D = load("res://assets/art/fx/fx_dragon_head.png")
	t.check(dragon.get_size()==Vector2(496,640) and dragon.get_image().detect_alpha()!=Image.ALPHA_NONE and dragon.get_image().has_mipmaps(),"ART-11 dragon496x640 alpha mipmaps")
	var settings: Dictionary = preload("res://scripts/shadow_afterimage.gd").presentation()
	var legacy: Dictionary = row.duplicate()
	legacy.Walk_cols = null
	legacy.Walk_back_cols = null
	view.configure(legacy,16,Color.WHITE,Color.WHITE)
	for item in [[true,true,true,4],[false,true,true,2],[false,false,true,3],[false,false,false,1]]:
		view.advance_player_skill_pose(Vector2.UP,true,0.02,item[0],item[1],item[2],Vector2.LEFT,settings)
		t.check(view.frame_column==item[3],"ART-11 fear dash slash normal priority "+str(item))
	view.advance_player_skill_pose(Vector2.RIGHT,true,0.02,false,true,true,Vector2.LEFT,settings)
	t.check(view.flip_h and view.frame_column==2,"ART-11 dash facing remains left despite current movement")
	var pivot := Vector2(0,view.foot_y)
	view.advance_player_skill_pose(Vector2.RIGHT,true,0,false,false,true,Vector2.RIGHT,settings)
	t.check((view.motion_transform*pivot).is_equal_approx(pivot),"ART-11 slash sway has no walking bob")
	view.trigger_basic_step(Vector2.RIGHT,2,0.1)
	t.check((view.step_transform()*pivot).is_equal_approx(pivot+Vector2(2,0)),"ART-11 basic step2px image only")
	var ghost := SpriteBody.new()
	ghost.configure_snapshot(view.pose_snapshot())
	t.check(ghost.image_transform()==view.image_transform() and ghost.frame_column==3,"ART-11 snapshots preserve skill pose and complete deformation")
	ghost.free()
	view.free()
	var main: Node = load("res://main.tscn").instantiate()
	t.root.add_child(main)
	for node in main.find_children("*","Node",true,false): node.set_physics_process(false)
	var n: Dictionary = main.round_nodes
	n.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":1})
	var enemy: EnemyActor = n.manager.get_living_enemies()[0]
	enemy.position = n.player.position+Vector2(50,0)
	var origin: Vector2 = n.player.position
	n.player.update_basic_attack(0,[enemy])
	var slashes: Array = n.map.get_children().filter(func(node: Node) -> bool: return node.get_script()==preload("res://scripts/basic_slash_fx.gd"))
	t.check(slashes.size()==1 and n.player.position==origin,"ART-11 basic effect/step preserve physical position")
	var fx: Node2D = slashes[0]
	var inside := true
	for point in fx.crescent_points(): inside = inside and preload("res://scripts/combat_geometry.gd").in_triangle(point,fx.base,fx.facing,fx.length,fx.width)
	for thickness in [1.5,5.0]:
		inside = inside and Geometry2D.triangulate_polygon(fx.crescent_ribbon(thickness)).size()>0
		for point in fx.crescent_ribbon(thickness): inside = inside and preload("res://scripts/combat_geometry.gd").in_triangle(point,fx.base,fx.facing,fx.length,fx.width)
	t.check(inside and fx.color==Color.TRANSPARENT,"ART-11 crescent path stays within original triangle and base polygon hidden")
	t.check(not fx.debug_enabled(),"ART-11 triangle hidden by default")
	n.map.get_node("TemporaryHud").toggle_debug()
	t.check(fx.debug_enabled(),"ART-11 F3 enables exact triangle debug")
	var screen: CanvasLayer = n.skills.screen_fx
	var screen_before: Rect2 = n.manager._get_screen_world_rect()
	var camera: Camera2D = n.player.get_node("Camera2D")
	var camera_offset := camera.offset
	screen.kick(5,0.15)
	screen._process(0.01)
	t.check(screen.shake_offset!=Vector2.ZERO and camera.offset==camera_offset and n.manager._get_screen_world_rect()==screen_before and n.player.position==origin,"ART-11 screen shake changes no camera/target/spawn/physics coordinates")
	screen.settings.Shake_enabled = "0"
	screen._process(0)
	t.check(screen.shake_offset==Vector2.ZERO,"ART-11 Shake_enabled0 disables shake immediately")
	screen.settings.Shake_enabled = "1"
	n.skills._fear_start({"Range":123.0,"Duration_sec":1.0,"Cast_sec":0.5},n.skills.clock)
	var waves: Array = n.map.get_children().filter(func(node: Node) -> bool: return node.get_script()==preload("res://scripts/dragon_fear_fx.gd"))
	t.check(waves.size()==1 and waves[0].radius==123 and waves[0].wave_radius(0.25)==61.5 and waves[0].wave_radius(0.5)==123,"ART-11 shockwave max radius is immutable cast Range")
	var heads: Array = n.player.character_view.get_children().filter(func(node: Node) -> bool: return node.get_script()==preload("res://scripts/dragon_fear_fx.gd"))
	t.check(heads.size()==1 and heads[0].head_only and heads[0].get_index()<n.player.sprite_body.get_index(),"ART-11 dragon draws before player body")
	n.player.stealth_remaining = 1
	n.skills.ui._process(0)
	t.check(is_equal_approx(n.player.modulate.a,0.45),"ART-11 stealth alpha0.45")
	main.queue_free()
	await t.process_frame
	await t.process_frame
