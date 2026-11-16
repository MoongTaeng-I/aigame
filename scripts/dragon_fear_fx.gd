extends Node2D
const RING := preload("res://assets/art/fx/fx_soft_ring.png")
const THIN_RING := preload("res://assets/art/fx/fx_thin_ring.png")
const DISK := preload("res://assets/art/fx/fx_soft_disk.png")
const DOT := preload("res://assets/art/fx/fx_soft_dot.png")
var settings: Dictionary
var radius := 0.0 # Actual combat Range; never replaced by visual wave radius.
var duration := 0.5
var age := 0.0
var head_only := false
var head_texture: Texture2D
var waves: Array = []
var bats: Array = []
var claws: Array = []
var embers: Array = []
var glow: Node2D
var ground: Node2D
var wave_count := 3
var wave_delay := 0.08
var wave_max := 900.0
var y_scale := 0.62
var bat_tail := 0.6
var bat_travel := 1100.0
var bat_wing_min := 0.5
var bat_hz := 12.0
var bat_eye_px := 1.0
var eye_color := Color("#e8283c")
var ring_peak := 0.85
var ring_alpha := 0.9
var edge_color := Color("#ffb3ba")
var edge_peak := 0.88
var edge_offset := 1.04
var disk_color := Color("#5a0010")
var disk_sec := 1.1
var scratch_sec := 0.15
var scratch_draw_sec := 0.06
var scratch_width := 4.0
var scratch_color := Color("#e8283c")
var scratch_core := Color.WHITE
var claw_start_ratio := 0.15
var claw_curve := 0.15
var ember_sec := 0.8
var ember_color := Color("#ff3a2e")
var ember_travel := 150.0
var ember_rise := 90.0
var head_start_scale := 0.6
var head_px := 260.0
var head_rise := 30.0

static func additive_material() -> CanvasItemMaterial:
	if Engine.has_meta(&"fx06_additive"): return Engine.get_meta(&"fx06_additive")
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	Engine.set_meta(&"fx06_additive",material)
	return material

func cache_settings() -> void:
	wave_count = int(settings.get("Fear_wave_count",3))
	wave_delay = float(settings.get("Fear_wave_delay_sec",0.08))
	wave_max = float(settings.get("Fear_wave_max_px",900))
	y_scale = float(settings.get("Fear_wave_y_scale",0.62))
	bat_tail = float(settings.get("Fear_bat_tail_sec",0.6))
	bat_travel = float(settings.get("Fear_bat_travel_px",1100))
	bat_wing_min = float(settings.get("Fear_bat_wing_min",0.5))
	bat_hz = float(settings.get("Fear_bat_hz",12))
	bat_eye_px = float(settings.get("Fear_bat_eye_px",1))
	eye_color = Color(settings.get("Fear_color",Color("#e8283c")))
	ring_peak = float(settings.get("Fear_ring_tex_peak",0.85))
	ring_alpha = float(settings.get("Fear_ring_alpha",0.9))
	edge_color = Color(Color(settings.get("Fear_edge_color",Color("#ffb3ba"))),float(settings.get("Fear_edge_alpha",0.6)))
	edge_peak = float(settings.get("Fear_edge_tex_peak",0.88))
	edge_offset = float(settings.get("Fear_edge_offset",1.04))
	disk_color = Color(Color(settings.get("Fear_disk_color",Color("#5a0010"))),float(settings.get("Fear_disk_alpha",0.45)))
	disk_sec = duration+float(settings.get("Fear_disk_tail_sec",0.6))
	scratch_sec = float(settings.get("Fear_scratch_sec",0.15))
	scratch_draw_sec = scratch_sec*float(settings.get("Fear_scratch_draw_ratio",0.4))
	scratch_width = float(settings.get("Fear_scratch_width",4))
	scratch_color = Color(settings.get("Fear_claw_color",Color("#e8283c")))
	scratch_core = Color(settings.get("Fear_scratch_core_color",Color.WHITE))
	claw_start_ratio = float(settings.get("Fear_claw_start_ratio",0.15))
	claw_curve = float(settings.get("Fear_claw_curve",0.15))
	ember_sec = float(settings.get("Fear_ember_sec",0.8))
	ember_color = Color(settings.get("Fear_ember_color",Color("#ff3a2e")))
	ember_travel = float(settings.get("Fear_ember_travel_px",150))
	ember_rise = float(settings.get("Fear_ember_rise_px",90))
	head_start_scale = float(settings.get("Fear_head_start_scale",0.6))
	head_px = float(settings.get("Fear_head_px",260))
	head_rise = float(settings.get("Fear_head_rise_px",30))

func initialize(visual_rng: RandomNumberGenerator) -> void:
	cache_settings()
	var outer := Color(settings.get("Fear_ring_outer_color",Color("#ff2a3c")))
	var inner := Color(settings.get("Fear_ring_inner_color",Color("#7a0010")))
	for i in range(wave_count):
		waves.append({"delay":i*wave_delay,"color":outer.lerp(inner,float(i)/maxi(1,wave_count-1))})
	var claw_count := int(settings.get("Fear_claw_count",8))
	for i in range(claw_count):
		var angle := TAU*i/maxi(1,claw_count)+visual_rng.randf_range(-1,1)*float(settings.get("Fear_claw_jitter",0.1))
		claws.append(Vector2.RIGHT.rotated(angle))
	for i in range(int(settings.get("Fear_bat_count",20))):
		var direction := Vector2.RIGHT.rotated(visual_rng.randf()*TAU)
		bats.append({"direction":direction,"start":radius*visual_rng.randf()*float(settings.get("Fear_bat_start_ratio",0.8)),"size":visual_rng.randf_range(float(settings.get("Fear_bat_min_px",8)),float(settings.get("Fear_bat_max_px",14))),"phase":visual_rng.randf()*TAU})
	for i in range(int(settings.get("Fear_ember_count",40))):
		var direction := Vector2.RIGHT.rotated(visual_rng.randf()*TAU)
		embers.append({"direction":direction,"start":visual_rng.randf()*float(settings.get("Fear_ember_start_px",36)),"size":visual_rng.randf_range(float(settings.get("Fear_ember_min_px",8)),float(settings.get("Fear_ember_max_px",16))),"speed":visual_rng.randf_range(0.6,1.0)})
	glow = Node2D.new()
	# Fear_glow_additive 0 keeps normal blending so the reds stay dark on bright snow.
	glow.material = additive_material() if int(settings.get("Fear_glow_additive",1))!=0 else null
	glow.draw.connect(_draw_glow)
	add_child(glow)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if head_only: cache_settings()

# Ground disk sits just before CharacterBodies so actors draw above it.
func attach_ground() -> void:
	var parent := get_parent()
	ground = Node2D.new()
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ground.draw.connect(_draw_ground)
	parent.add_child(ground)
	var bodies := parent.get_node_or_null("CharacterBodies")
	if bodies!=null: parent.move_child(ground,bodies.get_index())
	ground.global_position = global_position
	tree_exiting.connect(ground.queue_free)

func wave_radius(at: float = -1, delay: float = 0) -> float:
	return wave_max*clampf(((age if at<0 else at)-delay)/maxf(duration,0.000001),0,1)

func lifetime() -> float:
	if head_only: return duration
	return maxf(maxf(duration+maxi(0,wave_count-1)*wave_delay,duration+bat_tail),maxf(disk_sec,ember_sec))

func _process(delta: float) -> void:
	delta *= float(get_viewport().get_meta(&"fx05_visual_scale",1.0)) if is_inside_tree() else 1.0
	age += maxf(delta,0)
	for i in range(waves.size()-1,-1,-1):
		if age>=float(waves[i].delay)+duration: waves.remove_at(i)
	if age>=scratch_sec: claws.clear()
	if age>=duration+bat_tail: bats.clear()
	if age>=ember_sec: embers.clear()
	if age>=lifetime():
		waves.clear()
		bats.clear()
		claws.clear()
		embers.clear()
		queue_free()
		return
	queue_redraw()
	if glow!=null: glow.queue_redraw()
	if is_instance_valid(ground): ground.queue_redraw()

func _draw() -> void:
	if head_only:
		var progress := clampf(age/maxf(duration,0.000001),0,1)
		var height := head_px*lerpf(head_start_scale,1,progress)
		var size := Vector2(height*496/640,height)
		var alpha := minf(progress*4,1)*minf((1-progress)*4,1)
		draw_texture_rect(head_texture,Rect2(Vector2(-size.x/2,-size.y-head_rise*progress),size),false,Color(1,1,1,alpha))
		return
	var bat_progress := clampf(age/maxf(duration+bat_tail,0.000001),0,1)
	var eye := Color(eye_color,1-bat_progress)
	for bat in bats:
		var center: Vector2 = Vector2(bat.direction)*(float(bat.start)+bat_travel*bat_progress)
		var size: float = bat.size
		var wing := size*lerpf(bat_wing_min,1,(sin(age*TAU*bat_hz+float(bat.phase))+1)*0.5)
		draw_colored_polygon(PackedVector2Array([center+Vector2(-size,-wing),center+Vector2(-size*0.45,0),center+Vector2(0,-size*0.2),center+Vector2(size*0.45,0),center+Vector2(size,-wing),center+Vector2(size*0.25,wing*0.4),center+Vector2(0,wing*0.2),center+Vector2(-size*0.25,wing*0.4)]),Color(0,0,0,1-bat_progress))
		for sign_x in [-1,1]: draw_circle(center+Vector2(sign_x*size*0.15,-size*0.1),bat_eye_px,eye)

func _draw_ground() -> void:
	if age>=disk_sec: return
	ground.draw_texture_rect(DISK,Rect2(-Vector2.ONE*radius,Vector2.ONE*radius*2),false,Color(disk_color,disk_color.a*(1-age/maxf(disk_sec,0.000001))))

func _draw_glow() -> void:
	glow.draw_set_transform(Vector2.ZERO,0,Vector2(1,y_scale))
	for wave in waves:
		var t := clampf((age-float(wave.delay))/maxf(duration,0.000001),0,1)
		var r := wave_radius(-1,float(wave.delay))
		if r<=0: continue
		var fade := minf(t*6,1)*(1-t)
		var half := r/ring_peak
		glow.draw_texture_rect(RING,Rect2(-Vector2.ONE*half,Vector2.ONE*half*2),false,Color(Color(wave.color),ring_alpha*fade))
		half = r*edge_offset/edge_peak
		glow.draw_texture_rect(THIN_RING,Rect2(-Vector2.ONE*half,Vector2.ONE*half*2),false,Color(edge_color,edge_color.a*fade))
	glow.draw_set_transform(Vector2.ZERO)
	if not claws.is_empty():
		var reach := clampf(age/maxf(scratch_draw_sec,0.000001),0,1)
		var alpha := 1-clampf(age/maxf(scratch_sec,0.000001),0,1)
		for direction in claws:
			var from: Vector2 = direction*radius*claw_start_ratio
			var to: Vector2 = from.lerp(Vector2(direction).rotated(claw_curve)*radius,reach)
			_needle(from,to,scratch_width,Color(scratch_color,alpha))
			_needle(from,to,scratch_width*0.35,Color(scratch_core,alpha))
	if not embers.is_empty():
		var t := clampf(age/maxf(ember_sec,0.000001),0,1)
		var spread := 1-(1-t)*(1-t)
		var tint := Color(ember_color,1-t)
		for ember in embers:
			var direction: Vector2 = ember.direction
			var center := direction*(float(ember.start)+ember_travel*float(ember.speed)*spread)*Vector2(1,y_scale)+Vector2(0,-ember_rise*spread)
			var size := float(ember.size)*(1-0.4*t)
			glow.draw_texture_rect(DOT,Rect2(center-Vector2.ONE*size*0.5,Vector2.ONE*size),false,tint)

func _needle(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	var side := (to-from).orthogonal().normalized()*width*0.5
	if side==Vector2.ZERO: return
	glow.draw_colored_polygon(PackedVector2Array([from,from.lerp(to,0.45)+side,to,from.lerp(to,0.45)-side]),color)
