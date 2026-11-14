extends Node2D
class_name SpriteBody

const SHADOW_SIZE := Vector2(32.0,12.0)
const SHADOW_COLOR := Color(0.0,0.0,0.0,0.35)

var texture: Texture2D
var layout := "dir3"
var columns := 1
var rows := 1
var cell_height := 0.0
var baseline := 0.0
var foot_y := 0.0
var animation_fps := 1.0
var idle_fps := 1.0
var attack_after_frame_sec := 0.1
var frame_row := 0
var frame_column := 0
var flip_h := false
var using_fallback := true
var show_shadow := true
var fallback_radius := 18.0
var fallback_color := Color("#b18cff")
var fallback_outline := Color("#eee6ff")
var _animation_elapsed := 0.0
var _animation_row := -1

func configure(record: Dictionary, radius: float, color: Color, outline: Color) -> void:
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
	var loaded := ResourceLoader.load(path,"Texture2D")
	if not (loaded is Texture2D) or not (layout in ["dir3","state3"]) or columns<1 or rows<1 or cell_height<=0 or animation_fps<=0 or idle_fps<=0 or attack_after_frame_sec<=0:
		_use_fallback("스프라이트 설정을 읽을 수 없어 원형 표시를 사용합니다: "+path)
		return
	texture = loaded
	using_fallback = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()

func configure_snapshot(snapshot: Dictionary) -> void:
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
		"texture":texture,"layout":layout,"columns":columns,"rows":rows,"cell_height":cell_height,
		"baseline":baseline,"foot_y":foot_y,"animation_fps":animation_fps,
		"idle_fps":idle_fps,"attack_after_frame_sec":attack_after_frame_sec,
		"frame_row":frame_row,"frame_column":frame_column,"flip_h":flip_h,
		"using_fallback":using_fallback,"fallback_radius":fallback_radius,
		"fallback_color":fallback_color,"fallback_outline":fallback_outline,"show_shadow":false,
	}

func advance_pose(direction: Vector2, moving: bool, delta: float) -> void:
	if direction!=Vector2.ZERO:
		if absf(direction.x)>absf(direction.y):
			frame_row = 2
			flip_h = direction.x<0.0
		else:
			frame_row = 0 if direction.y>0.0 else 1
			flip_h = false
	if moving:
		_animation_elapsed += maxf(0.0,delta)
		frame_column = floori(_animation_elapsed*animation_fps)%maxi(1,columns)
	else:
		_animation_elapsed = 0.0
		frame_column = 0
	queue_redraw()

func advance_state_pose(direction: Vector2, moving: bool, delta: float) -> void:
	if direction.x<0.0: flip_h = true
	elif direction.x>0.0: flip_h = false
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

func source_rect() -> Rect2:
	if texture==null:
		return Rect2()
	var frame_size := Vector2(texture.get_width()/float(columns),texture.get_height()/float(rows))
	return Rect2(Vector2(frame_column,frame_row)*frame_size,frame_size)

func display_rect() -> Rect2:
	var source := source_rect()
	if source.size.y<=0.0:
		return Rect2()
	var scale_factor := cell_height/source.size.y
	var size := source.size*scale_factor
	return Rect2(Vector2(-size.x*0.5,foot_y-baseline*scale_factor),size)

func _use_fallback(message: String) -> void:
	texture = null
	using_fallback = true
	print("ART-01 경고: "+message)
	queue_redraw()

func _draw() -> void:
	if using_fallback or texture==null:
		draw_circle(Vector2.ZERO,fallback_radius,fallback_color)
		draw_arc(Vector2.ZERO,fallback_radius,0.0,TAU,48,fallback_outline,2.0)
		return
	if show_shadow:
		draw_set_transform(Vector2.ZERO,0.0,Vector2(1.0,SHADOW_SIZE.y/SHADOW_SIZE.x))
		draw_circle(Vector2.ZERO,SHADOW_SIZE.x*0.5,SHADOW_COLOR)
		draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
	var destination := display_rect()
	if flip_h:
		draw_set_transform(Vector2.ZERO,0.0,Vector2(-1.0,1.0))
		destination.position.x = -destination.end.x
	draw_texture_rect_region(texture,destination,source_rect(),Color.WHITE,false,true)
	if flip_h:
		draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
