extends Node2D
class_name SpriteBody

const SHADOW_SIZE := Vector2(32.0,12.0)
const SHADOW_COLOR := Color(0.0,0.0,0.0,0.35)

var texture: Texture2D
var idle_texture: Texture2D
var layout := "dir3"
var columns := 1
var rows := 1
var cell_height := 0.0
var baseline := 0.0
var anchor_x: Variant = null
var sprite_tint := Color.WHITE
var flip_deadband := 0.3
var foot_y := 0.0
var animation_fps := 1.0
var idle_fps := 1.0
var attack_after_frame_sec := 0.1
var frame_row := 0
var frame_column := 0
var flip_h := false
var using_fallback := true
var show_shadow := true
var shadow_size := SHADOW_SIZE
var fallback_radius := 18.0
var fallback_color := Color("#b18cff")
var fallback_outline := Color("#eee6ff")
var _animation_elapsed := 0.0
var _animation_row := -1
var _pose_moving := false
var _using_idle := false
var _walk_frame_column := 0
var motion_values: Dictionary = {}
var motion_transform := Transform2D.IDENTITY
var _motion_clock := 0.0
var _visual_cast_active := false
var _lunge_remaining := 0.0
var _lunge_direction := Vector2.RIGHT
var basic_step_remaining := 0.0
var basic_step_direction := Vector2.RIGHT
var basic_step_px := 0.0
var basic_step_sec := 0.1

func configure(record: Dictionary, radius: float, color: Color, outline: Color) -> void:
	motion_values.clear()
	for key in ["Bob_px","Step_hz","Squash","Tilt_deg","Breath"]:
		if record.get(key)!=null: motion_values[key] = float(record[key])
	motion_transform = Transform2D.IDENTITY
	_motion_clock = 0.0
	_visual_cast_active = false
	_lunge_remaining = 0.0
	var presentation: Dictionary = load("res://scripts/shadow_afterimage.gd").presentation()
	flip_deadband = float(presentation.Flip_deadband)
	idle_texture = null
	_using_idle = false
	_animation_elapsed = 0.0
	_animation_row = -1
	_pose_moving = false
	frame_column = 0
	frame_row = 0
	_walk_frame_column = 0
	flip_h = false
	anchor_x = record.get("Sprite_anchor_x")
	sprite_tint = Color(String(record.Sprite_tint)) if record.get("Sprite_tint")!=null else Color.WHITE
	shadow_size = Vector2(float(record.Shadow_w) if record.get("Shadow_w")!=null else SHADOW_SIZE.x,float(record.Shadow_h) if record.get("Shadow_h")!=null else SHADOW_SIZE.y)
	fallback_radius = radius
	fallback_color = color
	fallback_outline = outline
	layout = String(record.get("Sprite_layout","dir3"))
	columns = int(record.get("Sprite_cols",1))
	rows = int(record.get("Sprite_rows",1))
	cell_height = float(record.get("Sprite_cell_height",0.0))
	baseline = float(record.get("Sprite_baseline",0.0))
	foot_y = float(record.get("Sprite_foot_y",0.0))
	animation_fps = float(record.get("Anim_fps",1.0))
	idle_fps = float(record.get("Idle_fps",animation_fps) if record.get("Idle_fps")!=null else animation_fps)
	attack_after_frame_sec = float(record.get("Attack_after_frame_sec",0.1) if record.get("Attack_after_frame_sec")!=null else 0.1)
	var path := String(record.get("Sprite_path","")).strip_edges()
	if path.is_empty():
		_use_fallback("Sprite_path가 비어 있어 원형 표시를 사용합니다.")
		return
	if not ResourceLoader.exists(path,"Texture2D"):
		_use_fallback("Sprite_path 파일이 없어 원형 표시를 사용합니다: "+path)
		return
	var loaded: Resource = texture if texture!=null and texture.resource_path==path else ResourceLoader.load(path,"Texture2D",ResourceLoader.CACHE_MODE_REUSE)
	if not (loaded is Texture2D) or not (layout in ["dir3","state3","walk1","walk_shoot","pose"]) or columns<1 or rows<1 or cell_height<=0 or animation_fps<=0 or idle_fps<=0 or attack_after_frame_sec<=0:
		_use_fallback("스프라이트 설정을 읽을 수 없어 원형 표시를 사용합니다: "+path)
		return
	texture = loaded
	using_fallback = false
	if record.has("Idle_sprite_path") and layout!="pose":
		var idle_path := String(record.get("Idle_sprite_path","")).strip_edges()
		if idle_path.is_empty() or not ResourceLoader.exists(idle_path,"Texture2D"):
			print("ART-03 경고: Idle_sprite_path가 비었거나 파일이 없어 이동 시트 첫 칸을 사용합니다: "+idle_path)
		else:
			var loaded_idle := ResourceLoader.load(idle_path,"Texture2D")
			if loaded_idle is Texture2D:
				idle_texture = loaded_idle
				_using_idle = true
			else:
				print("ART-03 경고: Idle_sprite_path를 이미지로 읽을 수 없어 이동 시트 첫 칸을 사용합니다: "+idle_path)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()

func configure_snapshot(snapshot: Dictionary) -> void:
	motion_transform = snapshot.get("motion_transform",Transform2D.IDENTITY)
	flip_deadband = float(snapshot.get("flip_deadband",0.3))
	anchor_x = snapshot.get("anchor_x")
	sprite_tint = snapshot.get("sprite_tint",Color.WHITE)
	shadow_size = snapshot.get("shadow_size",SHADOW_SIZE)
	texture = snapshot.get("texture") as Texture2D
	layout = String(snapshot.get("layout","dir3"))
	columns = int(snapshot.get("columns",1))
	rows = int(snapshot.get("rows",1))
	cell_height = float(snapshot.get("cell_height",0.0))
	baseline = float(snapshot.get("baseline",0.0))
	foot_y = float(snapshot.get("foot_y",0.0))
	animation_fps = float(snapshot.get("animation_fps",1.0))
	idle_fps = float(snapshot.get("idle_fps",animation_fps))
	attack_after_frame_sec = float(snapshot.get("attack_after_frame_sec",0.1))
	frame_row = int(snapshot.get("frame_row",0))
	frame_column = int(snapshot.get("frame_column",0))
	flip_h = bool(snapshot.get("flip_h",false))
	using_fallback = bool(snapshot.get("using_fallback",texture==null))
	fallback_radius = float(snapshot.get("fallback_radius",18.0))
	fallback_color = Color(snapshot.get("fallback_color",Color("#b18cff")))
	fallback_outline = Color(snapshot.get("fallback_outline",Color("#eee6ff")))
	show_shadow = bool(snapshot.get("show_shadow",false))
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()

func pose_snapshot() -> Dictionary:
	return {
		"motion_transform":step_transform()*motion_transform,
		"texture":texture,"layout":layout,"columns":columns,"rows":rows,"cell_height":cell_height,
		"baseline":baseline,"foot_y":foot_y,"animation_fps":animation_fps,
		"anchor_x":anchor_x,"sprite_tint":sprite_tint,
		"flip_deadband":flip_deadband,
		"idle_fps":idle_fps,"attack_after_frame_sec":attack_after_frame_sec,
		"frame_row":frame_row,"frame_column":frame_column,"flip_h":flip_h,
		"using_fallback":using_fallback,"fallback_radius":fallback_radius,
		"shadow_size":shadow_size,
		"fallback_color":fallback_color,"fallback_outline":fallback_outline,"show_shadow":false,
	}

func advance_pose(direction: Vector2, moving: bool, delta: float) -> void:
	if layout=="pose":
		update_movement_flip(direction)
		var normalized := direction.normalized()
		frame_row = 0
		frame_column = 1 if moving and columns>1 and normalized.y < -flip_deadband and absf(normalized.y)>absf(normalized.x) else 0
		advance_pose_motion(moving,delta)
		return
	if direction!=Vector2.ZERO:
		if absf(direction.x)>absf(direction.y):
			frame_row = 2
			update_movement_flip(direction)
		else:
			frame_row = 0 if direction.y>0.0 else 1
			flip_h = false
	var state_changed := moving!=_pose_moving
	_pose_moving = moving
	_using_idle = not moving and idle_texture!=null
	if state_changed:
		_animation_elapsed = 0.0
		frame_column = 0
	elif moving:
		_animation_elapsed += maxf(0.0,delta)
		frame_column = floori(_animation_elapsed*animation_fps)%maxi(1,columns)
	elif idle_texture!=null:
		_animation_elapsed += maxf(0.0,delta)
		frame_column = floori(_animation_elapsed*idle_fps)%maxi(1,columns)
	else:
		_animation_elapsed = 0.0
		frame_column = 0
	queue_redraw()

func advance_state_pose(direction: Vector2, moving: bool, delta: float) -> void:
	if layout=="pose":
		advance_shadow_pose(direction,moving,delta,false,direction)
		return
	update_movement_flip(direction)
	var next_row := 1 if moving else 0
	if _animation_row!=next_row:
		_animation_row = next_row
		_animation_elapsed = 0.0
	frame_row = next_row
	_animation_elapsed += maxf(0.0,delta)
	var fps := animation_fps if moving else idle_fps
	frame_column = floori(_animation_elapsed*fps)%maxi(1,columns)
	queue_redraw()

func set_attack_pose(direction: Vector2, column: int) -> void:
	if direction.x<0.0: flip_h = true
	elif direction.x>0.0: flip_h = false
	_animation_row = 2
	_animation_elapsed = 0.0
	frame_row = 2
	frame_column = clampi(column,0,maxi(0,columns-1))
	queue_redraw()

func advance_walk_pose(direction: Vector2, moving: bool, delta: float, keep_facing: bool = false) -> void:
	if not keep_facing:
		update_movement_flip(direction)
	frame_row = 0
	if layout=="pose":
		frame_column = 0
		advance_pose_motion(moving,delta)
		return
	_animation_elapsed = _animation_elapsed+maxf(delta,0.0) if moving else 0.0
	frame_column = floori(_animation_elapsed*animation_fps)%maxi(columns,1) if moving else 0
	_walk_frame_column = frame_column
	queue_redraw()

func set_shoot_pose(remaining: float, release_age: float, enabled: bool) -> void:
	if layout=="pose":
		frame_row = 0
		frame_column = 1 if enabled and columns>1 and (release_age<0.15-0.000000001 or remaining<=0.3+0.000000001) else 0
		queue_redraw()
		return
	frame_row = 0
	frame_column = _walk_frame_column
	if enabled:
		if release_age<0.2-0.000000001:
			frame_row = 1
			frame_column = 2 if release_age<0.1-0.000000001 else 3
		elif remaining<=0.3+0.000000001:
			frame_row = 1
			frame_column = 0 if remaining>0.15+0.000000001 else 1
	queue_redraw()

func advance_shadow_pose(direction: Vector2, moving: bool, delta: float, attacking: bool, attack_direction: Vector2) -> void:
	if attacking:
		if attack_direction.x<0: flip_h = true
		elif attack_direction.x>0: flip_h = false
	else: update_movement_flip(direction)
	frame_row = 0
	frame_column = 1 if attacking and columns>1 else 0
	advance_pose_motion(moving,delta,attacking,attack_direction)

func advance_pose_motion(moving: bool, delta: float, attacking: bool = false, attack_direction: Vector2 = Vector2.RIGHT) -> void:
	basic_step_remaining = maxf(0,basic_step_remaining-maxf(delta,0))
	_motion_clock += maxf(delta,0.0)
	var began := attacking and not _visual_cast_active
	if began:
		_lunge_remaining = 0.1
		_lunge_direction = attack_direction.normalized()
	else: _lunge_remaining = maxf(0.0,_lunge_remaining-maxf(delta,0.0))
	_visual_cast_active = attacking
	motion_transform = Transform2D.IDENTITY
	if motion_values.is_empty():
		queue_redraw()
		return
	var wave := sin(_motion_clock*TAU*float(motion_values.get("Step_hz",0.0))) if moving else 0.0
	var bounce := absf(wave)
	var squash := float(motion_values.get("Squash",0.0))*bounce
	var stretch := Vector2(1.0+squash,1.0-squash)
	var offset := Vector2(0,-float(motion_values.get("Bob_px",0.0))*bounce)
	if not moving: stretch.y += float(motion_values.get("Breath",0.0))*sin(_motion_clock*TAU)
	if _lunge_remaining>0:
		var impulse := _lunge_remaining/0.1
		offset += _lunge_direction*4.0*impulse
		stretch *= Vector2(1.0+0.1*impulse,1.0-0.1*impulse)
	var angle := deg_to_rad(float(motion_values.get("Tilt_deg",0.0)))*wave
	motion_transform = Transform2D(angle,stretch,0.0,Vector2.ZERO)
	var pivot := Vector2(0,foot_y)
	motion_transform.origin = pivot+offset-motion_transform*pivot
	queue_redraw()

func update_movement_flip(direction: Vector2) -> void:
	var normalized := direction.normalized()
	if absf(normalized.x)>flip_deadband:
		flip_h = normalized.x<0.0

func source_rect() -> Rect2:
	var shown := current_texture()
	if shown==null:
		return Rect2()
	var frame_size := Vector2(shown.get_width()/float(columns),shown.get_height()/float(rows))
	return Rect2(Vector2(frame_column,frame_row)*frame_size,frame_size)

func current_texture() -> Texture2D:
	if _using_idle and idle_texture!=null:
		return idle_texture
	return texture

func display_rect() -> Rect2:
	var source := source_rect()
	if source.size.y<=0.0:
		return Rect2()
	var scale_factor := cell_height/source.size.y
	var size := source.size*scale_factor
	var horizontal := float(anchor_x) if anchor_x!=null else source.size.x*0.5
	return Rect2(Vector2(-horizontal*scale_factor,foot_y-baseline*scale_factor),size)

func _use_fallback(message: String) -> void:
	texture = null
	using_fallback = true
	print("ART-01 경고: "+message)
	queue_redraw()

func _draw() -> void:
	if show_shadow: draw_ground_shadow(self,shadow_size)
	if using_fallback or texture==null:
		draw_circle(Vector2.ZERO,fallback_radius,fallback_color)
		draw_arc(Vector2.ZERO,fallback_radius,0.0,TAU,48,fallback_outline,2.0)
		return
	var destination := display_rect()
	draw_set_transform_matrix(image_transform())
	draw_texture_rect_region(current_texture(),destination,source_rect(),sprite_tint,false,true)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func image_transform() -> Transform2D:
	return step_transform()*motion_transform*Transform2D(Vector2(-1 if flip_h else 1,0),Vector2(0,1),Vector2.ZERO)

func step_transform() -> Transform2D:
	return Transform2D(0,basic_step_direction*basic_step_px*basic_step_remaining/maxf(basic_step_sec,0.000001))

func trigger_basic_step(direction: Vector2, px: float, seconds: float) -> void:
	basic_step_direction = direction.normalized()
	basic_step_px = px
	basic_step_sec = seconds
	basic_step_remaining = seconds
	queue_redraw()

func advance_player_skill_pose(direction: Vector2, moving: bool, delta: float, fear: bool, dash: bool, slash: bool, dash_direction: Vector2, settings: Dictionary) -> void:
	advance_pose(direction,moving,delta)
	if layout!="pose" or columns<5 or not (fear or dash or slash): return
	frame_row = 0
	frame_column = 4 if fear else (2 if dash else 3)
	if dash and not fear:
		if dash_direction.x<0: flip_h = true
		elif dash_direction.x>0: flip_h = false
	var angle := sin(_motion_clock*TAU*float(settings.get("Slash_pose_hz",12)))*deg_to_rad(float(settings.get("Slash_pose_tilt_deg",5))) if slash and not fear and not dash else sin(_motion_clock*TAU)*deg_to_rad(float(settings.get("Skill_pose_sway_deg",1)))
	var offset := Vector2(0,-float(settings.get("Fear_pose_float_px",4))*absf(sin(_motion_clock*PI))) if fear else Vector2.ZERO
	motion_transform = Transform2D(angle,Vector2.ZERO)
	var pivot := Vector2(0,foot_y)
	motion_transform.origin = pivot+offset-motion_transform*pivot
	queue_redraw()

static func draw_ground_shadow(canvas: CanvasItem, size: Vector2) -> void:
	var settings: Dictionary = load("res://scripts/shadow_afterimage.gd").presentation()
	var color := Color(String(settings.get("Shadow_color","#46506e")))
	var alpha := float(settings.get("Shadow_alpha",0.45))
	var layers := maxi(1,int(settings.get("Shadow_layers",8)))
	color.a = 1.0-pow(1.0-alpha,1.0/layers)
	canvas.draw_set_transform(Vector2.ZERO,0.0,Vector2(1.0,size.y/size.x))
	for i in range(layers):
		canvas.draw_circle(Vector2.ZERO,size.x*0.5*(1.0-float(settings.get("Shadow_softness",0.35))*float(i)/maxi(1,layers-1)),color)
	canvas.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
