extends Node2D

const Draw = preload("res://scripts/combat_fx_draw.gd")
var settings: Dictionary
var shadow := true
var visual_rng := RandomNumberGenerator.new()
var slots: Array = []
var cursor := 0
var active_count := 0

func configure(values: Dictionary, capacity: int, is_shadow: bool) -> void:
	settings = values
	shadow = is_shadow
	z_index = 40
	process_mode = Node.PROCESS_MODE_PAUSABLE
	visual_rng.randomize()
	for i in range(capacity): slots.append({"active":false,"kind":"","point":Vector2.ZERO,"velocity":Vector2.ZERO,"gravity":0.0,"size":0.0,"age":0.0,"life":0.0})

func spawn(kind: String, point: Vector2, size: float, life: float, velocity: Vector2 = Vector2.ZERO, gravity: float = 0) -> void:
	if slots.is_empty(): return
	var slot: Dictionary = slots[cursor]
	if not slot.active: active_count+=1
	cursor = (cursor+1)%slots.size()
	slot.active = true
	slot.kind = kind
	slot.point = point
	slot.size = size
	slot.life = life
	slot.age = 0.0
	slot.velocity = velocity
	slot.gravity = gravity
	queue_redraw()

func belion_burst(point: Vector2) -> void:
	var life := float(settings.get("Belion_burst_sec",0.3))
	for i in range(int(settings.get("Belion_shard_count",7))):
		var velocity := Vector2.RIGHT.rotated(visual_rng.randf_range(-PI+float(settings.get("Belion_shard_angle_margin",0.15)),-float(settings.get("Belion_shard_angle_margin",0.15))))*visual_rng.randf_range(float(settings.get("Belion_shard_speed_min",60)),float(settings.get("Belion_shard_speed_max",120)))
		spawn("shard",point,visual_rng.randf_range(float(settings.get("Belion_shard_min_px",18)),float(settings.get("Belion_shard_max_px",34))),life,velocity)
	for i in range(int(settings.get("Belion_stone_count",5))):
		spawn("stone",point,float(settings.get("Belion_stone_px",5)),life,Vector2(visual_rng.randf_range(-float(settings.get("Belion_stone_speed_x",80)),float(settings.get("Belion_stone_speed_x",80))),visual_rng.randf_range(-float(settings.get("Belion_stone_speed_y_max",120)),-float(settings.get("Belion_stone_speed_y_min",70)))),float(settings.get("Belion_stone_gravity",350)))
	spawn("star",point,float(settings.get("Belion_star_px",12)),life)

func advance(delta: float) -> void:
	if get_tree().paused: return
	if active_count==0: return
	for slot in slots:
		if not slot.active: continue
		slot.age += maxf(0,delta)
		if slot.age>=slot.life:
			slot.active = false
			active_count-=1
	queue_redraw()

func _physics_process(delta: float) -> void: advance(delta)

func _draw() -> void:
	var palette := Draw.colors(settings,shadow)
	for slot in slots:
		if not slot.active: continue
		var progress := clampf(float(slot.age)/maxf(float(slot.life),0.000001),0,1)
		var point := to_local(Vector2(slot.point)+Vector2(slot.velocity)*float(slot.age)+Vector2.DOWN*float(slot.gravity)*float(slot.age)*float(slot.age)*0.5)
		if slot.kind=="star": Draw.star(self,point,float(slot.size)*(1-progress),palette[0],1-progress)
		elif slot.kind=="mark":
			for angle in [-PI/4,PI/4]:
				var side := Vector2.RIGHT.rotated(angle)*float(slot.size)*0.5
				Draw.blade(self,point-side,point+side,float(settings.get("Beru_mark_width",9))*(1-progress),palette,1-progress)
		elif slot.kind=="stone":
			var size := float(slot.size)*(1-progress)
			draw_colored_polygon(PackedVector2Array([point+Vector2(-size,0),point+Vector2(0,-size),point+Vector2(size,0),point+Vector2(0,size)]),Color(Color(settings.get("Belion_stone_color","#5f6480")),1-progress))
		else:
			var direction := Vector2(slot.velocity).normalized()
			Draw.blade(self,point,point+direction*float(slot.size)*(1-progress),float(settings.get("Shadow_spark_width",3))*(1-progress),palette,1-progress)

func _exit_tree() -> void:
	slots.clear()
