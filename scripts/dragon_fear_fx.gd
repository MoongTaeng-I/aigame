extends Node2D
var settings: Dictionary
var radius := 0.0
var duration := 0.5
var age := 0.0
var head_only := false
var head_texture: Texture2D
func wave_radius(at: float = -1) -> float:
	return radius*clampf((age if at<0 else at)/maxf(duration,0.000001),0,1)
func _process(delta: float) -> void:
	age += maxf(delta,0)
	if age>duration: queue_free()
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
	var color := Color(String(settings.get("Fear_color","#a34dff")))
	color.a = 1-progress
	draw_arc(Vector2.ZERO,wave_radius(),0,TAU,96,color,3,true)
	var claw_alpha := maxf(0,1-age/float(settings.get("Fear_claw_sec",0.12)))
	for i in range(int(settings.get("Fear_claw_count",6))):
		var direction := Vector2.RIGHT.rotated(TAU*i/int(settings.get("Fear_claw_count",6)))
		draw_line(direction*radius*0.15,direction.rotated(0.15)*radius*0.7,Color(Color(String(settings.get("Fear_claw_color","#e83948"))),claw_alpha),float(settings.get("Fear_claw_width",3)),true)
	for i in range(int(settings.get("Fear_bat_count",20))):
		var direction := Vector2.RIGHT.rotated(i*2.399963)
		var center := direction*radius*progress*(0.5+0.5*float(i%5)/4)
		var size := float(settings.get("Fear_bat_px",6))*(1-progress)
		draw_colored_polygon(PackedVector2Array([center+Vector2(-size,-size*0.5),center,center+Vector2(size,-size*0.5),center+Vector2(0,size*0.4)]),Color(0.03,0.02,0.06,1-progress))
