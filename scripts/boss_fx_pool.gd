extends Node2D

const Draw = preload("res://scripts/combat_fx_draw.gd")
var manager: Node2D
var settings: Dictionary
var slots: Array = []
var gates: Array = []
var ghosts: Array = []
var cursor := 0
var gate_cursor := 0
var rng := RandomNumberGenerator.new()
var age := 0.0
var slow_remaining := 0.0
var active_count := 0
var events: Dictionary = {}
var gate_layer: Node2D
var kill_presenting := false

func visual_delta(delta: float) -> float:
	return delta*float(get_viewport().get_meta(&"fx05_visual_scale",1.0))

func configure(owner_manager: Node2D, values: Dictionary) -> void:
	manager = owner_manager
	settings = values
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 45
	rng.randomize()
	for i in range(int(settings.Fx05_pool_max)):
		slots.append({"active":false,"kind":"","point":Vector2.ZERO,"direction":Vector2.RIGHT,"radius":0.0,"size":0.0,"age":0.0,"life":1.0,"seed":0.0,"data":{}})
	if int(settings.Boss_fx_enabled)!=0:
		gate_layer = preload("res://scripts/boss_gate_fx.gd").new()
		gate_layer.pool = self
		var map: Node = manager.get_parent()
		map.add_child(gate_layer)
		map.move_child(gate_layer,0) # Parent ground first, then gate, then y-sorted bodies.
		for i in range(int(settings.Gate_pool_max)):
			gates.append({"active":false,"opened":false,"point":Vector2.ZERO,"start":0.0,"emerge":-1.0,"actor":null,"id":"","close":false})
	if int(settings.Impact_fx_enabled)!=0:
		for i in range(int(settings.Boss_ghost_max)):
			var image := SpriteBody.new()
			image.hide()
			image.show_shadow = false
			add_child(image)
			ghosts.append({"image":image,"age":0.0,"life":0.0,"active":false})

func enabled(boss: bool = true) -> bool:
	return int(settings.Boss_fx_enabled if boss else settings.Impact_fx_enabled)!=0

func emit(kind: String, point: Vector2, radius: float, life: float, size: float = 0, direction: Vector2 = Vector2.RIGHT, data: Dictionary = {}) -> Dictionary:
	var slot: Dictionary = slots[cursor]
	cursor = (cursor+1)%slots.size()
	if not slot.active: active_count+=1
	slot.merge({"active":true,"kind":kind,"point":point,"direction":direction,"radius":radius,"size":size,"age":0.0,"life":life,"seed":rng.randf()*TAU,"data":data},true)
	events[kind] = int(events.get(kind,0))+1
	queue_redraw()
	return slot

func puffs(point: Vector2, count: int, seconds: float) -> void:
	for i in range(count): emit("puff",point,float(settings.Fx05_puff_spread_px),seconds,rng.randf_range(float(settings.Fx05_puff_min_px),float(settings.Fx05_puff_max_px)),Vector2.RIGHT.rotated(rng.randf()*TAU))

func strike(boss: Node2D, row: Dictionary, point: Vector2, direction: Vector2) -> void:
	if not enabled(): return
	var kind := int(row.Kind)
	if kind==0:
		for i in range(int(settings.Bear_claw_count)):
			emit("claw",point,float(row.Range)*(1.0-i*float(settings.Bear_claw_spacing_ratio)),float(settings.Bear_claw_sec),float(settings.Bear_claw_width),direction,{"arc":deg_to_rad(float(row.Arc_deg))})
	elif kind==2:
		emit("ring",point,float(row.Slam_radius),float(settings.Bear_wave_sec),float(settings.Bear_wave_width))
		for i in range(int(settings.Bear_spike_count)): emit("spike",point+Vector2.RIGHT.rotated(TAU*i/int(settings.Bear_spike_count))*float(row.Slam_radius)*float(settings.Bear_spike_radius_ratio),0,float(settings.Bear_spike_sec),rng.randf_range(float(settings.Bear_spike_min_px),float(settings.Bear_spike_max_px)))
		for i in range(int(settings.Bear_shard_count)): emit("shard",point,float(settings.Bear_shard_speed),float(settings.Bear_spike_sec),float(settings.Bear_shard_px),Vector2.RIGHT.rotated(rng.randf_range(-PI,0)))
		shake(float(settings.Bear_slam_shake_px),float(settings.Bear_slam_shake_sec))
	elif kind==4:
		for i in range(int(settings.Elf_push_rings)): emit("ring",point,float(row.Use_range),float(settings.Elf_push_sec),float(settings.Elf_push_width),Vector2.RIGHT,{"delay":i*float(settings.Elf_push_delay_sec)})
	elif kind==7:
		var points: PackedVector2Array = boss.baruka.triangle_points()
		for i in range(2): emit("line",points[2],0,float(settings.Baruka_tri_sec),float(settings.Baruka_slash_width),points[i]-points[2])
	elif kind==8:
		emit("cross",point,float(settings.Baruka_blink_px),float(settings.Baruka_blink_sec),float(settings.Baruka_slash_width))
		emit("star",point,float(settings.Baruka_star_px),float(settings.Baruka_blink_sec))

func dash_segment(previous: Vector2, point: Vector2, elapsed: float, before: float) -> void:
	if not enabled(): return
	var interval := float(settings.Bear_dust_interval_sec)
	var start := floori((before+0.000000001)/interval)
	var finish := floori((elapsed+0.000000001)/interval)
	for step in range(start+1,finish+1):
		var fraction := clampf((step*interval-before)/maxf(elapsed-before,0.000001),0,1)
		puffs(previous.lerp(point,fraction),int(settings.Bear_dust_count),float(settings.Bear_dash_fx_sec))

func dash_start(point: Vector2, direction: Vector2, length: float) -> void:
	if not enabled(): return
	for i in range(int(settings.Bear_speedline_count)):
		var offset := direction.orthogonal()*rng.randf_range(-float(settings.Bear_speedline_spread),float(settings.Bear_speedline_spread))
		emit("line",point+offset,0,float(settings.Bear_dash_fx_sec),float(settings.Bear_speedline_width),direction*length)

func stealth(point: Vector2) -> void:
	if enabled(): puffs(point,int(settings.Elf_smoke_count),float(settings.Elf_smoke_sec))

func burst_prep(boss: Node2D) -> void:
	if enabled(): emit("gather",boss.global_position,float(settings.Elf_gather_px),float(settings.Elf_gather_sec),0,Vector2.RIGHT,{"actor":boss})

func zone(point: Vector2, radius: float, seconds: float) -> void:
	if not enabled(): return
	emit("zone",point,radius,seconds,float(settings.Zone_crystal_px))

func schedule_gate(id: String, point: Vector2, seconds_until_spawn: float) -> void:
	if not enabled(): return
	var gate: Dictionary = gates[gate_cursor]
	gate_cursor = (gate_cursor+1)%gates.size()
	gate.merge({"active":true,"opened":false,"point":point,"start":age,"scheduled":manager._elapsed_seconds+maxf(0,seconds_until_spawn-float(settings.Gate_lead_sec)),"emerge":-1.0,"actor":null,"id":id,"close":false},true)

func gate_center(point: Vector2) -> Vector2:
	return point+Vector2(0,-float(settings.Gate_px)*float(settings.Gate_center_up_ratio)-float(settings.Gate_back_px))

func emerge(boss: Node2D) -> void:
	if not enabled(): return
	var gate: Dictionary = {}
	for entry in gates:
		if entry.active and entry.emerge<0: gate = entry; break
	if gate.is_empty():
		schedule_gate("direct",boss.global_position,0)
		gate = gates[(gate_cursor-1+gates.size())%gates.size()]
	gate.actor = boss
	gate.emerge = age
	if not gate.opened:
		gate.opened = true; gate.start = age
		preload("res://scripts/audio_events.gd").sfx(self,"gate_open")
	shake(float(settings.Gate_shake_px),float(settings.Gate_shake_sec))
	flash(float(settings.Gate_flash_alpha),float(settings.Gate_flash_sec))

func hit_player() -> void:
	if not enabled(false): return
	var screen := screen_fx()
	if screen!=null: screen.player_hit()
	shake(float(settings.Player_hit_shake_px),float(settings.Player_hit_shake_sec))
	manager._player.set_meta(&"fx05_hp_shake",float(settings.Player_hp_shake_sec))

func died(enemy: Node2D) -> void:
	if not enabled(false): return
	if not enemy.has_method("configure_boss"):
		puffs(enemy.global_position,int(settings.Kill_puff_count),float(settings.Kill_puff_sec))
		return
	for slot in slots:
		if slot.active and slot.kind=="zone" and slot.data.get("owner")==enemy:
			slot.active = false
			slot.data = {}
			active_count-=1
	queue_redraw()
	slow_remaining = float(settings.Boss_kill_slowmo_sec)
	kill_presenting = true
	get_viewport().set_meta(&"fx05_visual_scale",float(settings.Boss_kill_slowmo_scale))
	get_viewport().set_meta(&"fx05_slow_owner",self)
	if enemy.sprite_body!=null:
		for ghost in ghosts:
			if ghost.active: continue
			ghost.active = true
			ghost.age = 0.0
			ghost.life = enemy.death_fade_sec
			ghost.image.configure_snapshot(enemy.sprite_body.pose_snapshot())
			ghost.image.global_position = enemy.global_position
			ghost.image.modulate = Color.WHITE
			ghost.image.material = enemy.sprite_body.material
			ghost.image.show()
			enemy.sprite_body.show_image = false
			enemy.sprite_body.request_redraw()
			break
	flash(float(settings.Boss_kill_flash_alpha),float(settings.Boss_kill_flash_sec))
	shake(float(settings.Boss_kill_shake_px),float(settings.Boss_kill_shake_sec))

func level_up(_level: int) -> void:
	if not enabled(false): return
	for i in range(int(settings.Level_ring_count)): emit("ring",manager._player.global_position,float(settings.Level_ring_px),float(settings.Level_ring_sec),float(settings.Level_ring_width),Vector2.RIGHT,{"delay":i*float(settings.Level_ring_delay)})

func screen_fx() -> Node:
	var skills: Node = manager._player.get("skill_presentation") if is_instance_valid(manager._player) else null
	return skills.screen_fx if is_instance_valid(skills) else null
func shake(px: float, seconds: float) -> void:
	var screen := screen_fx()
	if screen!=null: screen.kick(px,seconds)
func flash(alpha: float, seconds: float) -> void:
	var screen := screen_fx()
	if screen!=null: screen.flash_white(alpha,seconds)

func advance(delta: float) -> void:
	var result_only := get_tree().paused
	if result_only:
		var session := manager.get_parent().get_parent()
		if not kill_presenting or not session.get("round_finished") or not session.get("round_result").get("cleared",false): return
	var owns_slow := is_same(get_viewport().get_meta(&"fx05_slow_owner",0),self)
	var scale := (float(settings.Boss_kill_slowmo_scale) if slow_remaining>0 else 1.0) if owns_slow else float(get_viewport().get_meta(&"fx05_visual_scale",1.0))
	if owns_slow: get_viewport().set_meta(&"fx05_visual_scale",scale)
	var scaled := delta*scale
	if result_only:
		slow_remaining = maxf(0,slow_remaining-delta)
		advance_ghosts(scaled)
		var screen := screen_fx()
		if screen!=null: screen.advance_result_kill(delta)
		kill_presenting = slow_remaining>0 or ghosts.any(func(ghost: Dictionary) -> bool: return ghost.active) or (screen!=null and (screen.white_remaining>0 or screen.remaining>0))
		return
	var had := active_count>0
	age+=scaled
	slow_remaining = maxf(0,slow_remaining-delta)
	for slot in slots if active_count>0 else []:
		if not slot.active: continue
		slot.age+=scaled
		var expired_zone: bool = slot.kind=="zone" and slot.data.has("owner") and (not is_instance_valid(slot.data.owner) or slot.data.owner.baruka==null or not slot.data.owner.baruka.zones.has(slot.data.zone))
		if slot.age>=slot.life or expired_zone:
			slot.active = false
			slot.data = {}
			active_count-=1
	advance_ghosts(scaled)
	var gate_visible := false
	for gate in gates:
		if not gate.active: continue
		if not gate.opened:
			if manager._elapsed_seconds<float(gate.scheduled): continue
			gate.opened = true
			gate.start = age
			preload("res://scripts/audio_events.gd").sfx(self,"gate_open")
		if gate.emerge<0:
			gate_visible = true
			continue
		var elapsed: float = age-gate.emerge
		var progress := clampf(elapsed/float(settings.Gate_emerge_sec),0,1)
		if is_instance_valid(gate.actor) and gate.actor.sprite_body!=null:
			var sprite: SpriteBody = gate.actor.sprite_body
			if progress<1:
				sprite.advance_shadow_pose(Vector2.DOWN,true,delta,false,gate.actor.facing)
			var eased := 1-pow(1-progress,3)
			var size := lerpf(float(settings.Gate_emerge_scale),1,eased)
			var pivot := Vector2(0,sprite.foot_y)
			var world_foot: Vector2 = gate.actor.global_position+pivot
			var offset: Vector2 = gate_center(gate.point).lerp(world_foot,eased)-world_foot
			sprite.presentation_transform = Transform2D(0,Vector2.ONE*size,0,offset+pivot-pivot*size)
			sprite.presentation_alpha = progress
			sprite.request_redraw()
		if elapsed>=float(settings.Gate_emerge_sec)+float(settings.Gate_close_sec):
			gate.active = false
			gate.actor = null
		else: gate_visible = true
	if had: queue_redraw()
	if gate_layer!=null and (gate_visible or gate_layer.was_visible):
		gate_layer.was_visible = gate_visible
		gate_layer.queue_redraw()

func _physics_process(delta: float) -> void: advance(delta)

func advance_ghosts(delta: float) -> void:
	for ghost in ghosts:
		if not ghost.active: continue
		ghost.age+=delta
		if ghost.age>=float(settings.Boss_hit_flash_sec): ghost.image.material = null
		ghost.image.modulate.a = maxf(0,1-ghost.age/maxf(ghost.life,0.000001))
		if ghost.age>=ghost.life:
			ghost.active = false
			ghost.image.hide()
			ghost.image.material = null

func _draw() -> void:
	var palette: Array[Color] = [settings.Boss_fx_outline,settings.Boss_fx_color,settings.Boss_fx_core]
	for slot in slots:
		if not slot.active: continue
		var p := clampf(float(slot.age)/maxf(float(slot.life),0.000001),0,1)
		var point := to_local(slot.point)
		var alpha := 1-p
		match slot.kind:
			"claw": Draw.arc(self,point,slot.radius,slot.direction.angle()-slot.data.arc*0.5,slot.direction.angle()-slot.data.arc*0.5+slot.data.arc*minf(1,p/float(settings.Fx05_draw_ratio)),slot.size*alpha,float(settings.Boss_fx_y_scale),palette,alpha)
			"line": Draw.blade(self,point,point+slot.direction,slot.size*alpha,palette,alpha)
			"cross":
				for angle in [-PI/4,PI/4]:
					var side := Vector2.RIGHT.rotated(angle)*float(slot.radius)*0.5
					Draw.blade(self,point-side,point+side,slot.size*alpha,palette,alpha)
			"star": Draw.star(self,point,slot.radius*alpha,palette[0],alpha)
			"arrow_tail": draw_circle(point,float(slot.radius)*alpha,Color(palette[1],float(settings.Arrow_tail_alpha)*alpha))
			"puff":
				point+=Vector2(slot.direction)*float(slot.radius)*p
				var size := float(slot.size)*minf(1,p/float(settings.Fx05_draw_ratio))*(1-p)
				draw_circle(point,size+float(settings.Fx05_outline_px)*alpha,Color(palette[0],alpha))
				draw_circle(point,size,Color(palette[1],alpha))
			"ring":
				var start := float(slot.data.get("delay",0))
				var t := clampf((float(slot.age)-start)/maxf(float(slot.life)-start,0.000001),0,1)
				var width := lerpf(float(slot.size),float(settings.Fx05_ring_end_width),t)
				for layer in range(3): draw_arc(point,slot.radius*t,0,TAU,64,Color(palette[layer],1-t),width+float(settings.Fx05_outline_px)*2 if layer==0 else (width if layer==1 else width*float(settings.Fx05_core_ratio)),true)
			"spike","shard":
				if slot.kind=="shard": point+=Vector2(slot.direction)*float(slot.radius)*float(slot.age)
				var direction: Vector2 = slot.direction if slot.kind=="shard" else Vector2.UP
				Draw.blade(self,point,point+direction*float(slot.size)*minf(1,p/float(settings.Fx05_draw_ratio)),float(settings.Fx05_spike_width)*alpha,palette,alpha)
			"gather":
				var actor = slot.data.actor
				if is_instance_valid(actor): point = to_local(actor.global_position+Vector2(float(settings.Elf_hand_x)*(-1 if actor.facing.x<0 else 1),float(settings.Elf_hand_y)))
				for i in range(int(settings.Elf_gather_particles)):
					Draw.star(self,point+Vector2.RIGHT.rotated(TAU*i/int(settings.Elf_gather_particles)+slot.seed)*float(slot.radius)*alpha,float(settings.Fx05_star_px)*(1-alpha*0.5),palette[0],1)
			"zone":
				for i in range(int(settings.Zone_crystal_count)):
					var center := point+Vector2.RIGHT.rotated(TAU*i/int(settings.Zone_crystal_count))*float(slot.radius)*float(settings.Zone_crystal_radius_ratio)
					Draw.blade(self,center,center+Vector2.UP*float(slot.size),float(settings.Fx05_spike_width),palette,minf(1,alpha*float(settings.Zone_fade_mult)))
				for i in range(int(settings.Zone_fog_count)):
					var center := point+Vector2.RIGHT.rotated(TAU*i/int(settings.Zone_fog_count))*float(slot.radius)
					draw_circle(center,float(settings.Zone_fog_px)*(1+float(settings.Zone_fog_wave)*sin(slot.age*TAU+slot.seed+i)),Color(palette[1],float(settings.Zone_fog_alpha)*minf(1,alpha*float(settings.Zone_fade_mult))))

func _exit_tree() -> void:
	if is_same(get_viewport().get_meta(&"fx05_slow_owner",0),self):
		get_viewport().set_meta(&"fx05_visual_scale",1.0)
		get_viewport().remove_meta(&"fx05_slow_owner")
	# Reparenting leaves and re-enters the tree without another _ready.
	# Keep fixed storage, but discard effects from the old world.
	active_count = 0
	for slot in slots:
		slot.active = false
		slot.data = {}
	for gate in gates:
		gate.active = false
		if is_instance_valid(gate.actor) and gate.actor.sprite_body!=null:
			gate.actor.sprite_body.presentation_transform = Transform2D.IDENTITY
			gate.actor.sprite_body.presentation_alpha = 1.0
		gate.actor = null
	for ghost in ghosts:
		ghost.active = false
		ghost.image.hide()
		ghost.image.material = null
	slow_remaining = 0.0
	kill_presenting = false

func _enter_tree() -> void:
	if is_instance_valid(gate_layer) and gate_layer.get_parent()!=manager.get_parent():
		gate_layer.reparent(manager.get_parent())
		manager.get_parent().move_child(gate_layer,0)

func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE and is_instance_valid(gate_layer): gate_layer.queue_free()
