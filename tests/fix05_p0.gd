extends RefCounted
# FIX-05: 0.8x boss bar with the name over the crest, rapid slash finish sound / per-cast fade / beat
# effects / beat span, heal as a repeatable weighted candidate, logo above the loading bar.
const UI = preload("res://scripts/system_ui.gd")

func run(t: SceneTree) -> void:
	var store: CsvDataStore = t._store()
	t.check(store.load_all().is_empty(),"FIX05 actual data loads")
	await boss_bar(t)
	await rapid(t)
	await heal(t,store)
	await logo(t)

func fixture(t: SceneTree) -> Dictionary:
	return preload("res://tests/fx03_p0.gd").new().fixture(t)

func spawn(n: Dictionary, boss_id: String, at: float) -> Node2D:
	return preload("res://tests/fix03_p0.gd").new().spawn(n,boss_id,at)

func boss_bar(t: SceneTree) -> void:
	var n := fixture(t)
	var bar: Control = n.director.boss_bar
	var frame_box := Rect2(bar.frame.position,bar.frame.size*bar.frame.scale)
	t.check(is_equal_approx(frame_box.size.x,480) and is_equal_approx(bar.frame.scale.x,0.8) and is_equal_approx(frame_box.size.y,47.6),"FIX05 frame 480 wide drawn at 0.8 (height 22 + 2 x (9.6 + 3.2) = 47.6)")
	t.check(is_equal_approx(bar.fill.size.y,22) and is_equal_approx(bar.fill.size.x,435.2) and bar.fill.position.is_equal_approx(frame_box.position+Vector2(22.4,12.8)),"FIX05 fill 435.2x22 inside the scaled border line + scaled padding")
	t.check(bar.crest.size.is_equal_approx(Vector2(96,34)*1.2) and bar.name_label.get_theme_font_size("font_size")==22 and bar.name_label.get_theme_color("font_outline_color")==Color("#1a1240"),"FIX05 crest 1.2x and name 22px with outline")
	var visible_top: float = bar.crest.position.y+6*1.2
	var name_center: float = bar.name_label.position.y+bar.name_label.size.y/2
	t.check(is_equal_approx(name_center,visible_top+(bar.crest.size.y-6*1.2)*0.333) and bar.name_label.get_index()>bar.crest.get_index() and bar.name_label.position.y>=0,"FIX05 name laid over the crest, centred a third down its visible height")
	var crest_bottom: float = bar.crest.position.y+bar.crest.size.y
	t.check(is_equal_approx(crest_bottom,bar.fill.position.y) and crest_bottom>frame_box.position.y,"FIX05 crest overlaps the frame top down to the fill's top edge without covering it")
	var height: float = bar.offset_bottom-bar.offset_top
	print("FIX05 boss bar stack height ",height," name top ",bar.name_label.position.y," crest top ",bar.crest.position.y," frame top ",frame_box.position.y)
	t.check(height<=76.0 and is_equal_approx(height,frame_box.end.y),"FIX05 name + crest + frame stack is about 75px ("+str(height)+")")
	var bear: Node2D = spawn(n,"boss_middle",100)
	var view: Control = n.director.toast_view
	t.check(bar.visible and is_equal_approx(view.stack_offset,bar.bottom_px()+6-float(view.presentation.Toast_top_px)) and is_equal_approx(bar.bottom_px(),18+height),"FIX05 toasts start right below the shorter bar")
	var box: Rect2 = bar.get_global_rect()
	for id in ["PlayerLevel","ElapsedTime","ExperienceAmount","TopExperienceBar"]:
		var other: Control = n.host.find_child(id,true,false)
		t.check(other!=null and not box.intersects(other.get_global_rect()),"FIX05 smaller bar clear of "+id)
	bear.apply_damage(330)
	t.check(is_equal_approx(bar.fill.size.x,435.2*bear.hp/bear.max_hp) and is_equal_approx(bar.trail_ratio(),1) and bar.is_processing(),"FIX05 fill follows hp and trail waits")
	bar._process(0.25)
	bar._process(0.35)
	t.check(is_equal_approx(bar.trail.size.x,bar.fill.size.x) and not bar.is_processing(),"FIX05 trail drains and stops")
	bear.apply_damage(bear.hp)
	var elf: Node2D = spawn(n,"boss_early",200)
	elf.elf.start_stealth()
	t.check(not bar.visible,"FIX05 bar hides during stealth")
	elf.elf.end_stealth(n.manager._elapsed_seconds)
	t.check(bar.visible,"FIX05 bar returns after stealth")
	n.host.free()
	await t.process_frame

func count(audio: Node, id: String) -> int:
	return int(audio.request_counts.get(id,0))

func trace_cast(n: Dictionary, enemy: Node2D) -> Dictionary:
	var skills: Node2D = n.skills
	var slash = skills.skills.skill_rapid_slash
	slash.cooldown_until = 0
	enemy.hp = enemy.max_hp
	skills.effects.clear()
	skills.try_use("skill_rapid_slash")
	var trace: Array = []
	var lines: Array = []
	var seen: Dictionary = {}
	for i in range(60):
		trace.append([snappedf(skills.clock-slash.started_at,0.0001),enemy.hp,slash.hits_done])
		# Expired entries leave the front of the list, so track entries by their hit time.
		for effect in skills.effects:
			if effect.has("lines") and not seen.has(effect.at):
				seen[effect.at] = true
				lines.append([snappedf(float(effect.at)-slash.started_at,0.0001),effect.lines.size(),effect.stars.size()])
		if not slash.active: break
		skills._physics_process(1.0/60.0)
	return {"trace":trace,"lines":lines,"span":slash.completed_at-slash.started_at}

func rapid(t: SceneTree) -> void:
	var n := fixture(t)
	var audio: Node = t.root.get_node("GameAudio")
	var skills: Node2D = n.skills
	var player: Node2D = n.player
	t.check(audio.sounds.has("rapid_slash_finish") and int(audio.sounds.rapid_slash_finish.max)==2 and is_equal_approx(audio.sounds.rapid_slash_finish.pitch,0.05) and is_equal_approx(audio.sounds.rapid_slash_finish.volume,0) and is_equal_approx(audio.sounds.rapid_slash_finish.interval,0),"FIX05 rapid_slash_finish registered with volume 0, two voices, pitch .05")
	n.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":1})
	var enemy: Node2D = n.manager.get_living_enemies().back()
	enemy.global_position = player.global_position+Vector2(40,0)
	enemy.max_hp = 100000
	player.last_move_direction = Vector2.RIGHT
	for i in range(2,audio.pool.size()): audio.pool[i].stop(); audio.pool[i].set_meta(&"sound","")
	audio.fades.clear()
	var before := {"finish":count(audio,"rapid_slash_finish"),"rapid":count(audio,"rapid_slash")}
	var slash = skills.skills.skill_rapid_slash
	slash.cooldown_until = 0
	skills.try_use("skill_rapid_slash")
	var stats: Dictionary = slash.snapshot
	var interval := float(stats.Hit_interval_sec)
	var span := (int(stats.Hits)-1)*interval
	var beat_times: Array = [0.0]
	var last_beat: int = skills.combo_beat
	while slash.active:
		skills._physics_process(1.0/60.0)
		if skills.combo_beat!=last_beat and skills.combo_beat>=0:
			beat_times.append(snappedf(skills.clock-slash.started_at,0.0001))
			last_beat = skills.combo_beat
	var length := span/3.0
	t.check(beat_times.size()==3 and beat_times[1]>=length-0.0001 and beat_times[1]<length+1.0/60.0+0.0001 and beat_times[2]>=2*length-0.0001 and beat_times[2]<2*length+1.0/60.0+0.0001,"FIX05 beats switch at (Hits-1) x interval / 3 steps: "+str(beat_times))
	t.check(is_equal_approx(slash.completed_at-slash.started_at,span),"FIX05 the last beat ends at the last hit (cast end)")
	t.check(count(audio,"rapid_slash_finish")==before.finish+1 and count(audio,"rapid_slash")==before.rapid,"FIX05 beat 3 plays rapid_slash_finish once and rapid_slash not at all")
	var handles: Array = audio.fades.back().handles if not audio.fades.is_empty() else []
	t.check(handles.size()==3 and is_equal_approx(audio.fades.back().delay,0.1) and is_equal_approx(audio.fades.back().fade,0.06),"FIX05 cast end schedules its three plays to fade after .1s over .06s")
	var playing_now: int = handles.filter(func(h: Array) -> bool: return audio.handle_playing(h)).size()
	var other_ok: bool = audio.request("slash")
	var other: Array = [audio.last_voice,audio.last_play_id]
	audio._advance_fades(0.1)
	var still: int = handles.filter(func(h: Array) -> bool: return audio.handle_playing(h)).size()
	audio._advance_fades(0.07)
	var after: int = handles.filter(func(h: Array) -> bool: return audio.handle_playing(h)).size()
	print("FIX05 cast sounds playing at end ",playing_now," after tail ",still," after fade ",after," other ",audio.handle_playing(other))
	t.check(after==0 and audio.fades.is_empty(),"FIX05 the cast's sounds are stopped after tail + fade")
	t.check(other_ok and audio.handle_playing(other),"FIX05 a slash sound from another attack keeps playing")
	for i in range(2,audio.pool.size()): audio.pool[i].stop(); audio.pool[i].set_meta(&"sound","")
	slash.cooldown_until = 0
	skills.try_use("skill_rapid_slash")
	skills._physics_process(1.0/60.0)
	var cut_handles: Array = skills.combo_handles.duplicate()
	skills.skills.skill_stealth.level = 1
	skills.skills.skill_stealth.cooldown_until = 0
	player.stealth_remaining = 0
	skills._stealth_start({"Duration_sec":1.0},skills.clock)
	skills._physics_process(1.0/60.0)
	t.check(not slash.active and skills.combo_handles.is_empty() and not audio.fades.is_empty() and audio.fades.back().handles==cut_handles,"FIX05 a cut cast schedules the same fade for its own plays")
	audio._advance_fades(0.2)
	t.check(cut_handles.all(func(h: Array) -> bool: return not audio.handle_playing(h)),"FIX05 the cut cast's sounds are stopped")
	player.stealth_remaining = 0
	var with_combo := trace_cast(n,enemy)
	t.check(with_combo.lines.size()==int(stats.Hits),"FIX05 one effect entry per hit")
	var lines_ok := true
	for entry in with_combo.lines:
		var beat := 2 if span<=0.000001 else clampi(floori((float(entry[0])+0.000000001)/length),0,2)
		lines_ok = lines_ok and ((entry[1]>0)==(beat==2))
	t.check(lines_ok,"FIX05 rapid slash lines only in beat 3, none in beats 1-2: "+str(with_combo.lines))
	skills.presentation.Rapid_combo_beats = 0
	var without := trace_cast(n,enemy)
	skills.presentation.Rapid_combo_beats = 3
	var stars_same := true
	for i in range(with_combo.lines.size()): stars_same = stars_same and with_combo.lines[i][2]==without.lines[i][2] and with_combo.lines[i][0]==without.lines[i][0]
	t.check(with_combo.trace==without.trace and is_equal_approx(with_combo.span,without.span) and stars_same,"FIX05 damage, hit count, hit times and hit marks match the combo-off cast")
	t.check(without.lines.all(func(e: Array) -> bool: return e[1]>0),"FIX05 with the combo off every hit keeps its lines")
	var saved: Dictionary = slash.snapshot
	slash.snapshot = saved.duplicate()
	slash.snapshot.Hits = 1
	slash.started_at = skills.clock
	t.check(skills.beat_at(skills.clock)==2,"FIX05 a one-hit cast is the last beat only")
	slash.snapshot = saved
	t.paused = false
	n.host.free()
	await t.process_frame

func heal(t: SceneTree, store: CsvDataStore) -> void:
	var row: Dictionary = store.get_row("choice.csv","choice_heal")
	t.check(int(row.Weight)==10 and is_equal_approx(float(store.get_row("choice_level.csv","choice_heal_01").Value),30),"FIX05 choice_heal Weight 10 and 30 percent value")
	var n := fixture(t)
	var choices: Node = n.choices
	var player: Node2D = n.player
	t.check(choices.candidates().has("choice_heal") and choices.candidates().size()>3,"FIX05 heal is a candidate next to the others")
	choices.random.seed = 20261117
	var mixed := false
	for i in range(200):
		var cards: Array = choices.draw_cards()
		if cards.has("choice_heal") and cards.filter(func(id: String) -> bool: return id!="choice_heal").size()==2: mixed = true
	t.check(mixed,"FIX05 heal is drawn together with two other choices")
	player.hp = 40
	player.add_experience(player.get_xp_to_next())
	choices.cards = ["choice_heal","choice_attack_range","choice_pickup_radius"]
	choices.select(0)
	t.check(player.hp==mini(player.max_hp,40+floori(player.max_hp*0.3)) and choices.candidates().has("choice_heal"),"FIX05 heal keeps its 30 percent effect and stays in the pool after being chosen")
	for id in choices.levels: choices.levels[id] = choices.level_rows[id].size()
	var only: Array = choices.draw_cards()
	t.check(only==["choice_heal","choice_heal","choice_heal"] and choices.candidates()==["choice_heal"],"FIX05 with nothing else left the screen still fills with heal")
	t.paused = false
	n.host.free()
	await t.process_frame

func logo(t: SceneTree) -> void:
	var flow := preload("res://scripts/game_flow.gd").new()
	t.root.add_child(flow)
	var ui: Control = flow.ui
	var box: Rect2 = ui.logo.get_rect()
	var bar: Rect2 = ui.progress.get_rect()
	print("FIX05 logo ",box," bar ",bar)
	t.check(bar.position.y-box.end.y>=24-0.001 and box.position.y>=24 and box.size.is_equal_approx(Vector2(640,640.0*734/1394)),"FIX05 logo bottom 24px above the loading bar, top below 24px, size kept")
	t.check(is_equal_approx(box.get_center().x,640),"FIX05 logo stays centred")
	flow.free()
	await t.process_frame
