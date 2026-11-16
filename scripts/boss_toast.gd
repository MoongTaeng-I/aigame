extends Control
const UI = preload("res://scripts/system_ui.gd")

const PANEL_SIZE := Vector2(533,88)
const TOP_MARGIN := 22.0
const CORNER_RADIUS := 14
const BORDER_WIDTH := 2
const CONTENT_MARGIN := 18.0
const FONT_SIZE := 20
const BACKGROUND := Color(0.055,0.035,0.09,0.92)
const BORDER := Color("#9870dc")
const TEXT_COLOR := Color("#ebf8ff")
const FADE_IN_SEC := 0.16
const FADE_OUT_SEC := 0.2
var panel: PanelContainer
var label: Label
var entries: Array = []
var warning: Dictionary = {}
var completion_label: Label
var pause_with_game := false
var result_keep_running := false
var presentation: Dictionary = preload("res://scripts/shadow_afterimage.gd").compiled_presentation().duplicate()

static func particle(word: String, consonant: String, vowel: String) -> String:
	if word.is_empty(): return word+vowel
	var code := word.unicode_at(word.length()-1)
	return word+(consonant if code>=0xAC00 and code<=0xD7A3 and (code-0xAC00)%28!=0 else vowel)

static func notify(source: Node, text: String) -> void:
	var views := source.get_tree().get_nodes_in_group("combat_toasts")
	# A fixture without a director legitimately has no HUD.
	for view in views:
		if view.get_parent().get_parent().manager==source.enemies:
			view.push_message(text)
			return

func _ready() -> void:
	theme = UI.THEME
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("combat_toasts")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = PanelContainer.new()
	panel.name = "BossToastPanel"
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -PANEL_SIZE.x/2
	panel.offset_right = PANEL_SIZE.x/2
	panel.offset_top = TOP_MARGIN
	panel.offset_bottom = TOP_MARGIN+PANEL_SIZE.y
	panel.custom_minimum_size = PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body_style := UI.THEME.get_stylebox("panel","PanelContainer").duplicate() as StyleBoxTexture
	body_style.content_margin_left = CONTENT_MARGIN
	body_style.content_margin_right = CONTENT_MARGIN
	body_style.content_margin_top = CONTENT_MARGIN
	body_style.content_margin_bottom = CONTENT_MARGIN
	panel.add_theme_stylebox_override("panel",body_style)
	label = Label.new()
	label.name = "BossToastText"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color",TEXT_COLOR)
	label.add_theme_font_size_override("font_size",FONT_SIZE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	label.add_theme_constant_override("outline_size",1)
	panel.hide()
	hide()

func present(text: String, age: float, remaining: float, showing: bool) -> void:
	if not warning.is_empty() and not warning.retiring:
		warning.age = age+float(warning.pause_elapsed)
		warning.remaining = remaining-float(warning.pause_elapsed) if showing else 0.0
		_refresh()

func push_message(text: String, duration: float = -1.0, is_warning: bool = false) -> void:
	var copy := panel.duplicate() as PanelContainer
	add_child(copy)
	copy.show()
	copy.draw.connect(draw_heading.bind(copy))
	var content := copy.get_child(0) as Label
	content.text = text
	# Let the actual Label shape and measure its wrapped text, including fallback fonts.
	content.size.x = PANEL_SIZE.x-CONTENT_MARGIN*2
	var height := maxf(PANEL_SIZE.y,content.get_minimum_size().y+CONTENT_MARGIN*2)
	copy.custom_minimum_size = Vector2(PANEL_SIZE.x,height)
	var entry := {"panel":copy,"text":text,"age":0.0,"remaining":float(presentation.Toast_sec) if duration<0 else duration,"warning":is_warning,"retiring":false,"pause_elapsed":0.0}
	entries.push_front(entry)
	if is_warning:
		warning = entry
		label = content
	var count := 0
	for item in entries:
		if item.retiring: continue
		count+=1
		if count>int(presentation.Toast_max):
			item.retiring = true
			item.remaining = minf(float(item.remaining),FADE_OUT_SEC)
	_refresh()

func _process(delta: float) -> void:
	if pause_with_game and get_tree().paused and not result_keep_running: return
	for entry in entries:
		if not entry.warning or entry.retiring or get_tree().paused:
			entry.age+=delta
			entry.remaining-=delta
			if entry.warning and get_tree().paused: entry.pause_elapsed+=delta
	_refresh()

func _refresh() -> void:
	for index in range(entries.size()-1,-1,-1):
		if float(entries[index].remaining)<=0:
			entries[index].panel.queue_free()
			entries.remove_at(index)
	var top := TOP_MARGIN
	for entry in entries:
		var view: PanelContainer = entry.panel
		if not entry.retiring:
			var height := maxf(view.custom_minimum_size.y,view.get_combined_minimum_size().y)
			view.offset_top = top
			view.offset_bottom = top+height
			top = view.offset_bottom+float(presentation.Toast_gap_px)
		view.modulate.a = minf(clampf(float(entry.age)/FADE_IN_SEC,0,1),clampf(float(entry.remaining)/FADE_OUT_SEC,0,1))
		if int(presentation.Ui_fx_enabled)!=0:
			var open := clampf(float(entry.age)/float(presentation.Ui_open_sec),0,1)
			var close := clampf(float(entry.remaining)/float(presentation.Ui_close_sec),0,1)
			view.pivot_offset = view.size/2
			view.scale.y = minf(lerpf(float(presentation.Ui_open_scale_y),1,open),close)
			view.position.x = (size.x-PANEL_SIZE.x)/2+sin(open*TAU*int(presentation.Ui_flicker_count))*float(presentation.Ui_jitter_px)*(1-open)
			if open<1 and sin(open*TAU*int(presentation.Ui_flicker_count))<0: view.modulate.a*=float(presentation.Ui_flicker_alpha)
		else:
			view.scale = Vector2.ONE
			view.modulate.a = 1
	visible = not entries.is_empty() or is_instance_valid(completion_label)

func show_completion(text: String) -> void:
	completion_label = Label.new()
	completion_label.text = text
	completion_label.add_theme_font_size_override("font_size",48)
	completion_label.z_index = -1
	add_child(completion_label)
	completion_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	completion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	show()

func draw_heading(view: Control) -> void:
	var title := "! 알림 !"
	var width := UI.BLACK.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
	view.draw_string(UI.BLACK,Vector2((view.size.x-width)/2,25),title,HORIZONTAL_ALIGNMENT_LEFT,-1,16,TEXT_COLOR)
