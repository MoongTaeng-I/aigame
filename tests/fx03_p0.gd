extends RefCounted

func fixture(t: SceneTree) -> Dictionary:
	var main: Node = load("res://main.tscn").instantiate()
	t.root.add_child(main)
	for node in main.find_children("*","Node",true,false): node.set_physics_process(false)
	var n: Dictionary = main.round_nodes
	n.host = main
	n.player.global_position = Vector2(400,400)
	return n

func count_fx(root: Node) -> int:
	var total := 0
	for node in root.find_children("*","Node",true,false):
		if node.get_script() in [preload("res://scripts/shadow_aura_fx.gd"),preload("res://scripts/shadow_aura_layer.gd")]: total+=1
	return total

func run(t: SceneTree) -> void:
	var n := fixture(t)
	for id in ["igrit","charger_test","belion"]:
		var actor: Node2D = n.shadows.summon(id)
		var fx: Node2D = actor.aura_fx
		fx.set_physics_process(false)
		fx.visual_rng.seed = 20261116
		var source: SpriteBody = actor.sprite_body
		source.advance_shadow_pose(Vector2.LEFT,true,0.1,false,Vector2.RIGHT)
		fx.advance(0)
		var rect := source.source_rect()
		var size: Vector2 = source.texture.get_size()
		var expected := Vector4(rect.position.x/size.x,rect.position.y/size.y,rect.size.x/size.x,rect.size.y/size.y)
		t.check(fx.aura.image_pose==source.image_transform() and fx.aura.position==source.position and fx.aura.material.get_shader_parameter("source_atlas")==source.texture and fx.aura.material.get_shader_parameter("frame_uv")==expected,"FX03 current cell flip motion and texture match "+id)
		t.check(fx.aura.get_parent()==source.get_parent() and fx.aura.get_index()<source.get_index() and fx.aura.z_index==-1,"FX03 exactly one aura behind body "+id)
		var body_material := ShaderMaterial.new()
		body_material.shader = preload("res://scripts/hit_flash.gdshader")
		source.material = body_material
		source.sprite_tint = Color.RED
		actor.cast_active = true
		fx.advance(0)
		t.check(is_equal_approx(fx.aura.boosted_alpha,0.75*1.3) and is_equal_approx(fx.aura.flame_length,14*1.4) and source.material==body_material and fx.aura.material!=source.material and source.sprite_tint==Color.RED,"FX03 cast boost separate from original tint/material "+id)
		fx.settings.Aura_alpha = "0.9"
		fx.advance(0)
		t.check(fx.aura.boosted_alpha==1,"FX03 boosted alpha capped1 "+id)
		fx.settings.Aura_alpha = "0.75"
		actor.cast_active = false
		fx.advance(0)
		var pool: Array = fx.embers
		var slot: Dictionary = pool[0]
		var puff_pool: Array = fx.puffs
		var wisp_pool: Array = fx.wisps
		var aura_id: int = fx.aura.get_instance_id()
		var combat_state: int = actor.random.state
		t.check(fx.bursts==1 and fx.puffs.filter(func(p: Dictionary) -> bool: return p.active).size()==12 and absf(Vector2(fx.puffs[0].point).x-actor.global_position.x)<fx.body_width(),"FX03 summon burst once at current world body position "+id)
		fx.advance(1)
		t.check(fx.emitted==6 and fx.embers.filter(func(p: Dictionary) -> bool: return p.active).size()==5 and fx.wisps.size()==2,"FX03 six embers/sec .8life and two wisps "+id)
		var live: Dictionary = fx.embers.filter(func(p: Dictionary) -> bool: return p.active)[0]
		var world: Vector2 = fx.ember_world_point(live)
		actor.global_position += Vector2(300,0)
		fx.advance(0)
		t.check(fx.ember_world_point(live)==world,"FX03 world embers do not follow body "+id)
		fx.advance(1)
		t.check(is_same(pool,fx.embers) and is_same(slot,fx.embers[0]) and is_same(wisp_pool,fx.wisps) and is_same(puff_pool,fx.puffs) and fx.aura.get_instance_id()==aura_id and actor.random.state==combat_state,"FX03 fixed pools/layer reused and combat RNG untouched "+id)
		var before: float = fx.age
		t.paused = true
		fx.advance(0.5)
		t.check(fx.age==before and is_equal_approx(float(fx.aura.material.get_shader_parameter("aura_time")),before) and fx.process_mode==Node.PROCESS_MODE_PAUSABLE,"FX03 pause freezes shader clock and pools "+id)
		t.paused = false
		var events: int = fx.bursts
		actor.angle_picker = func() -> float: return 0.0
		actor.teleport()
		fx.advance(0)
		t.check(fx.bursts==events+1 and fx.puffs.filter(func(p: Dictionary) -> bool: return p.active).size()==12,"FX03 teleport arrival burst exactly once "+id)
		var image: Node2D = n.shadows.leave_afterimage(actor.global_position,actor.snapshot(),0.2)
		t.check(count_fx(image)==0 and image.sprite_body.get_child_count()==0,"FX03 afterimage has no aura or particles "+id)
		fx.settings.Ember_rate = "0"
		fx.advance(0.801)
		t.check(fx.embers.filter(func(p: Dictionary) -> bool: return p.active).is_empty() and fx.puffs.filter(func(p: Dictionary) -> bool: return p.active).is_empty() and fx.wisps.size()==2,"FX03 expired particles inactive; fixed wisps renew "+id)
		actor.free()
		image.free()
		await t.process_frame
		t.check(count_fx(n.host)==0 and pool.is_empty() and puff_pool.is_empty() and wisp_pool.is_empty(),"FX03 shadow removal clears nodes and pools "+id)
	n.host.free()
	await t.process_frame
	n = fixture(t)
	t.check(count_fx(n.host)==0,"FX03 restart has zero leftover FX")
	var cache: Dictionary = Engine.get_meta(&"combat_presentation").duplicate()
	var disabled := cache.duplicate()
	disabled.Shadow_aura_enabled = "0"
	Engine.set_meta(&"combat_presentation",disabled)
	for id in ["igrit","charger_test","belion"]:
		var actor: Node2D = n.shadows.summon(id)
		t.check(actor.aura_fx==null and count_fx(n.host)==0,"FX03 disabled creates zero layers/pools/particles "+id)
		actor.free()
		await t.process_frame
	Engine.set_meta(&"combat_presentation",cache)
	n.host.free()
	await t.process_frame

func measure(t: SceneTree) -> void:
	var n := fixture(t)
	n.manager._max_alive = 150 # Measurement-only fixture; gameplay cap unchanged.
	n.player.configure_combat(1000000000,t._attack())
	for i in range(150):
		n.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":1})
		var enemy: EnemyActor = n.manager.get_living_enemies().back()
		enemy.global_position = n.player.global_position+Vector2.RIGHT.rotated(TAU*i/150.0)*300
		enemy.hp = 10000
	n.shadows.capacity = 3 # Measurement-only; actual MAX_TYPES remains2.
	for id in ["igrit","charger_test","belion"]:
		var actor: Node2D = n.shadows.summon(id)
		actor.aura_fx.set_physics_process(false)
		actor.aura_fx.advance(0.2)
	await t.physics_frame
	await t.physics_frame
	var start := Time.get_ticks_usec()
	n.shadows._physics_process(1.0/60)
	n.player._physics_process(1.0/60)
	n.manager._physics_process(1.0/60)
	for actor in n.shadows.actors: actor.aura_fx.advance(1.0/60)
	var elapsed := Time.get_ticks_usec()-start
	var result := {"enemies":n.manager.get_alive_count(),"shadows":n.shadows.actors.size(),"samples":1,"elapsed_us":elapsed,"elapsed_ms":elapsed/1000.0,"rendering_included":false,"scope":"enemy/shadow/player physics plus FX pool/uniform update","pass_threshold":null}
	var file := FileAccess.open("res://.local/fx-03-performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	file.close()
	print("FX03 PERFORMANCE ",JSON.stringify(result))
	n.host.free()
	t.paused = false
	await t.process_frame
