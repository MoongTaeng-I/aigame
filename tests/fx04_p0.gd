extends RefCounted

const Fixtures = preload("res://tests/fx03_p0.gd")

class VanishingGeometry:
	extends Node2D
	var draws := 0
	func _draw() -> void:
		draws+=1
		var draw = preload("res://scripts/combat_fx_draw.gd")
		var palette := draw.colors({},true)
		for width in [0.01,0.00001,0.00000001]:
			draw.blade(self,Vector2(1400,1400),Vector2(1400.004,1400),width,palette)
			draw.arc(self,Vector2(1400,1400),100,0,PI,width,0.62,palette,1)
			draw.star(self,Vector2(1400,1400),width,palette[0])

func active(slots: Array) -> Array:
	return slots.filter(func(slot: Dictionary) -> bool: return slot.active)

func run(t: SceneTree) -> void:
	var vanishing := VanishingGeometry.new()
	t.root.add_child(vanishing)
	for i in range(3): await t.process_frame
	t.check(vanishing.draws>0,"FX04 subpixel dying blade/arc/star render without degenerate polygon submission")
	vanishing.free()
	await player_and_numbers(t)
	await shadows(t)
	await switches(t)

func player_and_numbers(t: SceneTree) -> void:
	var n: Dictionary = Fixtures.new().fixture(t)
	n.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":1})
	var enemy: EnemyActor = n.manager.get_living_enemies()[0]
	enemy.global_position = n.player.global_position+Vector2(60,0)
	enemy.hp = 1000
	var numbers: Node2D = n.manager.damage_numbers
	n.player.update_basic_attack(0,[enemy])
	t.check(not n.player.current_basic_fx.thrust and n.player.sprite_body.frame_column==23 and active(numbers.slots).size()==1 and numbers.slots[0].value==10,"FX04 first hit slash23 one actual damage number")
	t.check(numbers.slots[0].color==Color.WHITE and n.player.basic_fx_pool.size()==8 and active(n.player.basic_impacts.slots).size()==1,"FX04 player color fixed blade pool and accepted hit star")
	var debug_actor: Node2D = n.shadows.summon("igrit")
	n.map.set_debug_visible(true)
	t.check(debug_actor.debug_ranges_visible() and n.player.current_basic_fx.debug_enabled(),"FX04 F3 reveals exact shadow ranges and player triangle")
	n.map.set_debug_visible(false)
	debug_actor.free()
	var hp: int = enemy.hp
	enemy.knockback_elapsed = enemy.knockback_duration
	enemy.global_position = n.player.global_position+Vector2(60,0)
	n.player.update_basic_attack(0.15,[enemy])
	t.check(n.player.current_basic_fx.thrust and n.player.sprite_body.frame_column==24 and enemy.hp==hp-10 and active(numbers.slots).size()==2,"FX04 second hit thrust24 unchanged hit .15 damage")
	var pivot := Vector2(0,n.player.sprite_body.foot_y)
	t.check((n.player.sprite_body.step_transform()*pivot).is_equal_approx(pivot+Vector2(6,0)),"FX04 thrust step six visual pixels")
	var frozen: Transform2D = n.player.sprite_body.motion_transform
	var old_frame: int = n.player.sprite_body.frame_column
	var location: Vector2 = n.player.global_position
	Input.action_press("move_right")
	n.player._physics_process(0.01)
	Input.action_release("move_right")
	t.check(n.player.global_position.x>location.x and n.player.sprite_body.frame_column==old_frame and n.player.sprite_body.motion_transform==frozen and n.player.sprite_body._pose_walk_elapsed>0,"FX04 image hitstop preserves movement and walk time")
	var count: int = numbers.sequence
	enemy.apply_damage(0)
	enemy.apply_damage(-1)
	enemy.is_logically_dead = true
	enemy.apply_damage(5)
	enemy.is_logically_dead = false
	t.check(numbers.sequence==count,"FX04 nonpositive and rejected hits create zero numbers")
	enemy.record_damage_presentation("shadow")
	enemy.apply_damage(5)
	t.check(active(numbers.slots).back().color==Color("#d6c8ff"),"FX04 shadow source color")
	enemy.hp = 3
	enemy.apply_damage(12)
	t.check(active(numbers.slots).back().value==3 and active(numbers.slots).back().color==Color("#ffd84a") and active(numbers.slots).back().killed,"FX04 kill color and actual HP loss rather than overkill")
	var row_count: int = numbers.slots.size()
	for i in range(65): numbers.show_damage(enemy,i+1,"player",false)
	t.check(row_count==60 and numbers.slots.size()==60 and active(numbers.slots).size()==60 and active(numbers.slots).all(func(s: Dictionary) -> bool: return int(s.serial)>=numbers.sequence-60),"FX04 sixty fixed slots oldest overwritten")
	var at: Vector2 = numbers.slots[0].point
	t.check(absf(at.x-enemy.global_position.x)<=8 and is_equal_approx(at.y,enemy.global_position.y+enemy.sprite_body.display_rect().position.y-6),"FX04 above sprite head world position jitter")
	t.paused = true
	numbers.advance(0.8)
	n.player.basic_impacts.advance(0.8)
	t.check(active(numbers.slots).size()==60 and numbers.slots[0].age==0 and active(n.player.basic_impacts.slots).size()==2,"FX04 pause freezes number and impact lifetimes")
	t.paused = false
	numbers.advance(0.55)
	n.player.basic_impacts.advance(0.12)
	t.check(active(numbers.slots).is_empty() and active(n.player.basic_impacts.slots).is_empty(),"FX04 expired fixed slots all inactive")
	for id in ["boss_ice_bear","boss_ice_elf","boss_baruka"]:
		var boss: Node2D = n.manager.create_boss(id,[],func() -> Node2D: return n.player)
		n.manager.activate_boss(boss)
		var previous: int = numbers.sequence
		boss.record_damage_presentation("shadow")
		boss.apply_damage(7)
		t.check(numbers.sequence==previous+1 and active(numbers.slots).back().value==7 and active(numbers.slots).back().color==Color("#d6c8ff"),"FX04 accepted boss hit has one sourced number "+id)
	await t.create_timer(0.21).timeout
	t.check(n.player.basic_fx_pool.all(func(fx: Node2D) -> bool: return not fx.visible and not fx.active),"FX04 original .2sec Timer expires and hides pooled effects")
	n.player.presentation = n.player.presentation.duplicate()
	n.player.presentation.Basic_fx_enabled = "0"
	var legacy: Node2D = n.player.acquire_basic_fx()
	legacy.settings = n.player.presentation
	legacy.base = Vector2.ZERO
	legacy.facing = Vector2.RIGHT
	legacy.length = 100
	legacy.width = 30
	t.check(not legacy.pooled and legacy.crescent_ribbon(5).size()>0,"FX04 basic disabled retains original crescent geometry")
	legacy.queue_free()
	var saved_slots: Array = numbers.slots
	var saved_fx: Array = n.player.basic_fx_pool.duplicate()
	n.host.free()
	await t.process_frame
	t.check(saved_slots.is_empty() and saved_fx.all(func(node: Variant) -> bool: return not is_instance_valid(node)),"FX04 round removal clears number pool and pooled sibling effects")

func shadows(t: SceneTree) -> void:
	var helper := preload("res://tests/belion_sweep_p0.gd").new()
	helper.t = t
	for id in ["igrit","charger_test","belion"]:
		var f: Dictionary = helper.fixture()
		var actor: Node2D = f.summons.summon(id)
		actor.position = Vector2.ZERO
		actor.motion_picker = func(_size: int) -> int: return 0
		var enemy: EnemyActor = t._spawn(f,Vector2(100,0),1000)
		actor.tick(0)
		var fx: Node2D = actor.attack_fx
		fx.set_physics_process(false)
		fx.impacts.set_physics_process(false)
		t.check(not actor.debug_ranges_visible(),"FX04 shadow ranges hidden by default "+id)
		var sprite: SpriteBody = actor.sprite_body
		var expected_height := 165 if id=="igrit" else (144 if id=="charger_test" else 158)
		t.check(absf(sprite.display_rect().size.y-expected_height)<=1 and sprite.texture.get_image().has_mipmaps(),"ART15 updated atlas height and mipmaps "+id)
		if id=="igrit":
			for motion in range(actor.motions.size()):
				if motion>0:
					actor.cancel_attack()
					actor.visual_hitstop_remaining = 0 # Independent motion fixture, after preceding image freeze.
					actor.ready_at = actor.clock
					actor.motion_picker = func(_size: int) -> int: return motion
					actor.target = enemy
					actor.start_attack()
				actor.update_sprite_visual(Vector2.ZERO,0)
				var hit: float = actor.motions[motion].Hit_time_sec
				t.check(sprite.frame_column==10,"ART15 Igris prep10 motion "+str(motion))
				actor.tick(hit-0.001)
				t.check(not actor.hit_done and sprite.frame_column==10,"ART15 Igris prep before hit "+str(motion))
				actor.tick(0.001)
				t.check(actor.hit_done and sprite.frame_column==1 and active(fx.arcs).size()==motion+1,"ART15 Igris hit frame1 exact time with arc "+str(motion))
				var arc: Dictionary = fx.arcs[motion]
				var diagonal: bool = actor.motions[motion].Id=="igrit_diagonal"
				t.check(active(fx.impacts.slots).size()==7*(motion+1),"FX04 Igris actual hit one star and six sparks "+str(motion))
				t.check(is_equal_approx(arc.radius,float(actor.attack.Range)*0.85*(0.75 if diagonal else 1)) and is_equal_approx(arc.width,36*(0.8 if diagonal else 1)) and is_equal_approx(arc.arc,deg_to_rad(float(actor.attack.Arc_deg))*(0.65 if diagonal else 1)),"FX04 Igris motion-specific arc dimensions "+str(motion))
			fx.advance(0.18)
			t.check(active(fx.arcs).is_empty(),"FX04 Igris crescent expires .18")
		elif id=="charger_test":
			t.check(sprite.frame_column==1,"ART15 Beru dash attack1")
			actor.tick(0.1)
			t.check(fx.claw_from==actor.dash_origin and fx.claw_to==actor.global_position and is_equal_approx(fx.claw_from.distance_to(fx.claw_to),float(actor.attack.Dash_speed)*0.1),"FX04 Beru claw follows actual traveled distance")
			var visual: Transform2D = sprite.motion_transform
			var before: Vector2 = actor.global_position
			actor.tick(0.01)
			t.check(actor.global_position.x>before.x and sprite.motion_transform==visual and sprite.frame_column==1,"FX04 shadow image hitstop leaves dash movement running")
			actor.tick(0.39)
			t.check(actor.hit_done and not actor.dash_through_active and actor.cast_active and sprite.frame_column==2,"ART15 Beru recovery finish2")
			fx.advance(0.299)
			t.check(fx.claw_visible,"FX04 Beru claw persists before .3")
			fx.advance(0.001)
			t.check(not fx.claw_visible,"FX04 Beru claw expires .3")
		else:
			t.check(sprite.frame_column==2 and fx.prep_stars.size()==3,"ART15 Belion prep2 three chain twinkles")
			actor.tick(0.399)
			t.check(sprite.frame_column==2 and active(fx.bands).is_empty(),"ART15 Belion prep lasts until .4")
			actor.tick(0.001)
			t.check(sprite.frame_column==1,"ART15 Belion sweep frame1 at .4")
			actor.tick(0.15)
			var first: Dictionary = fx.bands[0]
			t.check(is_equal_approx(first.a,actor.facing.angle()-PI/2) and is_equal_approx(fx.bands[fx.band_cursor-1].b,actor.sweep_current_angle) and fx.stripe_index==15,"FX04 Belion stripe angles track actual forward half sweep")
			actor.tick(0.15)
			t.check(not actor.cast_active and active(fx.impacts.slots).size()>=13,"FX04 Belion final burst seven shards five stones star")
			t.check(active(fx.impacts.slots).filter(func(s: Dictionary) -> bool: return s.kind=="shard").size()==14 and active(fx.impacts.slots).filter(func(s: Dictionary) -> bool: return s.kind=="stone").size()==10 and active(fx.impacts.slots).filter(func(s: Dictionary) -> bool: return s.kind=="star").size()==2,"FX04 one hit plus endpoint each emit exact 7/5/1 burst")
			fx.advance(0.25)
			t.check(active(fx.bands).is_empty(),"FX04 Belion bands expire .25")
			actor.clock = actor.ready_at
			actor.target = enemy
			actor.start_attack()
			actor.tick(0.55)
			t.check(fx.bands[30].a>fx.bands[30].b,"FX04 Belion reverse sweep follows alternating gameplay")
		fx.impacts.advance(1)
		t.check(active(fx.impacts.slots).is_empty(),"FX04 shadow impact slots expire "+id)
		actor.config = actor.config.duplicate()
		actor.config.Prep_col = null
		actor.config.Finish_col = null
		actor.visual_hitstop_remaining = 0
		actor.cast_active = true
		actor.update_sprite_visual(Vector2.ZERO,0)
		t.check(sprite.frame_column==1,"ART15 blank optional pose columns preserve original attack1 "+id)
		actor.aura_fx.advance(0)
		var ghost := SpriteBody.new()
		ghost.configure_snapshot(sprite.pose_snapshot())
		t.check(ghost.frame_column==sprite.frame_column and ghost.image_transform()==sprite.image_transform() and actor.aura_fx.aura.image_pose==sprite.image_transform(),"ART15 snapshot aura track updated atlas pose "+id)
		ghost.free()
		var saved_arcs: Array = fx.arcs
		var saved_impacts: Array = fx.impacts.slots
		await helper.close(f)
		t.check(saved_arcs.is_empty() and saved_impacts.is_empty(),"FX04 shadow removal clears fixed arrays "+id)

func switches(t: SceneTree) -> void:
	var original: Dictionary = Engine.get_meta(&"combat_presentation").duplicate()
	var off := original.duplicate()
	off.Shadow_attack_fx_enabled = "0"
	off.Damage_number_enabled = "0"
	Engine.set_meta(&"combat_presentation",off)
	var n: Dictionary = Fixtures.new().fixture(t)
	var actor: Node2D = n.shadows.summon("belion")
	t.check(actor.attack_fx==null and actor.debug_ranges_visible() and n.manager.damage_numbers==null,"FX04 switches create no FX/numbers and retain previous range display")
	n.host.free()
	Engine.set_meta(&"combat_presentation",original)
	await t.process_frame

func measure(t: SceneTree) -> void:
	var n: Dictionary = Fixtures.new().fixture(t)
	n.manager._max_alive = 150
	n.player.configure_combat(1000000000,t._attack())
	for i in range(150):
		n.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":1})
		var enemy: EnemyActor = n.manager.get_living_enemies().back()
		enemy.global_position = n.player.global_position+Vector2.RIGHT.rotated(TAU*i/150.0)*100
		enemy.hp = 10000
	n.shadows.capacity = 3
	for id in ["igrit","charger_test","belion"]: n.shadows.summon(id)
	var start := Time.get_ticks_usec()
	n.skills.try_use("skill_rapid_slash")
	n.skills._physics_process(0.2)
	n.shadows._physics_process(0.2)
	n.player._physics_process(0.2)
	n.manager._physics_process(1.0/60)
	for actor in n.shadows.actors:
		actor.aura_fx.advance(0.2)
		actor.attack_fx.advance(0.2)
		actor.attack_fx.impacts.advance(0.2)
	n.manager.damage_numbers.advance(0.2)
	var elapsed := Time.get_ticks_usec()-start
	var result := {"enemies":150,"shadows":3,"rapid_slash":true,"elapsed_us":elapsed,"rendering_included":false,"pass_threshold":null}
	var file := FileAccess.open("res://.local/fx-04-performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	file.close()
	print("FX04 PERFORMANCE ",JSON.stringify(result))
	n.host.free()
	await t.process_frame
