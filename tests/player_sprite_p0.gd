extends RefCounted

const SpriteBodyScript = preload("res://scripts/sprite_body.gd")
const AfterimageScript = preload("res://scripts/shadow_afterimage.gd")

var t: SceneTree
var store: CsvDataStore

func run(tree: SceneTree) -> void:
	t = tree
	store = t._store()
	var error := store.load_all()
	t.check(error.is_empty(),"ART-01 actual sprite data loads: "+error)
	if not error.is_empty(): return
	await actual_sheet()
	await fallback_paths()

func make_view(record: Dictionary) -> Node2D:
	var view := SpriteBodyScript.new()
	t.root.add_child(view)
	view.configure(record,16.0,Color("#b18cff"),Color("#eee6ff"))
	return view

func actual_sheet() -> void:
	var record: Dictionary = store.get_row("player.csv","player_01")
	var view = make_view(record)
	t.check(not view.using_fallback and view.texture!=null and view.idle_texture!=null and view.columns==4 and view.rows==3,"ART-03 separate4x3 move and idle sheets connect")
	t.check(view.texture.get_width()==1488 and view.texture.get_height()==1140 and view.idle_texture.get_width()==1488 and view.idle_texture.get_height()==1140,"ART-03 both player sheets are1488x1140")
	t.check(view.texture.get_image().has_mipmaps() and view.idle_texture.get_image().has_mipmaps(),"ART-03 both texture imports generate mipmaps")
	t.check(view.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"ART-01 player uses linear mipmap filter")
	view.advance_pose(Vector2.DOWN,true,1.0)
	t.check(view.current_texture()==view.texture and view.frame_column==0,"ART-03 moving state starts move sheet at frame1")
	var directions := [
		[Vector2.DOWN,0,false,"down"],[Vector2.UP,1,false,"up"],
		[Vector2.RIGHT,2,false,"right"],[Vector2.LEFT,2,true,"left"],
		[Vector2(1,1),0,false,"down diagonal tie"],[Vector2(-1,-1),1,false,"up diagonal tie"],
		[Vector2(2,1),2,false,"right dominant diagonal"],[Vector2(-2,1),2,true,"left dominant diagonal"],
	]
	for item in directions:
		view.advance_pose(item[0],true,0.0)
		t.check(view.frame_row==item[1] and view.flip_h==item[2],"ART-01 direction row and flip "+String(item[3]))
	view.advance_pose(Vector2.LEFT,true,1.0/12.0)
	t.check(view.frame_column==1 and view.current_texture()==view.texture,"ART-03 moving animation advances at12fps on move sheet")
	view.advance_pose(Vector2.ZERO,false,1.0)
	t.check(view.frame_row==2 and view.flip_h and view.frame_column==0 and view.current_texture()==view.idle_texture,"ART-03 stop keeps direction and starts idle sheet at frame1")
	view.advance_pose(Vector2.ZERO,false,1.0/6.0)
	t.check(view.frame_column==1 and view.current_texture()==view.idle_texture,"ART-03 stopped or movement-locked pose loops idle sheet at6fps")
	view.advance_pose(Vector2.RIGHT,true,1.0)
	t.check(view.frame_column==0 and view.current_texture()==view.texture,"ART-03 idle-to-move switch restarts move sheet at frame1")
	var rect: Rect2 = view.display_rect()
	var source: Rect2 = view.source_rect()
	var baseline_y := rect.position.y+float(record.Sprite_baseline)*(rect.size.y/source.size.y)
	t.check(absf(rect.size.y-87.0)<=1.0 and is_equal_approx(baseline_y,float(record.Sprite_foot_y)),"ART-03 display cell height87 and baseline meets foot offset")
	var afterimage := AfterimageScript.new()
	t.root.add_child(afterimage)
	afterimage.configure({"kind":"player","radius":16.0,"sprite_pose":view.pose_snapshot()},0.3,0.45)
	t.check(afterimage.sprite_body!=null and afterimage.sprite_body.texture==view.texture and afterimage.sprite_body.frame_row==2 and afterimage.sprite_body.frame_column==0 and not afterimage.sprite_body.flip_h,"ART-03 dash afterimage preserves move-sheet frame and flip")
	view.queue_free()
	afterimage.queue_free()
	await t.process_frame

func fallback_paths() -> void:
	var base: Dictionary = store.get_row("player.csv","player_01").duplicate(true)
	for value in ["","res://assets/art/player/not_found_idle.png"]:
		var idle_record := base.duplicate(true)
		idle_record.Idle_sprite_path = value
		var idle_view = make_view(idle_record)
		idle_view.advance_pose(Vector2.LEFT,true,0.0)
		idle_view.advance_pose(Vector2.ZERO,false,1.0)
		t.check(not idle_view.using_fallback and idle_view.texture!=null and idle_view.idle_texture==null and idle_view.current_texture()==idle_view.texture and idle_view.frame_column==0,"ART-03 empty or missing idle sheet holds move sheet frame1 without crash: "+value)
		idle_view.queue_free()
		await t.process_frame
	for value in ["","res://assets/art/player/not_found.png"]:
		var record := base.duplicate(true)
		record.Sprite_path = value
		var view = make_view(record)
		view.queue_redraw()
		await t.process_frame
		t.check(view.using_fallback and view.texture==null,"ART-01 empty or missing path falls back to circle without crash: "+value)
		view.queue_free()
		await t.process_frame
