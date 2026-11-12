extends Control

const Visual = preload("res://scripts/shadow_visual.gd")
const RADIUS := 10.0
var dash_shape := false

func _draw() -> void:
	draw_set_transform(size/2)
	if dash_shape: Visual.draw_charger_pose(self,RADIUS,Vector2.RIGHT)
	else: Visual.draw_pose(self,RADIUS,Vector2.RIGHT,-1,0)
