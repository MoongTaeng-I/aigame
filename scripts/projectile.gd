extends Node2D
class_name CombatProjectile
const ICE_TEXTURE = preload("res://assets/art/fx/fx_ice_arrow.png")

var direction := Vector2.RIGHT
var speed: float = 0.0
var damage: int = 0
var body_radius: float = 6.0
var expire_rule: int = 0
var max_distance: float = 0.0
var max_lifetime_sec: float = 0.0
var map_bounds := Rect2()
var player: Node2D
var traveled: float = 0.0
var lived: float = 0.0
var spent: bool = false
var ice_arrow := false
var ice_texture: Texture2D
var visual_settings: Dictionary
var trail_points := PackedVector2Array()
var trail_times := PackedFloat64Array()
var trail_cursor := 0
var next_trail := 0.0
var visual_clock := 0.0

func configure(record: Dictionary, origin: Vector2, aim: Vector2, bounds: Rect2, target: Node2D) -> void:
	global_position = origin
	direction = origin.direction_to(aim)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	speed = float(record["Speed"])
	damage = int(record["Damage"])
	body_radius = float(record["Body_radius"])
	expire_rule = int(record["Expire_rule"])
	max_distance = float(record["Max_distance"]) if record["Max_distance"] != null else 0.0
	max_lifetime_sec = float(record["Max_lifetime_sec"]) if record["Max_lifetime_sec"] != null else 0.0
	if String(record.get("Id","")) in ["proj_test_01","elf_arrow","elf_burst_arrow"]: preload("res://scripts/audio_events.gd").sfx(self,"arrow_shot")
	map_bounds = bounds
	player = target
	visual_settings = preload("res://scripts/shadow_afterimage.gd").compiled_presentation()
	ice_arrow = int(visual_settings.Boss_fx_enabled)!=0 and String(record.get("Id","")) in ["proj_test_01","elf_arrow","elf_burst_arrow"]
	if ice_arrow:
		ice_texture = ICE_TEXTURE
		trail_points.resize(int(visual_settings.Arrow_tail_count))
		trail_times.resize(int(visual_settings.Arrow_tail_count))
		trail_times.fill(-INF)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()

func advance(delta: float) -> void:
	if spent:
		return
	var step := delta
	if expire_rule == 0:
		step = minf(step, maxf(0.0, max_distance - traveled) / speed)
	elif expire_rule == 1:
		step = minf(step, maxf(0.0, max_lifetime_sec - lived))
	elif expire_rule == 2:
		for axis in range(2):
			var component := direction[axis] * speed
			if component > 0.0:
				step = minf(step, maxf(0.0, map_bounds.end[axis] - global_position[axis]) / component)
			elif component < 0.0:
				step = minf(step, maxf(0.0, global_position[axis] - map_bounds.position[axis]) / -component)
	var origin := global_position
	var movement := direction * speed * step
	global_position += movement
	traveled += speed * step
	lived += step
	if ice_arrow: advance_visual(origin,step)
	if player != null and is_instance_valid(player) and _segment_hits_player(origin, global_position):
		spent = true
		visible = false
		if player.has_method("record_damage_source"): player.record_damage_source(origin)
		player.apply_damage(damage)
		finish_visual()
		queue_free()
		return
	if expire_rule == 0 and traveled + 0.000000001 >= max_distance:
		spent = true
	elif expire_rule == 1 and lived + 0.000000001 >= max_lifetime_sec:
		spent = true
	elif expire_rule == 2 and (global_position.x <= map_bounds.position.x or global_position.y <= map_bounds.position.y or global_position.x >= map_bounds.end.x or global_position.y >= map_bounds.end.y):
		spent = true
	if spent:
		visible = false
		finish_visual()
		queue_free()

func finish_visual() -> void:
	if not ice_arrow or get_parent()==null: return
	var pool: Node = get_parent().get("boss_fx")
	if not is_instance_valid(pool) or not pool.enabled(): return
	for i in range(trail_points.size()):
		var elapsed := visual_clock-trail_times[i]
		if elapsed>=float(visual_settings.Arrow_tail_sec): continue
		var slot: Dictionary = pool.emit("arrow_tail",trail_points[i],float(visual_settings.Arrow_tail_px),float(visual_settings.Arrow_tail_sec))
		slot.age = elapsed

func _segment_hits_player(origin: Vector2, endpoint: Vector2) -> bool:
	var segment := endpoint - origin
	var length_squared := segment.length_squared()
	var fraction := 0.0
	if length_squared > 0.0:
		fraction = clampf((player.global_position - origin).dot(segment) / length_squared, 0.0, 1.0)
	var closest := origin + segment * fraction
	var radius := body_radius + float(player.body_radius)
	return closest.distance_squared_to(player.global_position) <= radius * radius

func advance_visual(previous: Vector2, delta: float) -> void:
	var scaled := delta*float(get_viewport().get_meta(&"fx05_visual_scale",1.0)) if is_inside_tree() else delta
	var start := visual_clock
	visual_clock+=scaled
	var interval := float(visual_settings.Arrow_tail_sec)/maxi(1,trail_points.size())
	next_trail = maxf(next_trail,visual_clock-float(visual_settings.Arrow_tail_sec))
	while next_trail<=visual_clock+0.000000001:
		trail_points[trail_cursor] = previous.lerp(global_position,clampf((next_trail-start)/maxf(scaled,0.000001),0,1))
		trail_times[trail_cursor] = next_trail
		trail_cursor = (trail_cursor+1)%trail_points.size()
		next_trail+=interval
	queue_redraw()

func _draw() -> void:
	if ice_arrow and ice_texture!=null:
		for i in range(trail_points.size()):
			var alpha := maxf(0,1-(visual_clock-trail_times[i])/float(visual_settings.Arrow_tail_sec))
			if alpha>0: draw_circle(to_local(trail_points[i]),float(visual_settings.Arrow_tail_px)*alpha,Color(visual_settings.Boss_fx_color,float(visual_settings.Arrow_tail_alpha)*alpha))
		draw_set_transform(Vector2.ZERO,direction.angle())
		var length := float(visual_settings.Arrow_px)
		var size := Vector2(length,length*ice_texture.get_height()/ice_texture.get_width())
		draw_texture_rect(ice_texture,Rect2(-size*0.5,size),false)
		draw_set_transform(Vector2.ZERO)
		return
	draw_circle(Vector2.ZERO, body_radius, Color("#ffdb59"))
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 24, Color("#fff6c7"), 1.5)
