extends RefCounted

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
