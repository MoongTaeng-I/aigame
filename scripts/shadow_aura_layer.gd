extends Node2D

var source: SpriteBody
var values: Dictionary
var image_pose := Transform2D.IDENTITY
var canvas_rect := Rect2()
var boosted_alpha := 0.0
var flame_length := 0.0
var uniforms := {}

func configure(body: SpriteBody, settings: Dictionary) -> void:
	source = body
	values = settings
	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://scripts/shadow_aura.gdshader")
	material = shader_material
	z_index = -1

func sync_pose(at: float, attacking: bool) -> void:
	var old_pose := image_pose
	var old_rect := canvas_rect
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
	set_uniform("source_atlas",source.texture)
	set_uniform("frame_uv",Vector4(frame.position.x/atlas.x,frame.position.y/atlas.y,frame.size.x/atlas.x,frame.size.y/atlas.y))
	set_uniform("body_size",rect.size)
	set_uniform("canvas_size",canvas_rect.size)
	set_uniform("padding",rect.position-canvas_rect.position)
	set_uniform("aura_px",radius)
	set_uniform("flame_px",flame_length)
	set_uniform("aura_alpha",boosted_alpha)
	set_uniform("aura_color",Color(values.Aura_color))
	set_uniform("core_color",Color(values.Aura_core_color))
	set_uniform("flicker_hz",float(values.Aura_flicker_hz))
	set_uniform("aura_time",at)
	set_uniform("noise_scale",float(values.Aura_noise_scale))
	set_uniform("core_spread_ratio",float(values.Aura_core_spread_ratio))
	set_uniform("core_flame_ratio",float(values.Aura_core_flame_ratio))
	if image_pose!=old_pose or canvas_rect!=old_rect: queue_redraw()

func _draw() -> void:
	if not visible: return
	draw_set_transform_matrix(image_pose)
	draw_rect(canvas_rect,Color.WHITE)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func set_uniform(key: String, value: Variant) -> void:
	if uniforms.get(key)==value: return
	uniforms[key] = value
	material.set_shader_parameter(key,value)
