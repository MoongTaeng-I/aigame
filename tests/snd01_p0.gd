extends RefCounted
const Events = preload("res://scripts/audio_events.gd")

func total(a: Node, id: String) -> int: return int(a.request_counts.get(id,0))

func run(t: SceneTree) -> void:
	var audio: Node = t.root.get_node("GameAudio")
	t.check(audio.pool.size()==16 and audio.sounds.size()==26 and AudioServer.get_bus_index("BGM")>=0 and AudioServer.get_bus_index("SFX")>=0,"SND01 one manager sixteen fixed voices three buses twentysix streams (FIX03)")
	for id in ["bgm_title","bgm_stage01","bgm_boss"]: t.check(audio.sounds[id].stream.loop,"SND01 BGM imported/loaded looping "+id)
	for i in range(2,16): audio.pool[i].stop()
	audio.clock+=10
	t.check(audio.request("xp_pickup") and not audio.request("xp_pickup"),"SND01 xp pickup min interval .05")
	for i in range(2,16): audio.pool[i].stop()
	for j in range(3): audio.clock+=0.06; audio.request("xp_pickup")
	audio.clock+=0.06
	t.check(not audio.request("xp_pickup"),"SND01 xp max concurrent three")
	for i in range(2,16): audio.pool[i].stop()
	for i in range(20): audio.request("slash")
	t.check(audio.pool.filter(func(p: AudioStreamPlayer) -> bool: return p.playing and p.bus=="SFX").size()<=3 and audio.pool.size()==16,"SND01 per sound concurrency and global pool fixed")
	t.check(audio.pool.all(func(p: AudioStreamPlayer) -> bool: return p.bus=="BGM" or p.pitch_scale>=0.95 and p.pitch_scale<=1.05),"SND01 pitch random confined .95 to1.05")
	for id in ["bgm_title","bgm_stage01","bgm_boss","bgm_stage01",""]:
		audio.music(id); audio._process(1)
	t.check(audio.music_id=="" and not audio.pool[0].playing and not audio.pool[1].playing,"SND01 title stage boss stage fadeout ends silence")
	var n: Dictionary = preload("res://tests/fx03_p0.gd").new().fixture(t)
	var before := total(audio,"xp_pickup")
	n.player.add_experience(1)
	t.check(total(audio,"xp_pickup")==before+1,"SND01 actual XP event requests once")
	before = total(audio,"player_hurt")
	n.player.apply_damage(1)
	t.check(total(audio,"player_hurt")==before+1,"SND01 accepted player damage event once")
	before = total(audio,"shadow_summon")
	n.shadows.summon("igrit")
	t.check(total(audio,"shadow_summon")==before+1,"SND01 summon event once")
	before = total(audio,"rapid_slash")
	n.skills.try_use("skill_rapid_slash")
	n.skills._physics_process(0.2)
	t.check(total(audio,"rapid_slash")==before+1,"SND01 rapid slash start once without per tick sound")
	var hud: Node = n.map.get_node("TemporaryHud")
	t.check(hud.xp_bar.offset_bottom==14 and is_equal_approx(n.skills.ui.glyphs[0].size.x,56*1.35),"SND01 XP bar14 and icon1.35")
	var cast = n.skills.skills.skill_dash
	cast.snapshot = cast.levels[0].duplicate(true)
	cast.active = false; cast.completed_at = 0; cast.cooldown_until = float(cast.snapshot.Cooldown_sec)
	n.skills.clock = float(cast.snapshot.Cooldown_sec)/2
	t.check(is_equal_approx(n.skills.ui.cooldown_ratio("skill_dash"),0.5),"SND01 cover ratio equals remaining over cooldown")
	n.skills.ui._process(0)
	n.skills.clock = cast.cooldown_until
	n.skills.ui._process(0)
	t.check(n.skills.ui.ready_flash[0]==0.25,"SND01 ready transition triggers .25 white edge")
	n.player.add_experience(n.player.get_xp_to_next())
	audio._process(0)
	t.check(t.paused and n.choices.active and audio.choice_pause() and audio.request("ui_click") and not audio.request("enemy_hit"),"SND01 selection pause permits level/UI only and stops game sounds")
	t.check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM")),audio.bgm_db+linear_to_db(0.5)),"SND01 paused BGM half linear volume")
	n.choices.select(0)
	n.host.free(); t.paused = false; await t.process_frame
	var flow := preload("res://scripts/game_flow.gd").new(); t.root.add_child(flow)
	while flow.state=="loading": await t.process_frame
	flow.ui.sound_sliders.BGM.value = 50
	flow.ui.sound_sliders.SFX.value = 0
	var sfx_bus := AudioServer.get_bus_index("SFX")
	t.check(is_equal_approx(audio.bgm_db,float(audio.settings.Sound_bgm_db)+linear_to_db(0.5)) and AudioServer.is_bus_mute(sfx_bus) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("BGM")),"SND01 sliders update separate buses (FX06 0-100 levels, 0 mutes)")
	var texts: Array = flow.ui.settings.find_children("*","Label",true,false).filter(func(label: Label) -> bool: return label.name!="Value" and not (label.text in ["배경음악","효과음"])).map(func(label: Label) -> String: return label.text)
	t.check(flow.ui.settings.find_child("SoundCredits",true,false)==null and texts==[],"SND01 settings show no notice, font or sound credit lines (FIX03)")
	flow.start_region(); flow.toggle_pause(); audio._process(0)
	t.check(not audio.choice_pause() and not audio.request("ui_click") and audio.pool.slice(2).all(func(p: AudioStreamPlayer) -> bool: return not p.playing),"SND01 ESC pause stops all SFX")
	flow.free();t.paused = false
	audio.set_level("BGM",100);audio.set_level("SFX",100);audio.music("bgm_title")
	await t.process_frame
	await event_paths(t,audio)
	await preload("res://tests/ui_glyph_p0.gd").new().run(t)

func event_paths(t: SceneTree, audio: Node) -> void:
	var n: Dictionary = preload("res://tests/fx03_p0.gd").new().fixture(t)
	n.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":1})
	var enemy: Node2D = n.manager.get_living_enemies().back()
	enemy.position = n.player.position+Vector2(60,0); enemy.hp = 1000
	var slash := total(audio,"slash"); var thrust := total(audio,"thrust"); var hit := total(audio,"enemy_hit")
	n.player.update_basic_attack(0,[enemy])
	enemy.knockback_elapsed = enemy.knockback_duration
	n.player.update_basic_attack(0.15,[enemy])
	t.check(total(audio,"slash")==slash+1 and total(audio,"thrust")==thrust+1 and total(audio,"enemy_hit")==hit+2,"SND01 actual odd/even basic strikes each request once and every accepted enemy hit requests")
	var die := total(audio,"enemy_die")
	enemy.apply_damage(enemy.hp)
	t.check(total(audio,"enemy_die")==die+1,"SND01 normal kill requests once")
	n.manager._spawn_from_row({"Enemy_id":"enemy_test_ranged","Spawn_count":1})
	var ranged: Node2D = n.manager.get_living_enemies().back()
	ranged.position = n.player.position+Vector2(100,0)
	ranged.shot_elapsed = ranged.shot_interval_sec
	var arrow := total(audio,"arrow_shot")
	n.manager._update_enemy_shot(ranged,0)
	t.check(total(audio,"arrow_shot")==arrow+1,"SND01 actual elf projectile launch requests once")
	var notify := total(audio,"system_notify"); var warning := total(audio,"boss_warning")
	n.director.toast_view.push_message("일반 알림")
	n.director.toast_view.push_message("보스 알림",1,true)
	t.check(total(audio,"system_notify")==notify+1 and total(audio,"boss_warning")==warning+1,"SND01 normal and boss toast select distinct sounds once")
	n.host.free(); await t.process_frame
	for id in ["skill_dash","skill_stealth","skill_dragon_fear"]:
		n = preload("res://tests/fx03_p0.gd").new().fixture(t)
		n.skills.skills[id].level = 1
		var name: String = id.trim_prefix("skill_")
		var before := total(audio,name)
		n.skills.try_use(id)
		t.check(total(audio,name)==before+1,"SND01 actual skill start once "+id)
		n.host.free(); await t.process_frame
	var a := total(audio,"igris_slash"); var b := total(audio,"beru_claw"); var c := total(audio,"belion_chain")
	await preload("res://tests/fx04_p0.gd").new().shadows(t)
	t.check(total(audio,"igris_slash")==a+2 and total(audio,"beru_claw")==b+1 and total(audio,"belion_chain")==c+2,"SND01 actual two Igris hit times Beru start and two alternating Belion starts each request once")
	var store: CsvDataStore = t._store(); store.load_all()
	n = preload("res://tests/fx03_p0.gd").new().fixture(t)
	var rows: Array = []
	for row in store.get_table("boss_action.csv").values():
		if row.Boss_id=="boss_middle": rows.append(row)
	var boss: Node2D = n.manager.create_boss("boss_ice_bear",rows,func() -> Node2D: return n.player)
	var gate := total(audio,"gate_open")
	n.manager.activate_boss(boss)
	t.check(total(audio,"gate_open")==gate+1 and audio.music_id=="bgm_boss","SND01 direct gate opens once and active boss switches music")
	var slam := total(audio,"boss_slam")
	boss.start_action(store.get_row("boss_action.csv","ice_bear_slam"),n.player.position)
	boss.clock = boss.phase_end; boss.advance_action()
	t.check(total(audio,"boss_slam")==slam+1,"SND01 actual bear slam judgment requests once")
	boss.apply_damage(boss.hp)
	t.check(audio.music_id=="bgm_stage01","SND01 actual boss death restores stage music")
	n.host.free(); await t.process_frame
	slam = total(audio,"boss_slam")
	await preload("res://tests/fx05_p0.gd").new().action_hooks(t,store)
	t.check(total(audio,"boss_slam")==slam+1,"SND01 actual Baruka ice-zone execution requests once")
