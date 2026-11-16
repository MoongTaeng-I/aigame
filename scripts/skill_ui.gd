extends Control
const UI = preload("res://scripts/system_ui.gd")
var palette: Dictionary = load("res://scripts/shadow_afterimage.gd").compiled_presentation().duplicate()

# All temporary skill presentation values live here; gameplay values come from CSV.
const CARD := Vector2(172.8,178.2)
const GAP := 12.0
const MARGIN := Vector2(24,24)
const ICON_SIZE := Vector2(75.6,75.6)
const ICON_OFFSET := Vector2(48.6,20)
const ICON_PIXELS := 64
const GAUGE_RADIUS := 34.0
const GAUGE_WIDTH := 3.0
const ARC_SEGMENTS := 64
const FONT_SIZE := 16
const SMALL_FONT_SIZE := 14
const NAME_OFFSET := Vector2(12,155)
const KEY_OFFSET := Vector2(8,121)
const LEVEL_OFFSET := Vector2(8,20)
const PLUS_OFFSET := Vector2(108,20)
const TIME_OFFSET := Vector2(48,86)
const LOCK_OFFSET := Vector2(57,4)
const LOCK_SIZE := Vector2(14,12)
const LOCK_SHACKLE_RADIUS := 5.0
const BG := Color("#211c30")
const BORDER := Color("#5d4a7f")
const INK := Color("#ebf8ff")
const GLYPH := Color("#c5a3ff")
const PLUS_COLOR := Color("#b2ffb0")
const ACTIVE := Color("#ff405e")
const GAUGE := Color("#c8a3ff")
const EMPTY_GAUGE := Color("#40384f")
const BORDER_WIDTH := 2.0
const GLOW_LAYERS := 4
const GLOW_STEP := 2.0
const GLOW_ALPHA := 0.06
const BLUR_PIXELS := 3.0
const BLUR_TINT := Color(0.12,0.12,0.14,1)
const RANGE_COLOR := Color(0.72,0.46,1.0,0.65)
const RANGE_FILL := Color(0.54,0.28,0.85,0.08)
const RANGE_WIDTH := 2.0
const SHAPE_WIDTH := 0.12
const SHAPE_EXTENT := 0.78
const STEALTH_ALPHA := 0.45
const FEAR_COLOR := Color("#74b7ed")
const FEAR_FLASH_SEC := 0.2
const BLUR_SHADER := """shader_type canvas_item;
uniform float blur_px;
uniform vec4 tint : source_color;
void fragment() {
    vec2 step_uv = TEXTURE_PIXEL_SIZE * blur_px;
    vec4 sum = vec4(0.0);
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            sum += texture(TEXTURE, UV + vec2(float(x), float(y)) * step_uv);
        }
    }
    COLOR = (sum / 9.0) * tint;
}
"""

var manager: Node2D
var glyphs: Array[TextureRect] = []
var overlay: Control
var last_ui_state: Array = []
var last_phases: Array = []
var ready_flash := [0.0,0.0,0.0,0.0]
var ui_clock := 0.0

func configure(skill_manager: Node2D) -> void:
	manager = skill_manager

func _ready() -> void:
	theme = UI.THEME
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var shader := Shader.new()
	shader.code = BLUR_SHADER
	for index in range(manager.SkillData.IDS.size()):
		var glyph := TextureRect.new()
		glyph.texture = UI.icon(manager.SkillData.IDS[index])
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		glyph.size = Vector2(56,56)*float(palette.Skill_icon_scale)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not manager.skills[manager.SkillData.IDS[index]].implemented:
			var material := ShaderMaterial.new()
			material.shader = shader
			material.set_shader_parameter("blur_px",BLUR_PIXELS)
			material.set_shader_parameter("tint",BLUR_TINT)
			glyph.material = material
		add_child(glyph)
		glyphs.append(glyph)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlays)
	add_child(overlay)
	_layout()

func card_rect(index: int) -> Rect2:
	var total: float = CARD.x*float(palette.Skill_icon_scale)/1.35*manager.SkillData.IDS.size()+GAP*(manager.SkillData.IDS.size()-1)
	return Rect2(Vector2(size.x-MARGIN.x-total+(CARD.x*float(palette.Skill_icon_scale)/1.35+GAP)*index,size.y-MARGIN.y-CARD.y),Vector2(CARD.x*float(palette.Skill_icon_scale)/1.35,CARD.y))

func _layout() -> void:
	for index in range(glyphs.size()):
		glyphs[index].position = card_rect(index).position+ICON_OFFSET

func _process(_delta: float) -> void:
	var presentation: Dictionary = manager.presentation
	var alpha := float(presentation.get("Stealth_alpha",STEALTH_ALPHA)) if manager.player.is_stealthed() else 1.0
	var weight := float(presentation.get("Stealth_wave_strength",0.15))*(0.5+0.5*sin(manager.clock*TAU*float(presentation.get("Stealth_wave_hz",0.6)))) if manager.player.is_stealthed() else 0.0
	manager.player.modulate = Color(Color.WHITE.lerp(Color(presentation.get("Fear_color","#a34dff")),weight),alpha)
	ui_clock+=_delta
	var animating: bool = manager.player.enhancement_points>0
	for i in range(ready_flash.size()):
		if ready_flash[i]>0: animating = true; ready_flash[i] = maxf(0,ready_flash[i]-_delta)
	var phases: Array = []
	for i in range(manager.SkillData.IDS.size()):
		var phase: String = manager.icon_state(manager.SkillData.IDS[i]).phase
		if last_phases.size()>i and last_phases[i] in ["cooldown","locked"] and phase=="ready":
			ready_flash[i] = float(palette.Skill_ready_flash_sec); animating = true
		phases.append(phase)
	last_phases = phases
	var state: Array = [size,manager.player.enhancement_points]
	for id in manager.SkillData.IDS: state.append(manager.icon_state(id))
	var changed: bool = state!=last_ui_state
	var layout_changed: bool = last_ui_state.is_empty() or last_ui_state[0]!=size
	if changed:
		last_ui_state = state.duplicate(true)
	if layout_changed:
		_layout()
		queue_redraw()
	if (changed or animating) and overlay!=null: overlay.queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		for index in range(manager.SkillData.IDS.size()):
			if card_rect(index).has_point(event.position):
				preload("res://scripts/audio_events.gd").sfx(self,"ui_click")
				manager.try_upgrade(manager.SkillData.IDS[index])
				accept_event()
				return

func _draw() -> void:
	if manager==null:
		return
	var font := UI.BOLD
	for index in range(manager.SkillData.IDS.size()):
		var state: Dictionary = manager.icon_state(manager.SkillData.IDS[index])
		var box := card_rect(index)
		UI.panel(self,box)
		var name_width := font.get_string_size(state.name,HORIZONTAL_ALIGNMENT_LEFT,-1,FONT_SIZE).x
		var name_point := box.position+Vector2((box.size.x-name_width)/2,146)
		draw_string_outline(font,name_point,state.name,HORIZONTAL_ALIGNMENT_LEFT,box.size.x-32,FONT_SIZE,3,Color("#16265a"))
		draw_string(font,name_point,state.name,HORIZONTAL_ALIGNMENT_LEFT,box.size.x-32,FONT_SIZE,INK)


func cooldown_ratio(id: String) -> float:
	var cast = manager.skills[id]
	if cast.active or cast.snapshot.is_empty(): return 0
	return clampf((cast.cooldown_until-manager.clock)/maxf(0.000001,float(cast.snapshot.Cooldown_sec)),0,1)

func outlined(value: String, point: Vector2, font_size: int, color: Color = INK) -> void:
	overlay.draw_string_outline(UI.BLACK,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color("#16265a"))
	overlay.draw_string(UI.BLACK,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw_overlays() -> void:
	for index in range(manager.SkillData.IDS.size()):
		var id: String = manager.SkillData.IDS[index]
		var state: Dictionary = manager.icon_state(id)
		var box := card_rect(index)
		var icon := Rect2(box.position+ICON_OFFSET,Vector2(56,56)*float(palette.Skill_icon_scale))
		var center := icon.get_center()
		overlay.draw_style_box(UI.THEME.get_stylebox("icon","SystemUI"),icon.grow(5))
		if state.phase in ["unimplemented","locked"]:
			overlay.draw_texture_rect(preload("res://assets/ui/ui_lock.png"),Rect2(center-Vector2(14,14),Vector2(28,28)),false)
		if state.show_gauge:
			var ratio := cooldown_ratio(id)
			var points := PackedVector2Array([center])
			for j in range(65): points.append(center+Vector2.RIGHT.rotated(-PI/2+TAU*(1-ratio+ratio*j/64.0))*icon.size.x/2)
			if not Geometry2D.triangulate_polygon(points).is_empty(): overlay.draw_colored_polygon(points,Color(0,0,0,float(palette.Skill_cooldown_alpha)))
			var font_size := int(palette.Skill_cooldown_font_size)
			var width := UI.BLACK.get_string_size(state.cooldown_text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
			outlined(state.cooldown_text,center+Vector2(-width/2,UI.BLACK.get_ascent(font_size)/2),font_size)
		var dot := float(palette.Skill_level_dot_px)
		var count: int = manager.skills[id].max_level()
		for level in range(count):
			var point := Vector2(center.x+(level-(count-1)/2.0)*(dot*2+5),icon.end.y+20)
			overlay.draw_circle(point,dot,Color("#96d7ff") if level<int(state.level) else Color("#24364e"))
			overlay.draw_circle(point,dot,INK,false,1)
		outlined(state.key,icon.position+Vector2(-3,20),22)
		if state.show_plus:
			var alpha := lerpf(float(palette.Skill_plus_min_alpha),1,0.5+0.5*sin(ui_clock*TAU*float(palette.Skill_plus_blink_hz)))
			var point := icon.end-Vector2(1,1)
			overlay.draw_circle(point,float(palette.Skill_plus_radius),Color(palette.Skill_plus_color,alpha))
			outlined("+",point+Vector2(-9,10),28,Color("#16265a"))
		if state.active_border: overlay.draw_rect(box,ACTIVE,false,3)
		if ready_flash[index]>0: overlay.draw_rect(icon.grow(6),Color(1,1,1,ready_flash[index]/float(palette.Skill_ready_flash_sec)),false,4)
	var points: int = manager.player.enhancement_points
	var badge := Rect2(card_rect(0).position+Vector2(0,-96),Vector2(240,80))
	UI.panel(overlay,badge)
	var caption := "강화 포인트 %d" % points
	var caption_width := UI.BLACK.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
	outlined(caption,badge.position+Vector2((badge.size.x-caption_width)/2,50),20,Color(palette.Skill_plus_color) if points>=1 else Color("#7d8da4"))

static func draw_ranges(node: Node2D, effects: Array) -> void:
	for effect in effects:
		var pos := node.to_local(effect.center)
		node.draw_circle(pos,float(effect.radius),RANGE_FILL)
		node.draw_arc(pos,float(effect.radius),0.0,TAU,ARC_SEGMENTS,RANGE_COLOR,RANGE_WIDTH,true)
