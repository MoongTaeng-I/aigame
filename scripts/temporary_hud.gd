extends CanvasLayer

const Portrait = preload("res://scripts/shadow_portrait.gd")
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
const TEXT_COLOR := Color("#eee5ff")
var manager: EnemyManager
var summons: Node2D
var skill_ui: Control
var root_control: Control
var timer_label: Label
var roster: HBoxContainer
var entries: Array = []

func configure(owner_manager: EnemyManager, shadow_manager: Node2D, skills: Control) -> void:
	manager = owner_manager
	summons = shadow_manager
	skill_ui = skills

func _ready() -> void:
	root_control = Control.new()
	root_control.name = "TemporaryHudRoot"
	add_child(root_control)
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	root_control.add_child(roster)
	summons.list_changed.connect(rebuild_roster)
	rebuild_roster()
	refresh()

static func format_elapsed(seconds: float) -> String:
	var whole := maxi(0,floori(seconds))
	return "%02d:%02d" % [whole/60,whole%60]

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	if not is_instance_valid(manager) or not is_instance_valid(skill_ui): return
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
		var path := String(record.Icon) if record.get("Icon")!=null else ""
		var card := Panel.new()
		card.custom_minimum_size = ROSTER_CARD
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = BACKGROUND
		style.border_color = BORDER
		style.set_border_width_all(1)
		card.add_theme_stylebox_override("panel",style)
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
