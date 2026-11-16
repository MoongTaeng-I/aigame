extends RefCounted

const THEME = preload("res://assets/ui/ui_theme.tres")
const BOLD = preload("res://assets/fonts/NotoSansKR-Bold-subset.otf")
const BLACK = preload("res://assets/fonts/NotoSansKR-Black-subset.otf")
const CREST = preload("res://assets/ui/ui_window_crest.png")
const FRAME = preload("res://assets/ui/ui_icon_frame.png")
const NOTICE = "본 게임은 웹툰 ‘나 혼자만 레벨업’의 비상업적 팬 게임(포트폴리오)입니다. 원작의 저작권은 각 권리자에게 있습니다."
# ui_window_crest.png is drawn from 10px above the window rect to 24px below it.
const CREST_TOP := -10.0
const ICONS = {
	"skill_dash":preload("res://assets/ui/icon_dash.png"),"skill_rapid_slash":preload("res://assets/ui/icon_rapid_slash.png"),
	"skill_stealth":preload("res://assets/ui/icon_stealth.png"),"skill_dragon_fear":preload("res://assets/ui/icon_dragon_fear.png"),
	"igrit":preload("res://assets/ui/icon_shadow_igris.png"),"charger_test":preload("res://assets/ui/icon_shadow_beru.png"),"belion":preload("res://assets/ui/icon_shadow_belion.png")}

static func settings() -> Dictionary:
	return preload("res://scripts/shadow_afterimage.gd").compiled_presentation()

static func icon(id: String) -> Texture2D:
	return ICONS.get(id.replace("choice_","").replace("shadow_",""))

static func panel(node: CanvasItem, box: Rect2, crest: bool = false) -> void:
	node.draw_style_box(THEME.get_stylebox("panel","Panel"),box)
	if crest: node.draw_texture_rect(CREST,Rect2(box.position+Vector2((box.size.x-96)/2,CREST_TOP),Vector2(96,34)),false)

# Inner margin of a ui_window rect: the drawn border line sits Ui_window_border_px inside the
# texture edge, and every label/button/slider keeps Ui_window_pad_x/y clear of that line.
static func window_margin() -> Vector4:
	var values := settings()
	var border := float(values.Ui_window_border_px)
	return Vector4(border+float(values.Ui_window_pad_x),border+float(values.Ui_window_pad_y),border+float(values.Ui_window_pad_x),border+float(values.Ui_window_pad_y))

static func window_style() -> StyleBoxTexture:
	var style := THEME.get_stylebox("panel","PanelContainer").duplicate() as StyleBoxTexture
	var margin := window_margin()
	style.content_margin_left = margin.x
	style.content_margin_top = margin.y
	style.content_margin_right = margin.z
	style.content_margin_bottom = margin.w
	return style

# Button rect height whose drawn face keeps `pad` px above and below one text line.
static func button_height(font_size: int, pad: float) -> float:
	return ceilf(float(settings().Ui_button_border_px)*2+pad*2+BOLD.get_height(font_size))

static func pad_window(container: PanelContainer) -> void:
	container.add_theme_stylebox_override("panel",window_style())

static func icon_draw(node: CanvasItem, texture: Texture2D, box: Rect2) -> void:
	if texture==null: return
	node.draw_texture_rect(texture,box.grow(-5),false)
	node.draw_style_box(preload("res://assets/ui/ui_theme.tres").get_stylebox("icon","SystemUI"),box)

static func crest(parent: Control) -> void:
	parent.draw.connect(func() -> void: parent.draw_texture(CREST,Vector2((parent.size.x-96)/2,CREST_TOP)))

static func animate_window(target: Control) -> Node:
	var motion := preload("res://scripts/ui_motion.gd").new()
	motion.target = target
	motion.values = settings()
	target.add_child(motion)
	return motion

static func animate_button(target: Button) -> void:
	preload("res://scripts/audio_events.gd").button(target)
	var values := settings()
	if int(values.Ui_fx_enabled)==0: return
	var tween: Array = [null]
	var scale_to := func(value: float) -> void:
		if tween[0]!=null and tween[0].is_valid(): tween[0].kill()
		target.pivot_offset = target.size/2
		tween[0] = target.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween[0].tween_property(target,"scale",Vector2.ONE*value,float(values.Ui_hover_sec))
	target.mouse_entered.connect(scale_to.bind(float(values.Ui_hover_scale)))
	target.mouse_exited.connect(scale_to.bind(1.0))
	target.button_down.connect(scale_to.bind(float(values.Ui_press_scale)))
	target.button_up.connect(scale_to.bind(1.0))
