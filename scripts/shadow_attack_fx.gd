extends Node2D

const Draw = preload("res://scripts/combat_fx_draw.gd")
var actor: Node2D
var settings: Dictionary
var impacts: Node2D
var visual_rng := RandomNumberGenerator.new()
var age := 0.0
var arcs: Array = []
var arc_cursor := 0
var bands: Array = []
var band_cursor := 0
var stripe_index := 0
var stripe_start := 0.0
var pending := -1
var claw_active := false
var claw_visible := false
var claw_from := Vector2.ZERO
var claw_to := Vector2.ZERO
var claw_direction := Vector2.RIGHT
var claw_ended := 0.0
var star_hits := 0
var prep_stars: Array[float] = []

func configure(owner_actor: Node2D, values: Dictionary) -> void:
	actor = owner_actor
	settings = values
	z_index = 40
	process_mode = Node.PROCESS_MODE_PAUSABLE
	visual_rng.randomize()
	for i in range(int(settings.get("Shadow_arc_pool",4))): arcs.append({"active":false,"at":0.0,"center":Vector2.ZERO,"direction":0.0,"radius":0.0,"arc":0.0,"width":0.0,"motion":""})
	for i in range(int(settings.get("Belion_band_pool",64))): bands.append({"active":false,"at":0.0,"center":Vector2.ZERO,"a":0.0,"b":0.0,"radius":0.0,"stripe":0})
	impacts = preload("res://scripts/combat_impact_pool.gd").new()
	add_child(impacts)
	impacts.configure(settings,int(settings.get("Shadow_impact_pool_max",512)),true)
	for i in range(int(settings.get("Belion_prep_stars",3))): prep_stars.append(0.0)

func begin_cast() -> void:
	star_hits = 0
	stripe_index = 0
	pending = -1
	stripe_start = actor.sweep_current_angle
	for i in range(prep_stars.size()): prep_stars[i] = visual_rng.randf_range(float(settings.get("Belion_prep_star_min",0.15)),float(settings.get("Belion_prep_star_max",0.9)))
	if actor.is_dash_through():
		claw_active = true
		claw_visible = true
		claw_from = actor.dash_origin
		claw_to = actor.global_position
		claw_direction = actor.dash_direction

func fan_hit() -> void:
	var slot: Dictionary = arcs[arc_cursor]
	arc_cursor = (arc_cursor+1)%arcs.size()
	var diagonal: bool = String(actor.motions[actor.motion_index].Id)=="igrit_diagonal"
	slot.active = true
	slot.at = age
	slot.center = actor.global_position
	slot.direction = actor.facing.angle()+deg_to_rad(float(settings.get("Igris_diagonal_tilt_deg",-25)) if diagonal else 0)
	slot.radius = float(actor.attack.Range)*float(settings.get("Igris_radius_ratio",0.85))*(float(settings.get("Igris_diagonal_radius_mult",0.75)) if diagonal else 1.0)
	slot.arc = deg_to_rad(float(actor.attack.Arc_deg))*(float(settings.get("Igris_diagonal_arc_mult",0.65)) if diagonal else 1.0)
	slot.width = float(settings.get("Igris_arc_width",36))*(float(settings.get("Igris_diagonal_width_mult",0.8)) if diagonal else 1.0)
	slot.motion = actor.motions[actor.motion_index].Id

func hit(point: Vector2) -> void:
	if actor.is_sweep(): impacts.belion_burst(point)
	elif actor.is_dash_through(): impacts.spawn("mark",point,float(settings.get("Beru_mark_length",44)),float(settings.get("Beru_mark_sec",0.2)))
	elif star_hits<int(settings.get("Igris_star_max",4)):
		star_hits+=1
		impacts.spawn("star",point,float(settings.get("Igris_star_px",18)),float(settings.get("Igris_star_sec",0.12)))
		for i in range(int(settings.get("Igris_spark_count",6))):
			impacts.spawn("spark",point,float(settings.get("Shadow_spark_px",8)),float(settings.get("Igris_star_sec",0.12)),Vector2.RIGHT.rotated(visual_rng.randf()*TAU)*float(settings.get("Shadow_spark_speed",70)))

func band(from: float, to: float) -> void:
	var step := deg_to_rad(float(settings.get("Belion_stripe_deg",6)))
	var cursor := from
	var direction := signf(to-from)
	while absf(to-cursor)>0.000001:
		if pending<0:
			pending = band_cursor
			band_cursor = (band_cursor+1)%bands.size()
			stripe_start = cursor
			var slot: Dictionary = bands[pending]
			slot.active = true
			slot.at = age
			slot.center = actor.global_position
			slot.radius = float(actor.attack.Range)
			slot.a = cursor
			slot.stripe = stripe_index
		var portion := minf(absf(to-cursor),maxf(0.000001,step-absf(cursor-stripe_start)))
		cursor += direction*portion
		bands[pending].b = cursor
		if absf(cursor-stripe_start)>=step-0.000001:
			pending = -1
			stripe_index+=1

func sweep_end() -> void:
	impacts.belion_burst(actor.global_position+Vector2.RIGHT.rotated(actor.sweep_current_angle)*float(actor.attack.Range))

func observe() -> void:
	if claw_active:
		if actor.dash_through_active: claw_to = actor.global_position
		else:
			if actor.hit_done: claw_to = actor.global_position
			claw_active = false
			claw_ended = age
	queue_redraw()

func advance(delta: float) -> void:
	if get_tree().paused: return
	age += maxf(0,delta)
	for slot in arcs:
		if slot.active and age-float(slot.at)>=float(settings.get("Igris_arc_life_sec",0.18)): slot.active = false
	for slot in bands:
		if slot.active and age-float(slot.at)>=float(settings.get("Belion_band_sec",0.25)): slot.active = false
	if claw_visible and not claw_active and age-claw_ended>=float(settings.get("Beru_claw_life_sec",0.3)): claw_visible = false
	queue_redraw()

func _physics_process(delta: float) -> void: advance(delta)

func _draw() -> void:
	var palette := Draw.colors(settings,true)
	for slot in arcs:
		if not slot.active: continue
		var t := age-float(slot.at)
		var draw_t := clampf(t/float(settings.get("Igris_arc_draw_sec",0.05)),0,1)
		var start: float = slot.direction-slot.arc*0.5
		Draw.arc(self,to_local(slot.center),slot.radius,start,start+slot.arc*draw_t,slot.width*(1-t/float(settings.get("Igris_arc_life_sec",0.18))),float(settings.get("Shadow_fx_y_scale",0.62)),palette,1)
	if claw_visible:
		var alpha := 1.0 if claw_active else maxf(0,1-(age-claw_ended)/float(settings.get("Beru_claw_life_sec",0.3)))
		for i in [-1,0,1]:
			var offset: Vector2 = claw_direction.orthogonal()*float(settings.get("Beru_claw_gap",14))*i
			Draw.blade(self,to_local(claw_from+offset),to_local(claw_to+offset),float(settings.get("Beru_claw_width",9))*alpha,palette,alpha)
	for slot in bands:
		if not slot.active or absf(slot.b-slot.a)<0.000001: continue
		var alpha := maxf(0,1-(age-float(slot.at))/float(settings.get("Belion_band_sec",0.25)))
		var points := PackedVector2Array()
		for edge in [1.0,float(settings.get("Belion_band_inner_ratio",0.78))]:
			for j in range(5):
				var fraction := j/4.0 if edge==1.0 else 1-j/4.0
				var point: Vector2 = Vector2.RIGHT.rotated(lerpf(slot.a,slot.b,fraction))*float(slot.radius)*float(edge)
				points.append(to_local(slot.center)+Vector2(point.x,point.y*float(settings.get("Shadow_fx_y_scale",0.62))))
		var fill := Color(String(settings.get("Belion_band_dark","#3c1470") if int(slot.stripe)%2==0 else settings.get("Belion_band_light","#9646ff")))
		fill.a = alpha
		draw_colored_polygon(points,fill)
		points.append(points[0])
		draw_polyline(points,Color(Color(String(settings.get("Belion_band_outline","#1e0832"))),alpha),float(settings.get("Belion_band_outline_px",2)),true)
		Draw.arc(self,to_local(slot.center),slot.radius,slot.a,slot.b,float(settings.get("Belion_tip_width",8)),float(settings.get("Shadow_fx_y_scale",0.62)),[palette[0],Color.WHITE,Color.WHITE],alpha)
	if actor.is_sweep() and actor.cast_active and actor.clock-actor.cast_started_at<float(actor.attack.Windup_sec):
		var state: Dictionary = actor.sweep_visual_state()
		var hand: Vector2 = state.get("hand",actor.global_position)
		var tip: Vector2 = actor.global_position+Vector2(state.direction)*float(actor.attack.Range)
		for i in range(prep_stars.size()):
			Draw.star(self,to_local(hand.lerp(tip,prep_stars[i])),float(settings.get("Belion_prep_star_px",10)),palette[0],0.5+0.5*sin(age*TAU*float(settings.get("Belion_prep_star_hz",8))+i))

func _exit_tree() -> void:
	arcs.clear()
	bands.clear()
	prep_stars.clear()
