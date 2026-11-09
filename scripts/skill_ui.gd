extends Control

# All temporary skill presentation values live here; gameplay values come from CSV.
const CARD := Vector2(128,132)
const GAP := 12.0
const MARGIN := Vector2(24,24)
const ICON_SIZE := Vector2(56,56)
const ICON_OFFSET := Vector2(36,14)
const ICON_PIXELS := 64
const GAUGE_RADIUS := 34.0
const GAUGE_WIDTH := 3.0
const ARC_SEGMENTS := 64
const FONT_SIZE := 16
const SMALL_FONT_SIZE := 14
const NAME_OFFSET := Vector2(8,100)
const KEY_OFFSET := Vector2(8,121)
const LEVEL_OFFSET := Vector2(8,20)
const PLUS_OFFSET := Vector2(108,20)
const TIME_OFFSET := Vector2(48,86)
const LOCK_OFFSET := Vector2(57,4)
const LOCK_SIZE := Vector2(14,12)
const LOCK_SHACKLE_RADIUS := 5.0
const BG := Color("#211c30")
const BORDER := Color("#5d4a7f")
const INK := Color("#eee5ff")
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
const STEALTH_ALPHA := 0.35
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

func configure(skill_manager: Node2D) -> void:
	manager = skill_manager

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var shader := Shader.new()
	shader.code = BLUR_SHADER
	for index in range(manager.SkillData.IDS.size()):
		var glyph := TextureRect.new()
		glyph.texture = _texture(index)
		glyph.size = ICON_SIZE
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
	var total: float = CARD.x*manager.SkillData.IDS.size()+GAP*(manager.SkillData.IDS.size()-1)
	return Rect2(Vector2(size.x-MARGIN.x-total+(CARD.x+GAP)*index,size.y-MARGIN.y-CARD.y),CARD)

func _layout() -> void:
	for index in range(glyphs.size()):
		glyphs[index].position = card_rect(index).position+ICON_OFFSET

func _process(_delta: float) -> void:
	manager.player.modulate.a = STEALTH_ALPHA if manager.player.is_stealthed() else 1.0
	_layout()
	queue_redraw()
	if overlay!=null:
		overlay.queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		for index in range(manager.SkillData.IDS.size()):
			if card_rect(index).has_point(event.position):
				manager.try_upgrade(manager.SkillData.IDS[index])
				accept_event()
				return

func _draw() -> void:
	if manager==null:
		return
	var font := ThemeDB.fallback_font
	for index in range(manager.SkillData.IDS.size()):
		var state: Dictionary = manager.icon_state(manager.SkillData.IDS[index])
		var box := card_rect(index)
		draw_rect(box,BG)
		draw_rect(box,BORDER,false,BORDER_WIDTH)
		draw_string(font,box.position+NAME_OFFSET,state.name,HORIZONTAL_ALIGNMENT_LEFT,CARD.x,FONT_SIZE,INK)
		draw_string(font,box.position+KEY_OFFSET,state.key,HORIZONTAL_ALIGNMENT_LEFT,CARD.x,SMALL_FONT_SIZE,INK)

func _draw_overlays() -> void:
	var font := ThemeDB.fallback_font
	for index in range(manager.SkillData.IDS.size()):
		var state: Dictionary = manager.icon_state(manager.SkillData.IDS[index])
		var box := card_rect(index)
		var center := box.position+ICON_OFFSET+ICON_SIZE/2.0
		if state.phase in ["unimplemented","locked"]:
			var pos := box.position+LOCK_OFFSET
			overlay.draw_rect(Rect2(pos,LOCK_SIZE),INK)
			overlay.draw_arc(pos+Vector2(LOCK_SIZE.x/2.0,0),LOCK_SHACKLE_RADIUS,PI,TAU,ARC_SEGMENTS,INK,BORDER_WIDTH,true)
		elif int(state.level)>0:
			overlay.draw_string(font,box.position+LEVEL_OFFSET,str(state.level),HORIZONTAL_ALIGNMENT_LEFT,CARD.x,SMALL_FONT_SIZE,INK)
		if state.show_plus:
			overlay.draw_string(font,box.position+PLUS_OFFSET,"+",HORIZONTAL_ALIGNMENT_LEFT,CARD.x,FONT_SIZE,PLUS_COLOR)
		if state.active_border:
			for layer in range(GLOW_LAYERS,0,-1):
				overlay.draw_rect(box.grow(layer*GLOW_STEP),Color(ACTIVE,GLOW_ALPHA),false,BORDER_WIDTH+layer*GLOW_STEP)
			overlay.draw_rect(box,ACTIVE,false,GAUGE_WIDTH)
		if state.show_gauge:
			overlay.draw_arc(center,GAUGE_RADIUS,-PI/2.0,TAU-PI/2.0,ARC_SEGMENTS,EMPTY_GAUGE,GAUGE_WIDTH,true)
			if float(state.progress)>0:
				overlay.draw_arc(center,GAUGE_RADIUS,-PI/2.0,-PI/2.0+TAU*float(state.progress),ARC_SEGMENTS,GAUGE,GAUGE_WIDTH,true)
			overlay.draw_string(font,box.position+TIME_OFFSET,state.cooldown_text,HORIZONTAL_ALIGNMENT_LEFT,CARD.x,FONT_SIZE,INK)

func _texture(index: int) -> ImageTexture:
	var image := Image.create(ICON_PIXELS,ICON_PIXELS,false,Image.FORMAT_RGBA8)
	for y in range(ICON_PIXELS):
		for x in range(ICON_PIXELS):
			var v := (Vector2(x,y)/float(ICON_PIXELS)-Vector2.ONE/2.0)*2.0
			var ink := false
			match index:
				0: ink = absf(v.y)<SHAPE_WIDTH and absf(v.x)<SHAPE_EXTENT or absf(v.x+absf(v.y)-SHAPE_EXTENT)<SHAPE_WIDTH
				1: ink = (absf(v.x+v.y)<SHAPE_WIDTH or absf(v.x+v.y-SHAPE_EXTENT)<SHAPE_WIDTH) and v.length()<SHAPE_EXTENT
				2: ink = absf(v.x)+absf(v.y)<SHAPE_EXTENT and absf(v.x)+absf(v.y)>SHAPE_EXTENT-SHAPE_WIDTH or v.length()<SHAPE_WIDTH*2.0
				3: ink = absf(v.x*v.y)<SHAPE_WIDTH and v.length()<SHAPE_EXTENT
			image.set_pixel(x,y,GLYPH if ink else Color.TRANSPARENT)
	return ImageTexture.create_from_image(image)

static func draw_ranges(node: Node2D, effects: Array) -> void:
	for effect in effects:
		var pos := node.to_local(effect.center)
		node.draw_circle(pos,float(effect.radius),RANGE_FILL)
		node.draw_arc(pos,float(effect.radius),0.0,TAU,ARC_SEGMENTS,RANGE_COLOR,RANGE_WIDTH,true)
