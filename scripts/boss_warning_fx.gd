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

static func circle(canvas: Node2D, center: Vector2, radius: float, progress: float, settings: Dictionary) -> void:
	canvas.draw_circle(center,radius,Color(settings.Boss_warn_color,float(settings.Boss_warn_alpha)))
	canvas.draw_circle(center,radius*progress,Color(settings.Boss_warn_color,float(settings.Boss_warn_deep_alpha)))
	canvas.draw_arc(center,radius,0,TAU,64,settings.Boss_warn_outline,float(settings.Boss_warn_width),true)

static func draw(boss: Node2D) -> bool:
	var settings: Dictionary = boss.visual_settings
	if int(settings.get("Boss_fx_enabled",1))==0: return false
	if boss.current.is_empty(): return true
	var row: Dictionary = boss.current
	var kind := int(row.Kind)
	var duration := maxf(float(row.Telegraph_sec),0.000001)
	var progress := clampf(1-(boss.phase_end-boss.clock)/duration,0,1) if boss.phase=="telegraph" else 1.0
	var center: Vector2 = boss.to_local(boss.origin)
	if kind in [1,9]:
		if kind==9 and boss.phase!="telegraph": return true
		var side: Vector2 = boss.facing.orthogonal()*boss.body_radius
		var end: Vector2 = boss.to_local(boss.dash_end)
		polygon(boss,PackedVector2Array([center+side,end+side,end-side,center-side]),(center+end)*0.5,progress,settings)
	elif kind==2: circle(boss,center,float(row.Slam_radius),progress,settings)
	elif kind==0:
		var points := PackedVector2Array([center])
		for i in range(33): points.append(center+Vector2.RIGHT.rotated(boss.facing.angle()-deg_to_rad(float(row.Arc_deg))*0.5+deg_to_rad(float(row.Arc_deg))*i/32)*float(row.Range))
		polygon(boss,points,center,progress,settings)
	elif kind==7:
		var points: PackedVector2Array = boss.baruka.triangle_points()
		for i in range(points.size()): points[i] = boss.to_local(points[i])
		polygon(boss,points,(points[0]+points[1]+points[2])/3,progress,settings)
	elif kind==8: circle(boss,boss.to_local(boss.baruka.area_center),float(row.Area_radius),progress,settings)
	elif kind==10:
		for point in boss.baruka.preview_zones: circle(boss,boss.to_local(point),float(row.Zone_radius),progress,settings)
	return true
