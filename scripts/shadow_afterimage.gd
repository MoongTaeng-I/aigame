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
	install_presentation(loaded)

static func presentation() -> Dictionary:
	if Engine.has_meta(PRESENTATION_CACHE): return Engine.get_meta(PRESENTATION_CACHE)
	# Pure presentation data; this loader never touches combat RNG or hit state.
	var file := FileAccess.open("res://data/combat_presentation.csv",FileAccess.READ)
	var result: Dictionary = {}
	file.get_csv_line()
	while not file.eof_reached():
		var cells := file.get_csv_line()
		if cells.size()==2: result[cells[0]] = cells[1]
	install_presentation(result)
	return Engine.get_meta(PRESENTATION_CACHE)

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
	delta *= float(get_viewport().get_meta(&"fx05_visual_scale",1.0)) if is_inside_tree() else 1.0
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

static func compiled_presentation() -> Dictionary:
	var raw := presentation()
	var stamp := raw.hash()
	var cached: Dictionary = Engine.get_meta(&"presentation_compiled",{})
	if cached.get("stamp") == stamp: return cached["values"]
	var values := compile_values(raw)
	Engine.set_meta(&"presentation_compiled",{"stamp":stamp,"values":values})
	return values

static func compile_values(raw: Dictionary) -> Dictionary:
	var values := {}
	for key in raw:
		var value = raw[key]
		if value is String:
			if value.begins_with("#"): value = Color(value)
			elif value.is_valid_float(): value = float(value)
		values[key] = value
	values.make_read_only()
	return values

static func install_presentation(raw: Dictionary) -> void:
	raw.make_read_only()
	var values := compile_values(raw)
	# Keep the public loading-screen cache and every new round identical.
	# Raw CSV spellings are retained only for compatibility/equivalence audits.
	Engine.set_meta(&"combat_presentation_raw",raw)
	Engine.set_meta(PRESENTATION_CACHE,values)
	Engine.set_meta(&"presentation_compiled",{"stamp":values.hash(),"values":values})
