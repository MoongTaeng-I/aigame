extends Node2D

# One batch-drawn node, fixed slots. No per-hit Node/Timer/scene allocation.
const SPARK_VERTICES := 8
var enabled := false
var duration: float
var radius: float
var core_radius: float
var outer_color: Color
var core_color: Color
var positions := PackedVector2Array()
var ages := PackedFloat64Array()
var cursor := 0
var active_count := 0
var emitted := 0
var overwritten := 0
var spark := PackedVector2Array()

func configure(enemies: Node, row: Dictionary) -> void:
	enabled = int(row.Enabled)==1
	set_physics_process(enabled)
	z_index = 1
	if not enabled: return
	duration = float(row.Duration_sec)
	radius = float(row.Radius)
	core_radius = float(row.Core_radius)
	outer_color = Color.html(String(row.Outer_color))
	core_color = Color.html(String(row.Core_color))
	positions.resize(int(row.Max_active))
	ages.resize(int(row.Max_active))
	ages.fill(duration)
	for index in range(SPARK_VERTICES):
		spark.append(Vector2.RIGHT.rotated(TAU*index/SPARK_VERTICES)*(radius if index%2==0 else core_radius))
	enemies.enemy_damaged.connect(emit_at)

func emit_at(world_position: Vector2) -> void:
	if not enabled: return
	if ages[cursor]>=duration: active_count += 1
	else: overwritten += 1
	positions[cursor] = world_position
	ages[cursor] = 0.0
	cursor = (cursor+1)%ages.size()
	emitted += 1
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not enabled or active_count==0: return
	for index in range(ages.size()):
		if ages[index]>=duration: continue
		ages[index] += delta
		if ages[index]>=duration: active_count -= 1
	queue_redraw()

func _draw() -> void:
	if not enabled: return
	for index in range(ages.size()):
		if ages[index]>=duration: continue
		var alpha := 1.0-float(ages[index])/duration
		var center := to_local(positions[index])
		var points := PackedVector2Array()
		for vertex in spark: points.append(center+vertex)
		var edge := outer_color
		edge.a *= alpha
		var core := core_color
		core.a *= alpha
		draw_colored_polygon(points,edge)
		draw_circle(center,core_radius,core)
