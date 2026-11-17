extends Control
# FIX-03: boss name + HP bar at the top centre, below the experience bar. Updated from the boss's
# damaged/died/stealth signals. JUICE-01: delayed trail; the node processes only while it moves.
# FIX-04: drawn with ui_boss_bar_frame (NinePatch), ui_boss_bar_fill and ui_boss_bar_trail; the
# window crest sits on the frame. FIX-05: 0.8x overall and the name is laid over the crest.
const UI = preload("res://scripts/system_ui.gd")
const FRAME_TEXTURE = preload("res://assets/ui/ui_boss_bar_frame.png")
const FILL_TEXTURE = preload("res://assets/ui/ui_boss_bar_fill.png")
const TRAIL_TEXTURE = preload("res://assets/ui/ui_boss_bar_trail.png")
const NAME_COLOR := Color("#ebf8ff")
var values: Dictionary = preload("res://scripts/shadow_afterimage.gd").compiled_presentation()
var boss: Node
var name_label: Label
var crest: TextureRect
var frame: NinePatchRect
var trail: TextureRect
var fill: TextureRect
var bar_width := 544.0
var bar_height := 28.0
var updates := 0
var trail_wait := 0.0
var trail_from := 0.0
var trail_age := 0.0
var stealth_hidden := false
var name_top := 0.0

func _ready() -> void:
	name = "BossHealthBar"
	theme = UI.THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var total_width := float(values.Boss_bar_width)
	bar_height = float(values.Boss_bar_height)
	var patch := int(values.Boss_bar_frame_patch)
	# FIX-05: the frame art is drawn at Boss_bar_frame_scale, so its border line sits
	# Boss_bar_frame_line_px x scale in from the edge; the fill sits that far in plus the padding.
	var frame_scale := float(values.Boss_bar_frame_scale)
	var line := float(values.Boss_bar_frame_line_px)*frame_scale
	var inset := Vector2(line+float(values.Boss_bar_inner_pad_x),line+float(values.Boss_bar_inner_pad_y))
	bar_width = total_width-inset.x*2
	var frame_size := Vector2(total_width,bar_height+inset.y*2)
	var font_size := int(values.Boss_bar_name_font_size)
	var name_height := ceilf(UI.BLACK.get_height(font_size))
	var crest_scale := float(values.Boss_bar_crest_scale)
	var crest_size := Vector2(UI.CREST.get_size())*crest_scale
	# The crest overlaps the frame top down to the fill's top edge (never over the fill). The name is
	# laid over the crest, centred Boss_bar_name_center_ratio down its visible (non-transparent) height.
	var clear_top := float(values.Boss_bar_crest_clear_top_px)*crest_scale
	var name_center := clear_top+(crest_size.y-clear_top)*float(values.Boss_bar_name_center_ratio)
	var crest_top := maxf(0.0,name_height/2-name_center)
	var frame_top := crest_top+crest_size.y-inset.y
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	offset_left = -total_width/2
	offset_right = total_width/2
	offset_top = float(values.Boss_bar_top_px)
	offset_bottom = offset_top+frame_top+frame_size.y
	frame = NinePatchRect.new()
	frame.name = "Frame"
	frame.texture = FRAME_TEXTURE
	frame.patch_margin_left = patch; frame.patch_margin_right = patch; frame.patch_margin_top = patch; frame.patch_margin_bottom = patch
	frame.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	frame.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	frame.position = Vector2(0,frame_top)
	frame.size = frame_size/frame_scale
	frame.scale = Vector2.ONE*frame_scale
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	trail = bar_piece("Trail",TRAIL_TEXTURE,frame.position+inset)
	fill = bar_piece("Fill",FILL_TEXTURE,frame.position+inset)
	crest = TextureRect.new()
	crest.name = "Crest"
	crest.texture = UI.CREST
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_SCALE
	crest.position = Vector2((total_width-crest_size.x)/2,crest_top)
	name_top = crest_top+name_center-name_height/2
	crest.size = crest_size
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crest)
	name_label = Label.new()
	name_label.name = "Name"
	name_label.position = Vector2(0,name_top)
	name_label.size = Vector2(total_width,name_height)
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
	set_process(false)
	hide()

# Fill and trail textures stretch to the bar rect; only their width changes with hp.
func bar_piece(id: String, texture: Texture2D, at: Vector2) -> TextureRect:
	var piece := TextureRect.new()
	piece.name = id
	piece.texture = texture
	piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	piece.stretch_mode = TextureRect.STRETCH_SCALE
	piece.position = at
	piece.size = Vector2(bar_width,bar_height)
	piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(piece)
	return piece

# Rect (bar local) that the fill and trail occupy at full hp.
func bar_rect() -> Rect2:
	return Rect2(fill.position,Vector2(bar_width,bar_height))

# Screen y of the frame's lower edge; toasts stack below it while shown.
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
