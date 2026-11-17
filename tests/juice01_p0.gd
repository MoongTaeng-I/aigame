extends RefCounted
# JUICE-01: presentation-only juice. xp absorb + pitch ladder, boss bar trail, kill pop, low-hp warning,
# zoom punch, fear vignette colour, toast border gap, boss bar polish and stealth hiding.
const EPS := 0.01

func run(t: SceneTree) -> void:
	var store: CsvDataStore = t._store()
	t.check(store.load_all().is_empty(),"JUICE01 actual data loads")
	keys(t)
	await experience(t)
	await trail(t)
	await kill_pop(t)
	await low_hp(t)
	await zoom(t)
	await toast_gap(t)
	await bar_polish(t)

func fixture(t: SceneTree) -> Dictionary:
	return preload("res://tests/fx03_p0.gd").new().fixture(t)

func spawn(n: Dictionary, boss_id: String, at: float) -> Node2D:
	return preload("res://tests/fix03_p0.gd").new().spawn(n,boss_id,at)

func keys(t: SceneTree) -> void:
	var v: Dictionary = preload("res://scripts/shadow_afterimage.gd").compiled_presentation()
	t.check(v.Fear_color==Color("#8a0012") and is_equal_approx(v.Fear_vignette_alpha,0.5),"JUICE01 fear vignette colour 8a0012 alpha .5")
	t.check(is_equal_approx(v.Xp_absorb_stretch,1.6) and is_equal_approx(v.Xp_absorb_trail_alpha,0.35) and is_equal_approx(v.Xp_pickup_flash_sec,0.12) and is_equal_approx(v.Xp_pickup_flash_px,14) and int(v.Xp_flash_pool)==12 and is_equal_approx(v.Xp_pitch_reset_sec,0.5) and int(v.Xp_pitch_max_semitones)==12,"JUICE01 experience keys")
	t.check(v.Boss_bar_trail_color==Color("#ffffff") and is_equal_approx(v.Boss_bar_trail_alpha,0.75) and is_equal_approx(v.Boss_bar_trail_delay_sec,0.25) and is_equal_approx(v.Boss_bar_trail_drain_sec,0.35),"JUICE01 boss trail keys")
	t.check(is_equal_approx(v.Kill_pop_scale,1.15) and is_equal_approx(v.Kill_pop_sec,0.08) and is_equal_approx(v.Kill_fling_px,10) and is_equal_approx(v.Kill_fling_sec,0.12),"JUICE01 kill pop keys")
	t.check(is_equal_approx(v.Low_hp_ratio,0.3) and v.Low_hp_color==Color("#c8102e") and is_equal_approx(v.Low_hp_beat_hz,1.2) and is_equal_approx(v.Low_hp_alpha_min,0.1) and is_equal_approx(v.Low_hp_alpha_max,0.35) and is_equal_approx(v.Low_hp_fade_sec,0.3) and is_equal_approx(v.Low_hp_bgm_lowpass_hz,1200),"JUICE01 low hp keys")
	t.check(int(v.Zoom_punch_enabled)==1 and is_equal_approx(v.Zoom_punch_scale,1.03) and is_equal_approx(v.Zoom_punch_in_sec,0.06) and is_equal_approx(v.Zoom_punch_out_sec,0.18) and is_equal_approx(v.Toast_visual_gap_px,6),"JUICE01 zoom and toast gap keys")
	t.check(int(v.Boss_bar_name_font_size)==22 and int(v.Boss_bar_border_px)==2 and v.Boss_bar_border_color==Color("#ece6ff") and is_equal_approx(v.Boss_bar_border_alpha,0.9) and int(v.Boss_bar_inner_line_px)==1 and v.Boss_bar_inner_line_color==Color("#1a1240") and int(v.Boss_bar_name_outline_px)==2 and v.Boss_bar_name_outline_color==Color("#1a1240"),"JUICE01 boss bar polish keys (FIX05 name 22)")

func experience(t: SceneTree) -> void:
	var audio: Node = t.root.get_node("GameAudio")
	var saved_clock: float = audio.clock
	var saved_last: Dictionary = audio.last_play.duplicate()
	audio.xp_last_pickup = -INF
	audio.clock = 1000.0
	var ladder: Array = []
	for i in range(15):
		audio.request("xp_pickup")
		ladder.append(audio.xp_semitones)
		audio.clock += 0.1
	t.check(ladder==[0,1,2,3,4,5,6,7,8,9,10,11,12,12,12],"JUICE01 xp pitch ladder +1 per pickup within .5s capped at +12: "+str(ladder))
	# The loop already advanced .1s after the last pickup; .39 more makes it .49s.
	audio.clock += 0.39
	audio.request("xp_pickup")
	t.check(audio.xp_semitones==12,"JUICE01 pickup .49s later keeps the ladder (held at the cap)")
	audio.clock += 0.51
	audio.request("xp_pickup")
	t.check(audio.xp_semitones==0,"JUICE01 pitch ladder resets to 0 after .5s without pickups")
	audio.clock += 0.3
	for i in range(2,audio.pool.size()): audio.pool[i].stop(); audio.pool[i].set_meta(&"sound","")
	audio.request("xp_pickup")
	var voice: AudioStreamPlayer = null
	for i in range(2,audio.pool.size()):
		if audio.pool[i].get_meta(&"sound")=="xp_pickup": voice = audio.pool[i]
	var expected := pow(2.0,1.0/12.0)
	t.check(audio.xp_semitones==1 and voice!=null and voice.pitch_scale>=expected*(1-0.05)-0.000001 and voice.pitch_scale<=expected*(1+0.05)+0.000001,"JUICE01 ladder pitch multiplies the existing random pitch")
	t.check(int(audio.sounds.xp_pickup.max)==3 and is_equal_approx(audio.sounds.xp_pickup.interval,0.05) and is_equal_approx(audio.sounds.xp_pickup.pitch,0.05),"JUICE01 xp_pickup Max_concurrent Min_interval Pitch_random unchanged")
	for i in range(2,audio.pool.size()): audio.pool[i].stop(); audio.pool[i].set_meta(&"sound","")
	audio.clock = saved_clock
	audio.last_play = saved_last
	audio.xp_last_pickup = -INF
	audio.xp_semitones = 0
	var n := fixture(t)
	var xp: Node2D = n.host.find_child("ExperienceManager",true,false)
	xp.set_physics_process(false)
	var flash: Node2D = xp.flash
	t.check(flash!=null and flash.slots.size()==12 and not flash.is_processing() and flash.redraws==0,"JUICE01 pickup flash pool of 12 allocated once and idle")
	n.player.global_position = Vector2(400,400)
	var far: Node2D = xp.drop_experience(Vector2(1400,400),1)
	var near: Node2D = xp.drop_experience(Vector2(470,400),1)
	for i in range(3): xp._physics_process(1.0/60.0)
	t.check(not far.is_pulling and far.redraws==0,"JUICE01 resting orb never redraws")
	t.check(near.is_pulling and near.stretch>1.0 and near.stretch<=1.6+0.000001 and near.pull_direction.is_equal_approx(Vector2.LEFT),"JUICE01 pulled orb stretches along its pull direction within 1.6")
	var level: int = n.player.level
	var exp_before: int = n.player.experience
	for i in range(120):
		if not is_instance_valid(near) or near.collected: break
		xp._physics_process(1.0/60.0)
	t.check(flash.active_count==1 and flash.is_processing() and flash.slots.any(func(s: Dictionary) -> bool: return s.active and s.point==n.player.global_position),"JUICE01 pickup emits one flash at the player position")
	t.check(n.player.experience==exp_before+1 or n.player.level>level,"JUICE01 pickup value and rule unchanged")
	for i in range(30): flash.emit(Vector2.ZERO)
	t.check(flash.slots.size()==12 and flash.active_count==12,"JUICE01 flash pool stays at 12 slots under 30 pickups")
	flash._process(0.13)
	t.check(flash.active_count==0 and not flash.is_processing(),"JUICE01 flashes end after .12s and processing stops")
	n.host.free()
	await t.process_frame

func trail(t: SceneTree) -> void:
	var n := fixture(t)
	var bar: Control = n.director.boss_bar
	var bear: Node2D = spawn(n,"boss_middle",100)
	t.check(bar.visible and is_equal_approx(bar.trail_ratio(),1) and not bar.is_processing(),"JUICE01 trail starts full and idle")
	t.check(bar.trail.get_index()>bar.frame.get_index() and bar.trail.get_index()<bar.fill.get_index() and bar.trail.texture==load("res://assets/ui/ui_boss_bar_trail.png"),"JUICE01 trail sits between frame and fill (FIX04 trail texture)")
	bear.apply_damage(220)
	var after: float = bar.ratio()
	t.check(after<1 and is_equal_approx(bar.trail_ratio(),1) and bar.is_processing(),"JUICE01 fill drops at once and the trail waits")
	bar._process(0.24)
	t.check(is_equal_approx(bar.trail_ratio(),1),"JUICE01 trail holds through .24s")
	bar._process(0.06)
	var mid: float = bar.trail_ratio()
	t.check(mid<1 and mid>after,"JUICE01 trail drains after the .25s wait")
	bear.apply_damage(110)
	t.check(is_equal_approx(bar.trail_ratio(),mid) and bar.ratio()<after,"JUICE01 new hit keeps the trail where it is")
	bar._process(0.24)
	t.check(is_equal_approx(bar.trail_ratio(),mid),"JUICE01 new hit restarts the .25s wait")
	bar._process(0.02)
	bar._process(0.33)
	t.check(not is_equal_approx(bar.trail_ratio(),bar.ratio()) and bar.is_processing(),"JUICE01 drain lasts .35s")
	bar._process(0.02)
	t.check(is_equal_approx(bar.trail_ratio(),bar.ratio()) and not bar.is_processing(),"JUICE01 trail meets the fill and processing stops")
	var updates: int = bar.updates
	for i in range(3): await t.process_frame
	t.check(bar.updates==updates and not bar.is_processing(),"JUICE01 idle boss bar does no per-frame work")
	n.host.free()
	await t.process_frame

func kill_pop(t: SceneTree) -> void:
	var n := fixture(t)
	n.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":1})
	var enemy: Node2D = n.manager.get_living_enemies().back()
	enemy.global_position = n.player.global_position+Vector2(60,0)
	var body: Node2D = enemy.sprite_body
	t.check(body.presentation_transform==Transform2D.IDENTITY and enemy.pop_age<0,"JUICE01 living enemy has no pop transform")
	var spot: Vector2 = enemy.global_position
	enemy.record_damage_presentation("player",n.player)
	enemy.apply_damage(enemy.hp)
	t.check(enemy.is_logically_dead and enemy.pop_age==0 and enemy.last_hit_direction.is_equal_approx(Vector2.RIGHT),"JUICE01 kill starts the pop along attacker to enemy")
	var pivot := Vector2(0,body.foot_y)
	enemy.update_actor(0.08,n.player.global_position,n.manager._get_map_world_rect())
	t.check(is_equal_approx(body.presentation_transform.x.length(),1.15) and enemy.global_position==spot,"JUICE01 pop reaches 1.15 at .08s while the actor stays put")
	enemy.update_actor(0.04,n.player.global_position,n.manager._get_map_world_rect())
	var moved: Vector2 = body.presentation_transform*pivot-pivot
	t.check(moved.is_equal_approx(Vector2(10,0)) and enemy.global_position==spot and enemy.collision_layer==0,"JUICE01 picture flings 10px by .12s with position and collision untouched")
	enemy.update_actor(0.1,n.player.global_position,n.manager._get_map_world_rect())
	t.check((body.presentation_transform*pivot-pivot).is_equal_approx(Vector2(10,0)) and is_equal_approx(body.presentation_transform.x.length(),1.15) and enemy.modulate.a<1,"JUICE01 pop holds while the existing fade continues")
	n.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":1})
	var plain: Node2D = n.manager.get_living_enemies().back()
	plain.apply_damage(plain.hp)
	plain.update_actor(0.12,n.player.global_position,n.manager._get_map_world_rect())
	var plain_pivot := Vector2(0,plain.sprite_body.foot_y)
	t.check((plain.sprite_body.presentation_transform*plain_pivot-plain_pivot).is_zero_approx(),"JUICE01 kill without a hit direction pops in place")
	var bear: Node2D = spawn(n,"boss_middle",100)
	n.manager.boss_fx.advance(2)
	var gate_free: Transform2D = bear.sprite_body.presentation_transform
	bear.record_damage_presentation("player",n.player)
	bear.apply_damage(bear.hp)
	t.check(bear.pop_age<0 and bear.sprite_body.presentation_transform==gate_free,"JUICE01 boss kill keeps its own death presentation without the pop")
	var children: int = n.manager.get_child_count()
	for i in range(20): n.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":1})
	var created: int = n.manager.get_child_count()
	for enemy_item in n.manager.get_living_enemies():
		if not enemy_item.has_method("configure_boss"): enemy_item.apply_damage(enemy_item.hp)
	t.check(n.manager.get_child_count()==created and created>=children,"JUICE01 mass kill pops create no extra nodes")
	n.host.free()
	await t.process_frame

func low_hp(t: SceneTree) -> void:
	var n := fixture(t)
	var audio: Node = t.root.get_node("GameAudio")
	var fx: CanvasLayer = n.low_hp
	var player: Node2D = n.player
	var bgm := AudioServer.get_bus_index("BGM")
	var sfx := AudioServer.get_bus_index("SFX")
	var sfx_effects := AudioServer.get_bus_effect_count(sfx)
	t.check(not fx.active and not fx.is_processing() and not fx.rect.visible and fx.rect.material==null and audio.lowpass_amount==0 and not AudioServer.is_bus_effect_enabled(bgm,audio.lowpass_index()),"JUICE01 low hp idle at full hp with the BGM filter off")
	var edge := int(floor(player.max_hp*0.3))
	player.hp = edge+1
	player.hp_changed.emit()
	t.check(not fx.active and not fx.is_processing(),"JUICE01 hp just above 30 percent stays off")
	player.hp = edge
	player.hp_changed.emit()
	t.check(fx.active and fx.is_processing() and audio.lowpass_target==1.0,"JUICE01 hp at 30 percent turns the warning on")
	fx._process(0.3)
	audio._apply_lowpass(0.3)
	var shown: float = fx.rect.material.get_shader_parameter("strength")
	t.check(fx.rect.visible and shown>=0.1-EPS and shown<=0.35+EPS and fx.rect.material.get_shader_parameter("tint")==Color("#c8102e"),"JUICE01 red vignette beats between .10 and .35")
	var samples: Array = []
	for i in range(40):
		fx._process(1.0/1.2/40.0)
		samples.append(float(fx.rect.material.get_shader_parameter("strength")))
	var peaks := 0
	for i in range(1,samples.size()-1):
		if samples[i]>samples[i-1] and samples[i]>=samples[i+1] and samples[i]>0.2: peaks += 1
	t.check(peaks==2 and samples.max()<=0.35+EPS and samples.min()>=0.1-EPS,"JUICE01 one 1.2Hz period has two heartbeat peaks")
	t.check(is_equal_approx(audio.lowpass.cutoff_hz,1200) and AudioServer.is_bus_effect_enabled(bgm,audio.lowpass_index()) and AudioServer.get_bus_effect_count(sfx)==sfx_effects,"JUICE01 BGM low-pass reaches 1200Hz over .3s and SFX bus is untouched")
	t.check(n.skills.screen_fx.vignette_rect!=fx.rect and fx.rect.material!=n.skills.screen_fx.vignette_rect.material,"JUICE01 low-hp vignette is separate from the fear vignette")
	player.hp = edge+1
	player.hp_changed.emit()
	t.check(not fx.active and fx.is_processing() and audio.lowpass_target==0.0,"JUICE01 recovering above 30 percent starts the fade out")
	fx._process(0.31)
	audio._apply_lowpass(0.31)
	t.check(not fx.is_processing() and not fx.rect.visible and fx.rect.material==null and audio.lowpass_amount==0 and not AudioServer.is_bus_effect_enabled(bgm,audio.lowpass_index()),"JUICE01 warning and filter fully off after .3s with the material detached")
	player.hp = 1
	player.hp_changed.emit()
	audio._apply_lowpass(0.3)
	n.host._end_round(false)
	t.check(fx.released and not fx.active and audio.lowpass_target==0.0,"JUICE01 result screen fades the warning and filter out")
	t.paused = false
	n.host.free()
	await t.process_frame
	t.check(audio.lowpass_amount==0 and not AudioServer.is_bus_effect_enabled(bgm,audio.lowpass_index()),"JUICE01 leaving the round leaves the BGM filter off")
	var flow := preload("res://scripts/game_flow.gd").new()
	t.root.add_child(flow)
	while flow.state=="loading": await t.process_frame
	while flow.ui.menu_locked(): await t.process_frame
	flow.start_region()
	var round_player: Node2D = flow.session.round_nodes.player
	round_player.hp = 1
	round_player.hp_changed.emit()
	audio._apply_lowpass(0.3)
	var on_in_round: bool = audio.lowpass_amount>0
	flow.show_menu()
	t.check(on_in_round and audio.lowpass_amount==0 and not AudioServer.is_bus_effect_enabled(bgm,audio.lowpass_index()),"JUICE01 menu return turns the BGM filter off at once")
	flow.start_region()
	t.check(audio.lowpass_amount==0 and not flow.session.round_nodes.low_hp.active,"JUICE01 a new round starts with the filter off")
	flow.free()
	t.paused = false
	await t.process_frame

func zoom(t: SceneTree) -> void:
	var n := fixture(t)
	var screen: CanvasLayer = n.skills.screen_fx
	var camera: Camera2D = n.player.get_node("Camera2D")
	var base: Vector2 = camera.zoom
	t.check(screen.camera==camera and screen.zoom_age<0,"JUICE01 zoom punch idle on the player camera")
	screen.zoom_punch()
	screen._advance_zoom(0.06)
	t.check(camera.zoom.is_equal_approx(base*1.03),"JUICE01 zoom reaches 1.03 at .06s")
	var age: float = screen.zoom_age
	screen.zoom_punch()
	t.check(is_equal_approx(screen.zoom_age,age),"JUICE01 overlapping trigger keeps the running punch")
	screen._advance_zoom(0.17)
	t.check(camera.zoom.x>base.x and camera.zoom.x<base.x*1.03,"JUICE01 zoom eases back during .18s")
	screen._advance_zoom(0.02)
	t.check(camera.zoom==base and screen.zoom_age<0,"JUICE01 zoom returns exactly after .24s")
	var layers: Array = n.host.find_children("*","CanvasLayer",true,false)
	t.check(not layers.is_empty() and layers.all(func(layer: CanvasLayer) -> bool: return not layer.follow_viewport_enabled),"JUICE01 UI canvas layers do not follow the camera zoom")
	screen.zoom_punch()
	screen._advance_zoom(0.03)
	screen.kick(5,0.1)
	t.check(screen.shake_offset!=Vector2.ZERO and camera.zoom.x>base.x,"JUICE01 zoom runs together with the screen shake")
	screen._advance_zoom(1)
	n.skills.skills.skill_dragon_fear.level = 1
	n.skills.try_use("skill_dragon_fear")
	t.check(screen.zoom_age>=0,"JUICE01 dragon fear cast starts a zoom punch")
	screen._advance_zoom(1)
	var bear: Node2D = spawn(n,"boss_middle",100)
	bear.apply_damage(bear.hp)
	t.check(screen.zoom_age>=0,"JUICE01 boss kill starts a zoom punch")
	screen._advance_zoom(1)
	screen.settings.Zoom_punch_enabled = 0
	screen.zoom_punch()
	t.check(screen.zoom_age<0 and camera.zoom==base,"JUICE01 Zoom_punch_enabled 0 turns the punch off")
	screen.settings.Zoom_punch_enabled = 1
	t.paused = false
	n.host.free()
	await t.process_frame

func drawn(entry: Dictionary, border: float) -> Vector2:
	var view: PanelContainer = entry.panel
	var height := maxf(view.custom_minimum_size.y,view.get_combined_minimum_size().y)
	var factor: float = view.scale.x
	return Vector2(view.offset_top+border*factor,view.offset_top+(height-border)*factor)

func toast_gap(t: SceneTree) -> void:
	var n := fixture(t)
	var view: Control = n.director.toast_view
	view.set_process(false)
	var border := float(view.presentation.Ui_window_border_px)
	# FIX-04: older toasts now fade 1s after creation once superseded, so the three arrive .25s apart.
	view.push_message("one")
	view._process(0.25)
	view.push_message("two")
	view._process(0.25)
	view.push_message("three")
	view._process(0.25)
	var lines: Array = []
	for entry in view.entries: lines.append(drawn(entry,border))
	t.check(is_equal_approx(lines[0].x,float(view.presentation.Toast_top_px)),"JUICE01 first toast border line stays at Toast_top_px")
	t.check(is_equal_approx(lines[1].x-lines[0].y,6) and is_equal_approx(lines[2].x-lines[1].y,6),"JUICE01 drawn toast border lines are 6px apart, shrunken ones included: "+str(lines))
	t.check(is_equal_approx(view.entries[1].panel.scale.x,0.85) and is_equal_approx(view.entries[2].panel.modulate.a,0.6),"JUICE01 step-back alpha .6 and scale .85 kept")
	n.host.free()
	await t.process_frame

func bar_polish(t: SceneTree) -> void:
	var n := fixture(t)
	var bar: Control = n.director.boss_bar
	t.check(bar.frame is NinePatchRect and bar.frame.texture==load("res://assets/ui/ui_boss_bar_frame.png") and bar.get_node_or_null("InnerLine")==null,"JUICE01 bar border now drawn by the FIX04 frame texture (flat border and inner line replaced)")
	t.check(bar.name_label.get_theme_font_size("font_size")==22 and bar.name_label.get_theme_constant("outline_size")==4 and bar.name_label.get_theme_color("font_outline_color")==Color("#1a1240"),"JUICE01 boss name 22px (FIX05) with a 2px 1a1240 outline")
	var level: Control = n.host.find_child("PlayerLevel",true,false)
	var timer: Control = n.host.find_child("ElapsedTime",true,false)
	var amount: Control = n.host.find_child("ExperienceAmount",true,false)
	var box: Rect2 = bar.get_global_rect()
	t.check(not box.intersects(level.get_global_rect()) and not box.intersects(timer.get_global_rect()) and not box.intersects(amount.get_global_rect()),"JUICE01 larger bar still clear of level, xp amount and time")
	var elf: Node2D = spawn(n,"boss_early",100)
	var view: Control = n.director.toast_view
	t.check(bar.visible and bar.boss==elf and is_equal_approx(view.stack_offset,bar.bottom_px()+6-float(view.presentation.Toast_top_px)),"JUICE01 toasts start below the taller bar")
	elf.elf.start_stealth()
	t.check(not bar.visible and is_equal_approx(view.stack_offset,0),"JUICE01 top bar hides while the elf is stealthed")
	elf.elf.end_stealth(n.manager._elapsed_seconds)
	t.check(bar.visible and bar.boss==elf,"JUICE01 top bar returns when stealth ends")
	elf.elf.start_stealth()
	elf.apply_damage(1)
	t.check(bar.visible and bar.boss==elf and not elf.elf.hidden,"JUICE01 a hit that breaks stealth shows the bar again")
	n.host.free()
	await t.process_frame
