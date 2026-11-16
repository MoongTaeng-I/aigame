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
var burst_hits := 0
var prep_stars: Array[float] = []
var was_visible := false
var redraw_frame := -1

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
	burst_hits = 0
	stripe_index = 0
	pending = -1
	stripe_start = actor.sweep_current_angle
	if actor.is_sweep():
		preload("res://scripts/impact_budget.gd").reserve_endpoint(preload("res://scripts/impact_budget.gd").scope(self),actor,int(settings.Belion_shard_count)+int(settings.Belion_stone_count)+1)
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
	if actor.is_sweep():
		if burst_hits<int(settings.Belion_burst_max):
			burst_hits+=1
			impacts.belion_burst(point)
		else: impacts.spawn("star",point,float(settings.Igris_star_px),float(settings.Igris_star_sec))
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
	redraw_active()

func advance(delta: float) -> void:
	delta *= float(get_viewport().get_meta(&"fx05_visual_scale",1.0)) if is_inside_tree() else 1.0
	if get_tree().paused: return
	age += maxf(0,delta)
	for slot in arcs:
		if slot.active and age-float(slot.at)>=float(settings.get("Igris_arc_life_sec",0.18)): slot.active = false
	for slot in bands:
		if slot.active and age-float(slot.at)>=float(settings.get("Belion_band_sec",0.25)): slot.active = false
	if claw_visible and not claw_active and age-claw_ended>=float(settings.get("Beru_claw_life_sec",0.3)): claw_visible = false
	redraw_active()

func redraw_active() -> void:
	var visible_fx: bool = claw_visible or (actor.is_sweep() and actor.cast_active)
	for slot in arcs:
		if slot.active: visible_fx = true; break
	for slot in bands:
		if slot.active: visible_fx = true; break
	if (visible_fx or was_visible) and redraw_frame!=Engine.get_process_frames():
		redraw_frame = Engine.get_process_frames()
		queue_redraw()
	was_visible = visible_fx

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
	draw_band_batch()
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

func draw_band_batch() -> void:
	var vertices: Array[Vector2] = []
	var colors: Array[Color] = []
	var indices: Array[int] = []
	var tips := PackedVector2Array()
	var tip_colors := PackedColorArray()
	var active: Array = bands.filter(func(slot: Dictionary) -> bool: return slot.active and absf(slot.b-slot.a)>0.000001)
	active.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.stripe<b.stripe)
	for slot in active:
		var alpha := maxf(0,1-(age-float(slot.at))/float(settings.Belion_band_sec))
		var fill: Color = settings.Belion_band_dark if int(slot.stripe)%2==0 else settings.Belion_band_light
		fill.a = alpha
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in range(5):
			var vector := Vector2.RIGHT.rotated(lerpf(slot.a,slot.b,i/4.0))*float(slot.radius)
			var point := Vector2(vector.x,vector.y*float(settings.Shadow_fx_y_scale))
			outer.append(to_local(slot.center)+point)
			inner.append(to_local(slot.center)+point*float(settings.Belion_band_inner_ratio))
			if tips.is_empty() or i>0:
				tips.append(outer[-1]); tip_colors.append(Color(1,1,1,alpha))
		for i in range(4): append_quad(vertices,colors,indices,outer[i],outer[i+1],inner[i+1],inner[i],fill)
		var border: Color = settings.Belion_band_outline
		border.a = alpha
		var loop := outer.duplicate()
		for i in range(4,-1,-1): loop.append(inner[i])
		loop.append(outer[0])
		for i in range(loop.size()-1):
			var side := loop[i].direction_to(loop[i+1]).orthogonal()*float(settings.Belion_band_outline_px)*0.5
			append_quad(vertices,colors,indices,loop[i]+side,loop[i+1]+side,loop[i+1]-side,loop[i]-side,border)
	if not indices.is_empty(): RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),PackedInt32Array(indices),PackedVector2Array(vertices),PackedColorArray(colors))
	if tips.size()>1: draw_polyline_colors(tips,tip_colors,float(settings.Belion_tip_width),true)

func append_quad(vertices: Array[Vector2], colors: Array[Color], indices: Array[int], a: Vector2,b: Vector2,c: Vector2,d: Vector2,color: Color) -> void:
	var start := vertices.size()
	vertices.append_array(PackedVector2Array([a,b,c,d]))
	for i in range(4): colors.append(color)
	indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))
