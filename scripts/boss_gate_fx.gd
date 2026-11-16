extends Node2D
var pool: Node2D
var was_visible := false
var texture: Texture2D = preload("res://assets/art/fx/fx_gate.png")
func _draw() -> void:
	for gate in pool.gates:
		if not gate.active or not gate.opened: continue
		var t: float = pool.age-gate.start
		var factor := minf(1,t/float(pool.settings.Gate_open_sec))
		if gate.emerge>=0: factor*=1-clampf((pool.age-gate.emerge-float(pool.settings.Gate_emerge_sec))/float(pool.settings.Gate_close_sec),0,1)
		var center: Vector2 = to_local(pool.gate_center(gate.point))
		var size: float = pool.settings.Gate_px*factor
		draw_set_transform(center,deg_to_rad(float(pool.settings.Gate_spin_deg))*maxf(0,t-float(pool.settings.Gate_open_sec)))
		draw_texture_rect(texture,Rect2(Vector2.ONE*-size*0.5,Vector2.ONE*size),false,Color(1,1,1,factor))
		draw_set_transform(Vector2.ZERO)
		for i in range(int(pool.settings.Gate_particle_count)):
			var phase := fposmod(t*float(pool.settings.Gate_particle_hz)+float(i)/int(pool.settings.Gate_particle_count),1)
			var point := center+Vector2.RIGHT.rotated(TAU*i/int(pool.settings.Gate_particle_count)+t)*size*0.5*(1-phase)
			draw_circle(point,float(pool.settings.Gate_particle_px)*(1-phase),Color(pool.settings.Boss_fx_core,factor*phase))
