extends Node
var target: Control
var values: Dictionary
var age := 0.0
var closing := false
var base_position := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	base_position = target.position
	target.visibility_changed.connect(open)
	open()

func open() -> void:
	if closing: return
	age = 0
	set_process(target.visible and int(values.Ui_fx_enabled)!=0)
	if not is_processing():
		target.scale = Vector2.ONE
		target.modulate.a = 1
		target.position.x = base_position.x

func close() -> void:
	closing = true
	age = 0
	base_position = target.position
	set_process(true)
	if int(values.Ui_fx_enabled)==0: target.queue_free()

func _process(delta: float) -> void:
	age+=delta
	var duration := float(values.Ui_close_sec if closing else values.Ui_open_sec)
	var p := clampf(age/maxf(duration,0.000001),0,1)
	target.pivot_offset = target.size/2
	target.scale.y = lerpf(1,0,p) if closing else lerpf(float(values.Ui_open_scale_y),1,p)
	target.modulate.a = 1-p if closing else (float(values.Ui_flicker_alpha) if p<1 and sin(p*TAU*int(values.Ui_flicker_count))<0 else 1.0)
	target.position.x = base_position.x+(0.0 if closing else sin(p*TAU*int(values.Ui_flicker_count))*float(values.Ui_jitter_px)*(1-p))
	if p>=1:
		target.position.x = base_position.x
		set_process(false)
		if closing: target.queue_free()
