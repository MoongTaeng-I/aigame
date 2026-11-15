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
const BELION_BODY := Color("#251334")
const BELION_OUTLINE := Color("#bd66ff")
const BELION_GLOW := Color(0.68,0.28,1.0,0.75)
const BELION_CHAIN_EDGE := Color(0.82,0.55,1.0,0.95)

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

static func draw_belion_pose(canvas: CanvasItem, radius: float, facing: Vector2) -> void:
	canvas.draw_circle(Vector2.ZERO,radius,BELION_BODY)
	canvas.draw_arc(Vector2.ZERO,radius,0,TAU,SECTOR_SEGMENTS,BELION_OUTLINE,2.0)
	var hand := facing.normalized()*radius*0.75
	canvas.draw_line(hand,hand+facing.normalized()*radius,Color("#d8a6ff"),3.0,true)

static func draw_belion_windup(canvas: CanvasItem, facing: Vector2, radius: float) -> void:
	var hand := facing.normalized()*radius*0.8
	canvas.draw_circle(hand,radius*0.6,Color(0.68,0.28,1.0,0.16))
	canvas.draw_arc(hand,radius*0.6,0,TAU,20,BELION_GLOW,2.0,true)

static func draw_belion_chain(canvas: CanvasItem, state: Dictionary, segments: int) -> void:
	if state.has("hand"):
		var geometry := belion_chain_geometry(state,segments)
		for diamond: PackedVector2Array in geometry.diamonds:
			var local := PackedVector2Array()
			for point in diamond: local.append(canvas.to_local(point))
			var border := local.duplicate()
			border.append(border[0])
			canvas.draw_polyline(border,Color(0.68,0.28,1.0,0.22),geometry.glow_width,true)
			canvas.draw_colored_polygon(local,Color(0.32,0.1,0.5,0.95))
			canvas.draw_polyline(border,BELION_CHAIN_EDGE,geometry.edge_width,true)
		return
	# Image-free procedural Belion keeps its previous chain presentation.
	segments = maxi(1,segments)
	var direction: Vector2 = Vector2(state.direction).normalized()
	var tangent := Vector2(-direction.y,direction.x)
	var hand: Vector2 = canvas.to_local(Vector2(state.center))+direction*10.0
	var previous: Vector2 = hand
	for index in range(1,segments+1):
		var fraction: float = float(index)/segments
		var bend: float = -float(state.sign)*sin(PI*fraction)*12.0*fraction
		var point: Vector2 = hand+direction*(float(state.range)-10.0)*fraction+tangent*bend
		canvas.draw_line(previous,point,Color(0.42,0.16,0.65,0.8),4.0,true)
		canvas.draw_circle(point,3.5,Color(0.78,0.42,1.0,0.95))
		previous = point

static func draw_belion_hand_windup(canvas: Node2D, hand: Vector2, radius: float) -> void:
	var local := canvas.to_local(hand)
	canvas.draw_circle(local,radius*0.6,Color(0.68,0.28,1.0,0.16))
	canvas.draw_arc(local,radius*0.6,0,TAU,20,BELION_GLOW,2.0,true)

static func belion_chain_geometry(state: Dictionary, segments: int) -> Dictionary:
	segments = maxi(1,segments)
	var hand: Vector2 = state.hand
	var center: Vector2 = state.center
	var tip := center+Vector2(state.direction)*float(state.range)
	var foot: Vector2 = state.foot
	var width := float(state.chain_width)
	var ground_hand := Vector2(hand.x,foot.y)
	var height := hand.y-foot.y
	var points := PackedVector2Array()
	var diamonds: Array[PackedVector2Array] = []
	for index in range(segments+1):
		var fraction := float(index)/segments
		# Ground projection follows the blade; elevation eases down to zero.
		var point := ground_hand.lerp(tip,fraction)+Vector2(0,height*pow(1.0-fraction,2.0))
		if index==0: point = hand
		elif index==segments: point = tip
		points.append(point)
		if index>0:
			var previous := points[index-1]
			var middle := (previous+point)*0.5
			var normal := previous.direction_to(point).orthogonal()*width*0.5
			diamonds.append(PackedVector2Array([previous,middle+normal,point,middle-normal]))
	return {"hand":hand,"tip":tip,"points":points,"diamonds":diamonds,"glow_width":width*0.75,"edge_width":width*0.1875}

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
