extends Node2D

var settings: Dictionary
var slots: Array = []
var visual_rng := RandomNumberGenerator.new()
var sequence := 0
var font: Font
var clock := 0.0
var active_count := 0
var by_enemy := {}

func configure(values: Dictionary) -> void:
	settings = values
	font = ThemeDB.fallback_font
	z_index = 60
	process_mode = Node.PROCESS_MODE_PAUSABLE
	visual_rng.randomize()
	for i in range(int(settings.get("Damage_number_max",60))): slots.append({"index":i,"active":false,"age":0.0,"pop_age":0.0,"last_hit":0.0,"enemy":"","serial":-1,"point":Vector2.ZERO,"value":0,"killed":false,"color":Color.WHITE})

func show_damage(enemy: Node2D, amount: int, source: String, killed: bool) -> void:
	if amount<=0 or slots.is_empty(): return
	var key := "%d:%d" % [enemy.get_instance_id(),enemy.spawn_order]
	var merge_sec := float(settings.get("Damage_number_merge_sec",0.15))
	var previous: int = by_enemy.get(key,-1)
	if merge_sec>0 and previous>=0:
		var current: Dictionary = slots[previous]
		if current.active and current.enemy==key and clock-float(current.last_hit)<=merge_sec+0.000000001:
			current.value += amount
			current.pop_age = 0.0
			current.last_hit = clock
			current.killed = current.killed or killed
			current.color = number_color(source,current.killed)
			queue_redraw()
			return
	var index := 0
	for i in range(slots.size()):
		if not slots[i].active:
			index = i
			break
		if int(slots[i].serial)<int(slots[index].serial): index = i
	var top: float = -enemy.body_radius
	if enemy.sprite_body!=null and not enemy.sprite_body.using_fallback: top = enemy.sprite_body.display_rect().position.y
	var slot: Dictionary = slots[index]
	if slot.active:
		if by_enemy.get(slot.enemy)==index: by_enemy.erase(slot.enemy)
	else: active_count+=1
	slot.active = true
	slot.age = 0.0
	slot.pop_age = 0.0
	slot.last_hit = clock
	slot.enemy = key
	by_enemy[key] = index
	slot.serial = sequence
	sequence += 1
	slot.point = enemy.global_position+Vector2(visual_rng.randf_range(-float(settings.get("Damage_number_jitter_px",8)),float(settings.get("Damage_number_jitter_px",8))),top-float(settings.get("Damage_number_head_gap",6)))
	slot.value = amount
	slot.killed = killed
	slot.color = number_color(source,killed)
	queue_redraw()

func number_color(source: String, killed: bool) -> Color:
	return Color(settings.get("Damage_number_kill_color",Color("#ffd84a")) if killed else (settings.get("Damage_number_shadow_color",Color("#d6c8ff")) if source=="shadow" else settings.get("Damage_number_player_color",Color.WHITE)))

func advance(delta: float) -> void:
	delta *= float(get_viewport().get_meta(&"fx05_visual_scale",1.0)) if is_inside_tree() else 1.0
	if get_tree().paused: return
	clock += maxf(delta,0)
	if active_count==0: return
	for slot in slots:
		if not slot.active: continue
		slot.age += maxf(delta,0)
		slot.pop_age += maxf(delta,0)
		if slot.age>=float(settings.get("Damage_number_sec",0.55)):
			slot.active = false
			active_count-=1
			if by_enemy.get(slot.enemy)==slot.index: by_enemy.erase(slot.enemy)
	queue_redraw()

func _physics_process(delta: float) -> void: advance(delta)

func _draw() -> void:
	for slot in slots:
		if not slot.active: continue
		var t := clampf(float(slot.age)/float(settings.get("Damage_number_sec",0.55)),0,1)
		var size := int(settings.get("Damage_number_size",18))
		var scale_factor := lerpf(float(settings.get("Damage_number_pop_scale",1.4)),1,clampf(float(slot.pop_age)/float(settings.get("Damage_number_pop_sec",0.08)),0,1))*(float(settings.get("Damage_number_kill_scale",1.2)) if slot.killed else 1.0)
		var point := to_local(Vector2(slot.point)+Vector2.UP*float(settings.get("Damage_number_rise_px",28))*t)
		var color: Color = slot.color
		var fade := float(settings.get("Damage_number_fade_fraction",0.4))
		color.a = 1-clampf((t-(1-fade))/maxf(fade,0.000001),0,1)
		draw_set_transform(point,0,Vector2.ONE*scale_factor)
		var text := str(slot.value)
		var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		var offset := Vector2(-width*0.5,0)
		draw_string_outline(font,offset,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,int(settings.get("Damage_number_outline_px",3)),Color(Color(settings.get("Player_fx_outline","#16265a")),color.a))
		draw_string(font,offset,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func _exit_tree() -> void:
	slots.clear()
	by_enemy.clear()
