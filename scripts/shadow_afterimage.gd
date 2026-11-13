extends Node2D

const Visual = preload("res://scripts/shadow_visual.gd")
var pose: Dictionary
var lifetime: float
var elapsed: float = 0.0
var opacity := 0.45

static func presentation() -> Dictionary:
	# Pure presentation data; this loader never touches combat RNG or hit state.
	var file := FileAccess.open("res://data/combat_presentation.csv",FileAccess.READ)
	var result: Dictionary = {}
	file.get_csv_line()
	while not file.eof_reached():
		var cells := file.get_csv_line()
		if cells.size()==2: result[cells[0]] = cells[1]
	return result

func configure(snapshot: Dictionary, seconds: float, alpha: float = 0.45) -> void:
	pose = snapshot.duplicate(true)
	lifetime = seconds
	opacity = alpha
	modulate.a = opacity
	queue_redraw()

func _physics_process(delta: float) -> void:
	elapsed += delta
	modulate.a = opacity*maxf(0.0,1.0-elapsed/lifetime)
	if elapsed+0.000000001>=lifetime:
		queue_free()

func _draw() -> void:
	if pose!=null:
		if pose.get("kind","")=="player":
			draw_circle(Vector2.ZERO,float(pose.radius),Color("#b18cff"))
			draw_arc(Vector2.ZERO,float(pose.radius),0,TAU,48,Color("#eee6ff"),2)
		elif pose.get("kind","")=="charger_test": Visual.draw_charger_pose(self,float(pose.radius),pose.facing)
		else: Visual.draw_pose(self,float(pose.radius),pose.facing,int(pose.motion),float(pose.phase))
