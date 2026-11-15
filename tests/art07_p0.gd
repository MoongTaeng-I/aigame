extends RefCounted

func run(t: SceneTree) -> void:
	var store: CsvDataStore = t._store()
	t.check(store.load_all().is_empty(),"ART-07 data loads")
	var view := preload("res://scripts/sprite_body.gd").new()
	view.configure(store.get_row("enemy.csv","enemy_01"),16,Color.WHITE,Color.WHITE)
	t.check(view.columns==6 and view.animation_fps==13 and absf(view.display_rect().size.y-72)<=1,"ART-07 six cells 13fps height72")
	for i in range(13):
		view.advance_walk_pose(Vector2.RIGHT,true,0.01/13 if i==0 else 1.0/13)
		t.check(view.frame_column==i%6,"ART-07 six-cell cycle "+str(i))
	for method in ["advance_walk_pose","advance_state_pose"]:
		for sign_x in [-1.0,1.0]:
			view.flip_h = sign_x>0
			for x in [0.0,0.29]:
				view.call(method,Vector2(sign_x*x,sqrt(1-x*x))*17,true,0)
				t.check(view.flip_h==(sign_x>0),"ART-07 normalized deadband retains "+method+str(sign_x)+str(x))
			view.call(method,Vector2(sign_x*0.31,sqrt(1-0.31*0.31))*17,true,0)
			t.check(view.flip_h==(sign_x<0),"ART-07 normalized .31 switches "+method+str(sign_x))
	view.flip_h = false
	view.advance_walk_pose(Vector2.LEFT,true,0,true)
	t.check(not view.flip_h,"ART-07 knockback facing priority")
	for x in [-0.01,0.01]:
		view.set_attack_pose(Vector2(x,1),1)
		t.check(view.flip_h==(x<0) and view.frame_row==2 and view.frame_column==1,"ART-07 attack facing overrides deadband "+str(x))
	var saved: Dictionary = Engine.get_meta(&"combat_presentation").duplicate()
	var custom := saved.duplicate()
	custom.Flip_deadband = "0.8"
	Engine.set_meta(&"combat_presentation",custom)
	view.configure(store.get_row("player.csv","player_01"),8,Color.WHITE,Color.WHITE)
	t.check(view.flip_deadband==0.8,"ART-07 reads deadband CSV cache")
	view.advance_pose(Vector2(-0.75,sqrt(1-0.75*0.75)),true,0)
	t.check(view.frame_row==2 and not view.flip_h,"ART-07 dir3 side retains below CSV band")
	view.advance_pose(Vector2(-0.85,sqrt(1-0.85*0.85)),true,0)
	t.check(view.frame_row==2 and view.flip_h,"ART-07 dir3 side flips above CSV band")
	Engine.set_meta(&"combat_presentation",saved)
	view.free()
	for value in ["-0.1","1.1","NaN","Inf","bad",""]:
		store.get_row("combat_presentation.csv","Flip_deadband").Value = value
		t.check(not CombatData.validate(store).is_empty(),"ART-07 invalid deadband rejected "+value)
	store.get_row("combat_presentation.csv","Flip_deadband").Value = "0.3"
	t.check(CombatData.validate(store).is_empty(),"ART-07 restores valid data")
