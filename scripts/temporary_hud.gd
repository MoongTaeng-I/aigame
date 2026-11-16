extends CanvasLayer

const UI = preload("res://scripts/system_ui.gd")
const Portrait = preload("res://scripts/shadow_portrait.gd")
const COMBAT_UI_SCALE := 0.75
const TIMER_MARGIN := Vector2(24,16)
const TIMER_SIZE := Vector2(160,36)
const TIMER_FONT_SIZE := 22
const ROSTER_CARD := Vector2(144,64)
const ROSTER_GAP := 10.0
const ROSTER_ABOVE_SKILLS := 12.0
const ICON_SIZE := Vector2(40,40)
const ICON_MARGIN := Vector2(8,12)
const NAME_MARGIN := Vector2(54,12)
const NAME_SIZE := Vector2(86,40)
const FONT_SIZE := 16
const BACKGROUND := Color("#211c30")
const BORDER := Color("#5d4a7f")
const TEXT_COLOR := Color("#ebf8ff")
var manager: EnemyManager
var summons: Node2D
var skill_ui: Control
var root_control: Control
var timer_label: Label
var roster: HBoxContainer
var entries: Array = []
var xp_bar: ProgressBar
var level_label: Label
var debug_labels: Array = []
var world_map: Node2D
var player: Node2D
var debug_visible := false
var performance_label: Label
var performance_elapsed := 0.0

func configure_look(map: Node2D, actor: Node2D, labels: Array) -> void:
	world_map = map
	player = actor
	debug_labels = labels
	for label in debug_labels: label.hide()
	# Keep the optional enemy counter clear of Lv and the two-line XP debug label.
	if not debug_labels.is_empty(): debug_labels[0].position.y = 140

func configure(owner_manager: EnemyManager, shadow_manager: Node2D, skills: Control) -> void:
	manager = owner_manager
	summons = shadow_manager
	skill_ui = skills

func _ready() -> void:
	root_control = Control.new()
	root_control.theme = UI.THEME
	root_control.name = "TemporaryHudRoot"
	add_child(root_control)
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	performance_label = Label.new()
	performance_label.name = "DebugPerformance"
	performance_label.position = Vector2(20,172)
	performance_label.add_theme_font_size_override("font_size",16)
	performance_label.add_theme_color_override("font_color",Color("#ebf8ff"))
	performance_label.hide()
	root_control.add_child(performance_label)
	if player!=null:
		xp_bar = ProgressBar.new()
		xp_bar.name = "TopExperienceBar"
		xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		xp_bar.show_percentage = false
		root_control.add_child(xp_bar)
		xp_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		xp_bar.offset_bottom = 8
		xp_bar.theme = UI.THEME
		level_label = Label.new()
		level_label.name = "PlayerLevel"
		level_label.position = Vector2(20,16)
		level_label.add_theme_color_override("font_color",Color("#ebf8ff"))
		level_label.add_theme_font_size_override("font_size",22)
		root_control.add_child(level_label)
		var hp_bar := preload("res://scripts/player_hp_bar.gd").new()
		hp_bar.name = "FootHpBar"
		hp_bar.player = player
		hp_bar.settings = load("res://scripts/shadow_afterimage.gd").compiled_presentation().duplicate()
		player.add_child(hp_bar)
	timer_label = Label.new()
	timer_label.name = "ElapsedTime"
	root_control.add_child(timer_label)
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	timer_label.offset_left = -TIMER_MARGIN.x-TIMER_SIZE.x
	timer_label.offset_right = -TIMER_MARGIN.x
	timer_label.offset_top = TIMER_MARGIN.y
	timer_label.offset_bottom = TIMER_MARGIN.y+TIMER_SIZE.y
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.add_theme_font_size_override("font_size",TIMER_FONT_SIZE)
	timer_label.add_theme_color_override("font_color",TEXT_COLOR)
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roster = HBoxContainer.new()
	roster.name = "OwnedShadows"
	roster.add_theme_constant_override("separation",int(ROSTER_GAP))
	roster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Share the skill control transform so logical layout and input remain aligned.
	skill_ui.add_child(roster)
	summons.list_changed.connect(rebuild_roster)
	rebuild_roster()
	refresh()

static func format_elapsed(seconds: float) -> String:
	var whole := maxi(0,floori(seconds))
	return "%02d:%02d" % [whole/60,whole%60]

func _process(_delta: float) -> void:
	refresh()
	if debug_visible:
		performance_elapsed += _delta
		if performance_elapsed>=0.25:
			performance_elapsed = 0
			performance_label.text = "FPS %d | Draw %d | Objects %d | Nodes %d | Enemies %d" % [Engine.get_frames_per_second(),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.OBJECT_COUNT),Performance.get_monitor(Performance.OBJECT_NODE_COUNT),manager.get_alive_count()]

func refresh() -> void:
	if not is_instance_valid(manager) or not is_instance_valid(skill_ui): return
	if player!=null:
		xp_bar.max_value = maxi(1,player.get_xp_to_next())
		xp_bar.value = player.experience
		level_label.text = "Lv %d" % player.level
	skill_ui.pivot_offset = skill_ui.size
	skill_ui.scale = Vector2.ONE*COMBAT_UI_SCALE
	timer_label.text = format_elapsed(manager._elapsed_seconds)
	var skill_box: Rect2 = skill_ui.card_rect(skill_ui.manager.SkillData.IDS.size()-1)
	var width := ROSTER_CARD.x*entries.size()+ROSTER_GAP*maxi(0,entries.size()-1)
	roster.position = Vector2(skill_box.end.x-width,skill_box.position.y-ROSTER_ABOVE_SKILLS-ROSTER_CARD.y)
	roster.size = Vector2(width,ROSTER_CARD.y)

func rebuild_roster() -> void:
	for child in roster.get_children(): child.free()
	entries.clear()
	for actor in summons.actors:
		var record: Dictionary = actor.config
		var mapped: Texture2D = UI.icon(String(record.Id))
		var path := String(record.Icon) if record.get("Icon")!=null else ""
		if path.is_empty() and mapped!=null: path = mapped.resource_path
		var card := Panel.new()
		card.custom_minimum_size = ROSTER_CARD
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.theme = UI.THEME
		roster.add_child(card)
		var icon: Control
		if path.is_empty():
			icon = Portrait.new()
			icon.dash_shape = actor.is_dash_through()
		else:
			var image := TextureRect.new()
			image.texture = load(path) as Texture2D
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon = image
		icon.position = ICON_MARGIN
		icon.size = ICON_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		var frame := NinePatchRect.new()
		frame.texture = UI.FRAME
		frame.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
		frame.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
		frame.patch_margin_left = 20; frame.patch_margin_right = 20; frame.patch_margin_top = 20; frame.patch_margin_bottom = 20
		frame.position = ICON_MARGIN-Vector2(4,4); frame.size = ICON_SIZE+Vector2(8,8)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(frame)
		var label := Label.new()
		label.text = String(record.get("Name_ko",""))
		label.position = NAME_MARGIN
		label.size = NAME_SIZE
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size",FONT_SIZE)
		label.add_theme_color_override("font_color",TEXT_COLOR)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(label)
		entries.append({"Id":record.Id,"name":label.text,"icon_path":path,"fallback":path.is_empty(),"icon":icon})
	refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode==KEY_F3 or event.keycode==KEY_F3):
		toggle_debug()
		get_viewport().set_input_as_handled()

func toggle_debug() -> void:
	debug_visible = not debug_visible
	if performance_label!=null: performance_label.visible = debug_visible
	for label in debug_labels: label.visible = debug_visible
	if world_map!=null: world_map.set_debug_visible(debug_visible)
