extends RefCounted

func stop_physics(main: Node) -> void:
	for child in main.find_children("*","Node",true,false): child.set_physics_process(false)

func run(t: SceneTree) -> void:
	var store: CsvDataStore = t._store()
	t.check(store.load_all().is_empty(),"ART14 data loads")
	for item in [["enemy.csv","enemy_01",1,8,10.0],["shadow.csv","igrit",2,9,14.0]]:
		var image := SpriteBody.new()
		image.configure(store.get_row(item[0],item[1]),16,Color.WHITE,Color.WHITE)
		var correct := true
		for i in range(17):
			if item[0]=="enemy.csv": image.advance_walk_pose(Vector2.RIGHT,true,0 if i==0 else 1.0/item[4])
			else: image.advance_shadow_pose(Vector2.RIGHT,true,0 if i==0 else 1.0/item[4],false,Vector2.RIGHT)
			correct = correct and image.frame_column==int(item[2])+i%8
		t.check(correct,"ART14 eight walking frames twice "+item[1])
		image.advance_shadow_pose(Vector2.ZERO,false,0,item[0]=="shadow.csv",Vector2.LEFT)
		t.check(image.frame_column==(1 if item[0]=="shadow.csv" else 0),"ART14 attack/idle overrides walk "+item[1])
		image.advance_shadow_pose(Vector2.ZERO,false,0,false,Vector2.RIGHT)
		t.check(image.frame_column==0,"ART14 stationary frame0 "+item[1])
		if item[0]=="enemy.csv": t.check(is_equal_approx(image.display_rect().size.y/image.source_rect().size.y,111.0/222.0),"ART14 bear keeps previous half-size pixel scale (115/230)")
		image.free()
	await death(t)
	await basic(t)

func death(t: SceneTree) -> void:
	var flow := preload("res://scripts/game_flow.gd").new()
	t.root.add_child(flow)
	var until := Time.get_ticks_msec()+8000
	while flow.state=="loading" and Time.get_ticks_msec()<until: await t.process_frame
	flow.start_region()
	stop_physics(flow.session)
	var n: Dictionary = flow.session.round_nodes
	n.manager._elapsed_seconds = 37.5
	flow.session.kills = 3
	var level: int = n.player.level
	var signals_seen := {"died":0,"ended":0}
	n.player.died.connect(func() -> void: signals_seen.died+=1)
	flow.session.round_ended.connect(func(_value: Dictionary) -> void: signals_seen.ended+=1)
	var position: Vector2 = n.player.global_position
	var flip: bool = n.player.sprite_body.flip_h
	n.player.record_damage_source(position+Vector2.LEFT*30)
	n.player.apply_damage(n.player.hp)
	var death: Node = n.player.death_presentation
	death.set_process(false)
	t.check(n.player.is_dead and t.paused and signals_seen.died==1 and flow.session.round_finished and flow.state=="playing" and signals_seen.ended==0,"ART14 death frame freezes world and defers result")
	t.check(flow.session.round_result.seconds==37.5 and flow.session.round_result.level==level and flow.session.round_result.kills==3,"ART14 summary fixed at HP0")
	t.check(n.player.sprite_body.frame_column==21 and death.artwork.flip_h==flip and n.player.sprite_body.show_shadow and not death.artwork.show_shadow,"ART14 stagger21 facing and original ground shadow")
	death.advance(0.299)
	t.check(n.player.sprite_body.frame_column==21 and flow.state=="playing","ART14 no result before stagger boundary")
	death.advance(0.001)
	t.check(n.player.sprite_body.frame_column==22 and death.artwork.motion_transform.y.length()<1,"ART14 drop22 begins .3 with squash")
	death.advance(0.12)
	t.check(is_equal_approx(death.artwork.motion_transform.y.length(),1) and is_zero_approx(death.overlay.color.a),"ART14 drop ends .42 before dim")
	death.advance(0.779)
	flow.toggle_pause()
	n.player.add_experience(9999)
	t.check(flow.state=="playing" and t.paused and n.player.level==level and signals_seen.ended==0,"ART14 no result before1.2 and ESC cannot unpause dead world")
	death.advance(0.001)
	t.check(flow.state=="result" and signals_seen.ended==1 and flow.result.seconds==37.5 and flow.result.kills==3,"ART14 result once at1.2 with frozen values")
	death.advance(10)
	t.check(signals_seen.ended==1 and is_equal_approx(death.overlay.color.a,0.45) and is_zero_approx(float(death.artwork.material.get_shader_parameter("hit_flash"))),"ART14 final dim/flash and no duplicate result")
	var pivot := Vector2(0,death.artwork.foot_y)
	t.check((death.artwork.motion_transform*pivot).is_equal_approx(pivot+Vector2(7,0)) and n.player.global_position==position,"ART14 visual knock opposite attacker7px without body movement")
	flow.start_region()
	stop_physics(flow.session)
	var fresh: Node = flow.session.round_nodes.player
	t.check(fresh.death_presentation==null and fresh.sprite_body.show_image and not fresh.is_dead and not t.paused,"ART14 retry clears death picture and overlay state")
	fresh.presentation = fresh.presentation.duplicate()
	fresh.presentation.Death_present_sec = 0
	fresh.apply_damage(fresh.hp)
	t.check(flow.state=="result" and fresh.death_presentation_complete,"ART14 zero duration gives immediate result")
	flow.free()
	t.paused = false
	var main: Node = load("res://main.tscn").instantiate()
	t.root.add_child(main)
	stop_physics(main)
	var player: Node = main.round_nodes.player
	player.apply_damage(player.hp)
	var elapsed: float = player.death_presentation.elapsed
	await t.process_frame
	await t.process_frame
	t.check(t.paused and player.death_presentation.elapsed>elapsed and player._death_label==null,"ART14 death animation advances while paused; standalone label delayed")
	player.death_presentation.advance(2)
	t.check(player._death_label!=null and player._death_label.text=="사망","ART14 standalone death label after presentation")
	main.free()
	t.paused = false

func basic(t: SceneTree) -> void:
	var main: Node = load("res://main.tscn").instantiate()
	t.root.add_child(main)
	stop_physics(main)
	var n: Dictionary = main.round_nodes
	n.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":1})
	var enemy: Node2D = n.manager.get_living_enemies()[0]
	enemy.global_position = n.player.global_position+Vector2(60,0)
	enemy.hp = 1000
	var damage: int = n.player._attack_data.Damage
	n.player.update_basic_attack(0,[enemy])
	t.check(n.player.sprite_body.frame_column==23 and enemy.hp==1000-damage,"ART14 first basic hit pose3 and unchanged damage")
	Input.action_press("move_right")
	n.player._physics_process(0.05)
	t.check(n.player.sprite_body.frame_column==23 and n.player.sprite_body._pose_walk_elapsed>0,"ART14 basic pose spans hit gap while walk time advances")
	n.player.update_basic_attack(0.15,[enemy])
	t.check(n.player.sprite_body.frame_column==24 and enemy.hp==1000-2*damage,"ART14 second basic hit pose3 and unchanged .15 hit time")
	n.player._physics_process(0.079)
	t.check(n.player.sprite_body.frame_column==24,"ART14 pose holds until .08 after last hit")
	n.player._physics_process(0.002)
	var image: SpriteBody = n.player.sprite_body
	t.check(image.frame_column==5+floori((image._pose_walk_elapsed+0.000000001)*12)%8,"ART14 basic end resumes continuous walking frame")
	n.player.basic_pose_remaining = 1
	n.player.basic_pose_direction = Vector2.LEFT
	n.player.fear_cast_remaining = 0.2
	n.player._physics_process(0.01)
	t.check(image.frame_column==4,"ART14 fear overrides basic")
	n.player.fear_cast_remaining = 0
	n.player.dash_remaining = 0.2
	n.player.dash_speed = 0
	n.player._physics_process(0.01)
	t.check(image.frame_column==2,"ART14 dash overrides basic")
	n.player.dash_remaining = 0
	n.skills.skills.skill_rapid_slash.active = true
	n.player._physics_process(0.01)
	t.check(image.frame_column==3 and not image.flip_h,"ART14 slash controls pose/facing instead of basic left-facing override")
	n.skills.skills.skill_rapid_slash.active = false
	n.player.presentation = n.player.presentation.duplicate()
	n.player.presentation.Basic_pose_enabled = 0
	n.player._physics_process(0.01)
	t.check(image.frame_column>=5 and image.frame_column<=12,"ART14 disabled basic pose leaves walking unchanged")
	Input.action_release("move_right")
	main.free()
	await t.process_frame
