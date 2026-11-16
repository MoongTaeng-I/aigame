extends Node2D

var settings: Dictionary
var visual_rng: RandomNumberGenerator
var age := 0.0
var speedlines: Array = []
var puffs: Array = []
var dash_track: Dictionary = {}

static func diamond(a: Vector2, b: Vector2, width: float) -> PackedVector2Array:
	var middle := (a+b)*0.5
	var side := a.direction_to(b).orthogonal()*width*0.5
	return PackedVector2Array([a,middle+side,b,middle-side])

static func blade(canvas: Node2D, a: Vector2, b: Vector2, width: float, color: Color, values: Dictionary, glow: bool = false, outline: Color = Color("#16265a")) -> void:
	if width<=0 or a.distance_squared_to(b)<=0.00000001: return
	if glow:
		var light := Color(values.get("Slash_glow_color","#5ad4ff"))
		light.a = float(values.get("Slash_glow_alpha",0.3))*color.a
		preload("res://scripts/combat_fx_draw.gd").polygon(canvas,diamond(a,b,width*float(values.get("Slash_glow_mult",2.6))),light)
	outline.a = color.a
	preload("res://scripts/combat_fx_draw.gd").polygon(canvas,diamond(a,b,width+2*float(values.get("Slash_outline_px",4))*color.a),outline)
	preload("res://scripts/combat_fx_draw.gd").polygon(canvas,diamond(a,b,width),color)
	preload("res://scripts/combat_fx_draw.gd").polygon(canvas,diamond(a,b,width*float(values.get("Fx_core_ratio",0.4))),Color(1,1,1,color.a))

static func star(canvas: Node2D, center: Vector2, size: float, alpha: float, values: Dictionary) -> void:
	for layer in [1,0]:
		var radius := size+float(values.get("Slash_outline_px",4))*float(layer)
		var points := PackedVector2Array()
		for i in range(8):
			points.append(center+Vector2.UP.rotated(TAU*i/8)*radius*(1.0 if i%2==0 else float(values.get("Slash_star_inner_ratio",0.25))))
		var color := Color(values.get("Fx_outline_color","#16265a")) if layer==1 else Color.WHITE
		color.a = alpha
		preload("res://scripts/combat_fx_draw.gd").polygon(canvas,points,color)

func start_dash(actor: Node2D, distance: float, direction: Vector2) -> void:
	dash_track = {"player":actor}
	for i in range(int(settings.get("Dash_speedline_count",9))):
		var side := direction.orthogonal()*visual_rng.randf_range(-1,1)*float(settings.get("Dash_speedline_spread_px",32))
		var length := distance*visual_rng.randf_range(float(settings.get("Dash_line_min_ratio",0.4)),float(settings.get("Dash_line_max_ratio",0.8)))
		var a := actor.global_position+side+direction*visual_rng.randf_range(0,distance-length)
		speedlines.append({"a":a,"b":a+direction*length,"at":age,"until":age+float(settings.get("Dash_speedline_sec",0.2))})
	spawn_puffs(actor.global_position,int(settings.get("Dash_start_puffs",5)))
	queue_redraw()

func spawn_puffs(at: Vector2, count: int) -> void:
	for i in range(count):
		var direction := Vector2.RIGHT.rotated(visual_rng.randf()*TAU)
		puffs.append({"center":at,"offset":direction*visual_rng.randf()*float(settings.get("Dash_puff_spread_px",14)),"at":age,"until":age+float(settings.get("Dash_puff_sec",0.25))})

func _process(delta: float) -> void:
	delta *= float(get_viewport().get_meta(&"fx05_visual_scale",1.0)) if is_inside_tree() else 1.0
	var had_effects := not speedlines.is_empty() or not puffs.is_empty()
	age += maxf(0,delta)
	if not dash_track.is_empty():
		var actor: Node2D = dash_track.player
		if not is_instance_valid(actor): dash_track.clear()
		elif actor.dash_remaining<=0:
			spawn_puffs(actor.global_position,int(settings.get("Dash_end_puffs",3)))
			dash_track.clear()
	for collection in [speedlines,puffs]:
		for i in range(collection.size()-1,-1,-1):
			if age>=float(collection[i].until): collection.remove_at(i)
	if had_effects or not speedlines.is_empty() or not puffs.is_empty(): queue_redraw()

func _draw() -> void:
	for line in speedlines:
		var remaining := 1-clampf((age-float(line.at))/maxf(float(line.until)-float(line.at),0.000001),0,1)
		blade(self,to_local(line.a),to_local(line.b),float(settings.get("Dash_speedline_width",3))*remaining,Color(1,1,1,remaining),settings,false,Color(settings.get("Fx_outline_color","#16265a")))
	for puff in puffs:
		var progress := clampf((age-float(puff.at))/maxf(float(puff.until)-float(puff.at),0.000001),0,1)
		var center := to_local(puff.center)+Vector2(puff.offset)*progress
		var radius := lerpf(float(settings.get("Dash_puff_start_px",3)),float(settings.get("Dash_puff_end_px",12)),progress)
		var outline := Color(settings.get("Fx_outline_color","#16265a"))
		outline.a = 1-progress
		draw_circle(center,radius+float(settings.get("Slash_outline_px",4)),outline)
		draw_circle(center,radius,Color(Color(settings.get("Dash_puff_color","#dbe7ff")),1-progress))
		draw_circle(center,radius*float(settings.get("Dash_puff_core_ratio",0.65)),Color(1,1,1,1-progress))
