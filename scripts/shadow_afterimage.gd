extends Node2D

const Visual = preload("res://scripts/shadow_visual.gd")
const SpriteBodyScript = preload("res://scripts/sprite_body.gd")
var pose: Dictionary
var lifetime: float
var elapsed: float = 0.0
var opacity := 0.45
var sprite_body: Node2D
const PRESENTATION_CACHE := &"combat_presentation"

static func cache_presentation(rows: Dictionary) -> void:
	var loaded: Dictionary = {}
	for row in rows.values(): loaded[row.Id] = row.Value
	# Only strings live in Engine metadata; no static GDScript resource is retained.
	Engine.set_meta(PRESENTATION_CACHE,loaded)

static func presentation() -> Dictionary:
	if Engine.has_meta(PRESENTATION_CACHE): return Engine.get_meta(PRESENTATION_CACHE).duplicate()
	# Pure presentation data; this loader never touches combat RNG or hit state.
	var file := FileAccess.open("res://data/combat_presentation.csv",FileAccess.READ)
	var result: Dictionary = {}
	file.get_csv_line()
	while not file.eof_reached():
		var cells := file.get_csv_line()
		if cells.size()==2: result[cells[0]] = cells[1]
	Engine.set_meta(PRESENTATION_CACHE,result)
	return result.duplicate()

func configure(snapshot: Dictionary, seconds: float, alpha: float = 0.45) -> void:
	pose = snapshot.duplicate(true)
	lifetime = seconds
	opacity = alpha
	modulate.a = opacity
	if pose.has("sprite_pose"):
		sprite_body = SpriteBodyScript.new()
		add_child(sprite_body)
		sprite_body.configure_snapshot(pose.sprite_pose)
	queue_redraw()

func _physics_process(delta: float) -> void:
	elapsed += delta
	modulate.a = opacity*maxf(0.0,1.0-elapsed/lifetime)
	if elapsed+0.000000001>=lifetime:
		queue_free()

func _draw() -> void:
	if pose!=null:
		if sprite_body!=null: return
		if pose.get("kind","")=="player":
			draw_circle(Vector2.ZERO,float(pose.radius),Color("#b18cff"))
			draw_arc(Vector2.ZERO,float(pose.radius),0,TAU,48,Color("#eee6ff"),2)
		elif pose.get("kind","")=="charger_test": Visual.draw_charger_pose(self,float(pose.radius),pose.facing)
		elif pose.get("kind","")=="belion": Visual.draw_belion_pose(self,float(pose.radius),pose.facing)
		else: Visual.draw_pose(self,float(pose.radius),pose.facing,int(pose.motion),float(pose.phase))
