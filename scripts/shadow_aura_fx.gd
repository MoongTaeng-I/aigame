extends Node2D

var actor: Node2D
var settings: Dictionary
var aura: Node2D
var visual_rng := RandomNumberGenerator.new()
var age := 0.0
var next_ember_at := 0.0
var emitted := 0
var bursts := 0
var embers: Array = []
var wisps: Array = []
var puffs: Array = []
var ember_cursor := 0

func configure(owner_actor: Node2D, values: Dictionary) -> void:
	actor = owner_actor
	settings = values.duplicate()
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 30
	visual_rng.randomize()
	if actor.sprite_body!=null:
		aura = preload("res://scripts/shadow_aura_layer.gd").new()
		aura.configure(actor.sprite_body,settings)
		actor.sprite_body.get_parent().add_child(aura)
		aura.get_parent().move_child(aura,actor.sprite_body.get_index())
		actor.tree_exiting.connect(aura.queue_free,CONNECT_ONE_SHOT)
	next_ember_at = 1.0/maxf(float(settings.Ember_rate),0.000001)
	for i in range(ceili(float(settings.Ember_rate)*float(settings.Ember_life_sec))+1):
		embers.append({"active":false,"born":0.0,"point":Vector2.ZERO,"size":0.0,"phase":0.0})
	for i in range(int(settings.Wisp_count)):
		wisps.append({"age":0.0,"phase":0.0,"x":0.0})
		reset_wisp(wisps.back())
	for i in range(int(settings.Burst_puffs)):
		puffs.append({"active":false,"born":0.0,"point":Vector2.ZERO,"foot_y":0.0,"direction":Vector2.ZERO,"radius":0.0})
	sync_aura()
	burst()

func body_height() -> float:
	return actor.sprite_body.baseline*actor.sprite_body.cell_height/actor.sprite_body.source_rect().size.y if actor.sprite_body!=null and not actor.sprite_body.using_fallback else actor.body_radius*2

func _exit_tree() -> void:
	if is_instance_valid(aura): aura.queue_free()
	embers.clear()
	wisps.clear()
	puffs.clear()

func body_width() -> float:
	return actor.sprite_body.display_rect().size.x if actor.sprite_body!=null and not actor.sprite_body.using_fallback else actor.body_radius*2

func body_world(point: Vector2) -> Vector2:
	# CharacterPresentation may sync after the summon/teleport callback. Use the
	# actor's current transform so world particles never inherit a stale view pose.
	if actor.sprite_body!=null: return actor.to_global(actor.sprite_body.image_transform()*point)
	return actor.to_global(point)

func foot_y() -> float:
	return actor.sprite_body.foot_y if actor.sprite_body!=null else 0.0

func reset_wisp(slot: Dictionary) -> void:
	slot.phase = visual_rng.randf()*TAU
	slot.x = visual_rng.randf_range(-1,1)*body_width()*float(settings.Wisp_spread_ratio)

func sync_aura() -> void:
	if is_instance_valid(aura): aura.sync_pose(age,actor.cast_active)

func burst() -> void:
	bursts += 1
	var center := body_world(Vector2(0,foot_y()-body_height()*float(settings.Burst_height_ratio)))
	var ground := actor.to_global(Vector2(0,foot_y())).y
	for slot in puffs:
		slot.active = true
		slot.born = age
		slot.point = center
		slot.foot_y = ground
		slot.direction = Vector2.RIGHT.rotated(visual_rng.randf()*TAU)
		slot.radius = visual_rng.randf_range(float(settings.Burst_min_px),float(settings.Burst_max_px))
	queue_redraw()

func ember_world_point(slot: Dictionary) -> Vector2:
	var elapsed := age-float(slot.born)
	return Vector2(slot.point)+Vector2(sin(elapsed*TAU*float(settings.Ember_sway_hz)+float(slot.phase))*float(settings.Ember_sway_px),-float(settings.Ember_rise_px)*elapsed)

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if get_tree().paused: return
	age += maxf(delta,0)
	for slot in embers:
		if slot.active and age-float(slot.born)>=float(settings.Ember_life_sec): slot.active = false
	while float(settings.Ember_rate)>0 and next_ember_at<=age+0.000000001:
		var slot: Dictionary = embers[ember_cursor]
		ember_cursor = (ember_cursor+1)%embers.size()
		slot.born = next_ember_at
		slot.active = age-next_ember_at<float(settings.Ember_life_sec)
		slot.point = body_world(Vector2(visual_rng.randf_range(-1,1)*body_width()*float(settings.Ember_spread_ratio),foot_y()-body_height()*visual_rng.randf_range(float(settings.Ember_height_min),float(settings.Ember_height_max))))
		slot.size = visual_rng.randf_range(float(settings.Ember_min_px),float(settings.Ember_max_px))
		slot.phase = visual_rng.randf()*TAU
		emitted += 1
		next_ember_at += 1.0/float(settings.Ember_rate)
	for slot in wisps:
		slot.age += maxf(delta,0)
		while float(slot.age)>=float(settings.Wisp_life_sec):
			slot.age -= float(settings.Wisp_life_sec)
			reset_wisp(slot)
	for slot in puffs:
		if slot.active and age-float(slot.born)>=float(settings.Burst_sec): slot.active = false
	sync_aura()
	queue_redraw()

func _draw() -> void:
	for slot in embers:
		if not slot.active: continue
		var progress := clampf((age-float(slot.born))/float(settings.Ember_life_sec),0,1)
		var radius := float(slot.size)*(1-progress)
		var point := to_local(ember_world_point(slot))
		draw_circle(point,radius,Color(Color(String(settings.Ember_color)),1-progress))
		draw_circle(point,radius*float(settings.Ember_core_ratio),Color(1,1,1,1-progress))
	for slot in wisps:
		var base := to_local(body_world(Vector2(float(slot.x),foot_y()-body_height()*float(settings.Wisp_height_ratio))))
		var steps := int(settings.Wisp_steps)
		for i in range(steps):
			var points := PackedVector2Array()
			for j in [i,i+1]:
				var part := float(j)/steps
				points.append(base+Vector2(sin(float(slot.phase)+part*TAU*float(settings.Wisp_turns)-float(slot.age)*TAU*float(settings.Wisp_flow_hz))*float(settings.Wisp_sway_px)*part,-float(settings.Wisp_length_px)*part))
			var progress := float(i)/steps
			var color := Color(String(settings.Wisp_color))
			color.a = float(settings.Wisp_alpha)*(1-float(slot.age)/float(settings.Wisp_life_sec))*(1-progress)
			draw_line(points[0],points[1],color,lerpf(float(settings.Wisp_start_width),float(settings.Wisp_end_width),progress),true)
	for slot in puffs:
		if not slot.active: continue
		var progress := clampf((age-float(slot.born))/float(settings.Burst_sec),0,1)
		var point: Vector2 = Vector2(slot.point)+Vector2(slot.direction)*float(settings.Burst_spread_px)*progress
		point.y = minf(point.y,float(slot.foot_y)-float(settings.Burst_above_foot_px))
		point = to_local(point)
		var radius := float(slot.radius)*(1-progress)
		draw_circle(point,radius+float(settings.Burst_outline_px)*(1-progress),Color(Color(String(settings.Burst_outline_color)),1-progress))
		draw_circle(point,radius,Color(Color(String(settings.Burst_color)),1-progress))
