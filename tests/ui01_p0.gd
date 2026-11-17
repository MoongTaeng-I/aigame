extends RefCounted
const UI = preload("res://scripts/system_ui.gd")

func run(t: SceneTree) -> void:
	t.check(UI.THEME.default_font==UI.BOLD and UI.BLACK!=null and UI.BOLD.get_font_name().contains("Noto"),"UI01 shared Noto theme and title font load")
	for name in ["normal","hover","pressed","disabled"]:
		var style := UI.THEME.get_stylebox(name,"Button") as StyleBoxTexture
		t.check(style!=null and style.texture_margin_left==24 and style.texture.get_size()==Vector2(160,64),"UI01 button ninepatch "+name)
	var window := UI.THEME.get_stylebox("panel","Panel") as StyleBoxTexture
	t.check(window.texture_margin_top==40 and window.axis_stretch_horizontal==StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH,"UI01 window40px stretched edges and center")
	var animated := Panel.new()
	t.root.add_child(animated)
	var opening := UI.animate_window(animated)
	opening._process(0.075)
	t.check(animated.scale.y>0.2 and animated.scale.y<1,"UI01 window open unfolds vertically without game timer")
	opening._process(0.075)
	t.check(animated.scale==Vector2.ONE and not opening.is_processing(),"UI01 window open finishes .15 and stops processing")
	opening.close()
	opening._process(0.1)
	t.check(animated.is_queued_for_deletion(),"UI01 closing window folds and releases .1")
	await t.process_frame
	for id in ["skill_dash","skill_rapid_slash","skill_stealth","skill_dragon_fear","igrit","charger_test","belion"]:
		t.check(UI.icon(id)!=null and UI.icon(id).get_size()==Vector2(256,256),"UI01 icon mapping "+id)
	t.check(UI.icon("choice_heal")==null and UI.icon("choice_attack_range")==null and UI.icon("choice_igrit")==UI.icon("igrit"),"UI01 choice ability text-only and shadow icon mapping")
	var flow := preload("res://scripts/game_flow.gd").new()
	t.root.add_child(flow)
	t.check(is_equal_approx(flow.ui.logo.position.y,650-24-640.0*734/1394) and flow.ui.logo.size.x==640 and flow.ui.dust.size()==30 and flow.ui.backdrop.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_COVERED,"UI01 title image crop logo and30 dust")
	while flow.state=="loading": await t.process_frame
	# BAL-02: menu input is blocked until the entry reveal has finished.
	while flow.ui.menu_locked(): await t.process_frame
	var ui: Control = flow.ui
	t.check(ui.theme==UI.THEME and ui.notice.text==UI.NOTICE and ui.backdrop.material==ui.art_menu,"UI01 menu theme blurred dark backdrop and fan notice")
	t.check(not ui.cards[0].visible and ui.cards[1].visible and ui.cards[2].visible and ui.cards[2].scale==Vector2.ONE*0.6 and ui.cards[2].get_node("Lock").visible,"UI01 first region selected/next preview and empty previous")
	flow.change_region(1)
	t.check(ui.cards[0].visible and not ui.cards[2].visible and ui.start_button.disabled and ui.locked_click.visible and ui.slide_remaining==0.2,"UI01 last locked region preserves disabled/notice action and slide starts")
	ui._process(0.2)
	t.check(ui.slide_remaining==0 and ui.cards[1].position==Vector2(360,142.5),"UI01 card slide finishes .2 without region logic delay")
	flow.change_region(-1)
	flow.start_region()
	var n: Dictionary = flow.session.round_nodes
	for node in flow.session.find_children("*","Node",true,false): node.set_physics_process(false)
	t.check(n.skills.ui.theme==UI.THEME and n.skills.ui.glyphs[0].texture==UI.icon("skill_dash") and n.map.get_node("TemporaryHud").root_control.theme==UI.THEME,"UI01 ingame skill and HUD share theme/images")
	n.player.add_experience(n.player.get_xp_to_next())
	t.check(t.paused and n.choices.active and n.choices.ui.theme==UI.THEME,"UI01 real levelup retains pause and themed choice")
	n.choices.select(0)
	flow.toggle_pause()
	t.check(flow.state=="paused" and ui.modal.theme==null and ui.modal.get_theme_font("font")==UI.BOLD,"UI01 pause modal inherits common theme")
	flow.resume()
	flow.free(); t.paused = false
	await t.process_frame
	var original: Dictionary = Engine.get_meta(&"combat_presentation")
	var off := original.duplicate(); off.Ui_fx_enabled = 0
	Engine.set_meta(&"combat_presentation",off)
	flow = preload("res://scripts/game_flow.gd").new(); t.root.add_child(flow)
	while flow.state=="loading": await t.process_frame
	# Loading installs the canonical CSV cache; override only the presentation test subject.
	flow.ui.values = off
	flow.change_region(1)
	t.check(flow.ui.slide_remaining==0,"UI01 disabled card transition immediate")
	var panel := Panel.new(); panel.theme = UI.THEME; t.root.add_child(panel)
	var motion := UI.animate_window(panel); motion.values = off; motion.open()
	t.check(not motion.is_processing() and panel.scale==Vector2.ONE and panel.modulate.a==1,"UI01 disabled window effect immediate")
	panel.free(); flow.free(); t.paused = false
	Engine.set_meta(&"combat_presentation",original)
	await t.process_frame
	var chars: Dictionary = {}
	for root_path in ["res://scripts","res://data"]:
		for name in DirAccess.get_files_at(root_path):
			if not (name.ends_with(".gd") or name.ends_with(".csv")): continue
			var text := FileAccess.get_file_as_string(root_path+"/"+name)
			for c in text:
				var code := c.unicode_at(0)
				if code>=32 and (code<127 or code>=0xAC00 and code<=0xD7A3 or c in "‘’…‹›→±×–—·!%"):
					chars[code] = true
	var missing: Array = []
	for code in chars:
		if not UI.BOLD.has_char(code) or not UI.BLACK.has_char(code): missing.append(String.chr(code))
	t.check(missing.is_empty(),"UI01 all used Korean/UI glyphs in both supplied fonts: "+str(missing))
