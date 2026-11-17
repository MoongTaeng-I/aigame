extends Node2D

var texture: Texture2D
var column := 0
var mirrored := false
var display_height := 234.0
var shadow_size := Vector2(70,24)
# One sheet cell (texture width / Props_cols, texture height); env_props.png is 6 x 321 by 468.
var cell_size := Vector2(321,468)

func _draw() -> void:
	preload("res://scripts/sprite_body.gd").draw_ground_shadow(self,shadow_size)
	var scale_factor := display_height/cell_size.y
	# The foot anchor (-160,-464) was set on the 321x468 cell; other cell sizes scale it.
	var rect := Rect2(Vector2(-160,-464)*(cell_size/Vector2(321,468))*scale_factor,cell_size*scale_factor)
	if mirrored: draw_set_transform_matrix(Transform2D(Vector2(-1,0),Vector2(0,1),Vector2.ZERO))
	draw_texture_rect_region(texture,rect,Rect2(column*cell_size.x,0,cell_size.x,cell_size.y))
	draw_set_transform_matrix(Transform2D.IDENTITY)
