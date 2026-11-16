extends CanvasLayer
# Presentation only: callers keep the existing flow order; this layer never blocks input.
var rect: ColorRect
var effect: ShaderMaterial
var enabled := true
var cover_sec := 0.5
var reveal_sec := 0.6
var mode := "idle"
var age := 0.0
var on_covered: Callable

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	var values: Dictionary = preload("res://scripts/shadow_afterimage.gd").compiled_presentation()
	enabled = int(values.Ui_fx_enabled)!=0
	cover_sec = float(values.get("Stage_cover_sec",0.5))
	reveal_sec = float(values.get("Stage_reveal_sec",0.6))
	rect = ColorRect.new()
	rect.name = "StageTransition"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect = ShaderMaterial.new()
	effect.shader = preload("res://scripts/stage_transition.gdshader")
	effect.set_shader_parameter("shade_color",Color(values.get("Stage_shade_color",Color("#0b0618"))))
	effect.set_shader_parameter("glow_color",Color(values.get("Stage_glow_color",Color("#7a5cff"))))
	effect.set_shader_parameter("band",float(values.get("Stage_glow_band",0.08)))
	effect.set_shader_parameter("noise_scale",float(values.get("Stage_noise_scale",6)))
	effect.set_shader_parameter("noise_mix",float(values.get("Stage_noise_mix",0.35)))
	rect.material = effect
	add_child(rect)
	finish()

func busy() -> bool:
	return mode=="cover"

# Covers the screen, then runs action. Disabled UI effects run action at once.
func cover(action: Callable) -> void:
	if not enabled:
		action.call()
		return
	if mode=="cover": return
	on_covered = action
	mode = "cover"
	age = 0.0
	_apply(0.0)

# Starts fully covered (or from the current cover) and clears from the centre outward.
func reveal() -> void:
	if not enabled:
		finish()
		return
	mode = "reveal"
	age = 0.0
	_apply(1.0)

func finish() -> void:
	mode = "idle"
	age = 0.0
	rect.hide()
	set_process(false)

func _apply(threshold: float) -> void:
	effect.set_shader_parameter("threshold",threshold)
	rect.show()
	set_process(true)

func _process(delta: float) -> void:
	age += maxf(delta,0)
	if mode=="cover":
		var t := clampf(age/maxf(cover_sec,0.000001),0,1)
		effect.set_shader_parameter("threshold",smoothstep(0.0,1.0,t))
		if t>=1:
			var action := on_covered
			on_covered = Callable()
			mode = "covered"
			set_process(false)
			if action.is_valid(): action.call()
	elif mode=="reveal":
		var t := clampf(age/maxf(reveal_sec,0.000001),0,1)
		effect.set_shader_parameter("threshold",1-smoothstep(0.0,1.0,t))
		if t>=1: finish()
