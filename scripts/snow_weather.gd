extends CanvasLayer

var settings: Dictionary
var particles: Array[Vector2] = []
var screen: Control
var elapsed := 0.0

func _ready() -> void:
	layer = 1
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	screen.draw.connect(draw_weather)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(settings.get("Forest_seed",11015))+1
	for i in range(int(settings.get("Snow_count",160))): particles.append(Vector2(rng.randf(),rng.randf()))

func _process(delta: float) -> void:
	elapsed += maxf(0,delta)
	screen.queue_redraw()

func draw_weather() -> void:
	var size := get_viewport().get_visible_rect().size
	var angle := deg_to_rad(float(settings.get("Snow_angle_deg",20)))
	var velocity := Vector2(sin(angle),cos(angle))*float(settings.get("Snow_speed",260))
	var radius := float(settings.get("Snow_size_px",2))
	for point in particles:
		var location := point*size+velocity*elapsed
		location = Vector2(fposmod(location.x,size.x),fposmod(location.y,size.y))
		screen.draw_line(location,location-velocity.normalized()*radius*3,Color(1,1,1,float(settings.get("Snow_alpha",0.65))),radius,true)
	var strength := float(settings.get("Fog_strength",0.45))
	var width := minf(size.x,size.y)*float(settings.get("Fog_width_ratio",0.18))
	for i in range(24):
		var inset := width*i/24
		var band := width/24+1
		var color := Color(1,1,1,strength*pow(1-float(i)/24,2))
		screen.draw_rect(Rect2(inset,0,band,size.y),color)
		screen.draw_rect(Rect2(size.x-inset-band,0,band,size.y),color)
		screen.draw_rect(Rect2(0,inset,size.x,band),color)
		screen.draw_rect(Rect2(0,size.y-inset-band,size.x,band),color)
