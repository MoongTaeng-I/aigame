extends Node

var player: Node2D
var settings: Dictionary
var elapsed := 0.0
var total := 0.0
var completed := false
var artwork: SpriteBody
var overlay: ColorRect
var knock_direction := Vector2.ZERO

func configure(actor: Node2D, values: Dictionary) -> void:
	player = actor
	settings = values.duplicate()
	total = maxf(0,float(settings.get("Death_present_sec",1.2)))
	process_mode = Node.PROCESS_MODE_ALWAYS
	knock_direction = -player.last_hit_direction
	if total<=0:
		complete()
		return
	if player.sprite_body!=null:
		artwork = SpriteBody.new()
		artwork.configure_snapshot(player.sprite_body.pose_snapshot())
		artwork.show_shadow = false
		player.sprite_body.add_child(artwork)
		player.sprite_body.show_image = false
		var flash := ShaderMaterial.new()
		flash.shader = preload("res://scripts/hit_flash.gdshader")
		artwork.material = flash
	var layer := CanvasLayer.new()
	layer.layer = 80 # Flow result UI is layer90.
	add_child(layer)
	overlay = ColorRect.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)
	advance(0)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if completed: return
	elapsed = minf(total,elapsed+maxf(0,delta))
	var stagger := maxf(0,float(settings.get("Death_stagger_sec",0.3)))
	var drop := maxf(0,float(settings.get("Death_drop_sec",0.12)))
	var first := clampf(elapsed/maxf(stagger,0.000001),0,1)
	var offset := knock_direction*float(settings.get("Death_knock_px",7))*(1-pow(1-first,2))
	var angle := deg_to_rad(float(settings.get("Death_tilt_deg",6)))*(1-first)
	var stretch := Vector2.ONE
	if elapsed>=stagger:
		var squash := float(settings.get("Death_drop_squash",0.12))*(1-clampf((elapsed-stagger)/maxf(drop,0.000001),0,1))
		stretch = Vector2(1+squash*0.6,1-squash)
	if artwork!=null:
		artwork.frame_row = 0
		artwork.frame_column = mini(21 if elapsed<stagger else 22,artwork.columns-1)
		player.sprite_body.frame_row = artwork.frame_row
		player.sprite_body.frame_column = artwork.frame_column
		var pivot := Vector2(0,artwork.foot_y)
		artwork.motion_transform = Transform2D(angle,stretch,0,Vector2.ZERO)
		artwork.motion_transform.origin = pivot+offset-artwork.motion_transform*pivot
		var flash_sec := float(settings.get("Death_flash_sec",0.3))
		artwork.material.set_shader_parameter("hit_flash",maxf(0,1-elapsed/maxf(flash_sec,0.000001)) if flash_sec>0 else 0.0)
		artwork.queue_redraw()
	var dim := clampf((elapsed-stagger-drop)/maxf(total-stagger-drop,0.000001),0,1)
	if elapsed>=total: dim = 1
	overlay.color = Color(0,0,0,float(settings.get("Death_dim_alpha",0.45))*dim)
	if elapsed>=total: complete()

func complete() -> void:
	if completed: return
	completed = true
	set_process(false)
	player.finish_death_presentation()
