extends Node2D

var texture: Texture2D
var column := 0
var mirrored := false
var display_height := 234.0
var shadow_size := Vector2(70,24)

func _draw() -> void:
	preload("res://scripts/sprite_body.gd").draw_ground_shadow(self,shadow_size)
	var scale_factor := display_height/468.0
	var rect := Rect2(Vector2(-160,-464)*scale_factor,Vector2(321,468)*scale_factor)
	if mirrored: draw_set_transform_matrix(Transform2D(Vector2(-1,0),Vector2(0,1),Vector2.ZERO))
	draw_texture_rect_region(texture,rect,Rect2(column*321,0,321,468))
	draw_set_transform_matrix(Transform2D.IDENTITY)
