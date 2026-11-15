extends Polygon2D
var base := Vector2.ZERO
var facing := Vector2.RIGHT
var length := 0.0
var width := 0.0
var life := 0.2
var age := 0.0
var settings: Dictionary
var debug_source: Node
func _process(delta: float) -> void:
	age += maxf(delta,0)
	queue_redraw()
func crescent_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(25):
		var u := float(i)/24
		var along := length*(0.25+0.45*sin(PI*u))
		var side := width*0.5*(1-along/length)*(2*u-1)*0.85
		points.append(base+facing*along+facing.orthogonal()*side)
	return points
func debug_enabled() -> bool:
	return is_instance_valid(debug_source) and bool(debug_source.get("debug_visible"))
func crescent_ribbon(thickness: float) -> PackedVector2Array:
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	var points := crescent_points()
	var side := facing.orthogonal()
	for i in range(points.size()):
		var half := 0.0 if i==0 or i==points.size()-1 else thickness*0.5*sin(PI*float(i)/(points.size()-1))
		var offset := points[i]-base
		var across := offset.dot(side)
		var max_along := length*(1-absf(across)/maxf(width*0.5,0.000001))
		var center := offset.dot(facing)
		# The curve is monotonic across the triangle; equal-across edges cannot self-intersect.
		var pair := [base+facing*clampf(center-half,0,max_along)+side*across,base+facing*clampf(center+half,0,max_along)+side*across]
		for edge in range(2):
			if edge==0: upper.append(pair[edge])
			elif i>0 and i<points.size()-1: lower.append(pair[edge])
	lower.reverse()
	upper.append_array(lower)
	return upper
func _draw() -> void:
	var alpha := clampf(1-age/maxf(life,0.000001),0,1)
	draw_colored_polygon(crescent_ribbon(float(settings.get("Basic_glow_width",5))),Color(Color(String(settings.get("Basic_glow_color","#83d9ff"))),alpha*0.6))
	draw_colored_polygon(crescent_ribbon(float(settings.get("Basic_core_width",1.5))),Color(Color(String(settings.get("Basic_core_color","#ffffff"))),alpha))
	if debug_enabled(): draw_colored_polygon(polygon,Color(1,0.945,0.659,0.35))
