extends RefCounted

const SECTOR_FILL := Color(0.25,0.55,1.0,0.14)
const SECTOR_BORDER := Color(0.45,0.75,1.0,0.65)
const SECTOR_HIT_FILL := Color(0.55,0.85,1.0,0.32)
const SECTOR_HIT_BORDER := Color(0.8,0.95,1.0,0.95)
const SECTOR_BORDER_WIDTH := 1.5
const SECTOR_FLASH_SEC := 0.12
const SECTOR_SEGMENTS := 48
const CHARGER_BODY := Color("#14323d")
const CHARGER_OUTLINE := Color("#50d9d0")
const CHARGER_MARK := Color("#b6fff4")

static func draw_circle_attack(canvas: Node2D, state: Dictionary) -> void:
	var center := canvas.to_local(Vector2(state.center))
	var flash := sector_flash(float(state.hit_age))
	canvas.draw_circle(center,float(state.radius),SECTOR_FILL.lerp(SECTOR_HIT_FILL,flash))
	canvas.draw_arc(center,float(state.radius),0,TAU,SECTOR_SEGMENTS,SECTOR_BORDER.lerp(SECTOR_HIT_BORDER,flash),SECTOR_BORDER_WIDTH,true)

static func draw_charger_pose(canvas: CanvasItem, radius: float, facing: Vector2) -> void:
	canvas.draw_circle(Vector2.ZERO,radius,CHARGER_BODY)
	canvas.draw_arc(Vector2.ZERO,radius,0,TAU,SECTOR_SEGMENTS,CHARGER_OUTLINE,2.0)
	var tip := facing*radius*1.4
	canvas.draw_colored_polygon(PackedVector2Array([tip,tip.rotated(2.4),tip.rotated(-2.4)]),CHARGER_MARK)

# Shared gameplay geometry is supplied by the actor; only tessellation and
# color interpolation belong here. World points also support moved canvases.
static func sector_points(geometry: Dictionary) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2(geometry.center)])
	var half_angle := deg_to_rad(float(geometry.arc_deg))*0.5
	var angle := Vector2(geometry.direction).angle()
	for i in range(SECTOR_SEGMENTS+1):
		points.append(Vector2(geometry.center)+Vector2.RIGHT.rotated(angle-half_angle+2.0*half_angle*i/SECTOR_SEGMENTS)*float(geometry.range))
	return points

static func sector_flash(hit_age: float) -> float:
	return 1.0-clampf(hit_age/SECTOR_FLASH_SEC,0.0,1.0) if hit_age>=0.0 else 0.0

static func draw_sector(canvas: Node2D, state: Dictionary) -> void:
	var points := sector_points(state)
	for i in range(points.size()): points[i] = canvas.to_local(points[i])
	var flash := sector_flash(float(state.hit_age))
	canvas.draw_colored_polygon(points,SECTOR_FILL.lerp(SECTOR_HIT_FILL,flash))
	points.append(points[0])
	canvas.draw_polyline(points,SECTOR_BORDER.lerp(SECTOR_HIT_BORDER,flash),SECTOR_BORDER_WIDTH,true)

# Temporary geometry, not final character art. Both actor and afterimage use
# exactly this pose function; visual dimensions do not define hit geometry.
static func draw_pose(canvas: CanvasItem, radius: float, facing: Vector2, motion: int, phase: float) -> void:
	canvas.draw_circle(Vector2.ZERO,radius,Color("#151025"))
	canvas.draw_arc(Vector2.ZERO,radius,0,TAU,24,Color("#9771dc"),2.0)
	var angle := facing.angle()
	if motion==0: angle += lerpf(-PI*0.6,PI*0.15,phase)
	elif motion==1: angle += lerpf(-PI*0.5,PI*0.5,phase)
	var tip := Vector2.RIGHT.rotated(angle)*radius*2.4
	canvas.draw_line(Vector2.ZERO,tip,Color("#afc9ff"),radius*0.22,true)
	canvas.draw_line(tip*0.25-Vector2.UP.rotated(angle)*radius*0.3,tip*0.25+Vector2.UP.rotated(angle)*radius*0.3,Color("#7653ab"),2.0,true)
	if motion==1:
		canvas.draw_arc(Vector2.ZERO,radius*2.2,facing.angle()-PI*0.5,angle,20,Color(0.6,0.7,1.0,0.35),2.0,true)
