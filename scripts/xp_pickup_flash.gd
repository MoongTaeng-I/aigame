extends Node2D
# JUICE-01: small sparkle where the player picked up experience. Fixed pool of Xp_flash_pool slots,
# one node; processes and redraws only while a slot is active.
var settings: Dictionary = preload("res://scripts/shadow_afterimage.gd").compiled_presentation()
var slots: Array = []
var cursor := 0
var active_count := 0
var redraws := 0
var life := 0.12
var size := 14.0
var color := Color("#a68cff")

func _ready() -> void:
	z_index = 30
	top_level = true
	life = float(settings.Xp_pickup_flash_sec)
	size = float(settings.Xp_pickup_flash_px)
	color = settings.Xp_color
	for i in range(int(settings.Xp_flash_pool)): slots.append({"active":false,"point":Vector2.ZERO,"age":0.0})
	set_process(false)

func emit(point: Vector2) -> void:
	if slots.is_empty() or life<=0: return
	var slot: Dictionary = slots[cursor]
	cursor = (cursor+1)%slots.size()
	if not slot.active: active_count += 1
	slot.active = true
	slot.point = point
	slot.age = 0.0
	set_process(true)
	redraws += 1
	queue_redraw()

func _process(delta: float) -> void:
	for slot in slots:
		if not slot.active: continue
		slot.age += delta
		if slot.age>=life:
			slot.active = false
			active_count -= 1
	redraws += 1
	queue_redraw()
	if active_count<=0: set_process(false)

func _draw() -> void:
	for slot in slots:
		if not slot.active: continue
		var t: float = slot.age/life
		var r := size*(0.4+0.6*t)
		var a := 1.0-t
		draw_circle(slot.point,r*0.35,Color(1,1,1,0.9*a))
		draw_arc(slot.point,r,0,TAU,20,Color(color,0.8*a),2.0,true)
		for i in range(4):
			var arm := Vector2.RIGHT.rotated(PI*0.25+PI*0.5*i)
			draw_line(slot.point+arm*r*0.5,slot.point+arm*r*1.2,Color(color,a),2.0,true)
