extends RefCounted

func run(t: SceneTree) -> void:
	var cache = preload("res://scripts/shadow_afterimage.gd")
	cache.presentation()
	var raw: Dictionary = Engine.get_meta(&"combat_presentation_raw")
	var typed: Dictionary = cache.compiled_presentation()
	var equal := true
	for key in raw:
		var value: Variant = raw[key]
		if value is String and value.begins_with("#"): equal = equal and typed[key]==Color(value)
		elif value is String and value.is_valid_float(): equal = equal and typed[key]==float(value)
		else: equal = equal and typed[key]==value
	t.check(equal and typed.is_read_only() and is_same(typed,cache.compiled_presentation()) and is_same(cache.presentation(),Engine.get_meta(&"combat_presentation")),"OPT01 all compiled colors/numbers equal old values and shared read-only loading cache")
	var n: Dictionary = preload("res://tests/fx03_p0.gd").new().fixture(t)
	n.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":2})
	var enemies: Array = n.manager.get_living_enemies()
	var a: EnemyActor = enemies[0]
	var b: EnemyActor = enemies[1]
	a.apply_damage(1)
	b.apply_damage(1)
	t.check(a.sprite_body.material==b.sprite_body.material and a.sprite_body.material==a.character_view.material and a.sprite_body.material.get_shader_parameter("hit_flash")==1.0,"OPT01 flashing actors share one white material")
	a.advance_hit_flash(0.079)
	t.check(a.sprite_body.material!=null,"OPT01 flash remains before .08")
	a.advance_hit_flash(0.001)
	t.check(a.sprite_body.material==null and a.character_view.material==null and b.sprite_body.material!=null,"OPT01 finished flash detaches without affecting another actor")
	b.advance_hit_flash(0.08)
	var numbers: Node2D = n.manager.damage_numbers
	numbers.advance(1)
	a.hp = 100
	var before: int = numbers.sequence
	a.apply_damage(5)
	var slot: Dictionary = numbers.slots.filter(func(s: Dictionary) -> bool: return s.active)[0]
	numbers.advance(0.1)
	a.apply_damage(7)
	t.check(numbers.sequence==before+1 and slot.value==12 and is_equal_approx(slot.age,0.1) and slot.pop_age==0,"OPT01 within .15 merges actual damage and resets pop only")
	numbers.advance(0.151)
	a.record_damage_presentation("shadow")
	a.apply_damage(3)
	t.check(numbers.sequence==before+2 and numbers.slots.filter(func(s: Dictionary) -> bool: return s.active).size()==2,"OPT01 after merge boundary creates another number")
	numbers.advance(0.01)
	a.hp = 2
	a.apply_damage(20)
	var last: Dictionary = numbers.slots.filter(func(s: Dictionary) -> bool: return s.active).back()
	t.check(last.value==5 and last.killed and last.color==Color("#ffd84a") and a.hp==0,"OPT01 merged kill actual HP loss and yellow priority")
	numbers.settings = numbers.settings.duplicate()
	numbers.settings.Damage_number_merge_sec = 0
	before = numbers.sequence
	b.hp = 100
	b.apply_damage(2)
	b.apply_damage(4)
	t.check(numbers.sequence==before+2,"OPT01 zero merge retains one number per hit")
	numbers.advance(1)
	t.check(numbers.active_count==0 and numbers.by_enemy.is_empty(),"OPT01 expired number slots and lookup all clear")
	for i in range(3): await t.process_frame
	var redraws := {"numbers":0,"body":0}
	numbers.draw.connect(func() -> void: redraws.numbers+=1)
	b.character_view.draw.connect(func() -> void: redraws.body+=1)
	for i in range(10):
		numbers.advance(0.01)
		b.character_view.sync_pose()
	for i in range(3): await t.process_frame
	t.check(redraws.numbers==0 and redraws.body==0,"OPT01 empty number pool and unchanged sprite presentation retain draw commands")
	var texture: Texture2D = Engine.get_meta(&"ground_shadow_texture")
	var image := texture.get_image()
	t.check(absf(image.get_pixel(64,64).a-float(typed.Shadow_alpha))<0.005 and image.get_pixel(0,0).a==0 and image.get_pixel(64,64).r==image.get_pixel(64,80).r,"OPT01 shared shadow texture preserves center alpha RGB and transparent corners")
	var first_id := texture.get_instance_id()
	SpriteBody.prepare_ground_shadow(typed)
	t.check(Engine.get_meta(&"ground_shadow_texture").get_instance_id()==first_id,"OPT01 shadow texture generated once for same settings")
	var area = preload("res://scripts/skill_area.gd")
	b.position = n.player.position+Vector2(20,0)
	var matches: Array = area.living_in_circle(n.player.position,30,[b,b,null,a,b])
	t.check(matches==[b],"OPT01 circle dictionary dedup preserves first occurrence and death rejection")
	var screen: CanvasLayer = n.skills.screen_fx
	screen.settings = screen.settings.duplicate()
	screen.settings.Shake_enabled = 0
	screen.set_slash_active(true)
	screen.kick(5,0.2,0.15)
	screen.flash_white(0.35,0.05)
	screen._process(0.025)
	t.check(not screen.screen.visible and screen.flash_rect.visible and screen.white_rect.visible and screen.dim_rect.visible and is_equal_approx(screen.white_rect.color.a,0.175),"OPT01 flat overlays preserve white flash alpha and hide screen sampler when shake off")
	var hud: Node = n.map.get_node("TemporaryHud")
	t.check(not hud.performance_label.visible,"OPT01 F3 performance display hidden by default")
	hud.toggle_debug()
	hud._process(0.25)
	t.check(hud.performance_label.visible and hud.performance_label.text.contains("FPS") and hud.performance_label.text.contains("Draw") and hud.performance_label.text.contains("Enemies"),"OPT01 F3 FPS drawcalls objects nodes enemies")
	n.host.free()
	t.paused = false
	await t.process_frame
