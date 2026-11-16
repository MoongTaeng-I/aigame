extends RefCounted

static func colors(values: Dictionary, shadow: bool) -> Array[Color]:
	return [Color(String(values.get("Shadow_fx_outline","#1a1240") if shadow else values.get("Player_fx_outline","#16265a"))),Color(String(values.get("Shadow_fx_color","#7a5cff") if shadow else values.get("Player_fx_color","#5ad4ff"))),Color(String(values.get("Shadow_fx_core","#ece6ff") if shadow else values.get("Player_fx_core","#ffffff")))]

static func polygon(canvas: Node2D, points: PackedVector2Array, color: Color) -> void:
	# A shrinking core can collapse to coincident float32 vertices before its
	# lifetime ends. Keep the slot alive, but submit only drawable geometry.
	if not Geometry2D.triangulate_polygon(points).is_empty(): canvas.draw_colored_polygon(points,color)

static func blade(canvas: Node2D, a: Vector2, b: Vector2, width: float, palette: Array, alpha: float = 1.0, border: float = 3) -> void:
	if a.distance_squared_to(b)<0.00001 or width<=0 or alpha<=0: return
	var midpoint := (a+b)*0.5
	var side := a.direction_to(b).orthogonal()
	for i in range(3):
		var w := width+border*2 if i==0 else (width if i==1 else width*0.4)
		var color: Color = palette[i]
		color.a *= alpha
		polygon(canvas,PackedVector2Array([a,midpoint+side*w*0.5,b,midpoint-side*w*0.5]),color)

static func arc(canvas: Node2D, center: Vector2, radius: float, from: float, to: float, width: float, yscale: float, palette: Array, alpha: float, border: float = 3) -> void:
	if absf(to-from)<0.00001 or width<=0 or alpha<=0: return
	for layer in range(3):
		var points := PackedVector2Array()
		var w := width+border*2 if layer==0 else (width if layer==1 else width*0.4)
		for edge in [1,-1]:
			for j in range(25):
				var t := j/24.0 if edge==1 else 1-j/24.0
				var r: float = radius+float(edge)*w*0.5*sin(PI*t)
				var point := Vector2.RIGHT.rotated(lerpf(from,to,t))*r
				points.append(center+Vector2(point.x,point.y*yscale))
		var color: Color = palette[layer]
		color.a *= alpha
		polygon(canvas,points,color)

static func star(canvas: Node2D, center: Vector2, size: float, outline: Color, alpha: float = 1) -> void:
	for layer in [1,0]:
		var points := PackedVector2Array()
		for i in range(8): points.append(center+Vector2.UP.rotated(TAU*i/8)*(size*0.5+2*layer)*(1.0 if i%2==0 else 0.25))
		var color := outline if layer==1 else Color.WHITE
		color.a *= alpha
		polygon(canvas,points,color)
