extends RefCounted

func make_view(record: Dictionary) -> SpriteBody:
	var view := SpriteBody.new()
	view.configure(record,16,Color.WHITE,Color.WHITE)
	return view

func run(t: SceneTree) -> void:
	var store: CsvDataStore = t._store()
	t.check(store.load_all().is_empty(),"ART13 actual CSV schemas load")
	var row: Dictionary = store.get_row("player.csv","player_01")
	var view := make_view(row)
	t.check(view.texture.get_size()==Vector2(5083,221) and view.columns==23 and view.source_rect().size==Vector2(221,221),"ART14 player23 cells221x221")
	t.check(view.walk_fps==12 and view.motion_values.Bob_px==2 and view.motion_values.Step_hz==1.5 and view.motion_values.Squash==0.03 and view.motion_values.Tilt_deg==1,"ART13 approved walking fps and motion")
	for direction in [Vector2.DOWN,Vector2.RIGHT,Vector2.UP]:
		view.configure(row,16,Color.WHITE,Color.WHITE)
		var start := 13 if direction==Vector2.UP else 5
		var correct := true
		for frame in range(17):
			view.advance_pose(direction,true,0 if frame==0 else 1.0/12)
			correct = correct and view.frame_column==start+frame%8
		t.check(correct,"ART13 eight-frame loop twice "+str(direction))
	view.configure(row,16,Color.WHITE,Color.WHITE)
	view.advance_pose(Vector2.DOWN,true,0.2)
	var elapsed := view._pose_walk_elapsed
	view.advance_pose(Vector2.UP,true,0)
	t.check(view.frame_column==15 and view._pose_walk_elapsed==elapsed,"ART13 front to back keeps leg phase")
	view.advance_pose(Vector2.DOWN,true,0)
	t.check(view.frame_column==7 and view._pose_walk_elapsed==elapsed,"ART13 back to front keeps leg phase")
	view.advance_pose(Vector2.UP,false,0.3)
	t.check(view.frame_column==0 and view._pose_walk_elapsed==0,"ART13 stopped restores original idle rule and resets timer")
	view.advance_pose(Vector2.UP,true,0)
	t.check(view.frame_column==13,"ART13 restart begins first back frame")
	var settings: Dictionary = preload("res://scripts/shadow_afterimage.gd").presentation()
	for flags in [[true,true,true,4],[false,true,true,2],[false,false,true,3]]:
		view.advance_player_skill_pose(Vector2.UP,true,0.2,flags[0],flags[1],flags[2],Vector2.LEFT,settings)
		t.check(view.frame_column==flags[3],"ART13 skill priority over walking "+str(flags))
	view.advance_pose(Vector2.LEFT,true,0)
	view.advance_pose(Vector2(-0.29,sqrt(1-0.29*0.29)),true,0)
	t.check(view.flip_h,"ART13 deadband unchanged during walking")
	var ghost := SpriteBody.new()
	ghost.configure_snapshot(view.pose_snapshot())
	t.check(ghost.frame_column==view.frame_column and ghost.flip_h==view.flip_h and ghost.image_transform()==view.image_transform(),"ART13 afterimage preserves walking frame flip and transform")
	ghost.free()
	var no_back: Dictionary = row.duplicate()
	no_back.Walk_back_cols = null
	view.configure(no_back,16,Color.WHITE,Color.WHITE)
	view.advance_pose(Vector2.UP,true,0.25)
	t.check(view.frame_column==8,"ART13 missing back span uses front walking")
	for bad in ["a-b","5-23","12-5","-1-4","5","5-4294967296"]:
		var invalid: Dictionary = row.duplicate()
		invalid.Walk_cols = bad
		view.configure(invalid,16,Color.WHITE,Color.WHITE)
		view.advance_pose(Vector2.UP,true,0.1)
		t.check(view.walk_cols.x<0 and view.frame_column==1,"ART13 invalid span warns and uses original back pose "+bad)
	var invalid: Dictionary = row.duplicate()
	invalid.Walk_back_cols = "13-23"
	view.configure(invalid,16,Color.WHITE,Color.WHITE)
	view.advance_pose(Vector2.RIGHT,true,0.1)
	t.check(view.frame_column==0,"ART13 invalid back span disables walking safely")
	invalid = row.duplicate()
	invalid.Walk_fps = 0
	view.configure(invalid,16,Color.WHITE,Color.WHITE)
	view.advance_pose(Vector2.RIGHT,true,0.1)
	t.check(view.frame_column==0,"ART13 invalid fps warns and falls back")
	view.configure(row,16,Color.WHITE,Color.WHITE)
	view.advance_walk_pose(Vector2.RIGHT,true,0.25)
	view.set_shoot_pose(1,1,false)
	t.check(view.frame_column==8,"ART13 enemy path supports walking while not shooting")
	view.set_shoot_pose(0.2,1,true)
	t.check(view.frame_column==1,"ART13 enemy attack overrides walking")
	view.configure(row,16,Color.WHITE,Color.WHITE)
	view.advance_shadow_pose(Vector2.RIGHT,true,0.25,false,Vector2.RIGHT)
	t.check(view.frame_column==8,"ART13 shadow path supports walking")
	view.advance_shadow_pose(Vector2.RIGHT,true,0.1,true,Vector2.LEFT)
	t.check(view.frame_column==1 and view.flip_h,"ART13 shadow attack and facing override walking")
	view.free()
	for file in ["enemy.csv","shadow.csv"]:
		for record in store.get_table(file).values():
			if record.Walk_cols!=null: continue # ART14 bear/igrit are covered by their new walking tests.
			var before: Dictionary = record.duplicate()
			for key in ["Walk_cols","Walk_back_cols","Walk_fps"]: before.erase(key)
			var actual := make_view(record)
			var legacy := make_view(before)
			var same: bool = record.Walk_cols==null and record.Walk_back_cols==null and record.Walk_fps==null
			for direction in [Vector2.RIGHT,Vector2.UP,Vector2.LEFT]:
				if file=="enemy.csv":
					actual.advance_walk_pose(direction,true,0.11)
					legacy.advance_walk_pose(direction,true,0.11)
				else:
					actual.advance_shadow_pose(direction,true,0.11,false,direction)
					legacy.advance_shadow_pose(direction,true,0.11,false,direction)
				same = same and actual.frame_column==legacy.frame_column and actual.frame_row==legacy.frame_row and actual.flip_h==legacy.flip_h and actual.motion_transform==legacy.motion_transform
			t.check(same,"ART13 empty walk fields preserve pose motion flip "+record.Id)
			actual.free()
			legacy.free()
