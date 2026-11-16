extends Node2D
var player: Node2D
var ratio := 1.0
var settings: Dictionary
func _process(_delta: float) -> void:
	var left := float(player.get_meta(&"fx05_hp_shake",0.0))
	left = maxf(0,left-_delta*float(get_viewport().get_meta(&"fx05_visual_scale",1.0)))
	player.set_meta(&"fx05_hp_shake",left)
	ratio = clampf(float(player.hp)/maxi(1,player.max_hp),0,1)
	position = Vector2(0,float(player.sprite_body.foot_y) if player.sprite_body!=null else 8)+Vector2(0,12)
	if left>0: position.x+=sin(left*TAU*float(settings.Player_hp_shake_hz))*float(settings.Player_hp_shake_px)*left/float(settings.Player_hp_shake_sec)
	queue_redraw()
func _draw() -> void:
	var rect := Rect2(-24,0,48,5)
	draw_rect(rect.grow(1),Color(settings.get("Hp_background","#182238")))
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*ratio,rect.size.y)),Color(settings.get("Hp_color","#e84d5b")))
