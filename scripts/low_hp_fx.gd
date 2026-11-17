extends CanvasLayer
# JUICE-01 low-hp warning: red edge vignette with a double heartbeat, plus a BGM low-pass through
# GameAudio. Driven by the player's hp_changed signal; processes only while showing or fading.
var settings: Dictionary = preload("res://scripts/shadow_afterimage.gd").compiled_presentation()
var player: Node2D
var rect: ColorRect
var active := false
var level := 0.0
var clock := 0.0
var released := false
var updates := 0
# One material, created once; attached only while the warning is visible so idle frames carry none.
var vignette: ShaderMaterial

func configure(owner_player: Node2D) -> void:
	player = owner_player
	player.hp_changed.connect(refresh)
	player.died.connect(release)

func _ready() -> void:
	layer = 109
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.name = "LowHpVignette"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette = ShaderMaterial.new()
	vignette.shader = preload("res://scripts/skill_vignette.gdshader")
	vignette.set_shader_parameter("tint",settings.Low_hp_color)
	vignette.set_shader_parameter("width",float(settings.Low_hp_vignette_width))
	vignette.set_shader_parameter("strength",0.0)
	add_child(rect)
	rect.hide()
	set_process(false)
	tree_exiting.connect(_reset_audio)
	refresh()

func audio() -> Node:
	return preload("res://scripts/audio_events.gd").manager(self)

func _reset_audio() -> void:
	var manager := audio()
	if manager!=null: manager.reset_low_hp()

func should_show() -> bool:
	return not released and is_instance_valid(player) and not player.is_dead and not player.run_finished and player.hp>0 and float(player.hp)<=float(player.max_hp)*float(settings.Low_hp_ratio)

func refresh() -> void:
	if player==null or not is_inside_tree(): return
	var next := should_show()
	if next==active: return
	active = next
	updates += 1
	if active: clock = 0.0
	var manager := audio()
	if manager!=null: manager.set_low_hp(active)
	rect.material = vignette
	set_process(true)

# Death, result screen: fade the warning out and keep it off for the rest of the round.
func release(_unused: Variant = null) -> void:
	released = true
	refresh()

# Double beat per 1/Low_hp_beat_hz seconds: a strong pulse then a weaker one.
func beat(time: float) -> float:
	var phase := fposmod(time*float(settings.Low_hp_beat_hz),1.0)
	var first := exp(-pow((phase-0.08)/0.06,2))
	var second := 0.7*exp(-pow((phase-0.30)/0.06,2))
	return maxf(first,second)

func _process(delta: float) -> void:
	var frozen := get_tree().paused and active
	if not frozen:
		clock += delta
		level = move_toward(level,1.0 if active else 0.0,delta/maxf(float(settings.Low_hp_fade_sec),0.000001))
	var low := float(settings.Low_hp_alpha_min)
	var strength := level*(low+(float(settings.Low_hp_alpha_max)-low)*beat(clock))
	vignette.set_shader_parameter("strength",strength)
	rect.visible = level>0
	if not active and level<=0:
		rect.material = null
		set_process(false)
