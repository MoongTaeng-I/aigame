extends CanvasLayer
var settings: Dictionary
var screen: ColorRect
var shake_offset := Vector2.ZERO
var remaining := 0.0
var duration := 0.0
var strength := 0.0
var flash_remaining := 0.0
var elapsed := 0.0
func _ready() -> void:
	layer = 110
	screen = ColorRect.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var effect := ShaderMaterial.new()
	effect.shader = load("res://scripts/skill_screen_fx.gdshader")
	screen.material = effect
	add_child(screen)
	screen.hide()
func kick(px: float, seconds: float, flash_sec: float = 0.0) -> void:
	strength = px
	duration = maxf(seconds,0.000001)
	remaining = seconds
	flash_remaining = maxf(flash_remaining,flash_sec)
	_process(0)
func _process(delta: float) -> void:
	elapsed += maxf(delta,0)
	remaining = maxf(0,remaining-delta)
	flash_remaining = maxf(0,flash_remaining-delta)
	shake_offset = Vector2.ZERO
	if int(settings.get("Shake_enabled",1))!=0 and remaining>0:
		var phase := elapsed*TAU*float(settings.get("Shake_hz",38))
		shake_offset = Vector2(sin(phase),cos(phase*1.31))*strength*remaining/duration
	if screen==null: return
	screen.visible = shake_offset!=Vector2.ZERO or flash_remaining>0
	screen.material.set_shader_parameter("shake_uv",shake_offset/get_viewport().get_visible_rect().size)
	screen.material.set_shader_parameter("flash",float(settings.get("Fear_flash_alpha",0.18))*flash_remaining/maxf(0.000001,float(settings.get("Fear_flash_sec",0.15))))
	screen.material.set_shader_parameter("flash_color",Color(String(settings.get("Fear_color","#a34dff"))))
