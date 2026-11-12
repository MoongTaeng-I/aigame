extends Control

const PANEL_SIZE := Vector2(800,88)
const TOP_MARGIN := 22.0
const CORNER_RADIUS := 14
const BORDER_WIDTH := 2
const CONTENT_MARGIN := 18.0
const FONT_SIZE := 20
const BACKGROUND := Color(0.055,0.035,0.09,0.92)
const BORDER := Color("#9870dc")
const TEXT_COLOR := Color("#f0e5ff")
const FADE_IN_SEC := 0.16
const FADE_OUT_SEC := 0.2
var panel: PanelContainer
var label: Label

func _ready() -> void:
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
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND
	style.border_color = BORDER
	style.set_border_width_all(BORDER_WIDTH)
	style.set_corner_radius_all(CORNER_RADIUS)
	style.content_margin_left = CONTENT_MARGIN
	style.content_margin_right = CONTENT_MARGIN
	style.content_margin_top = CONTENT_MARGIN
	style.content_margin_bottom = CONTENT_MARGIN
	panel.add_theme_stylebox_override("panel",style)
	label = Label.new()
	label.name = "BossToastText"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color",TEXT_COLOR)
	label.add_theme_font_size_override("font_size",FONT_SIZE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	hide()

func present(text: String, age: float, remaining: float, showing: bool) -> void:
	label.text = text
	visible = showing
	modulate.a = minf(clampf(age/FADE_IN_SEC,0,1),clampf(remaining/FADE_OUT_SEC,0,1)) if showing else 0.0

func show_completion(text: String) -> void:
	# Preserve the previous temporary completion message without a new game screen.
	label.text = text
	modulate.a = 1
	show()
