extends RefCounted
const Fear = preload("res://scripts/dragon_fear_fx.gd")
const Dust = preload("res://scripts/motion_dust.gd")
const Geometry = preload("res://scripts/combat_geometry.gd")
const DT := 1.0/60.0

func run(t: SceneTree) -> void:
	await fear(t)
	await motion(t)
	await dust(t)
	await attack(t)
	await choice(t)
	await flow(t)

func fx02() -> RefCounted: return preload("res://tests/fx02_p0.gd").new()

func waves_in(n: Dictionary) -> Array:
	return n.map.get_children().filter(func(node: Node) -> bool: return node.get_script()==Fear)

func fear(t: SceneTree) -> void:
	var f := fx02()
	var n: Dictionary = f.fixture(t)
	var cast = n.skills.skills.skill_dragon_fear
	cast.level = 1
	var stats: Dictionary = cast.levels[0]
	var inside: EnemyActor = f.enemy(n,n.player.global_position+Vector2(float(stats.Range)-1,0))
	var outside: EnemyActor = f.enemy(n,n.player.global_position+Vector2(float(stats.Range)+1,0))
	var combat_rng: int = n.manager._random.state
	cast.start(0)
	var wave: Node2D = waves_in(n)[0]
	t.check(inside.is_feared() and not outside.is_feared() and is_equal_approx(inside.fear_remaining,float(stats.Duration_sec)) and wave.radius==float(stats.Range) and is_equal_approx(n.player.fear_cast_remaining,float(stats.Cast_sec)) and n.manager._random.state==combat_rng,"FX06 fear Range duration targets cast lock and combat RNG unchanged")
	t.check(wave.waves.size()==3 and wave.claws.size()==8 and wave.bats.size()==20 and wave.embers.size()==40,"FX06 fear three rings eight scratches twenty bats forty embers")
	t.check(Color(wave.waves[0].color).is_equal_approx(Color("#ff2a3c")) and Color(wave.waves[2].color).is_equal_approx(Color("#7a0010")) and is_equal_approx(wave.y_scale,0.62) and wave.wave_radius(float(stats.Cast_sec),float(wave.waves[2].delay))>=0 and wave.wave_max>=900,"FX06 ring colors outer to inner, ground squash .62, last ring reaches offscreen 900")
	var additive: CanvasItemMaterial = Fear.additive_material()
	t.check(wave.glow.material==additive and additive.blend_mode==CanvasItemMaterial.BLEND_MODE_ADD and wave.material==null,"FX06 fear glow uses the shared additive material")
	var bodies: Node = n.map.get_node("CharacterBodies")
	t.check(is_instance_valid(wave.ground) and wave.ground.get_parent()==n.map and wave.ground.get_index()<bodies.get_index() and wave.ground.global_position==wave.global_position and is_equal_approx(wave.disk_color.a,0.45) and is_equal_approx(wave.disk_sec,float(stats.Cast_sec)+0.6),"FX06 actual range disk below actors fading over Cast_sec+.6")
	t.check(wave.scratch_width<=4 and is_equal_approx(wave.scratch_sec,0.15) and is_equal_approx(wave.ember_sec,0.8),"FX06 scratches width<=4 for .15s, embers .8s")
	n.skills._fear_start(stats,n.skills.clock)
	var both: Array = waves_in(n)
	var materials := {}
	for item in both: materials[item.glow.material.get_instance_id()] = true
	t.check(both.size()==2 and materials.size()==1,"FX06 repeated fear reuses one additive material")
	wave._process(0.16)
	t.check(wave.claws.is_empty() and wave.embers.size()==40 and wave.waves.size()==3,"FX06 scratches end at .15 while rings and embers continue")
	var ground: Node2D = wave.ground
	wave._process(wave.lifetime())
	await t.process_frame
	t.check(not is_instance_valid(wave) and not is_instance_valid(ground),"FX06 fear wave and ground disk freed after lifetime")
	await f.cleanup(t,n)

func walk(n: Dictionary, action: String, frames: int) -> void:
	for name in ["move_right","move_left","move_up","move_down"]: Input.action_release(name)
	if not action.is_empty(): Input.action_press(action)
	for i in range(frames): n.player._physics_process(DT)

func motion(t: SceneTree) -> void:
	var f := fx02()
	var n: Dictionary = f.fixture(t)
	var player: Node2D = n.player
	var sprite: SpriteBody = player.sprite_body
	var shape: CollisionShape2D = player.get_node("CollisionShape2D")
	var radius: float = (shape.shape as CircleShape2D).radius
	var origin: Vector2 = player.global_position
	walk(n,"move_right",1)
	t.check(player.global_position.is_equal_approx(origin+Vector2(player.move_speed*DT,0)) and sprite._start_left>0 and sprite.locomotion_transform.x.x>1 and sprite.locomotion_transform.y.y<1,"FX06 start squash is image-only; one frame moves exactly Move_speed")
	walk(n,"move_right",11)
	t.check(player.global_position.is_equal_approx(origin+Vector2(player.move_speed*DT*12,0)) and is_equal_approx(sprite._lean,deg_to_rad(6)) and sprite._start_left==0,"FX06 lean reaches6deg by .12s with unchanged travel")
	walk(n,"move_left",1)
	t.check(sprite.flip_h and sprite._turn_left>0 and sprite.locomotion_transform.get_scale().x<1,"FX06 left-right turn narrows image")
	walk(n,"",1)
	t.check(sprite._stop_left>0 and sprite.locomotion_transform.get_scale().y>1,"FX06 stop stretches image")
	walk(n,"",8)
	t.check(sprite._stop_left==0 and is_equal_approx(sprite._lean,0) and sprite.locomotion_transform.is_equal_approx(Transform2D.IDENTITY),"FX06 locomotion returns to identity at rest")
	player.character_view.sync_pose()
	t.check(shape.position==Vector2.ZERO and (shape.shape as CircleShape2D).radius==radius and player.character_view.global_position==player.to_global(Vector2(0,sprite.foot_y)),"FX06 collision and y-sort foot untouched by image motion")
	walk(n,"",0)
	await f.cleanup(t,n)

func dust(t: SceneTree) -> void:
	var f := fx02()
	var n: Dictionary = f.fixture(t)
	var sprite: SpriteBody = n.player.sprite_body
	var pool: Node2D = Dust.find(n.player)
	t.check(pool!=null and pool.active==0 and not pool.is_processing() and sprite.dust_every==1,"FX06 one idle dust pool per round without processing")
	for pair in [["move_right",[5,9]],["move_up",[13,17]]]:
		var exact := true
		var emitted := 0
		var previous := -1
		for name in ["move_right","move_left","move_up","move_down"]: Input.action_release(name)
		Input.action_press(pair[0])
		for i in range(90):
			var before: int = pool.active
			n.player._physics_process(DT)
			var column: int = sprite.frame_column
			var contact: bool = column!=previous and column in pair[1]
			exact = exact and (pool.active-before==(3 if contact else 0))
			if contact: emitted += 1
			previous = column
			pool._process(1)
		t.check(exact and emitted>=4,"FX06 player dust only on foot contact columns "+str(pair[1]))
	for name in ["move_right","move_left","move_up","move_down"]: Input.action_release(name)
	var foe: EnemyActor = f.enemy(n,n.player.global_position+Vector2(400,0))
	var image: SpriteBody = foe.sprite_body
	var contacts := 0
	var bursts := 0
	var last := -1
	for i in range(120):
		var before: int = pool.active
		foe.update_walk_visual(n.player.global_position,true,DT,false)
		if image.frame_column!=last and image.frame_column in [1,5]: contacts += 1
		last = image.frame_column
		if pool.active>before: bursts += 1
		pool._process(1)
	t.check(image.dust_every==2 and contacts>=4 and bursts==floori(contacts/2.0),"FX06 enemy dust at every second foot contact")
	t.check(pool.active==0 and not pool.is_processing(),"FX06 dust pool stops processing when empty")
	await f.cleanup(t,n)

func attack(t: SceneTree) -> void:
	var f := fx02()
	var n: Dictionary = f.fixture(t)
	var player: Node2D = n.player
	var sprite: SpriteBody = player.sprite_body
	var foe: EnemyActor = f.enemy(n,player.global_position+Vector2(60,0))
	foe.hp = 1000
	var gap: float = float(player._attack_data.Hit_gap_sec)
	var damage: int = int(player._attack_data.Damage)
	player.update_basic_attack(0,[foe])
	var effect: Node2D = player.current_basic_fx
	var judged := Geometry.triangle_points(player.global_position+Vector2.RIGHT*player.body_radius,Vector2.RIGHT,float(player._attack_data.Range),float(player._attack_data.Range)*0.381)
	t.check(foe.hp==1000-damage and player._next_hit_at==gap and player._remaining_hits==1 and effect.polygon==judged,"FX06 first strike judgment and schedule unchanged")
	t.check(effect.base.is_equal_approx(player.global_position+Vector2(18,sprite.foot_y-40)),"FX06 slash trail starts at hand (+18,-40 from foot)")
	t.check(foe.sprite_body.hit_squash_left>0 and foe.sprite_body.locomotion_transform.get_scale().is_equal_approx(Vector2(1.1,0.9)),"FX06 struck enemy image squashes 1.1x.9")
	var screen: CanvasLayer = n.skills.screen_fx
	t.check(screen.shake_offset.is_equal_approx(Vector2(-1,0)) and is_equal_approx(screen.push_duration,0.05),"FX06 strike pushes picture 1px toward attack for .05s")
	foe.sprite_body.advance_pose_motion(false,0.081)
	t.check(foe.sprite_body.locomotion_transform.is_equal_approx(Transform2D.IDENTITY),"FX06 enemy squash recovers after .08s")
	foe.knockback_elapsed = foe.knockback_duration
	player.update_basic_attack(gap-0.02,[foe])
	t.check(sprite.windup_offset.is_equal_approx(Vector2(-1,0)) and player._next_hit_at==gap and player._remaining_hits==1 and foe.hp==1000-damage,"FX06 windup pulls image back before strike without moving the schedule")
	player.update_basic_attack(gap,[foe])
	t.check(sprite.windup_offset==Vector2.ZERO and foe.hp==1000-2*damage and player._remaining_hits==0,"FX06 strike clears windup and lands the same hit")
	screen.settings = screen.settings.duplicate()
	screen.settings.Shake_enabled = "0"
	screen.push_remaining = 0
	screen._process(0)
	screen.push(Vector2.RIGHT,1,0.05)
	t.check(screen.shake_offset==Vector2.ZERO and screen.push_remaining==0,"FX06 Shake_enabled0 skips strike push")
	await f.cleanup(t,n)

func choice(t: SceneTree) -> void:
	var f := fx02()
	var n: Dictionary = f.fixture(t)
	var audio: Node = t.root.get_node("GameAudio")
	var level_before := int(audio.request_counts.get("level_up",0))
	n.player.add_experience(n.player.get_xp_to_next())
	t.check(n.choices.active and int(audio.request_counts.get("level_up",0))==level_before,"FX06 choice window opens without its appearance sound")
	var ui: Control = n.choices.ui
	var window := Rect2(0,float(ui.WINDOW_TOP),0,float(ui.WINDOW_HEIGHT))
	var title: float = ui.TITLE_TOP-window.position.y
	var cards: float = ui.card_rect(0).position.y-(ui.TITLE_TOP+ui.TITLE_SIZE.y)
	var reroll: float = ui.reroll_rect().position.y-ui.card_rect(0).end.y
	var bottom: float = window.end.y-ui.reroll_rect().end.y
	t.check(title>0 and is_equal_approx(title,cards) and is_equal_approx(cards,reroll) and is_equal_approx(reroll,bottom),"FX06 title cards reroll evenly spaced in window")
	var slots := [ui.ICON_TOP,ui.NAME_TOP-ui.ICON_TOP-ui.ICON_SIZE,ui.DESCRIPTION_TOP-ui.NAME_TOP-ui.NAME_HEIGHT,ui.LEVEL_TOP-ui.DESCRIPTION_TOP-ui.DESCRIPTION_HEIGHT,ui.CARD_SIZE.y-ui.LEVEL_TOP-ui.LEVEL_HEIGHT]
	var even := true
	for gap in slots: even = even and gap>0 and is_equal_approx(gap,slots[0])
	t.check(even,"FX06 card icon name description level evenly spaced with shared baselines")
	var click_before := int(audio.request_counts.get("ui_click",0))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = ui.card_rect(0).get_center()
	ui._gui_input(event)
	t.check(int(audio.request_counts.get("ui_click",0))==click_before+1 and not n.choices.active,"FX06 card selection keeps ui_click")
	await f.cleanup(t,n)

func flow(t: SceneTree) -> void:
	var game := preload("res://scripts/game_flow.gd").new()
	t.root.add_child(game)
	while game.state=="loading": await t.process_frame
	var transition: CanvasLayer = game.ui.transition
	t.check(transition.mode=="idle" and not transition.rect.visible and not transition.is_processing(),"FX06 transition hidden while idle")
	game.start_region()
	t.check(game.state=="playing" and game.session.round_nodes.manager._elapsed_seconds==0 and transition.mode=="reveal" and transition.rect.visible,"FX06 restart path starts round at once and only reveals")
	transition._process(transition.reveal_sec)
	t.check(transition.mode=="idle" and not transition.rect.visible and not transition.is_processing(),"FX06 shader node hidden after reveal")
	game.show_menu()
	t.check(game.state=="menu" and game.session==null and transition.mode=="reveal","FX06 menu return keeps flow and reveals")
	transition.finish()
	transition.enabled = false
	var ran := [false]
	transition.cover(func() -> void: ran[0] = true)
	t.check(ran[0] and transition.mode=="idle" and not transition.rect.visible,"FX06 Ui_fx_enabled0 switches immediately")
	game.queue_free()
	await t.process_frame
