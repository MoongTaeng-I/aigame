extends RefCounted

const Geometry = preload("res://scripts/combat_geometry.gd")
const Afterimage = preload("res://scripts/shadow_afterimage.gd")
const Visual = preload("res://scripts/shadow_visual.gd")
const TRAIL_LIFE := 0.3
const TRAIL_INTERVAL := 0.045
const PREVIEW := Color(0.3,0.8,1,0.28)
const ICE := Color(0.4,0.85,1,0.48)
var boss: Node2D
var rows: Dictionary = {}
var area_center := Vector2.ZERO
var destinations: Array[Vector2] = []
var zones: Array = []
var preview_zones: Array[Vector2] = []
var trails: Array[Node2D] = []
var strike_index := 0
var chase_until := 0.0
var next_trail_at := 0.0
var last_branch := ""

func configure(actor: Node2D) -> void:
	boss = actor
	for row in boss.actions: rows[int(row.Kind)] = row
	var config: Dictionary = boss.manager.boss_director.bosses[rows[7].Boss_id]
	boss.move_speed = float(boss.manager._enemy_records[config.Move_speed_ref_enemy].Move_speed)*float(config.Move_speed_mult)

func now() -> float:
	return boss.clock

func target() -> Node2D:
	return boss.target_provider.call()

func tick(delta: float) -> void:
	update_zones()
	var locked: float = minf(delta,boss.fear_remaining)
	boss.fear_remaining = maxf(0,boss.fear_remaining-delta)
	if locked>0 or boss.is_feared():
		last_branch = "fear"
		boss.queue_redraw()
		return
	var player := target()
	if not is_instance_valid(player): return
	if not boss.current.is_empty():
		if player.is_stealthed() and int(boss.current.Kind)==9:
			interrupt()
		else:
			advance()
			last_branch = "action"
			boss.queue_redraw()
			return
	if now()<boss.recover_until: return
	if player.is_stealthed():
		last_branch = "wander"
		if not boss.has_wander_target or boss.global_position.distance_to(boss.wander_target)<0.000001:
			boss.wander_target = boss.clamp_position_to_map(boss.global_position+Vector2.RIGHT.rotated(boss.rng.randf()*TAU)*sqrt(boss.rng.randf())*boss.manager.wander_radius,boss.map_bounds)
			boss.has_wander_target = true
		boss.move_boss(boss.wander_target,delta,true)
		return
	boss.has_wander_target = false
	var distance: float = boss.global_position.distance_to(player.global_position)
	if not player.is_frozen():
		if boss.planned.is_empty():
			var available: Array = []
			var weight := 0
			for kind in [8,9,10]:
				var row: Dictionary = rows[kind]
				if now()>=float(boss.ready_at[row.Id]):
					available.append(row)
					weight+=int(row.Pick_weight)
			if weight>0:
				var pick: int = boss.rng.randi_range(1,weight)
				for row in available:
					pick-=int(row.Pick_weight)
					if pick<=0:
						boss.planned = row
						break
		if not boss.planned.is_empty() and distance<=float(boss.planned.Use_range):
			start(boss.planned,player.global_position)
			boss.planned = {}
			last_branch = "skill"
			return
	if distance<=float(rows[7].Use_range) and now()>=float(boss.ready_at[rows[7].Id]):
		start(rows[7],player.global_position)
		last_branch = "basic"
	else:
		last_branch = "follow"
		boss.move_boss(player.global_position,delta)
	boss.queue_redraw()

func start(row: Dictionary, point: Vector2) -> void:
	boss.current = row.duplicate(true)
	boss.phase = "telegraph"
	boss.phase_end = now()+float(row.Telegraph_sec)
	strike_index = 0
	destinations.clear()
	preview_zones.clear()
	if int(row.Kind)==8:
		area_center = boss.global_position
	elif int(row.Kind)==10:
		area_center = point
		for i in range(int(row.Zone_count)):
			preview_zones.append(boss.clamp_position_to_map(area_center+Vector2.RIGHT.rotated(boss.rng.randf()*TAU)*sqrt(boss.rng.randf())*float(row.Area_radius),boss.map_bounds))
	else:
		prepare_path(point,float(row.Dash_distance))
		if int(row.Kind)==9: chase_until = now()+float(row.Duration_sec)
	boss.queue_redraw()

func prepare_path(point: Vector2, limit: float) -> void:
	boss.origin = boss.global_position
	boss.facing = boss.origin.direction_to(point)
	if boss.facing==Vector2.ZERO: boss.facing = Vector2.RIGHT
	var distance := minf(limit,boss.origin.distance_to(point)) if int(boss.current.Kind)==9 else limit
	var bounds: Rect2 = boss.map_bounds.grow(-boss.body_radius)
	var direction: Vector2 = boss.facing
	var start_point: Vector2 = boss.origin
	if direction.x>0: distance = minf(distance,(bounds.end.x-start_point.x)/direction.x)
	elif direction.x<0: distance = minf(distance,(bounds.position.x-start_point.x)/direction.x)
	if direction.y>0: distance = minf(distance,(bounds.end.y-start_point.y)/direction.y)
	elif direction.y<0: distance = minf(distance,(bounds.position.y-start_point.y)/direction.y)
	boss.dash_length = maxf(0,distance)
	boss.dash_end = start_point+direction*boss.dash_length
	boss.dash_hit = false

func pick_destination() -> Vector2:
	var row: Dictionary = boss.current
	var bounds: Rect2 = boss.map_bounds.grow(-boss.body_radius)
	for i in range(256):
		var point: Vector2 = area_center+Vector2.RIGHT.rotated(boss.rng.randf()*TAU)*sqrt(boss.rng.randf())*float(row.Area_radius)
		if bounds.has_point(point) and point.distance_to(boss.global_position)>=float(row.Strike_min_distance): return point
	# Deterministic geometric fallback, independent of the player.
	for i in range(64):
		var point: Vector2 = boss.clamp_position_to_map(area_center+Vector2.RIGHT.rotated(TAU*i/64.0)*float(row.Area_radius),boss.map_bounds)
		if point.distance_to(area_center)<=float(row.Area_radius)+0.000001 and point.distance_to(boss.global_position)>=float(row.Strike_min_distance): return point
	return boss.global_position

func begin_move(at: float) -> bool:
	if int(boss.current.Kind)==8:
		var point := pick_destination()
		if point.distance_to(boss.global_position)<float(boss.current.Strike_min_distance):
			finish(at)
			return false
		destinations.append(point)
		prepare_path(point,boss.global_position.distance_to(point))
	boss.phase = "dash"
	boss.dash_started = at
	boss.collision_layer = 0
	next_trail_at = at
	strike_index+=1
	return true

func advance() -> void:
	# A large frame can cross multiple boundaries; preserve scheduled times.
	while not boss.current.is_empty():
		var kind: int = int(boss.current.Kind)
		if boss.phase=="telegraph":
			if now()+0.000000001<boss.phase_end: return
			if kind==10:
				for point in preview_zones:
					zones.append({"center":point,"until":boss.phase_end+float(boss.current.Zone_life_sec),"radius":float(boss.current.Zone_radius),"freeze":float(boss.current.Freeze_sec),"inside":false})
				var at: float = boss.phase_end
				preview_zones.clear()
				finish(at)
				update_zones()
				return
			if not begin_move(boss.phase_end): return
		if boss.phase=="interval":
			if now()+0.000000001<boss.phase_end: return
			if kind==9:
				if boss.phase_end>=chase_until:
					finish(chase_until)
					return
				prepare_path(target().global_position,float(boss.current.Dash_distance))
				boss.phase = "telegraph"
				boss.phase_end+=float(boss.current.Telegraph_sec)
				continue
			if not begin_move(boss.phase_end): return
		if boss.phase=="dash":
			var end_time: float = boss.dash_started+boss.dash_length/float(boss.current.Dash_speed)
			var previous: Vector2 = boss.global_position
			var distance: float = minf(boss.dash_length,maxf(0,now()-boss.dash_started)*float(boss.current.Dash_speed))
			boss.global_position = boss.origin+boss.facing*distance
			if kind==8: leave_trails(minf(now(),end_time))
			if kind in [8,9] and not boss.dash_hit and Geometry.in_corridor(target().global_position,previous,boss.global_position,boss.facing,boss.body_radius):
				boss.dash_hit = true
				target().apply_damage(int(boss.current.Damage))
			if now()+0.000000001<end_time: return
			boss.global_position = boss.dash_end
			boss.collision_layer = 2
			if kind==7:
				if triangle_contains(target().global_position): target().apply_damage(int(boss.current.Damage))
				finish(end_time)
				return
			if kind==8 and strike_index>=int(boss.current.Strike_count):
				finish(end_time)
				return
			if kind==9 and end_time>=chase_until:
				finish(end_time)
				return
			boss.phase = "interval"
			boss.phase_end = end_time+float(boss.current.Strike_interval_sec)

func triangle_points() -> PackedVector2Array:
	var base: Vector2 = boss.dash_end+boss.facing*boss.body_radius
	var side: Vector2 = boss.facing.orthogonal()*float(boss.current.Tri_width)*0.5
	return PackedVector2Array([base+side,base-side,base+boss.facing*float(boss.current.Tri_length)])

func triangle_contains(point: Vector2) -> bool:
	var base: Vector2 = boss.dash_end+boss.facing*boss.body_radius
	var offset := point-base
	var along: float = offset.dot(boss.facing)
	var length: float = boss.current.Tri_length
	return along>=-0.000001 and along<=length+0.000001 and absf(offset.dot(boss.facing.orthogonal()))<=float(boss.current.Tri_width)*0.5*(1-along/length)+0.000001

func leave_trails(until: float) -> void:
	for i in range(trails.size()-1,-1,-1):
		if not is_instance_valid(trails[i]): trails.remove_at(i)
	while next_trail_at<=until+0.000000001:
		var copy := Afterimage.new()
		copy.configure({"radius":boss.body_radius,"facing":boss.facing,"motion":-1,"phase":0.0},TRAIL_LIFE)
		boss.add_child(copy)
		copy.top_level = true
		copy.global_position = boss.origin+boss.facing*minf(boss.dash_length,maxf(0,next_trail_at-boss.dash_started)*float(boss.current.Dash_speed))
		trails.append(copy)
		next_trail_at+=TRAIL_INTERVAL

func update_zones() -> void:
	var player := target()
	if not is_instance_valid(player): return
	for i in range(zones.size()-1,-1,-1):
		var zone: Dictionary = zones[i]
		if now()+0.000000001>=float(zone.until):
			zones.remove_at(i)
			continue
		var inside: bool = player.global_position.distance_to(zone.center)<=float(zone.radius)
		if inside and not zone.inside: player.apply_freeze(float(zone.freeze))
		zone.inside = inside
	boss.queue_redraw()

func finish(at: float) -> void:
	preview_zones.clear()
	boss.finish_action(at)

func interrupt() -> void:
	preview_zones.clear()
	finish(now())

func cleanup() -> void:
	boss.current = {}
	boss.planned = {}
	boss.phase = "idle"
	preview_zones.clear()
	zones.clear()
	for copy in trails:
		if is_instance_valid(copy): copy.queue_free()
	trails.clear()
	boss.queue_redraw()

func geometry() -> Dictionary:
	if boss.current.is_empty(): return {}
	return {"kind":int(boss.current.Kind),"center":area_center,"end":boss.dash_end,"direction":boss.facing,"points":triangle_points() if int(boss.current.Kind)==7 else PackedVector2Array(),"zones":preview_zones.duplicate()}

func draw() -> void:
	for zone in zones: boss.draw_circle(boss.to_local(zone.center),float(zone.radius),ICE)
	Visual.draw_pose(boss,boss.body_radius,boss.facing,-1,0)
	boss.draw_line(Vector2(-boss.body_radius,-boss.body_radius-8),Vector2(-boss.body_radius+boss.body_radius*2*float(boss.hp)/maxi(boss.max_hp,1),-boss.body_radius-8),Color("#ff6d6d"),4)
	if boss.current.is_empty(): return
	var kind: int = int(boss.current.Kind)
	if kind==7:
		var points := triangle_points()
		for i in range(points.size()): points[i] = boss.to_local(points[i])
		boss.draw_colored_polygon(points,PREVIEW)
	elif kind==8:
		boss.draw_arc(boss.to_local(area_center),float(boss.current.Area_radius),0,TAU,64,ICE,2)
	elif kind==9 and boss.phase=="telegraph":
		var side: Vector2 = boss.facing.orthogonal()*boss.body_radius
		boss.draw_colored_polygon(PackedVector2Array([boss.to_local(boss.origin+side),boss.to_local(boss.dash_end+side),boss.to_local(boss.dash_end-side),boss.to_local(boss.origin-side)]),PREVIEW)
	elif kind==10:
		for point in preview_zones: boss.draw_arc(boss.to_local(point),float(boss.current.Zone_radius),0,TAU,32,ICE,2)
