extends Node2D

const SkillData = preload("res://scripts/skill_data.gd")
const Cast = preload("res://scripts/skill_cast.gd")
const Area = preload("res://scripts/skill_area.gd")
const UI = preload("res://scripts/skill_ui.gd")
const Toast = preload("res://scripts/boss_toast.gd")
var presentation: Dictionary = preload("res://scripts/shadow_afterimage.gd").compiled_presentation().duplicate()
var visual_rng := RandomNumberGenerator.new()
var visuals_enabled := true

var player: Node2D
var enemies: EnemyManager
var records: Dictionary = {}
var skills: Dictionary = {}
var clock: float = 0.0
var effects: Array = []
var ui: Control
var screen_fx: CanvasLayer
var cartoon_fx: Node2D

func configure(owner_player: Node2D, enemy_manager: EnemyManager, skill_records: Dictionary, slash_levels: Dictionary, extra_levels: Dictionary = {}, stealth_rule: Dictionary = {}) -> void:
	player = owner_player
	player.skill_presentation = self
	enemies = enemy_manager
	if not stealth_rule.is_empty():
		enemies.wander_radius = float(stealth_rule.Wander_radius)
	records = skill_records.duplicate(true)
	for id in SkillData.IDS:
		if not InputMap.has_action(id):
			InputMap.add_action(id)
		InputMap.action_erase_events(id)
		var event := InputEventKey.new()
		event.physical_keycode = SkillData.standard_key(records[id].Key)
		InputMap.action_add_event(id,event)
		var cast := Cast.new()
		var callback := Callable(self,"_slash_tick") if id=="skill_rapid_slash" else Callable()
		var rows: Array = slash_levels.values() if id=="skill_rapid_slash" else []
		var mode := "ticks"
		if extra_levels.has(id):
			rows = extra_levels[id].values()
			if id=="skill_dash":
				callback = Callable(self,"_dash_start")
				mode = "timed"
			elif id=="skill_stealth":
				callback = Callable(self,"_stealth_start")
				mode = "instant"
			elif id=="skill_dragon_fear":
				callback = Callable(self,"_fear_start")
				mode = "timed"
		cast.configure(rows,1 if records[id].Initially_unlocked else 0,callback,mode,"Cast_sec" if id=="skill_dragon_fear" else "Duration_sec")
		skills[id] = cast

func _ready() -> void:
	z_index = 20
	cartoon_fx = preload("res://scripts/skill_cartoon_fx.gd").new()
	cartoon_fx.settings = presentation
	cartoon_fx.visual_rng = visual_rng
	add_child(cartoon_fx)
	screen_fx = preload("res://scripts/skill_screen_fx.gd").new()
	screen_fx.settings = presentation
	screen_fx.camera = player.get_node_or_null("Camera2D")
	add_child(screen_fx)
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = UI.new()
	ui.configure(self)
	layer.add_child(ui)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	for id in SkillData.IDS:
		if event.is_action_pressed(id):
			try_use(id)

func try_use(id: String) -> bool:
	if player.is_dead or get_tree().paused or player.is_frozen() or player.is_stealthed() or player.is_fear_casting():
		return false
	if id=="skill_dragon_fear" and player.dash_remaining>0.000000001:
		return false
	var started: bool = skills[id].start(clock)
	if started: preload("res://scripts/audio_events.gd").sfx(self,id.trim_prefix("skill_"))
	if started: Toast.notify(self,"[스킬 : %s 사용합니다]" % Toast.particle(String(records[id].Name_ko),"을","를"))
	return started

func try_upgrade(id: String) -> bool:
	var cast = skills[id]
	if player.is_dead or get_tree().paused or player.is_frozen() or not cast.implemented or player.enhancement_points<1 or cast.level>=cast.max_level():
		return false
	player.enhancement_points -= 1
	cast.level += 1
	return true

func _physics_process(delta: float) -> void:
	if player==null or player.is_dead or get_tree().paused:
		return
	var had_effects: bool = not effects.is_empty() or skills.skill_rapid_slash.active
	clock += delta
	for cast in skills.values():
		cast.advance(clock)
	if screen_fx!=null: screen_fx.set_slash_active(visuals_enabled and skills.skill_rapid_slash.active)
	for index in range(effects.size()-1,-1,-1):
		var effect: Dictionary = effects[index]
		if not effect.has("lines"):
			if clock>=float(effect.until): effects.remove_at(index)
			continue
		if effect.has("lines"):
			effect.visual_age = float(effect.get("visual_age",0))+maxf(0,clock-float(effect.get("visual_clock",effect.at)))*float(get_viewport().get_meta(&"fx05_visual_scale",1.0))
			effect.visual_clock = clock
		var elapsed := float(effect.get("visual_age",clock-float(effect.at)))
		if effect.has("stars") and elapsed>=float(presentation.get("Slash_star_sec",0.12)): effect.stars.clear()
		if elapsed>=float(effect.until)-float(effect.at): effects.remove_at(index)
	if had_effects or not effects.is_empty() or skills.skill_rapid_slash.active: queue_redraw()

func _slash_tick(stats: Dictionary, at: float) -> void:
	if player.is_dead or player.is_stealthed():
		return
	var candidates: Array = enemies.get_living_enemies()
	var star_candidates: Array = []
	if visuals_enabled:
		for enemy in Area.living_in_circle(player.global_position,float(stats.Range),candidates):
			star_candidates.append({"enemy":enemy,"hp":enemy.hp,"position":enemy.global_position})
	Area.damage_circle(player.global_position,float(stats.Range),int(stats.Damage),candidates)
	if visuals_enabled:
		var lines: Array = []
		var widths: Array = []
		for index in range(int(presentation.get("Slash_lines_per_tick",4))):
			var direction := Vector2.RIGHT.rotated(visual_rng.randf()*TAU)
			var offset := visual_rng.randf_range(-0.6,0.6)*float(stats.Range)
			var center: Vector2 = player.global_position+direction.orthogonal()*offset
			var half_length := sqrt(float(stats.Range)*float(stats.Range)-offset*offset)*float(presentation.get("Slash_length_mult",1.5))
			lines.append([center-direction*half_length,center+direction*half_length])
			widths.append(float(presentation.get("Slash_fx_width",9)))
		var stars: Array = []
		for candidate in star_candidates:
			if is_instance_valid(candidate.enemy) and candidate.enemy.hp<int(candidate.hp) and stars.size()<int(presentation.get("Slash_star_max",4)):
				if preload("res://scripts/impact_budget.gd").take(preload("res://scripts/impact_budget.gd").scope(self),int(presentation.Impact_spawn_max_per_frame)):
					stars.append(candidate.position)
		var finishing: bool = stats.has("Hits") and skills.skill_rapid_slash.hits_done+1>=int(stats.Hits)
		if finishing:
			for angle in [PI/4,-PI/4]:
				var half := Vector2.RIGHT.rotated(angle)*float(stats.Range)*float(presentation.get("Slash_length_mult",1.5))*float(presentation.get("Slash_finish_length_mult",1.8))
				lines.append([player.global_position-half,player.global_position+half])
				widths.append(float(presentation.get("Slash_finish_width",16)))
			if screen_fx!=null:
				screen_fx.kick(float(presentation.get("Shake_px",5)),float(presentation.get("Slash_shake_sec",0.08)))
				screen_fx.flash_white(float(presentation.get("Slash_finish_flash",0.35)),float(presentation.get("Slash_finish_flash_sec",0.05)))
		effects.append({"center":player.global_position,"radius":float(stats.Range),"until":at+float(presentation.get("Slash_life_sec",0.25)),"at":at,"lines":lines,"widths":widths,"stars":stars,"finishing":finishing})
		if screen_fx!=null: screen_fx.set_slash_active(true)
	queue_redraw()

func icon_state(id: String) -> Dictionary:
	var cast = skills[id]
	var remaining := maxf(0.0,cast.cooldown_until-clock)
	var cooling: bool = not cast.active and remaining>0.000000001
	var progress := 0.0
	if not cast.snapshot.is_empty() and not cast.active:
		progress = clampf((clock-cast.completed_at)/float(cast.snapshot.Cooldown_sec),0.0,1.0)
	return {"phase":"unimplemented" if not cast.implemented else ("locked" if cast.level==0 else ("active" if cast.active else ("cooldown" if cooling else "ready"))),
		"level":cast.level,"name":records[id].Name_ko,"key":records[id].Key,
		"show_plus":cast.implemented and player.enhancement_points>=1 and cast.level<cast.max_level(),
		"active_border":cast.active,"show_gauge":cooling,"progress":progress,
		"cooldown_text":"%.1f" % (maxf(1.0,ceil(remaining*10.0-0.000000001))/10.0) if cooling else ""}

func _dash_start(stats: Dictionary, _at: float) -> void:
	player.begin_dash(float(stats.Distance),float(stats.Duration_sec))
	if visuals_enabled:
		if cartoon_fx!=null: cartoon_fx.start_dash(player,float(stats.Distance),player.dash_direction)
		if screen_fx!=null: screen_fx.kick(float(presentation.get("Dash_shake_px",2)),float(presentation.get("Dash_shake_sec",0.06)))

func _stealth_start(stats: Dictionary, at: float) -> void:
	player.stealth_remaining = float(stats.Duration_sec)
	player.cancel_basic_attack()
	skills["skill_rapid_slash"].cancel(at)

func _fear_start(stats: Dictionary, at: float) -> void:
	player.fear_cast_remaining = float(stats.Cast_sec)
	for enemy in Area.living_in_circle(player.global_position,float(stats.Range),enemies.get_living_enemies()):
		enemy.apply_fear(float(stats.Duration_sec))
	effects.append({"center":player.global_position,"radius":float(stats.Range),"until":at+UI.FEAR_FLASH_SEC,"fear":true})
	if visuals_enabled:
		var wave := preload("res://scripts/dragon_fear_fx.gd").new()
		wave.settings = presentation
		wave.radius = float(stats.Range)
		wave.duration = float(stats.Cast_sec)
		wave.initialize(visual_rng)
		wave.z_index = 10
		get_parent().add_child(wave)
		wave.global_position = player.global_position
		wave.attach_ground()
		var head := preload("res://scripts/dragon_fear_fx.gd").new()
		head.settings = presentation
		head.duration = float(stats.Cast_sec)
		head.head_only = true
		head.head_texture = load("res://assets/art/fx/fx_dragon_head.png")
		var host: Node2D = player.character_view if is_instance_valid(player.character_view) else player
		host.add_child(head)
		host.move_child(head,0)
		head.global_position = player.global_position
		if screen_fx!=null:
			screen_fx.kick(float(presentation.get("Fear_shake_px",8)),float(presentation.get("Fear_shake_sec",0.25)),float(presentation.get("Fear_flash_sec",0.15)))
			screen_fx.start_fear(float(stats.Cast_sec))
			screen_fx.zoom_punch()
	queue_redraw()

func _draw() -> void:
	var fx = preload("res://scripts/skill_cartoon_fx.gd")
	var slash = skills.get("skill_rapid_slash")
	if visuals_enabled and slash!=null and slash.active and not slash.snapshot.is_empty():
		var segments := int(presentation.get("Slash_range_dashes",48))
		for i in range(segments):
			draw_arc(to_local(player.global_position),float(slash.snapshot.Range),TAU*i/segments,TAU*(i+0.5)/segments,4,Color(Color(presentation.get("Slash_range_color","#5ad4ff")),float(presentation.get("Slash_range_alpha",0.35))),float(presentation.get("Slash_range_width",2)),true)
	for effect in effects:
		if not effect.has("lines"):
			if effect.has("fear"): continue
			UI.draw_ranges(self,[effect])
			continue
		var age := float(effect.get("visual_age",maxf(0,clock-float(effect.at))))
		var draw_sec := float(presentation.get("Slash_draw_sec",0.03))
		var life := float(presentation.get("Slash_life_sec",0.25))
		var hold := draw_sec+float(presentation.get("Slash_hold_sec",0.04))
		var remaining := 1-clampf((age-hold)/maxf(life-hold,0.000001),0,1)
		for i in range(effect.lines.size()):
			var line: Array = effect.lines[i]
			var a := to_local(line[0])
			var b := to_local(line[1])
			b = a.lerp(b,clampf(age/maxf(draw_sec,0.000001),0,1))
			fx.blade(self,a,b,float(effect.widths[i])*remaining,Color(Color(presentation.Slash_outer_color),remaining),presentation,true,Color(presentation.get("Fx_outline_color","#16265a")))
		var star_sec := float(presentation.get("Slash_star_sec",0.12))
		if age<star_sec:
			for center in effect.stars: fx.star(self,to_local(center),float(presentation.get("Slash_star_px",12)),1-age/star_sec,presentation)
		var flash_sec := float(presentation.get("Slash_tick_flash_sec",0.05))
		if age<flash_sec:
			draw_circle(to_local(effect.center),float(presentation.get("Slash_tick_flash_px",18)),Color(1,1,1,float(presentation.get("Slash_tick_flash_alpha",0.8))*(1-age/flash_sec)))
