extends Node2D

var source: SpriteBody
var values: Dictionary
var image_pose := Transform2D.IDENTITY
var canvas_rect := Rect2()
var boosted_alpha := 0.0
var flame_length := 0.0

func configure(body: SpriteBody, settings: Dictionary) -> void:
	source = body
	values = settings
	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://scripts/shadow_aura.gdshader")
	material = shader_material
	z_index = -1

func sync_pose(at: float, attacking: bool) -> void:
	visible = is_instance_valid(source) and source.visible and source.texture!=null and not source.using_fallback
	if not visible: return
	position = source.position
	image_pose = source.image_transform()
	var rect := source.display_rect()
	var radius := float(values.Aura_px)
	flame_length = float(values.Aura_flame_px)*(float(values.Aura_attack_flame_mult) if attacking else 1.0)
	boosted_alpha = minf(1,float(values.Aura_alpha)*(float(values.Aura_attack_boost) if attacking else 1.0))
	canvas_rect = rect.grow(radius)
	canvas_rect.position.y -= flame_length
	canvas_rect.size.y += flame_length
	var frame := source.source_rect()
	var atlas := Vector2(source.texture.get_size())
	material.set_shader_parameter("source_atlas",source.texture)
	material.set_shader_parameter("frame_uv",Vector4(frame.position.x/atlas.x,frame.position.y/atlas.y,frame.size.x/atlas.x,frame.size.y/atlas.y))
	material.set_shader_parameter("body_size",rect.size)
	material.set_shader_parameter("canvas_size",canvas_rect.size)
	material.set_shader_parameter("padding",rect.position-canvas_rect.position)
	material.set_shader_parameter("aura_px",radius)
	material.set_shader_parameter("flame_px",flame_length)
	material.set_shader_parameter("aura_alpha",boosted_alpha)
	material.set_shader_parameter("aura_color",Color(String(values.Aura_color)))
	material.set_shader_parameter("core_color",Color(String(values.Aura_core_color)))
	material.set_shader_parameter("flicker_hz",float(values.Aura_flicker_hz))
	material.set_shader_parameter("aura_time",at)
	material.set_shader_parameter("noise_scale",float(values.Aura_noise_scale))
	material.set_shader_parameter("core_spread_ratio",float(values.Aura_core_spread_ratio))
	material.set_shader_parameter("core_flame_ratio",float(values.Aura_core_flame_ratio))
	queue_redraw()

func _draw() -> void:
	if not visible: return
	draw_set_transform_matrix(image_pose)
	draw_rect(canvas_rect,Color.WHITE)
	draw_set_transform_matrix(Transform2D.IDENTITY)
