extends CanvasLayer
var settings: Dictionary
var screen: ColorRect
var dim_rect: ColorRect
var flash_rect: ColorRect
var white_rect: ColorRect
var vignette_rect: ColorRect
var shake_offset := Vector2.ZERO
var remaining := 0.0
var duration := 0.0
var strength := 0.0
var flash_remaining := 0.0
var elapsed := 0.0
var slash_active := false
var slash_alpha := 0.0
var white_remaining := 0.0
var white_duration := 0.0
var white_strength := 0.0
var vignette_remaining := 0.0
var vignette_duration := 0.0
var player_hit_remaining := 0.0
var push_direction := Vector2.ZERO
var push_px := 0.0
var push_remaining := 0.0
var push_duration := 0.0

func push(direction: Vector2, px: float, seconds: float) -> void:
	if int(settings.get("Shake_enabled",1))==0 or seconds<=0 or direction==Vector2.ZERO: return
	push_direction = direction.normalized()
	push_px = px
	push_duration = seconds
	push_remaining = seconds
	_process(0)

func set_slash_active(active: bool) -> void:
	slash_active = active

func flash_white(alpha: float, seconds: float) -> void:
	white_strength = alpha
	white_duration = seconds
	white_remaining = seconds
	_process(0)

func start_fear(cast_seconds: float) -> void:
	vignette_duration = cast_seconds+float(settings.get("Fear_vignette_tail_sec",0.6))
	vignette_remaining = vignette_duration
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
	dim_rect = overlay()
	flash_rect = overlay()
	white_rect = overlay()
	vignette_rect = overlay()
	var vignette := ShaderMaterial.new()
	vignette.shader = preload("res://scripts/skill_vignette.gdshader")
	vignette_rect.material = vignette
func kick(px: float, seconds: float, flash_sec: float = 0.0) -> void:
	var limit := float(settings.get("Shake_max_px",8))
	var current := strength*remaining/maxf(duration,0.000001)
	var incoming := minf(px,limit)
	if incoming>=current:
		strength = incoming
		duration = maxf(seconds,0.000001)
		remaining = seconds
	flash_remaining = maxf(flash_remaining,flash_sec)
	_process(0)
func _process(delta: float) -> void:
	delta *= float(get_viewport().get_meta(&"fx05_visual_scale",1.0)) if is_inside_tree() else 1.0
	player_hit_remaining = maxf(0,player_hit_remaining-delta)
	elapsed += maxf(delta,0)
	remaining = maxf(0,remaining-delta)
	flash_remaining = maxf(0,flash_remaining-delta)
	white_remaining = maxf(0,white_remaining-delta)
	vignette_remaining = maxf(0,vignette_remaining-delta)
	push_remaining = maxf(0,push_remaining-delta)
	var target := float(settings.get("Slash_dim_alpha",0.12)) if slash_active else 0.0
	var fade := float(settings.get("Slash_dim_in_sec",0.05)) if slash_active else float(settings.get("Slash_dim_out_sec",0.15))
	slash_alpha = move_toward(slash_alpha,target,float(settings.get("Slash_dim_alpha",0.12))*maxf(delta,0)/maxf(fade,0.000001))
	shake_offset = Vector2.ZERO
	if int(settings.get("Shake_enabled",1))!=0 and remaining>0:
		var phase := elapsed*TAU*float(settings.get("Shake_hz",38))
		shake_offset = Vector2(sin(phase),cos(phase*1.31))*strength*remaining/duration
	if int(settings.get("Shake_enabled",1))!=0 and push_remaining>0:
		# The shader samples at UV+offset, so the picture moves opposite the offset.
		shake_offset -= push_direction*push_px*push_remaining/push_duration
	shake_offset = shake_offset.limit_length(float(settings.get("Shake_max_px",8)))
	if screen==null: return
	screen.visible = shake_offset!=Vector2.ZERO
	if screen.visible: screen.material.set_shader_parameter("shake_uv",shake_offset/get_viewport().get_visible_rect().size)
	var fear := Color(settings.get("Fear_color",Color("#a34dff")))
	dim_rect.color = Color(settings.get("Fx_outline_color",Color("#16265a")),slash_alpha)
	flash_rect.color = Color(fear,float(settings.get("Fear_flash_alpha",0.18))*flash_remaining/maxf(0.000001,float(settings.get("Fear_flash_sec",0.15))))
	white_rect.color = Color(1,1,1,white_strength*white_remaining/maxf(white_duration,0.000001))
	dim_rect.visible = dim_rect.color.a>0
	flash_rect.visible = flash_rect.color.a>0
	white_rect.visible = white_rect.color.a>0
	vignette_rect.visible = vignette_remaining>0 or player_hit_remaining>0
	if vignette_rect.visible:
		var hit_strength := float(settings.Player_hit_vignette_alpha)*player_hit_remaining/float(settings.Player_hit_vignette_sec)
		var fear_strength := float(settings.get("Fear_vignette_alpha",0.6))*vignette_remaining/maxf(vignette_duration,0.000001)
		vignette_rect.material.set_shader_parameter("tint",settings.Player_hit_color if hit_strength>fear_strength else fear)
		vignette_rect.material.set_shader_parameter("strength",maxf(hit_strength,fear_strength))
		vignette_rect.material.set_shader_parameter("width",float(settings.get("Fear_vignette_width",0.4)))

func overlay() -> ColorRect:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rect)
	rect.hide()
	return rect

func player_hit() -> void:
	player_hit_remaining = float(settings.Player_hit_vignette_sec)
	_process(0)

func advance_result_kill(delta: float) -> void:
	# Only the approved kill flash/shake advances under the result pause.
	delta *= float(get_viewport().get_meta(&"fx05_visual_scale",1.0))
	elapsed += maxf(delta,0)
	remaining = maxf(0,remaining-delta)
	white_remaining = maxf(0,white_remaining-delta)
	shake_offset = Vector2.ZERO
	if int(settings.get("Shake_enabled",1))!=0 and remaining>0:
		var phase := elapsed*TAU*float(settings.get("Shake_hz",38))
		shake_offset = (Vector2(sin(phase),cos(phase*1.31))*strength*remaining/duration).limit_length(float(settings.Shake_max_px))
	if screen==null: return
	screen.visible = shake_offset!=Vector2.ZERO
	if screen.visible: screen.material.set_shader_parameter("shake_uv",shake_offset/get_viewport().get_visible_rect().size)
	white_rect.color = Color(1,1,1,white_strength*white_remaining/maxf(white_duration,0.000001))
	white_rect.visible = white_remaining>0
