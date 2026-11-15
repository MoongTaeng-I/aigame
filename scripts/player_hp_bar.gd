extends Node2D
var player: Node2D
var ratio := 1.0
var settings: Dictionary
func _process(_delta: float) -> void:
	ratio = clampf(float(player.hp)/maxi(1,player.max_hp),0,1)
	position = Vector2(0,float(player.sprite_body.foot_y) if player.sprite_body!=null else 8)+Vector2(0,12)
	queue_redraw()
func _draw() -> void:
	var rect := Rect2(-24,0,48,5)
	draw_rect(rect.grow(1),Color(String(settings.get("Hp_background","#182238"))))
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*ratio,rect.size.y)),Color(String(settings.get("Hp_color","#e84d5b"))))
