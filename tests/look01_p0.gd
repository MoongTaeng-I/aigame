extends RefCounted

func run(t: SceneTree) -> void:
	var main: Node = load("res://main.tscn").instantiate()
	t.root.add_child(main)
	for node in main.find_children("*","Node",true,false): node.set_physics_process(false)
	var n: Dictionary = main.round_nodes
	var map: Node2D = n.map
	t.check(map.ground.get_size()==Vector2(1254,1254) and map.get_map_rect()==Rect2(-1280,-720,2560,1440) and map.texture_repeat==CanvasItem.TEXTURE_REPEAT_ENABLED,"LOOK-01 ground repeat covers original map rectangle")
	var other: Node2D = load("res://scenes/map.tscn").instantiate()
	t.root.add_child(other)
	t.check(map.prop_layout==other.prop_layout and map.prop_layout.size()>14,"LOOK-01 fixed seed reproduces all forest and inner props")
	var bodies: Node2D = map.get_node("CharacterBodies")
	var count := 0
	var collision_free := true
	for child in bodies.get_children():
		if child.get_script()==preload("res://scripts/environment_prop.gd"):
			count += 1
			collision_free = collision_free and not (child is CollisionObject2D) and child.find_children("*","CollisionShape2D",true,false).is_empty() and map.get_map_rect().has_point(child.position)
	t.check(bodies.y_sort_enabled and count==map.prop_layout.size() and collision_free,"LOOK-01 all props share character y-sort and have no collision")
	var walls := 0
	for child in map.get_children():
		if child is StaticBody2D: walls += 1
	t.check(walls==4 and n.player.body_radius==16,"LOOK-01 original four world boundaries and player radius preserved")
	var weather: CanvasLayer = map.get_node("SnowWeather")
	var before: Vector2 = n.player.position
	weather._process(1)
	t.check(weather.particles.size()==160 and weather.layer==1 and weather.screen.mouse_filter==Control.MOUSE_FILTER_IGNORE and n.player.position==before and weather.find_children("*","CollisionObject2D",true,false).is_empty(),"LOOK-01 weather screen-only and no physics/input changes")
	var hud: Node = map.get_node("TemporaryHud")
	t.check(not hud.debug_visible and not map.debug_visible and not n.player._hp_label.visible and not n.manager._count_label.visible,"LOOK-01 text HUD and debug map hidden by default")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F3
	key.pressed = true
	hud._unhandled_key_input(key)
	t.check(hud.debug_visible and map.debug_visible and n.player._hp_label.visible and n.manager._count_label.visible,"LOOK-01 F3 shows original debug HUD and map")
	key.echo = true
	hud._unhandled_key_input(key)
	t.check(hud.debug_visible,"LOOK-01 F3 echo does not retoggle")
	key.echo = false
	hud._unhandled_key_input(key)
	t.check(not hud.debug_visible and not map.debug_visible,"LOOK-01 F3 toggles off")
	n.player.experience = 3
	hud.refresh()
	t.check(hud.xp_bar.value==n.player.experience and hud.xp_bar.max_value==maxi(1,n.player.get_xp_to_next()) and hud.level_label.text=="Lv %d"%n.player.level and hud.xp_bar.anchor_right==1,"LOOK-01 full-width XP bar and level synchronize")
	n.player.hp = n.player.max_hp/2
	var hp_bar: Node2D = n.player.get_node("FootHpBar")
	hp_bar._process(0)
	t.check(is_equal_approx(hp_bar.ratio,float(n.player.hp)/n.player.max_hp) and hp_bar.position==Vector2(0,n.player.sprite_body.foot_y+12),"LOOK-01 foot HP bar synchronizes without sprite deformation")
	var xp: Node2D = map.get_node("ExperienceManager")
	var orb: Node2D = xp.drop_experience(n.player.position,2)
	var rule: Dictionary = xp._rule
	t.check(orb.radius==float(rule.Orb_radius) and orb.value==2 and orb.advance(0,n.player),"LOOK-01 crystal retains radius value and original contact collection")
	other.queue_free()
	main.queue_free()
	await t.process_frame
	await t.process_frame
