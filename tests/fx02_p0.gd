extends RefCounted

func fixture(t: SceneTree) -> Dictionary:
	var main: Node = load("res://main.tscn").instantiate()
	t.root.add_child(main)
	for node in main.find_children("*","Node",true,false): node.set_physics_process(false)
	var n: Dictionary = main.round_nodes
	n.host = main
	n.skills.visual_rng.seed = 20261116
	return n

func cleanup(t: SceneTree, n: Dictionary) -> void:
	n.host.free()
	t.paused = false
	await t.process_frame

func enemy(n: Dictionary, position: Vector2) -> EnemyActor:
	n.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":1})
	var actor: EnemyActor = n.manager.get_living_enemies().back()
	actor.global_position = position
	actor.hp = 10000
	return actor

func run(t: SceneTree) -> void:
	await slash(t)
	await dash(t)
	await fear(t)

func slash(t: SceneTree) -> void:
	var n := fixture(t)
	var cast = n.skills.skills.skill_rapid_slash
	var radius := float(cast.levels[0].Range)
	var inside := enemy(n,n.player.global_position+Vector2(radius*0.5,0))
	var outside := enemy(n,n.player.global_position+Vector2(radius+1,0))
	var combat_rng: int = n.manager._random.state
	cast.start(0)
	var effect: Dictionary = n.skills.effects.back()
	t.check(effect.lines.size()==4 and effect.widths==[9.0,9.0,9.0,9.0] and is_equal_approx(effect.until-effect.at,0.25),"FX02 slash four keyed lines with .25 lifetime")
	t.check(inside.hp==10000-int(cast.snapshot.Damage) and outside.hp==10000 and n.manager._random.state==combat_rng,"FX02 extended light does not change damage radius or combat RNG")
	t.check(effect.stars.size()==1 and effect.stars[0]==inside.global_position,"FX02 stars only on actually damaged enemies")
	var correct := true
	for line in effect.lines:
		var center: Vector2 = (line[0]+line[1])*0.5
		var offset: float = center.distance_to(n.player.global_position)
		correct = correct and is_equal_approx(Vector2(line[0]).distance_to(line[1]),sqrt(radius*radius-offset*offset)*2*1.5)
	t.check(correct,"FX02 slash light length is chord times1.5")
	for i in range(5): enemy(n,n.player.global_position+Vector2(20,i))
	n.skills._physics_process(0.121)
	t.check(effect.stars.is_empty(),"FX02 stars expire after .12")
	t.check(n.skills.effects.back().stars.size()==4,"FX02 stars capped at keyed maximum4")
	n.skills._physics_process(0.279)
	var last: Dictionary = n.skills.effects.back()
	t.check(last.finishing and last.lines.size()==6 and last.widths.slice(4)==[16.0,16.0],"FX02 last tick adds two X lights")
	t.check(n.skills.screen_fx.white_remaining>0 and n.skills.screen_fx.strength==5,"FX02 last tick flash and shake5")
	n.skills._physics_process(0.251)
	t.check(n.skills.effects.is_empty(),"FX02 slash arrays empty after last light lifetime")
	await cleanup(t,n)

func dash(t: SceneTree) -> void:
	var n := fixture(t)
	await t.physics_frame
	await t.physics_frame
	Input.action_press("move_right")
	var before: Vector2 = n.player.global_position
	var stats: Dictionary = n.skills.skills.skill_dash.levels[0]
	n.skills._dash_start(stats,0)
	var fx: Node2D = n.skills.cartoon_fx
	t.check(fx.speedlines.size()==9 and fx.puffs.size()==5,"FX02 dash nine speedlines five departure puffs")
	var lengths := true
	for line in fx.speedlines:
		var distance: float = Vector2(line.a).distance_to(line.b)
		lengths = lengths and distance>=float(stats.Distance)*0.4 and distance<=float(stats.Distance)*0.8 and is_zero_approx(Vector2(line.b-line.a).y)
	t.check(lengths,"FX02 speedlines parallel path lengths40-80percent")
	n.player._physics_process(0.05)
	t.check(is_equal_approx(n.player.sprite_body.pose_snapshot().motion_transform.determinant(),1.25*0.9),"FX02 dash snapshot includes image-only stretch")
	n.player._physics_process(0.05)
	n.player._physics_process(0.05)
	t.check(is_equal_approx(n.player.global_position.distance_to(before),float(stats.Distance)),"FX02 dash movement distance unchanged")
	t.check(n.player.dash_trails.size()==8,"FX02 player trail spacing .02 gives eight samples in .15")
	n.player._physics_process(0.04)
	t.check(is_equal_approx(n.player.dash_land_remaining,0.04),"FX02 landing recovery lasts configured .08")
	var trails_ok := true
	var last_alpha := 0.0
	for copy in n.player.dash_trails:
		trails_ok = trails_ok and copy.opacity>=last_alpha and copy.opacity<=0.45 and copy.lifetime==0.3 and copy.sprite_body.sprite_tint==Color("#8a6bff")
		last_alpha = copy.opacity
	t.check(trails_ok,"FX02 player trails tinted and rear alpha lower within original lifetime/cap")
	fx._process(0)
	t.check(fx.puffs.size()==8 and fx.dash_track.is_empty(),"FX02 arrival adds three puffs and clears tracking")
	fx._process(0.251)
	t.check(fx.puffs.is_empty() and fx.speedlines.is_empty(),"FX02 dash arrays empty after keyed lifetimes")
	for copy in n.player.dash_trails: copy._physics_process(0.301)
	await t.process_frame
	n.player.update_dash_trail_alpha()
	t.check(n.player.dash_trails.is_empty(),"FX02 expired player trail nodes and references cleared")
	Input.action_release("move_right")
	await cleanup(t,n)

func fear(t: SceneTree) -> void:
	var n := fixture(t)
	var cast = n.skills.skills.skill_dragon_fear
	cast.level = 1
	var stats: Dictionary = cast.levels[0]
	var inside := enemy(n,n.player.global_position+Vector2(float(stats.Range)-1,0))
	var outside := enemy(n,n.player.global_position+Vector2(float(stats.Range)+1,0))
	var combat_rng: int = n.manager._random.state
	cast.start(0)
	var waves: Array = n.map.get_children().filter(func(node: Node) -> bool: return node.get_script()==preload("res://scripts/dragon_fear_fx.gd"))
	var wave: Node2D = waves[0]
	t.check(waves.size()==1 and wave.waves.size()==3 and wave.claws.size()==8 and wave.bats.size()==40,"FX02 fear one batch with three waves eight claws forty bats")
	t.check(inside.is_feared() and not outside.is_feared() and wave.radius==float(stats.Range) and n.manager._random.state==combat_rng,"FX02 fear Range duration and combat RNG unchanged")
	t.check(wave.wave_radius(float(stats.Cast_sec))==900 and is_equal_approx(float(wave.waves[2].delay),0.16),"FX02 visual waves900 delayed .08 independently of Range")
	var sizes := true
	for bat in wave.bats: sizes = sizes and float(bat.size)>=8 and float(bat.size)<=14
	t.check(sizes,"FX02 bat size8-14")
	var screen: CanvasLayer = n.skills.screen_fx
	screen.settings = screen.settings.duplicate()
	screen.settings.Shake_enabled = "0"
	screen.kick(8,0.25,0.15)
	screen.flash_white(0.35,0.05)
	screen.set_slash_active(true)
	screen._process(0.01)
	t.check(screen.shake_offset==Vector2.ZERO and screen.flash_remaining>0 and screen.white_remaining>0 and screen.vignette_remaining>0 and screen.slash_alpha>0 and not screen.screen.visible and screen.dim_rect.visible and screen.flash_rect.visible and screen.white_rect.visible and screen.vignette_rect.visible,"OPT01 shake disabled preserves ColorRect/vignette overlays without screen sampling")
	screen.set_slash_active(false)
	screen._process(float(stats.Cast_sec)+0.61)
	t.check(not screen.screen.visible and screen.slash_alpha==0,"FX02 screen transient values return to zero")
	wave._process(float(stats.Cast_sec)+0.001)
	t.check(wave.waves.size()==2 and wave.claws.is_empty(),"FX02 first wave expires while delayed waves remain")
	wave._process(wave.lifetime()+0.001)
	t.check(wave.waves.is_empty() and wave.bats.is_empty() and wave.claws.is_empty() and wave.is_queued_for_deletion(),"FX02 fear arrays empty and node freed at keyed lifetime")
	var heads: Array = n.player.character_view.get_children().filter(func(node: Node) -> bool: return node.get_script()==preload("res://scripts/dragon_fear_fx.gd"))
	for head in heads: head._process(float(stats.Cast_sec)+0.001)
	await t.process_frame
	t.check(n.map.get_children().filter(func(node: Node) -> bool: return node.get_script()==preload("res://scripts/dragon_fear_fx.gd")).is_empty(),"FX02 expired fear world batch removed")
	await cleanup(t,n)

func measure(t: SceneTree) -> void:
	var n := fixture(t)
	n.manager._max_alive = 150 # Benchmark-only capacity; no game CSV change.
	for i in range(150): enemy(n,n.player.global_position+Vector2.RIGHT.rotated(TAU*i/150.0)*40)
	var count: int = n.manager.get_alive_count()
	t.check(count==150,"FX02 measurement fixture has150 real spawned enemies")
	n.skills.skills.skill_dragon_fear.level = 1
	var started := Time.get_ticks_usec()
	n.skills.skills.skill_rapid_slash.start(0)
	n.skills.skills.skill_dragon_fear.start(0)
	var elapsed := Time.get_ticks_usec()-started
	var result := {"enemies":count,"elapsed_us":elapsed,"elapsed_ms":elapsed/1000.0,"samples":1,"rendering_included":false,"includes_damage_fear_and_fx_creation":true,"pass_threshold":null}
	var file := FileAccess.open("res://.local/fx-02-performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	file.close()
	print("FX02 PERFORMANCE ",JSON.stringify(result))
	await cleanup(t,n)
