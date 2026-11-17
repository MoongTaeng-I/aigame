extends Node2D
class_name SpriteBody
var redraw_state: Array = []
var redraw_frame := -1
var presentation_transform := Transform2D.IDENTITY
var presentation_alpha := 1.0

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
var show_image := true
var shadow_size := SHADOW_SIZE
var fallback_radius := 18.0
var fallback_color := Color("#b18cff")
var fallback_outline := Color("#eee6ff")
var _animation_elapsed := 0.0
var _animation_row := -1
var _pose_moving := false
var _using_idle := false
var _walk_frame_column := 0
var walk_cols := Vector2i(-1,-1)
var walk_back_cols := Vector2i(-1,-1)
var walk_fps := 0.0
var _pose_walk_elapsed := 0.0
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
var windup_offset := Vector2.ZERO
var locomotion_transform := Transform2D.IDENTITY
var _lean := 0.0
var _was_moving := false
var _was_flip := false
var _start_left := 0.0
var _stop_left := 0.0
var _turn_left := 0.0
var hit_squash_left := 0.0
var lean_max := 0.0
var lean_sec := 0.12
var start_sec := 0.08
var start_scale := Vector2.ONE
var stop_sec := 0.1
var stop_scale := Vector2.ONE
var turn_sec := 0.08
var turn_scale_x := 1.0
var hit_squash_sec := 0.08
var hit_squash_scale := Vector2.ONE
var dust_every := 0
var _dust_contacts := 0
var _last_walk_column := -1

func configure(record: Dictionary, radius: float, color: Color, outline: Color) -> void:
	motion_values.clear()
	for key in ["Bob_px","Step_hz","Squash","Tilt_deg","Breath"]:
		if record.get(key)!=null: motion_values[key] = float(record[key])
	motion_transform = Transform2D.IDENTITY
	_motion_clock = 0.0
	_visual_cast_active = false
	_lunge_remaining = 0.0
	var presentation: Dictionary = load("res://scripts/shadow_afterimage.gd").compiled_presentation()
	cache_locomotion(presentation)
	prepare_ground_shadow(presentation)
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
	sprite_tint = Color(record.Sprite_tint) if record.get("Sprite_tint")!=null else Color.WHITE
	shadow_size = Vector2(float(record.Shadow_w) if record.get("Shadow_w")!=null else SHADOW_SIZE.x,float(record.Shadow_h) if record.get("Shadow_h")!=null else SHADOW_SIZE.y)
	fallback_radius = radius
	fallback_color = color
	fallback_outline = outline
	layout = String(record.get("Sprite_layout","dir3"))
	columns = int(record.get("Sprite_cols",1))
	rows = int(record.get("Sprite_rows",1))
	configure_walk(record)
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
	request_redraw()

func configure_snapshot(snapshot: Dictionary) -> void:
	prepare_ground_shadow(load("res://scripts/shadow_afterimage.gd").compiled_presentation())
	presentation_transform = snapshot.get("presentation_transform",Transform2D.IDENTITY)
	presentation_alpha = float(snapshot.get("presentation_alpha",1.0))
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
	request_redraw()

func pose_snapshot() -> Dictionary:
	return {
		"motion_transform":step_transform()*locomotion_transform*motion_transform,"presentation_transform":presentation_transform,"presentation_alpha":presentation_alpha,
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
		var idle_column := 1 if moving and columns>1 and normalized.y < -flip_deadband and absf(normalized.y)>absf(normalized.x) else 0
		frame_column = pose_walk_column(idle_column,moving,delta)
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
	request_redraw()

func advance_state_pose(direction: Vector2, moving: bool, delta: float) -> void:
	delta *= float(get_viewport().get_meta(&"fx05_visual_scale",1.0)) if is_inside_tree() else 1.0
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
	request_redraw()

func set_attack_pose(direction: Vector2, column: int) -> void:
	if direction.x<0.0: flip_h = true
	elif direction.x>0.0: flip_h = false
	_animation_row = 2
	_animation_elapsed = 0.0
	frame_row = 2
	frame_column = clampi(column,0,maxi(0,columns-1))
	request_redraw()

func advance_walk_pose(direction: Vector2, moving: bool, delta: float, keep_facing: bool = false) -> void:
	if not keep_facing:
		update_movement_flip(direction)
	frame_row = 0
	if layout=="pose":
		frame_column = pose_walk_column(0,moving,delta)
		_walk_frame_column = frame_column
		advance_pose_motion(moving,delta)
		return
	_animation_elapsed = _animation_elapsed+maxf(delta,0.0) if moving else 0.0
	frame_column = floori(_animation_elapsed*animation_fps)%maxi(columns,1) if moving else 0
	_walk_frame_column = frame_column
	request_redraw()

func set_shoot_pose(remaining: float, release_age: float, enabled: bool) -> void:
	if layout=="pose":
		frame_row = 0
		frame_column = 1 if enabled and columns>1 and (release_age<0.15-0.000000001 or remaining<=0.3+0.000000001) else _walk_frame_column
		request_redraw()
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
	request_redraw()

func advance_shadow_pose(direction: Vector2, moving: bool, delta: float, attacking: bool, attack_direction: Vector2) -> void:
	if attacking:
		if attack_direction.x<0: flip_h = true
		elif attack_direction.x>0: flip_h = false
	else: update_movement_flip(direction)
	frame_row = 0
	var walking_column := pose_walk_column(0,moving,delta)
	frame_column = 1 if attacking and columns>1 else walking_column
	advance_pose_motion(moving,delta,attacking,attack_direction)

func configure_walk(record: Dictionary) -> void:
	walk_cols = Vector2i(-1,-1)
	walk_back_cols = Vector2i(-1,-1)
	walk_fps = 0.0
	_pose_walk_elapsed = 0.0
	if layout!="pose" or record.get("Walk_cols")==null or String(record.Walk_cols).strip_edges().is_empty(): return
	var pattern := RegEx.new()
	pattern.compile("^[0-9]+-[0-9]+$")
	var parsed: Array[Vector2i] = []
	for key in ["Walk_cols","Walk_back_cols"]:
		var text := String(record[key]).strip_edges() if record.get(key)!=null else ""
		if text.is_empty():
			parsed.append(Vector2i(-1,-1))
			continue
		if pattern.search(text)==null:
			print("ART-13 warning: invalid ",key,"=",text,"; using existing pose")
			return
		var parts := text.split("-")
		var first := int(parts[0])
		var last := int(parts[1])
		if first<0 or first>last or last>=columns:
			print("ART-13 warning: out-of-bounds ",key,"=",text,"; using existing pose")
			return
		parsed.append(Vector2i(first,last))
	var fps := float(record.get("Walk_fps",0.0)) if record.get("Walk_fps")!=null else 0.0
	if not is_finite(fps) or fps<=0:
		print("ART-13 warning: invalid Walk_fps; using existing pose")
		return
	walk_cols = parsed[0]
	walk_back_cols = parsed[1]
	walk_fps = fps

func pose_walk_column(idle_column: int, moving: bool, delta: float) -> int:
	delta *= float(get_viewport().get_meta(&"fx05_visual_scale",1.0)) if is_inside_tree() else 1.0
	if not moving:
		_pose_walk_elapsed = 0.0
		_last_walk_column = -1
	if layout!="pose" or walk_cols.x<0 or not moving: return idle_column
	_pose_walk_elapsed += maxf(0,delta)
	var span := walk_back_cols if idle_column==1 and walk_back_cols.x>=0 else walk_cols
	var column := span.x+floori((_pose_walk_elapsed+0.000000001)*walk_fps)%(span.y-span.x+1)
	if dust_every>0 and column!=_last_walk_column and (column==span.x or column==span.x+floori((span.y-span.x+1)*0.5)):
		_dust_contacts += 1
		if _dust_contacts%dust_every==0:
			var dust := preload("res://scripts/motion_dust.gd").find(self)
			if dust!=null: dust.emit(to_global(Vector2(0,foot_y)))
	_last_walk_column = column
	return column

# Boss-only explicit pose path; existing player/shadow/enemy selection is unchanged.
func advance_explicit_pose(column: int, direction: Vector2, moving: bool, delta: float, locked_facing: bool) -> void:
	if locked_facing:
		if direction.x<0: flip_h = true
		elif direction.x>0: flip_h = false
	else: update_movement_flip(direction)
	var entering_strike := column==2 and frame_column!=2
	frame_row = 0
	frame_column = clampi(column,0,maxi(columns-1,0))
	# The existing 4px lunge fires on entry to column2, including repeated casts.
	_visual_cast_active = not entering_strike and column==2
	advance_pose_motion(moving,delta,column==2,direction)

func advance_pose_motion(moving: bool, delta: float, attacking: bool = false, attack_direction: Vector2 = Vector2.RIGHT) -> void:
	delta *= float(get_viewport().get_meta(&"fx05_visual_scale",1.0)) if is_inside_tree() else 1.0
	basic_step_remaining = maxf(0,basic_step_remaining-maxf(delta,0))
	if hit_squash_left>0:
		hit_squash_left = maxf(0,hit_squash_left-maxf(delta,0))
		update_locomotion_transform()
	_motion_clock += maxf(delta,0.0)
	var began := attacking and not _visual_cast_active
	if began:
		_lunge_remaining = 0.1
		_lunge_direction = attack_direction.normalized()
	else: _lunge_remaining = maxf(0.0,_lunge_remaining-maxf(delta,0.0))
	_visual_cast_active = attacking
	motion_transform = Transform2D.IDENTITY
	if motion_values.is_empty():
		request_redraw()
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
	request_redraw()

func advance_frozen_walk_time(moving: bool, delta: float) -> void:
	if not moving: _pose_walk_elapsed = 0
	elif layout=="pose" and walk_cols.x>=0: _pose_walk_elapsed += maxf(0,delta)

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
	request_redraw()

func _draw() -> void:
	if show_shadow: draw_ground_shadow(self,shadow_size)
	if not show_image: return
	if using_fallback or texture==null:
		draw_circle(Vector2.ZERO,fallback_radius,fallback_color)
		draw_arc(Vector2.ZERO,fallback_radius,0.0,TAU,48,fallback_outline,2.0)
		return
	var destination := display_rect()
	draw_set_transform_matrix(image_transform())
	draw_texture_rect_region(current_texture(),destination,source_rect(),Color(sprite_tint,sprite_tint.a*presentation_alpha),false,true)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func image_transform() -> Transform2D:
	return presentation_transform*step_transform()*locomotion_transform*motion_transform*Transform2D(Vector2(-1 if flip_h else 1,0),Vector2(0,1),Vector2.ZERO)

func step_transform() -> Transform2D:
	return Transform2D(0,basic_step_direction*basic_step_px*basic_step_remaining/maxf(basic_step_sec,0.000001)+windup_offset)

func cache_locomotion(settings: Dictionary) -> void:
	lean_max = deg_to_rad(float(settings.get("Move_lean_deg",6)))
	lean_sec = maxf(float(settings.get("Move_lean_sec",0.12)),0.000001)
	start_sec = maxf(float(settings.get("Move_start_sec",0.08)),0.000001)
	start_scale = Vector2(float(settings.get("Move_start_scale_x",1.06)),float(settings.get("Move_start_scale_y",0.94)))
	stop_sec = maxf(float(settings.get("Move_stop_sec",0.1)),0.000001)
	stop_scale = Vector2(float(settings.get("Move_stop_scale_x",0.96)),float(settings.get("Move_stop_scale_y",1.04)))
	turn_sec = maxf(float(settings.get("Move_turn_sec",0.08)),0.000001)
	turn_scale_x = float(settings.get("Move_turn_scale_x",0.92))
	hit_squash_sec = maxf(float(settings.get("Enemy_hit_squash_sec",0.08)),0.000001)
	hit_squash_scale = Vector2(float(settings.get("Enemy_hit_squash_x",1.1)),float(settings.get("Enemy_hit_squash_y",0.9)))
	dust_every = int(settings.get("Move_dust_npc_every",2))
	_dust_contacts = 0
	_last_walk_column = -1
	_lean = 0.0
	_was_moving = false
	_was_flip = false
	_start_left = 0.0
	_stop_left = 0.0
	_turn_left = 0.0
	hit_squash_left = 0.0
	windup_offset = Vector2.ZERO
	locomotion_transform = Transform2D.IDENTITY

# Player-only artwork deformation; position, speed and collision stay untouched.
func advance_locomotion(direction: Vector2, moving: bool, delta: float, dashing: bool = false) -> void:
	delta = maxf(delta*(float(get_viewport().get_meta(&"fx05_visual_scale",1.0)) if is_inside_tree() else 1.0),0)
	if dashing:
		_start_left = 0
		_stop_left = 0
		_turn_left = 0
		_was_flip = flip_h
	elif moving and not _was_moving:
		_start_left = start_sec
		_stop_left = 0
	elif not moving and _was_moving:
		_stop_left = stop_sec
		_start_left = 0
	_was_moving = moving
	if not dashing and flip_h!=_was_flip:
		_was_flip = flip_h
		_turn_left = turn_sec
	_start_left = maxf(0,_start_left-delta)
	_stop_left = maxf(0,_stop_left-delta)
	_turn_left = maxf(0,_turn_left-delta)
	var target := lean_max*clampf(direction.normalized().x,-1,1) if moving else 0.0
	_lean = move_toward(_lean,target,lean_max*delta/lean_sec)
	update_locomotion_transform()

func trigger_hit_squash() -> void:
	hit_squash_left = hit_squash_sec
	update_locomotion_transform()

func update_locomotion_transform() -> void:
	var stretch := Vector2.ONE
	if _start_left>0: stretch *= Vector2.ONE.lerp(start_scale,_start_left/start_sec)
	if _stop_left>0: stretch *= Vector2.ONE.lerp(stop_scale,_stop_left/stop_sec)
	if _turn_left>0: stretch.x *= lerpf(1,turn_scale_x,_turn_left/turn_sec)
	if hit_squash_left>0: stretch *= Vector2.ONE.lerp(hit_squash_scale,hit_squash_left/hit_squash_sec)
	var deformation := Transform2D(_lean,stretch,0,Vector2.ZERO)
	var pivot := Vector2(0,foot_y)
	deformation.origin = pivot-deformation*pivot
	locomotion_transform = deformation
	request_redraw()

func apply_dash_stretch(direction: Vector2, dashing: bool, landing: float, settings: Dictionary) -> void:
	if not dashing and landing<=0: return
	var stretch := Vector2(float(settings.get("Dash_stretch_x",1.25)),float(settings.get("Dash_stretch_y",0.9)))
	if not dashing:
		stretch = Vector2.ONE.lerp(Vector2(1/stretch.x,1/stretch.y),clampf(landing/maxf(float(settings.get("Dash_land_sec",0.08)),0.000001),0,1))
	var rotation_axis := Transform2D(direction.angle(),Vector2.ZERO)
	var deformation := rotation_axis*Transform2D(0,stretch,0,Vector2.ZERO)*rotation_axis.affine_inverse()
	var pivot := Vector2(0,foot_y)
	deformation.origin = pivot-deformation*pivot
	motion_transform = deformation*motion_transform
	request_redraw()

func trigger_basic_step(direction: Vector2, px: float, seconds: float) -> void:
	basic_step_direction = direction.normalized()
	basic_step_px = px
	basic_step_sec = seconds
	basic_step_remaining = seconds
	request_redraw()

func advance_player_skill_pose(direction: Vector2, moving: bool, delta: float, fear: bool, dash: bool, slash: bool, dash_direction: Vector2, settings: Dictionary, slash_column: int = 3) -> void:
	advance_pose(direction,moving,delta)
	if layout!="pose" or columns<5 or not (fear or dash or slash): return
	frame_row = 0
	frame_column = 4 if fear else (2 if dash else clampi(slash_column,0,columns-1))
	if dash and not fear:
		if dash_direction.x<0: flip_h = true
		elif dash_direction.x>0: flip_h = false
	var angle := sin(_motion_clock*TAU*float(settings.get("Slash_pose_hz",12)))*deg_to_rad(float(settings.get("Slash_pose_tilt_deg",5))) if slash and not fear and not dash else sin(_motion_clock*TAU)*deg_to_rad(float(settings.get("Skill_pose_sway_deg",1)))
	var offset := Vector2(0,-float(settings.get("Fear_pose_float_px",4))*absf(sin(_motion_clock*PI))) if fear else Vector2.ZERO
	motion_transform = Transform2D(angle,Vector2.ZERO)
	var pivot := Vector2(0,foot_y)
	motion_transform.origin = pivot+offset-motion_transform*pivot
	request_redraw()

static func prepare_ground_shadow(settings: Dictionary) -> void:
	var signature := [settings.get("Shadow_color",Color("#46506e")),settings.get("Shadow_alpha",0.45),settings.get("Shadow_layers",8),settings.get("Shadow_softness",0.35)]
	if Engine.get_meta(&"ground_shadow_signature",[])==signature: return
	var image := Image.create(128,128,false,Image.FORMAT_RGBA8)
	var layers := maxi(1,int(signature[2]))
	var layer_alpha := 1.0-pow(1.0-float(signature[1]),1.0/layers)
	var color := Color(signature[0])
	for y in range(128):
		for x in range(128):
			var radius := Vector2((x+0.5)/64.0-1,(y+0.5)/64.0-1).length()
			var count := 0
			for i in range(layers):
				if radius<=1.0-float(signature[3])*i/maxi(1,layers-1): count+=1
			image.set_pixel(x,y,Color(color,1.0-pow(1.0-layer_alpha,count)))
	image.generate_mipmaps()
	Engine.set_meta(&"ground_shadow_texture",ImageTexture.create_from_image(image))
	Engine.set_meta(&"ground_shadow_signature",signature)

static func draw_ground_shadow(canvas: CanvasItem, size: Vector2) -> void:
	var texture: Texture2D = Engine.get_meta(&"ground_shadow_texture") if Engine.has_meta(&"ground_shadow_texture") else null
	if texture!=null: canvas.draw_texture_rect(texture,Rect2(-size*0.5,size),false)

func request_redraw() -> void:
	var state := [presentation_transform,presentation_alpha,texture,idle_texture,frame_row,frame_column,columns,rows,cell_height,baseline,anchor_x,foot_y,flip_h,_using_idle,motion_transform,locomotion_transform,windup_offset,basic_step_direction,basic_step_px,basic_step_remaining,show_shadow,show_image,sprite_tint,shadow_size,using_fallback,fallback_radius,fallback_color,fallback_outline]
	if state==redraw_state: return
	redraw_state = state
	if redraw_frame==Engine.get_process_frames(): return
	redraw_frame = Engine.get_process_frames()
	queue_redraw()
