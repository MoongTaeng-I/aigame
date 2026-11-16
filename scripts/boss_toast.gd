extends Control
const UI = preload("res://scripts/system_ui.gd")

const CORNER_RADIUS := 14
const BORDER_WIDTH := 2
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

# Height of the drawn frame (inside the border line): title line, gap, one body line, padding.
static func visible_height(values: Dictionary, body_font_size: int = FONT_SIZE) -> float:
	return float(values.Toast_pad_y)*2+UI.BLACK.get_height(int(values.Toast_title_font_size))+float(values.Toast_title_gap_px)+UI.BOLD.get_height(body_font_size)

# Rect offset that puts the first toast's drawn frame Toast_top_px below the screen top.
static func first_top(values: Dictionary) -> float:
	return float(values.Toast_top_px)-float(values.Ui_window_border_px)

func border() -> float: return float(presentation.Ui_window_border_px)

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
	var start_size := Vector2(float(presentation.Toast_min_width)+border()*2,visible_height(presentation)+border()*2)
	panel.offset_left = -start_size.x/2
	panel.offset_right = start_size.x/2
	panel.offset_top = first_top(presentation)
	panel.offset_bottom = panel.offset_top+start_size.y
	panel.custom_minimum_size = start_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body_style := UI.THEME.get_stylebox("panel","PanelContainer").duplicate() as StyleBoxTexture
	body_style.content_margin_left = border()+float(presentation.Toast_pad_x)
	body_style.content_margin_right = body_style.content_margin_left
	body_style.content_margin_top = border()+float(presentation.Toast_pad_y)+UI.BLACK.get_height(int(presentation.Toast_title_font_size))+float(presentation.Toast_title_gap_px)
	body_style.content_margin_bottom = border()+float(presentation.Toast_pad_y)
	panel.add_theme_stylebox_override("panel",body_style)
	label = Label.new()
	label.name = "BossToastText"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
	preload("res://scripts/audio_events.gd").sfx(self,"boss_warning" if is_warning else "system_notify")
	var copy := panel.duplicate() as PanelContainer
	add_child(copy)
	copy.show()
	copy.draw.connect(draw_heading.bind(copy))
	var content := copy.get_child(0) as Label
	content.text = text.replace("\n"," ")
	# Widths below are of the drawn frame: text width + Toast_pad_x per side, clamped to
	# [Toast_min_width, screen width - Toast_screen_margin]; the font shrinks only past the maximum.
	var pad := float(presentation.Toast_pad_x)*2
	var maximum := maxf(float(presentation.Toast_min_width),size.x-float(presentation.Toast_screen_margin))
	var font_size := FONT_SIZE
	var measured := UI.BOLD.get_string_size(content.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+pad
	if measured>maximum: font_size = maxi(int(presentation.Toast_min_font_size),floori(font_size*(maximum-pad)/(measured-pad)))
	content.add_theme_font_size_override("font_size",font_size)
	measured = ceilf(UI.BOLD.get_string_size(content.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)+pad
	var width := clampf(measured,float(presentation.Toast_min_width),maximum)+border()*2
	copy.custom_minimum_size = Vector2(width,visible_height(presentation,font_size)+border()*2)
	copy.size = copy.custom_minimum_size
	copy.offset_left = -width/2; copy.offset_right = width/2
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
	var top := first_top(presentation)
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
			view.position.x = (size.x-view.size.x)/2+sin(open*TAU*int(presentation.Ui_flicker_count))*float(presentation.Ui_jitter_px)*(1-open)
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
	var font_size := int(presentation.Toast_title_font_size)
	var width := UI.BLACK.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	view.draw_string(UI.BLACK,Vector2((view.size.x-width)/2,border()+float(presentation.Toast_pad_y)+UI.BLACK.get_ascent(font_size)),title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,TEXT_COLOR)
