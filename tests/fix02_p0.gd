extends RefCounted
const UI = preload("res://scripts/system_ui.gd")
const Toast = preload("res://scripts/boss_toast.gd")
const EPS := 0.51

func run(t: SceneTree) -> void:
	await flow(t)
	await toast(t)
	await choice(t)
	await fear(t)
	export_filter(t)

func fx02() -> RefCounted: return preload("res://tests/fx02_p0.gd").new()

func settle(t: SceneTree) -> void:
	# Window open motion (Ui_open_sec) scales the window; wait until it has finished.
	await t.create_timer(float(UI.settings().Ui_open_sec)+0.15,true,false,true).timeout
	await t.process_frame

# Rect inside a ui_window rect that keeps Ui_window_pad_x/y clear of the drawn border line.
func padded(window: Control) -> Rect2:
	var m := UI.window_margin()
	return Rect2(window.global_position+Vector2(m.x,m.y),window.size-Vector2(m.x+m.z,m.y+m.w))

func text_fits(control: Control) -> bool:
	if control is Button:
		var font: Font = control.get_theme_font("font")
		var font_size: int = control.get_theme_font_size("font_size")
		var face := float(UI.settings().Ui_button_border_px)
		return font.get_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x<=control.size.x-face*2 and font.get_height(font_size)<=control.size.y-face*2
	if control is Label and control.autowrap_mode==TextServer.AUTOWRAP_OFF:
		var font: Font = control.get_theme_font("font")
		return font.get_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,-1,control.get_theme_font_size("font_size")).x<=control.size.x+EPS
	return true

func content_inside(window: Control) -> Dictionary:
	var area := padded(window).grow(EPS)
	var bad: Array = []
	var count := 0
	for node in window.find_children("*","Control",true,false):
		if not (node is Label or node is Button or node is Range) or not node.is_visible_in_tree(): continue
		count += 1
		if not area.encloses(node.get_global_rect()) or not text_fits(node): bad.append("%s %s" % [node.name,node.get_global_rect()])
	return {"ok":bad.is_empty() and count>0,"bad":bad,"count":count}

func flow(t: SceneTree) -> void:
	var game := preload("res://scripts/game_flow.gd").new()
	t.root.add_child(game)
	var lead := 0.0
	var partial := false
	var until := Time.get_ticks_msec()+12000
	while game.state=="loading" and Time.get_ticks_msec()<until:
		await t.process_frame
		if game.state!="loading": break
		var elapsed := (Time.get_ticks_msec()-game.loading_started)/1000.0
		lead = maxf(lead,game.ui.progress.value-elapsed/5.0)
		partial = partial or (game.load_progress==1 and game.ui.progress.value<0.9)
	t.check(game.state=="menu" and game.loading_minimum==5 and game.loading_elapsed>=5 and is_equal_approx(game.ui.progress.value,1),"FIX02 loading screen held for Loading_sec 5 then menu")
	t.check(partial and lead<=0.05,"FIX02 loading bar fills over 5 seconds even after data is ready")
	var ui: Control = game.ui
	t.check(ui.notice.text==UI.NOTICE and not UI.NOTICE.contains("글꼴") and UI.NOTICE.ends_with("원작의 저작권은 각 권리자에게 있습니다."),"FIX02 region screen notice drops the font credit")
	# BAL-02: menu input is blocked until the loading -> menu entry reveal has finished.
	while ui.menu_locked(): await t.process_frame
	ui.toggle_settings()
	await settle(t)
	var settings_check := content_inside(ui.settings)
	t.check(settings_check.ok,"FIX02 menu settings text sliders numbers button inside window padding %s" % [settings_check.bad])
	var labels: Array = ui.settings.find_children("*","Label",true,false).filter(func(label: Label) -> bool: return label.name!="Value" and not (label.text in ["배경음악","효과음"])).map(func(label: Label) -> String: return label.text)
	t.check(labels==[],"FIX02 settings show no notice or credit text (FIX03)")
	var gear: Button = ui.find_child("SettingsButton",true,false)
	t.check(gear!=null and gear.get_theme_font_size("font_size")==16 and text_fits(gear),"FIX02 settings button text 16px fits inside the button face")
	ui.toggle_settings()
	var audio: Node = t.root.get_node("GameAudio")
	game.start_region()
	game.toggle_pause()
	t.check(game.state=="paused" and ui.pause_sliders.has("BGM") and ui.pause_sliders.has("SFX") and ui.modal.find_children("*","Button",true,false).map(func(b: Button) -> String: return b.text)==["계속","메인으로"],"FIX02 ESC pause window adds BGM and SFX sliders and keeps its buttons")
	await settle(t)
	var pause_check := content_inside(ui.modal)
	t.check(pause_check.ok,"FIX02 pause window content inside window padding %s" % [pause_check.bad])
	ui.pause_sliders.BGM.value = 30
	t.check(is_equal_approx(audio.levels.BGM,30) and ui.sound_sliders.BGM.value==30 and ui.sound_sliders.BGM.get_parent().get_node("Value").text=="30" and ui.pause_sliders.BGM.get_parent().get_node("Value").text=="30","FIX02 pause slider change shows on the menu slider")
	ui.sound_sliders.SFX.value = 40
	t.check(is_equal_approx(audio.levels.SFX,40) and ui.pause_sliders.SFX.value==40 and ui.pause_sliders.SFX.get_parent().get_node("Value").text=="40","FIX02 menu slider change shows on the pause slider")
	game.resume()
	t.check(game.state=="playing" and not t.paused,"FIX02 pause continue unchanged")
	game.session.round_ended.emit({"seconds":754.2,"level":12,"kills":1234,"shadows":["이그리트","베르","벨리온"],"cleared":false})
	await settle(t)
	var result_check := content_inside(ui.modal)
	var widths: Array = ui.modal.find_children("*","Button",true,false).map(func(b: Button) -> float: return b.size.x)
	t.check(game.state=="result" and result_check.ok and widths.size()==2 and is_equal_approx(widths[0],widths[1]) and is_equal_approx(widths[0],padded(ui.modal).size.x),"FIX02 result text and equal-width buttons inside window padding %s" % [result_check.bad])
	ui.sound_sliders.BGM.value = 100
	ui.sound_sliders.SFX.value = 100
	game.show_menu()
	game.queue_free()
	t.paused = false
	await t.process_frame

func toast(t: SceneTree) -> void:
	var f := fx02()
	var n: Dictionary = f.fixture(t)
	var values := UI.settings()
	var border := float(values.Ui_window_border_px)
	var view: Control = n.director.toast_view
	view.push_message("짧은 알림")
	await t.process_frame
	await t.process_frame
	var entry: Dictionary = view.entries[0]
	var panel: PanelContainer = entry.panel
	var label: Label = panel.get_child(0)
	var frame := Rect2(panel.position+Vector2.ONE*border,panel.size-Vector2.ONE*border*2)
	var title_size := int(values.Toast_title_font_size)
	var title_top := border+float(values.Toast_pad_y)
	var title_bottom := title_top+UI.BLACK.get_height(title_size)
	var body := Rect2(label.position,label.size)
	t.check(is_equal_approx(frame.position.y,16) and title_top-border>=12 and body.position.y-title_bottom>=6-EPS and frame.size.y+border-body.end.y>=12-EPS and body.size.y>=UI.BOLD.get_height(20)-EPS,"FIX02 toast title and body inside the frame: top 16, padding 12, title gap 6")
	t.check(is_equal_approx(frame.size.x,420),"FIX02 short toast keeps minimum frame width 420")
	var long_text := "[보스 몬스터 '얼음 군주 바루카'가 전장에 등장합니다. 모든 그림자 병사는 즉시 전투 준비를 하십시오. 경고: 강력한 냉기 공격이 이어집니다]"
	view.push_message(long_text,5.0,true)
	await t.process_frame
	await t.process_frame
	var warning: PanelContainer = view.entries[0].panel
	var warning_label: Label = warning.get_child(0)
	var font_size := warning_label.get_theme_font_size("font_size")
	var text_width := UI.BOLD.get_string_size(warning_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var warning_frame := warning.size.x-border*2
	t.check(warning_frame<=1280-80+EPS and text_width+80<=warning_frame+EPS and font_size<20 and warning.size.y>=Toast.visible_height(values,font_size)+border*2-EPS,"FIX02 long boss warning shrinks only past screen-80 and keeps 40px side padding")
	var mid := "[스킬 : 드래곤 피어를 사용합니다]"
	view.push_message(mid)
	await t.process_frame
	var medium: PanelContainer = view.entries[0].panel
	var medium_width := UI.BOLD.get_string_size(mid,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
	t.check(absf(medium.size.x-border*2-maxf(420,ceilf(medium_width)+80))<=EPS,"FIX02 toast width follows text width plus 40px per side")
	await f.cleanup(t,n)

func choice(t: SceneTree) -> void:
	var f := fx02()
	var n: Dictionary = f.fixture(t)
	var values := UI.settings()
	var border := float(values.Ui_window_border_px)
	var button_face := float(values.Ui_button_border_px)
	n.director.toast_view.push_message("[스킬 : 드래곤 피어를 사용합니다]")
	n.player.add_experience(n.player.get_xp_to_next())
	await t.process_frame
	var ui: Control = n.choices.ui
	var toast_panel: PanelContainer = n.director.toast_view.entries[0].panel
	var toast_bottom: float = toast_panel.position.y+toast_panel.size.y-border
	var window: Rect2 = ui.window_rect()
	var frame := window.grow(-border)
	t.check(n.choices.active and window.position.y+UI.CREST_TOP>=toast_bottom and frame.position.y-toast_bottom>=40 and window.end.y<=720,"FIX02 level-up window and crest start below the first toast, window stays on screen")
	t.check(ui.title_top-frame.position.y>=24 and ui.title_top>=window.position.y+UI.CREST_TOP+34,"FIX02 level-up title clears the crest and top padding")
	var gaps: Array = []
	var right := frame.position.x
	for i in range(3):
		var card: Rect2 = ui.card_rect(i).grow(-border)
		gaps.append(card.position.x-right)
		right = card.end.x
	gaps.append(frame.end.x-right)
	var even := true
	for gap in gaps: even = even and gap>=float(values.Ui_window_pad_x) and is_equal_approx(gap,gaps[0])
	t.check(even,"FIX02 card gaps equal the window side gaps %s" % [gaps])
	var card_bottom: float = ui.CARD_SIZE.y-border
	t.check(ui.card_inset>=border+20 and ui.icon_top>=border+20 and ui.level_text_top+ui.level_text_height<=card_bottom-24+EPS and ui.level_top>ui.description_top+ui.description_height,"FIX02 card padding 20/20/24 and Lv text 24px above card border")
	var reroll: Rect2 = ui.reroll_rect()
	var face := reroll.grow(-button_face)
	t.check((face.size.y-UI.BOLD.get_height(20))/2>=10 and is_equal_approx(frame.end.y-face.end.y,28) and face.position.y-(ui.card_rect(0).end.y-border)>=24-EPS,"FIX02 reroll text padding>=10 and button 28px above window border")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = ui.card_rect(1).get_center()
	ui._gui_input(event)
	t.check(not n.choices.active,"FIX02 card click still selects through the moved layout")
	await f.cleanup(t,n)

func fear(t: SceneTree) -> void:
	var f := fx02()
	var n: Dictionary = f.fixture(t)
	var cast = n.skills.skills.skill_dragon_fear
	cast.level = 1
	var stats: Dictionary = cast.levels[0]
	cast.start(0)
	var screen: CanvasLayer = n.skills.screen_fx
	screen._process(0)
	t.check(screen.fear_dim_rect.visible and screen.fear_dim_rect.color.is_equal_approx(Color(Color("#200008"),0.25)),"FIX02 fear darkens the screen #200008 alpha .25 while casting")
	screen._process(float(stats.Cast_sec)+float(screen.fear_dim_tail)*0.5)
	t.check(screen.fear_dim_rect.color.a<0.25 and screen.fear_dim_rect.color.a>0,"FIX02 fear dim fades over the vignette tail")
	screen._process(float(screen.fear_dim_tail))
	t.check(not screen.fear_dim_rect.visible,"FIX02 fear dim hidden after the tail")
	await f.cleanup(t,n)

func export_filter(t: SceneTree) -> void:
	var config := ConfigFile.new()
	var loaded := config.load("res://export_presets.cfg")
	var filters := String(config.get_value("preset.0","include_filter","")).split(",")
	var trimmed: Array = Array(filters).map(func(item: String) -> String: return item.strip_edges())
	t.check(loaded==OK and trimmed.has("*.csv") and trimmed.has("assets/fonts/OFL.txt") and trimmed.has("assets/audio/CREDITS.txt") and FileAccess.file_exists("res://assets/fonts/OFL.txt") and FileAccess.file_exists("res://assets/audio/CREDITS.txt"),"FIX02 export include filter ships OFL.txt and CREDITS.txt")
