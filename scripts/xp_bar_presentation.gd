extends Control
var hud: CanvasLayer
var actor: Node2D
var settings: Dictionary
var previous_xp := 0
var previous_level := 1
var gain_flash := 0.0
var level_flash := 0.0
var gradient: Texture2D
var last_size := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	previous_xp = actor.experience; previous_level = actor.level
	if not Engine.has_meta(&"xp_gradient"):
		var image := GradientTexture2D.new()
		var colors := Gradient.new()
		colors.set_color(0,settings.Xp_fill_start); colors.set_color(1,settings.Xp_fill_end)
		image.gradient = colors
		image.width = 256; image.height = 14
		image.fill_from = Vector2(0,0); image.fill_to = Vector2(1,0)
		Engine.set_meta(&"xp_gradient",image)
	gradient = Engine.get_meta(&"xp_gradient")

func ratio() -> float: return float(actor.experience)/maxi(1,actor.get_xp_to_next())

func _process(delta: float) -> void:
	var dirty: bool = gain_flash>0 or level_flash>0 or last_size!=get_parent().size
	if actor.experience!=previous_xp or actor.level!=previous_level:
		gain_flash = float(settings.Xp_gain_flash_sec)
		if actor.level!=previous_level: level_flash = float(settings.Xp_level_flash_sec)
		previous_xp = actor.experience; previous_level = actor.level
		hud.refresh(); dirty = true
	gain_flash = maxf(0,gain_flash-delta); level_flash = maxf(0,level_flash-delta)
	last_size = get_parent().size
	if dirty: queue_redraw()

func _draw() -> void:
	var bar := Rect2(Vector2.ZERO,get_parent().size)
	var fill := Rect2(2,2,maxf(0,(bar.size.x-4)*ratio()),maxf(0,bar.size.y-4))
	if fill.size.x>0:
		draw_rect(fill.grow(2),Color(settings.Xp_fill_start,float(settings.Xp_bar_glow_alpha)))
		draw_texture_rect(gradient,fill,false,Color(1,1,1,0.88))
	if gain_flash>0: draw_rect(Rect2(Vector2(maxf(0,fill.end.x-8),0),Vector2(8,bar.size.y)),Color(1,1,1,gain_flash/float(settings.Xp_gain_flash_sec)))
	if level_flash>0: draw_rect(bar,Color(1,1,1,level_flash/float(settings.Xp_level_flash_sec)))
