extends Node2D

const Visual = preload("res://scripts/shadow_visual.gd")
var pose: Dictionary
var lifetime: float
var elapsed: float = 0.0

func configure(snapshot: Dictionary, seconds: float) -> void:
	pose = snapshot.duplicate(true)
	lifetime = seconds
	modulate.a = 0.45
	queue_redraw()

func _physics_process(delta: float) -> void:
	elapsed += delta
	modulate.a = 0.45*maxf(0.0,1.0-elapsed/lifetime)
	if elapsed+0.000000001>=lifetime:
		queue_free()

func _draw() -> void:
	if pose!=null:
		Visual.draw_pose(self,float(pose.radius),pose.facing,int(pose.motion),float(pose.phase))
