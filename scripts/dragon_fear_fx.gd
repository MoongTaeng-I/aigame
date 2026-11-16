extends Node2D
var settings: Dictionary
var radius := 0.0 # Actual combat Range; never replaced by visual wave radius.
var duration := 0.5
var age := 0.0
var head_only := false
var head_texture: Texture2D
var waves: Array = []
var bats: Array = []
var claws: Array = []

func initialize(visual_rng: RandomNumberGenerator) -> void:
	for i in range(int(settings.get("Fear_wave_count",3))):
		waves.append({"delay":i*float(settings.get("Fear_wave_delay_sec",0.08))})
	for i in range(int(settings.get("Fear_claw_count",8))):
		var angle := TAU*i/maxi(1,int(settings.get("Fear_claw_count",8)))+visual_rng.randf_range(-1,1)*float(settings.get("Fear_claw_jitter",0.1))
		claws.append(Vector2.RIGHT.rotated(angle))
	for i in range(int(settings.get("Fear_bat_count",40))):
		var direction := Vector2.RIGHT.rotated(visual_rng.randf()*TAU)
		bats.append({"direction":direction,"start":radius*visual_rng.randf()*float(settings.get("Fear_bat_start_ratio",0.8)),"size":visual_rng.randf_range(float(settings.get("Fear_bat_min_px",8)),float(settings.get("Fear_bat_max_px",14))),"phase":visual_rng.randf()*TAU})

func wave_radius(at: float = -1, delay: float = 0) -> float:
	return float(settings.get("Fear_wave_max_px",900))*clampf(((age if at<0 else at)-delay)/maxf(duration,0.000001),0,1)

func lifetime() -> float:
	return duration if head_only else maxf(duration+maxi(0,int(settings.get("Fear_wave_count",3))-1)*float(settings.get("Fear_wave_delay_sec",0.08)),duration+float(settings.get("Fear_bat_tail_sec",0.6)))

func _process(delta: float) -> void:
	age += maxf(delta,0)
	for i in range(waves.size()-1,-1,-1):
		if age>=float(waves[i].delay)+duration: waves.remove_at(i)
	if age>=float(settings.get("Fear_claw_sec",0.12)): claws.clear()
	if age>=duration+float(settings.get("Fear_bat_tail_sec",0.6)): bats.clear()
	if age>=lifetime():
		waves.clear()
		bats.clear()
		claws.clear()
		queue_free()
	queue_redraw()

func _draw() -> void:
	var progress := clampf(age/maxf(duration,0.000001),0,1)
	if head_only:
		var scale_factor := lerpf(float(settings.get("Fear_head_start_scale",0.6)),1,progress)
		var height := float(settings.get("Fear_head_px",260))*scale_factor
		var size := Vector2(height*496/640,height)
		var alpha := minf(progress*4,1)*minf((1-progress)*4,1)
		draw_texture_rect(head_texture,Rect2(Vector2(-size.x/2,-size.y-float(settings.get("Fear_head_rise_px",30))*progress),size),false,Color(1,1,1,alpha))
		return
	var color := Color(settings.get("Fear_color","#e8283c"))
	var outline := Color(settings.get("Fear_outline_color","#3c000f"))
	if age<duration:
		draw_circle(Vector2.ZERO,radius,Color(color,float(settings.get("Fear_range_alpha",0.18))))
		draw_arc(Vector2.ZERO,radius,0,TAU,96,outline,float(settings.get("Fear_range_width",6)),true)
	draw_set_transform(Vector2.ZERO,0,Vector2(1,float(settings.get("Fear_wave_y_scale",0.62))))
	for wave in waves:
		if age<float(wave.delay): continue
		var t := clampf((age-float(wave.delay))/maxf(duration,0.000001),0,1)
		var width := lerpf(float(settings.get("Fear_wave_start_width",22)),float(settings.get("Fear_wave_end_width",4)),t)
		var r := wave_radius(-1,float(wave.delay))
		if r<=0: continue
		outline.a = 1-t
		color.a = 1-t
		draw_arc(Vector2.ZERO,r,0,TAU,96,outline,width+2*float(settings.get("Slash_outline_px",4)),true)
		draw_arc(Vector2.ZERO,r,0,TAU,96,color,width,true)
		draw_arc(Vector2.ZERO,r,0,TAU,96,Color(1,1,1,1-t),width*float(settings.get("Fx_core_ratio",0.4)),true)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	var fx = preload("res://scripts/skill_cartoon_fx.gd")
	var claw_alpha := maxf(0,1-age/maxf(float(settings.get("Fear_claw_sec",0.12)),0.000001))
	for direction in claws:
		fx.blade(self,direction*radius*float(settings.get("Fear_claw_start_ratio",0.15)),Vector2(direction).rotated(float(settings.get("Fear_claw_curve",0.15)))*radius,float(settings.get("Fear_claw_width",10)),Color(Color(settings.get("Fear_claw_color","#e8283c")),claw_alpha),settings,false,outline)
	var bat_progress := clampf(age/maxf(duration+float(settings.get("Fear_bat_tail_sec",0.6)),0.000001),0,1)
	for bat in bats:
		var center: Vector2 = Vector2(bat.direction)*(float(bat.start)+float(settings.get("Fear_bat_travel_px",1100))*bat_progress)
		var size: float = bat.size
		var flap := lerpf(float(settings.get("Fear_bat_wing_min",0.5)),1,(sin(age*TAU*float(settings.get("Fear_bat_hz",12))+float(bat.phase))+1)*0.5)
		var wing := size*flap
		draw_colored_polygon(PackedVector2Array([center+Vector2(-size,-wing),center+Vector2(-size*0.45,0),center+Vector2(0,-size*0.2),center+Vector2(size*0.45,0),center+Vector2(size,-wing),center+Vector2(size*0.25,wing*0.4),center+Vector2(0,wing*0.2),center+Vector2(-size*0.25,wing*0.4)]),Color(0,0,0,1-bat_progress))
		for sign_x in [-1,1]: draw_circle(center+Vector2(sign_x*size*0.15,-size*0.1),float(settings.get("Fear_bat_eye_px",1)),Color(Color(settings.get("Fear_color","#e8283c")),1-bat_progress))
