extends Node2D
const DOT := preload("res://assets/art/fx/fx_soft_dot.png")
const META := &"fx06_motion_dust"
var capacity := 96
var per_step := 3
var life := 0.3
var min_px := 8.0
var max_px := 12.0
var spread := 10.0
var rise := 6.0
var color := Color(1,1,1,0.5)
var origins := PackedVector2Array()
var drifts := PackedVector2Array()
var ages := PackedFloat32Array()
var sizes := PackedFloat32Array()
var active := 0
var random := RandomNumberGenerator.new()

static func find(source: Node) -> Node:
	if not source.is_inside_tree(): return null
	var viewport := source.get_viewport()
	return viewport.get_meta(META) if viewport.has_meta(META) else null

func configure(settings: Dictionary) -> void:
	capacity = int(settings.get("Move_dust_pool",96))
	per_step = int(settings.get("Move_dust_count",3))
	life = float(settings.get("Move_dust_sec",0.3))
	min_px = float(settings.get("Move_dust_min_px",8))
	max_px = float(settings.get("Move_dust_max_px",12))
	spread = float(settings.get("Move_dust_spread_px",10))
	rise = float(settings.get("Move_dust_rise_px",6))
	color = Color(Color(settings.get("Move_dust_color",Color.WHITE)),float(settings.get("Move_dust_alpha",0.5)))
	origins.resize(capacity); drifts.resize(capacity); ages.resize(capacity); sizes.resize(capacity)
	random.seed = 6060
	active = 0
	set_process(false)

func _enter_tree() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	get_viewport().set_meta(META,self)

func _ready() -> void:
	set_process(active>0)

func _exit_tree() -> void:
	var viewport := get_viewport()
	if viewport.has_meta(META) and viewport.get_meta(META)==self: viewport.remove_meta(META)

func emit(foot: Vector2) -> void:
	for i in range(per_step):
		if active>=capacity: return
		var side := random.randf_range(-1,1)
		origins[active] = to_local(foot)+Vector2(side*spread*0.5,0)
		drifts[active] = Vector2(side*spread,-rise)
		ages[active] = 0
		sizes[active] = random.randf_range(min_px,max_px)
		active += 1
	set_process(true)

func _process(delta: float) -> void:
	delta *= float(get_viewport().get_meta(&"fx05_visual_scale",1.0))
	var i := 0
	while i<active:
		ages[i] += maxf(delta,0)
		if ages[i]>=life:
			active -= 1
			origins[i] = origins[active]; drifts[i] = drifts[active]; ages[i] = ages[active]; sizes[i] = sizes[active]
		else: i += 1
	if active==0: set_process(false)
	queue_redraw()

func _draw() -> void:
	for i in range(active):
		var t := ages[i]/life
		var size := sizes[i]*(0.6+0.6*t)
		draw_texture_rect(DOT,Rect2(origins[i]+drifts[i]*t-Vector2.ONE*size*0.5,Vector2.ONE*size),false,Color(color,color.a*(1-t)))
