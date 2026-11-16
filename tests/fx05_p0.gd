extends RefCounted

func count(pool: Node, kind: String) -> int:
	return pool.slots.filter(func(slot: Dictionary) -> bool: return slot.active and slot.kind==kind).size()

func run(t: SceneTree) -> void:
	var n: Dictionary = preload("res://tests/fx03_p0.gd").new().fixture(t)
	var fx: Node2D = n.manager.boss_fx
	t.check(fx!=null and fx.slots.size()==512 and fx.gates.size()==4 and fx.ghosts.size()==4,"FX05 fixed pools allocated once")
	var store: CsvDataStore = t._store()
	t.check(store.load_all().is_empty(),"FX05 actual data loads")
	for asset in [["fx_gate",Vector2(512,512)],["fx_ice_arrow",Vector2(256,54)]]:
		var image: Texture2D = load("res://assets/art/fx/"+asset[0]+".png")
		t.check(image.get_size()==asset[1] and image.get_image().has_mipmaps() and image.get_image().detect_alpha()!=Image.ALPHA_NONE,"FX05 transparent mipmapped asset "+asset[0])
	var rows: Array = []
	for row in store.get_table("boss_action.csv").values():
		if row.Boss_id=="boss_middle": rows.append(row)
	var boss: Node2D = n.manager.create_boss("boss_ice_bear",rows,func() -> Node2D: return n.player)
	boss.position = Vector2.ZERO
	fx.schedule_gate("test",boss.position,3.5)
	n.manager._elapsed_seconds = 2.299
	fx.advance(2.299)
	t.check(not fx.gates[0].opened,"FX05 gate not visible before spawn minus1.2")
	n.manager._elapsed_seconds = 2.3
	fx.advance(0.001)
	t.check(fx.gates[0].opened and fx.gate_layer.get_parent()==n.map and fx.gate_layer.get_index()<n.map.get_node("CharacterBodies").get_index() and fx.gate_layer.z_index==0,"FX05 gate lead and draw order behind every character")
	fx.advance(1.2)
	n.manager.activate_boss(boss)
	var location: Vector2 = boss.position
	fx.advance(0)
	t.check(boss.is_active and boss.position==location and boss.sprite_body.presentation_alpha==0 and is_equal_approx(boss.sprite_body.presentation_transform.x.length(),0.55),"FX05 emerge starts at active instant without moving collision or delaying AI")
	var foot := Vector2(0,boss.sprite_body.foot_y)
	t.check((boss.position+boss.sprite_body.image_transform()*foot).is_equal_approx(fx.gate_center(location)),"FX05 first picture foot equals standing gate center")
	fx.advance(0.45)
	t.check(boss.position==location and boss.sprite_body.presentation_alpha==1 and boss.sprite_body.presentation_transform==Transform2D.IDENTITY,"FX05 emerge finishes at actual actor position .45")
	fx.advance(0.4)
	t.check(not fx.gates[0].active,"FX05 gate closes after emerge plus.4")
	var basic: Dictionary = store.get_row("boss_action.csv","ice_bear_basic")
	fx.advance(1)
	boss.clock = 10
	boss.start_action(basic,boss.position+Vector2(100,0))
	boss.clock = 10.399
	boss.advance_action()
	t.check(count(fx,"claw")==0,"FX05 no bear claw before judgment")
	boss.clock = 10.4
	boss.advance_action()
	t.check(count(fx,"claw")==3 and boss.current.is_empty(),"FX05 three bear claws at exact basic judgment")
	fx.advance(0.2)
	t.check(count(fx,"claw")==0,"FX05 bear claws expire .2")
	var slam: Dictionary = store.get_row("boss_action.csv","ice_bear_slam")
	fx.strike(boss,slam,boss.position,Vector2.RIGHT)
	t.check(count(fx,"ring")==1 and count(fx,"spike")==8 and count(fx,"shard")==6,"FX05 slam ring eight spikes six shards")
	fx.advance(0.4)
	t.check(count(fx,"ring")==0 and count(fx,"spike")==0 and count(fx,"shard")==0,"FX05 slam keyed lifetimes clear")
	fx.dash_start(Vector2.ZERO,Vector2.RIGHT,400)
	fx.dash_segment(Vector2.ZERO,Vector2(100,0),0.1,0)
	t.check(count(fx,"line")==6 and count(fx,"puff")==4,"FX05 bear dash six lines and four puffs per.1 actual path")
	fx.advance(1)
	fx.stealth(Vector2.ZERO)
	t.check(count(fx,"puff")==10,"FX05 elf stealth ten smoke circles per transition")
	fx.advance(0.35)
	t.check(count(fx,"puff")==0,"FX05 elf smoke expires .35")
	var push: Dictionary = store.get_row("boss_action.csv","ice_elf_push")
	fx.strike(boss,push,Vector2.ZERO,Vector2.RIGHT)
	fx.burst_prep(boss)
	t.check(count(fx,"ring")==2 and count(fx,"gather")==1,"FX05 elf push two rings and one prep gathering batch")
	fx.advance(1)
	var arrow_row: Dictionary = store.get_row("projectile.csv","elf_arrow")
	var arrow := CombatProjectile.new()
	n.manager.add_child(arrow)
	arrow.configure(arrow_row,Vector2.ZERO,Vector2(100,100),Rect2(-2000,-2000,4000,4000),null)
	var speed: float = arrow.speed
	var radius: float = arrow.body_radius
	arrow.advance(0.1)
	t.check(arrow.ice_arrow and arrow.direction.is_equal_approx(Vector2.ONE.normalized()) and is_equal_approx(arrow.traveled,speed*0.1) and arrow.body_radius==radius and arrow.trail_points.size()==4,"FX05 arrow image direction and four tails leave speed/radius/travel invariant")
	arrow.advance(100)
	t.check(arrow.spent and count(fx,"arrow_tail")>0,"FX05 spent logical arrow leaves pooled tail samples for remaining visual life")
	fx.advance(0.15)
	t.check(count(fx,"arrow_tail")==0,"FX05 handed-off arrow tails clear by .15")
	n.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":1})
	var normal: Node2D = n.manager.get_living_enemies().back()
	normal.apply_damage(normal.hp)
	t.check(count(fx,"puff")==5,"FX05 actual normal enemy kill emits five snow puffs")
	fx.advance(0.25)
	var screen: Node = n.skills.screen_fx
	screen.kick(100,0.3)
	screen._process(0.01)
	var amplitude: float = screen.strength*screen.remaining/screen.duration
	screen.kick(1,0.1)
	t.check(screen.strength<=8 and screen.shake_offset.length()<=8.000001 and screen.strength*screen.remaining/screen.duration>=amplitude-0.000001,"FX05 shake cap eight and weaker overlap does not replace stronger")
	screen.settings = screen.settings.duplicate()
	screen.settings.Shake_enabled = 0
	n.player.apply_damage(1)
	screen._process(0)
	t.check(screen.shake_offset==Vector2.ZERO and screen.player_hit_remaining==0.25 and screen.vignette_rect.visible,"FX05 Shake0 preserves player hit vignette")
	var bar: Node = n.player.get_node("FootHpBar")
	bar._process(0.03)
	t.check(not is_zero_approx(bar.position.x) and absf(bar.position.x)<=3,"FX05 HP bar shakes only artwork")
	bar._process(0.2)
	t.check(is_zero_approx(bar.position.x),"FX05 HP bar shake ends .2")
	n.player.add_experience(n.player.get_xp_to_next())
	t.check(t.paused and count(fx,"ring")==2,"FX05 actual level-up emits two light rings")
	var paused_age: float = fx.age
	fx.advance(0.4)
	t.check(fx.age==paused_age,"FX05 explicit choice pause freezes effect progress")
	n.choices.select(0)
	boss.apply_damage(1)
	boss.advance_hit_flash(0.099)
	t.check(boss.sprite_body.material!=null,"FX05 boss white flash lasts before .1")
	boss.advance_hit_flash(0.001)
	t.check(boss.sprite_body.material==null,"FX05 boss white flash detaches at .1")
	var logical: float = n.manager._elapsed_seconds
	var hp: int = boss.hp
	fx.died(boss)
	fx.advance(0.2)
	t.check(n.manager._elapsed_seconds==logical and boss.hp==hp and is_equal_approx(fx.slow_remaining,0.2) and is_equal_approx(fx.ghosts[0].age,0.06) and Engine.time_scale==1,"FX05 kill slowdown changes visual age only, not game clock HP or Engine time scale")
	fx.advance(1)
	var view := SubViewport.new()
	view.world_2d = World2D.new()
	t.root.add_child(view)
	n.host.reparent(view)
	fx.level_up(2)
	t.check(fx.slots.size()==512 and count(fx,"ring")==2 and fx.gate_layer.is_inside_tree(),"FX05 reparent retains fixed storage and clears/reuses effects without another ready")
	view.free()
	await t.process_frame
	await action_hooks(t,store)
	await result_pause(t)
	var original: Dictionary = Engine.get_meta(&"combat_presentation").duplicate()
	var off := original.duplicate()
	off.Boss_fx_enabled = 0
	off.Impact_fx_enabled = 0
	Engine.set_meta(&"combat_presentation",off)
	n = preload("res://tests/fx03_p0.gd").new().fixture(t)
	t.check(n.manager.boss_fx==null,"FX05 both flags zero create no boss/impact pool or gate")
	n.host.free()
	Engine.set_meta(&"combat_presentation",original)
	await t.process_frame

func result_pause(t: SceneTree) -> void:
	var flow := preload("res://scripts/game_flow.gd").new()
	t.root.add_child(flow)
	while flow.state=="loading": await t.process_frame
	flow.start_region()
	for node in flow.session.find_children("*","Node",true,false): node.set_physics_process(false)
	var n: Dictionary = flow.session.round_nodes
	var helper := preload("res://tests/flow_p0.gd").new()
	var boss: Node2D = helper.spawn_final(n)
	var clock: float = n.manager._elapsed_seconds
	var skill_clock: float = n.skills.clock
	flow.toggle_pause()
	var fx: Node = n.manager.boss_fx
	var paused_age: float = fx.age
	fx.advance(0.2)
	t.check(flow.state=="paused" and fx.age==paused_age,"FX05 ESC pause freezes boss FX")
	flow.resume()
	boss.apply_damage(boss.hp)
	var age: float = fx.age
	var ghost_age: float = fx.ghosts[0].age
	var slash_age: float = n.skills.clock
	fx.advance(0.4)
	t.check(t.paused and flow.state=="result" and flow.result.seconds==clock and n.manager._elapsed_seconds==clock and n.skills.clock==skill_clock and fx.age==age and fx.ghosts[0].age>ghost_age and Engine.time_scale==1,"FX05 result pause advances kill picture only with result/game/effect clocks unchanged")
	fx.advance(1)
	t.check(not fx.ghosts[0].active and not n.skills.screen_fx.screen.visible and not n.skills.screen_fx.white_rect.visible and n.skills.clock==slash_age,"FX05 result kill picture flash and shake finish without resuming other effects")
	flow.free()
	t.paused = false
	await t.process_frame

func action_hooks(t: SceneTree, store: CsvDataStore) -> void:
	var n: Dictionary = preload("res://tests/fx03_p0.gd").new().fixture(t)
	var fx: Node2D = n.manager.boss_fx
	var rows: Array = []
	for row in store.get_table("boss_action.csv").values():
		if row.Boss_id=="boss_final": rows.append(row)
	var boss: Node2D = n.manager.create_boss("boss_baruka",rows,func() -> Node2D: return n.player)
	n.manager.activate_boss(boss)
	boss.position = Vector2.ZERO
	n.player.position = Vector2(500,0)
	boss.clock = 0
	boss.start_action(store.get_row("boss_action.csv","baruka_basic"),n.player.position)
	boss.clock = boss.phase_end
	boss.baruka.advance()
	var points: PackedVector2Array = boss.baruka.triangle_points()
	t.check(count(fx,"line")==0,"FX05 tri slash not emitted before dash arrival")
	boss.clock = boss.dash_started+boss.dash_length/float(boss.current.Dash_speed)
	boss.baruka.advance()
	var lines: Array = fx.slots.filter(func(s: Dictionary) -> bool: return s.active and s.kind=="line")
	t.check(lines.size()==2 and lines[0].point==points[2] and lines[0].direction==points[0]-points[2],"FX05 actual tri arrival emits two exact triangle-edge slashes")
	fx.advance(0.2)
	boss.start_action(store.get_row("boss_action.csv","baruka_blink"),n.player.position)
	boss.clock = boss.phase_end
	boss.baruka.advance()
	var state: int = boss.rng.state
	boss.clock = boss.dash_started+boss.dash_length/float(boss.current.Dash_speed)
	boss.baruka.advance()
	t.check(count(fx,"cross")==1 and count(fx,"star")==1 and boss.rng.state==state,"FX05 blink arrival emits X/star without consuming combat RNG")
	boss.baruka.interrupt()
	fx.advance(1)
	var ice: Dictionary = store.get_row("boss_action.csv","baruka_ice")
	boss.start_action(ice,n.player.position)
	boss.clock = boss.phase_end
	boss.baruka.advance()
	t.check(count(fx,"zone")==int(ice.Zone_count) and boss.baruka.zones.size()==int(ice.Zone_count) and int(fx.settings.Zone_crystal_count)==5,"FX05 actual zone creation one batch per unchanged logical zone five crystals each")
	boss.clock+=float(ice.Zone_life_sec)
	boss.baruka.update_zones()
	fx.advance(0)
	t.check(count(fx,"zone")==0,"FX05 crystal/fog lifetime follows actual zone expiration")
	rows = []
	for row in store.get_table("boss_action.csv").values():
		if row.Boss_id=="boss_early": rows.append(row)
	var elf: Node2D = n.manager.create_boss("boss_ice_elf",rows,func() -> Node2D: return n.player)
	n.manager.activate_boss(elf)
	elf.position = Vector2.ZERO
	n.player.position = Vector2(70,0)
	elf.elf.cleanup()
	elf.elf.tick(0)
	t.check(count(fx,"ring")==2,"FX05 actual elf push emits two rings at push application")
	elf.elf.tick(0)
	t.check(elf.elf.hidden and count(fx,"puff")==10,"FX05 actual stealth start emits ten puffs")
	elf.elf.end_stealth(5)
	t.check(not elf.elf.hidden and count(fx,"puff")==20,"FX05 actual stealth end emits ten more puffs")
	elf.elf.tick(0)
	t.check(elf.elf.burst and count(fx,"gather")==1,"FX05 actual burst preparation emits gathering only at start")
	n.host.free()
	await t.process_frame
