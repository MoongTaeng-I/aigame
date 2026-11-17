extends Control
# FIX-03: large boss name + HP bar at the top centre, below the experience bar.
# Updated from the boss's damaged/died/stealth signals. JUICE-01: a delayed white trail sits between
# Back and Fill; the node processes only while that trail is waiting or draining.
const UI = preload("res://scripts/system_ui.gd")
const NAME_COLOR := Color("#ebf8ff")
var values: Dictionary = preload("res://scripts/shadow_afterimage.gd").compiled_presentation()
var boss: Node
var name_label: Label
var frame: Panel
var inner: Panel
var back: ColorRect
var trail: ColorRect
var fill: ColorRect
var bar_width := 560.0
var bar_height := 18.0
var updates := 0
var trail_wait := 0.0
var trail_from := 0.0
var trail_age := 0.0
var stealth_hidden := false

func _ready() -> void:
	name = "BossHealthBar"
	theme = UI.THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_width = float(values.Boss_bar_width)
	bar_height = float(values.Boss_bar_height)
	var line := float(values.Boss_bar_inner_line_px)
	var border := float(values.Boss_bar_border_px)
	var margin := line+border
	var font_size := int(values.Boss_bar_name_font_size)
	var name_height := ceilf(UI.BLACK.get_height(font_size))
	var bar_top := name_height+float(values.Boss_bar_name_gap_px)+margin
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	offset_left = -bar_width/2-margin
	offset_right = bar_width/2+margin
	offset_top = float(values.Boss_bar_top_px)
	offset_bottom = offset_top+bar_top+bar_height+margin
	name_label = Label.new()
	name_label.name = "Name"
	name_label.position = Vector2.ZERO
	name_label.size = Vector2(bar_width+margin*2,name_height)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.add_theme_font_override("font",UI.BLACK)
	name_label.add_theme_font_size_override("font_size",font_size)
	name_label.add_theme_color_override("font_color",NAME_COLOR)
	name_label.add_theme_color_override("font_outline_color",values.Boss_bar_name_outline_color)
	name_label.add_theme_constant_override("outline_size",int(values.Boss_bar_name_outline_px)*2)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)
	back = ColorRect.new()
	back.name = "Back"
	back.position = Vector2(margin,bar_top)
	back.size = Vector2(bar_width,bar_height)
	back.color = values.Boss_bar_back_color
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	trail = ColorRect.new()
	trail.name = "Trail"
	trail.position = back.position
	trail.size = back.size
	trail.color = Color(values.Boss_bar_trail_color,float(values.Boss_bar_trail_alpha))
	trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(trail)
	fill = ColorRect.new()
	fill.name = "Fill"
	fill.position = back.position
	fill.size = back.size
	fill.color = values.Boss_bar_color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	inner = outline("InnerLine",Rect2(back.position-Vector2.ONE*line,back.size+Vector2.ONE*line*2),line,values.Boss_bar_inner_line_color)
	frame = outline("Frame",Rect2(back.position-Vector2.ONE*margin,back.size+Vector2.ONE*margin*2),border,Color(values.Boss_bar_border_color,float(values.Boss_bar_border_alpha)))
	set_process(false)
	hide()

func outline(id: String, box: Rect2, width: float, color: Color) -> Panel:
	var view := Panel.new()
	view.name = id
	view.position = box.position
	view.size = box.size
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.set_border_width_all(int(width))
	style.border_color = color
	view.add_theme_stylebox_override("panel",style)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	return view

# Screen y of the bar's lower edge (outer border included); toasts stack below it while shown.
func bottom_px() -> float:
	return offset_bottom

func show_boss(actor: Node, display_name: String) -> void:
	release()
	boss = actor
	name_label.text = display_name
	actor.damaged.connect(_on_damaged)
	actor.died.connect(_on_gone)
	actor.tree_exiting.connect(release)
	if actor.has_signal("stealth_changed"): actor.stealth_changed.connect(_on_stealth)
	_apply()
	trail.size.x = fill.size.x
	stealth_hidden = actor.get("elf")!=null and actor.elf.hidden
	visible = not stealth_hidden

func release() -> void:
	if is_instance_valid(boss):
		if boss.damaged.is_connected(_on_damaged): boss.damaged.disconnect(_on_damaged)
		if boss.died.is_connected(_on_gone): boss.died.disconnect(_on_gone)
		if boss.tree_exiting.is_connected(release): boss.tree_exiting.disconnect(release)
		if boss.has_signal("stealth_changed") and boss.stealth_changed.is_connected(_on_stealth): boss.stealth_changed.disconnect(_on_stealth)
	boss = null
	stealth_hidden = false
	trail_wait = 0.0
	set_process(false)
	if visible: hide()

func ratio() -> float:
	return fill.size.x/bar_width

func trail_ratio() -> float:
	return trail.size.x/bar_width

func _on_damaged(_world_position: Vector2) -> void:
	_apply()

func _on_gone(_dead: Node) -> void:
	release()

# Same rule as the overhead bar: hidden while the elf is stealthed, shown again when it ends.
func _on_stealth(hidden_now: bool) -> void:
	stealth_hidden = hidden_now
	visible = is_instance_valid(boss) and not hidden_now

func _apply() -> void:
	updates += 1
	fill.size.x = bar_width*clampf(float(boss.hp)/maxf(float(boss.max_hp),1.0),0,1)
	if trail.size.x<fill.size.x or int(values.Ui_fx_enabled)==0:
		trail.size.x = fill.size.x
		set_process(false)
		return
	if trail.size.x>fill.size.x:
		# A new hit restarts the wait and keeps the trail where it is.
		trail_wait = float(values.Boss_bar_trail_delay_sec)
		trail_from = trail.size.x
		trail_age = 0.0
		set_process(true)

func _process(delta: float) -> void:
	if trail_wait>0:
		trail_wait -= delta
		if trail_wait>0: return
		delta = -trail_wait
		trail_wait = 0.0
	trail_age += delta
	var t := clampf(trail_age/maxf(float(values.Boss_bar_trail_drain_sec),0.000001),0,1)
	trail.size.x = lerpf(trail_from,fill.size.x,t)
	if t>=1:
		trail.size.x = fill.size.x
		set_process(false)
