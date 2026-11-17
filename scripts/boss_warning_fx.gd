extends RefCounted

static func polygon(canvas: Node2D, points: PackedVector2Array, center: Vector2, progress: float, settings: Dictionary) -> void:
	var fill := Color(settings.Boss_warn_color,float(settings.Boss_warn_alpha))
	preload("res://scripts/combat_fx_draw.gd").polygon(canvas,points,fill)
	var inner := PackedVector2Array()
	for point in points: inner.append(center.lerp(point,progress))
	preload("res://scripts/combat_fx_draw.gd").polygon(canvas,inner,Color(settings.Boss_warn_color,float(settings.Boss_warn_deep_alpha)))
	var edge := points.duplicate()
	edge.append(points[0])
	canvas.draw_polyline(edge,settings.Boss_warn_outline,float(settings.Boss_warn_width),true)

# blink=true draws the Baruka blink_strike area in the blue Blink_warn_* colours (BAL-02); every other telegraph stays red.
static func circle(canvas: Node2D, center: Vector2, radius: float, progress: float, settings: Dictionary, blink: bool = false) -> void:
	var fill: Color = settings.Blink_warn_color if blink else settings.Boss_warn_color
	canvas.draw_circle(center,radius,Color(fill,float(settings.Blink_warn_alpha if blink else settings.Boss_warn_alpha)))
	canvas.draw_circle(center,radius*progress,Color(fill,float(settings.Blink_warn_deep_alpha if blink else settings.Boss_warn_deep_alpha)))
	canvas.draw_arc(center,radius,0,TAU,64,settings.Blink_warn_outline if blink else settings.Boss_warn_outline,float(settings.Boss_warn_width),true)

# BAL-02 ice bear chief: extra motion inside the unchanged telegraph shapes. Immediate draws only
# (no nodes, no materials), and only while the telegraph phase is running.
static func bear_fan(canvas: Node2D, center: Vector2, facing: float, row: Dictionary, elapsed: float, progress: float, settings: Dictionary) -> void:
	var light: Color = settings.Bear_warn_light_color
	var half := deg_to_rad(float(row.Arc_deg))*0.5
	var count := int(settings.Bear_fan_arc_count)
	for i in range(count):
		var t := fposmod(elapsed*float(settings.Bear_fan_sweep_hz)+float(i)/maxi(count,1),1.0)
		canvas.draw_arc(center,maxf(float(row.Range)*t,1),facing-half,facing+half,24,Color(light,float(settings.Bear_warn_light_alpha)*(1-t)),float(settings.Bear_fan_arc_width),true)
	if progress>=float(settings.Bear_fan_blink_from) and fposmod(elapsed*float(settings.Bear_fan_blink_hz),1.0)<0.5:
		var edge := PackedVector2Array([center])
		for i in range(33): edge.append(center+Vector2.RIGHT.rotated(facing-half+half*2*i/32)*float(row.Range))
		edge.append(center)
		canvas.draw_polyline(edge,Color(light,float(settings.Bear_warn_light_alpha)),float(settings.Boss_warn_width)+2,true)

static func bear_dash(canvas: Node2D, center: Vector2, end: Vector2, half_width: float, elapsed: float, settings: Dictionary) -> void:
	var light := Color(settings.Bear_warn_light_color,float(settings.Bear_warn_light_alpha))
	var along := end-center
	if along.length()<1: return
	var forward := along.normalized()
	var side := forward.orthogonal()*half_width*0.7
	var count := int(settings.Bear_dash_chevron_count)
	var flow := fposmod(elapsed*float(settings.Bear_dash_flow_hz),1.0)
	for i in range(count):
		var tip := center+along*((float(i)+flow)/maxi(count,1))
		var back := tip-forward*half_width*0.7
		canvas.draw_polyline(PackedVector2Array([back+side,tip,back-side]),light,float(settings.Bear_dash_chevron_width),true)
	var arm := (forward+forward.orthogonal())*half_width*0.6
	var cross := (forward-forward.orthogonal())*half_width*0.6
	canvas.draw_line(end-arm,end+arm,light,float(settings.Bear_dash_x_width),true)
	canvas.draw_line(end-cross,end+cross,light,float(settings.Bear_dash_x_width),true)

static func bear_slam(canvas: Node2D, center: Vector2, radius: float, progress: float, remaining: float, settings: Dictionary) -> void:
	var light := Color(settings.Bear_warn_light_color,float(settings.Bear_warn_light_alpha))
	canvas.draw_arc(center,maxf(radius*(1-progress),1),0,TAU,48,light,float(settings.Bear_slam_ring_width),true)
	var count := int(settings.Bear_slam_crack_count)
	for i in range(count):
		var angle := TAU*i/maxi(count,1)+0.3
		var bend := 0.22 if i%2==0 else -0.22
		var middle := center+Vector2.RIGHT.rotated(angle+bend)*radius*progress*0.55
		canvas.draw_polyline(PackedVector2Array([center,middle,center+Vector2.RIGHT.rotated(angle)*radius*progress]),settings.Boss_warn_outline,float(settings.Bear_slam_crack_width),true)
	var flash_sec := float(settings.Bear_slam_flash_sec)
	if remaining<flash_sec and flash_sec>0:
		canvas.draw_circle(center,radius,Color(1,1,1,float(settings.Bear_slam_flash_alpha)*(1-remaining/flash_sec)))

static func draw(boss: Node2D) -> bool:
	var settings: Dictionary = boss.visual_settings
	if int(settings.get("Boss_fx_enabled",1))==0: return false
	if boss.current.is_empty(): return true
	var row: Dictionary = boss.current
	var kind := int(row.Kind)
	var duration := maxf(float(row.Telegraph_sec),0.000001)
	var progress := clampf(1-(boss.phase_end-boss.clock)/duration,0,1) if boss.phase=="telegraph" else 1.0
	var center: Vector2 = boss.to_local(boss.origin)
	var telegraph: bool = boss.phase=="telegraph"
	var remaining := maxf(0,float(boss.phase_end-boss.clock))
	var elapsed := duration-remaining
	if kind in [1,9]:
		if kind==9 and boss.phase!="telegraph": return true
		var side: Vector2 = boss.facing.orthogonal()*boss.body_radius
		var end: Vector2 = boss.to_local(boss.dash_end)
		polygon(boss,PackedVector2Array([center+side,end+side,end-side,center-side]),(center+end)*0.5,progress,settings)
		if kind==1 and telegraph:
			bear_dash(boss,center,end,boss.body_radius,elapsed,settings)
			boss.warning_extra = 2
	elif kind==2:
		circle(boss,center,float(row.Slam_radius),progress,settings)
		if telegraph:
			bear_slam(boss,center,float(row.Slam_radius),progress,remaining,settings)
			boss.warning_extra = 3
	elif kind==0:
		var points := PackedVector2Array([center])
		for i in range(33): points.append(center+Vector2.RIGHT.rotated(boss.facing.angle()-deg_to_rad(float(row.Arc_deg))*0.5+deg_to_rad(float(row.Arc_deg))*i/32)*float(row.Range))
		polygon(boss,points,center,progress,settings)
		if telegraph:
			bear_fan(boss,center,boss.facing.angle(),row,elapsed,progress,settings)
			boss.warning_extra = 1
	elif kind==7:
		var points: PackedVector2Array = boss.baruka.triangle_points()
		for i in range(points.size()): points[i] = boss.to_local(points[i])
		polygon(boss,points,(points[0]+points[1]+points[2])/3,progress,settings)
	elif kind==8: circle(boss,boss.to_local(boss.baruka.area_center),float(row.Area_radius),progress,settings,true)
	elif kind==10:
		for point in boss.baruka.preview_zones: circle(boss,boss.to_local(point),float(row.Zone_radius),progress,settings)
	return true
