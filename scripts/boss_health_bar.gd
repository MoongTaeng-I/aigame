extends Control
# FIX-03: large boss name + HP bar at the top centre, below the experience bar.
# Updated only from the boss's damaged/died signals; nothing runs per frame.
# Back, Fill and Frame are separate nodes so a delayed "lag" bar can later sit between Back and Fill.
const UI = preload("res://scripts/system_ui.gd")
const FRAME_MARGIN := 6.0
const NAME_COLOR := Color("#ebf8ff")
const NAME_OUTLINE := Color("#16265a")
var values: Dictionary = preload("res://scripts/shadow_afterimage.gd").compiled_presentation()
var boss: Node
var name_label: Label
var frame: Panel
var back: ColorRect
var fill: ColorRect
var bar_width := 560.0
var bar_height := 18.0
var updates := 0

func _ready() -> void:
	name = "BossHealthBar"
	theme = UI.THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_width = float(values.Boss_bar_width)
	bar_height = float(values.Boss_bar_height)
	var font_size := int(values.Boss_bar_name_font_size)
	var name_height := ceilf(UI.BLACK.get_height(font_size))
	var bar_top := name_height+float(values.Boss_bar_name_gap_px)+FRAME_MARGIN
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	offset_left = -bar_width/2-FRAME_MARGIN
	offset_right = bar_width/2+FRAME_MARGIN
	offset_top = float(values.Boss_bar_top_px)
	offset_bottom = offset_top+bar_top+bar_height+FRAME_MARGIN
	name_label = Label.new()
	name_label.name = "Name"
	name_label.position = Vector2.ZERO
	name_label.size = Vector2(bar_width+FRAME_MARGIN*2,name_height)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.add_theme_font_override("font",UI.BLACK)
	name_label.add_theme_font_size_override("font_size",font_size)
	name_label.add_theme_color_override("font_color",NAME_COLOR)
	name_label.add_theme_color_override("font_outline_color",NAME_OUTLINE)
	name_label.add_theme_constant_override("outline_size",3)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)
	frame = Panel.new()
	frame.name = "Frame"
	frame.position = Vector2(0,bar_top-FRAME_MARGIN)
	frame.size = Vector2(bar_width+FRAME_MARGIN*2,bar_height+FRAME_MARGIN*2)
	frame.add_theme_stylebox_override("panel",UI.THEME.get_stylebox("background","ProgressBar"))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	back = ColorRect.new()
	back.name = "Back"
	back.position = Vector2(FRAME_MARGIN,bar_top)
	back.size = Vector2(bar_width,bar_height)
	back.color = values.Boss_bar_back_color
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	fill = ColorRect.new()
	fill.name = "Fill"
	fill.position = back.position
	fill.size = back.size
	fill.color = values.Boss_bar_color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	hide()

# Screen y of the bar's lower edge; toasts stack below it while the bar is shown.
func bottom_px() -> float:
	return offset_bottom

func show_boss(actor: Node, display_name: String) -> void:
	release()
	boss = actor
	name_label.text = display_name
	actor.damaged.connect(_on_damaged)
	actor.died.connect(_on_gone)
	actor.tree_exiting.connect(release)
	_apply()
	show()

func release() -> void:
	if is_instance_valid(boss):
		if boss.damaged.is_connected(_on_damaged): boss.damaged.disconnect(_on_damaged)
		if boss.died.is_connected(_on_gone): boss.died.disconnect(_on_gone)
		if boss.tree_exiting.is_connected(release): boss.tree_exiting.disconnect(release)
	boss = null
	if visible: hide()

func ratio() -> float:
	return fill.size.x/bar_width

func _on_damaged(_world_position: Vector2) -> void:
	_apply()

func _on_gone(_dead: Node) -> void:
	release()

func _apply() -> void:
	updates += 1
	fill.size.x = bar_width*clampf(float(boss.hp)/maxf(float(boss.max_hp),1.0),0,1)
