extends RefCounted

static func in_sector(center: Vector2, direction: Vector2, radius: float, arc_deg: float, point: Vector2) -> bool:
	var offset := point-center
	if offset.length_squared()>radius*radius: return false
	if offset==Vector2.ZERO: return true
	return absf(wrapf(offset.angle()-direction.angle(),-PI,PI))<=deg_to_rad(arc_deg)*0.5+0.000000001

static func segment_distance(point: Vector2, start: Vector2, end: Vector2) -> float:
	var motion := end-start
	var fraction := clampf((point-start).dot(motion)/motion.length_squared(),0,1) if motion.length_squared()>0 else 0.0
	return point.distance_to(start+motion*fraction)

static func in_corridor(point: Vector2, start: Vector2, end: Vector2, direction: Vector2, half_width: float) -> bool:
	var offset := point-start
	var along := offset.dot(direction)
	return along>=0 and along<=start.distance_to(end)+0.000001 and absf(offset.dot(direction.orthogonal()))<=half_width
