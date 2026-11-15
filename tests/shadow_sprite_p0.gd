extends RefCounted

const HelperScript = preload("res://tests/shadow_summons_p0.gd")

var t: SceneTree

func run(tree: SceneTree) -> void:
	t = tree
	var helper = HelperScript.new()
	helper.t = t
	var f: Dictionary = helper.fixture()
	var legacy: Dictionary = preload("res://tests/legacy_art_records.gd").igrit(f.store.get_row("shadow.csv","igrit"))
	f.store.get_row("shadow.csv","igrit").merge(legacy,true)
	if f.store.get_table("shadow.csv").is_empty():
		await helper.close(f)
		return
	var player_texture := ResourceLoader.load("res://assets/art/player/player_move_sheet.png","Texture2D") as Texture2D
	var player_idle_texture := ResourceLoader.load("res://assets/art/player/player_idle_sheet.png","Texture2D") as Texture2D
	var igris_texture := ResourceLoader.load("res://assets/art/shadow/igris_sheet.png","Texture2D") as Texture2D
	t.check(player_texture!=null and player_idle_texture!=null and player_texture.get_width()==1488 and player_texture.get_height()==1140 and player_idle_texture.get_width()==1488 and player_idle_texture.get_height()==1140,"ART-03 player move and idle sheets are1488x1140")
	t.check(igris_texture!=null and igris_texture.get_width()==1920 and igris_texture.get_height()==1260,"ART-02 Igris sheet is1920x1260")
	t.check(player_texture.get_image().has_mipmaps() and player_idle_texture.get_image().has_mipmaps() and igris_texture.get_image().has_mipmaps(),"ART-03 player sheets and Igris sheet import mipmaps")
	var player_row: Dictionary = preload("res://tests/legacy_art_records.gd").player(f.store.get_row("player.csv","player_01"))
	var player_view := preload("res://scripts/sprite_body.gd").new()
	f.host.add_child(player_view)
	player_view.configure(player_row,16,Color("#b18cff"),Color("#eee6ff"))
	t.check(player_view.layout=="dir3" and absf(player_view.display_rect().size.y-87.0)<=1.0,"ART-03 player keeps dir3 with display height87")
	var igris = f.summons.summon("igrit")
	t.check(igris!=null and igris.sprite_body!=null and igris.sprite_body.layout=="state3","ART-02 production Igris uses state3 sprite body")
	igris.tick(1.0/6.0)
	t.check(igris.sprite_body.frame_row==0 and igris.sprite_body.frame_column==1,"ART-02 idle row loops at Idle_fps6")
	igris.global_position = Vector2(300,0)
	igris.tick(0.125)
	t.check(igris.sprite_body.frame_row==1 and igris.sprite_body.frame_column==1 and igris.sprite_body.flip_h,"ART-02 moving left uses row2 at8fps and flips")
	igris.global_position = Vector2(-300,0)
	igris.tick(0.125)
	t.check(igris.sprite_body.frame_row==1 and not igris.sprite_body.flip_h,"ART-02 moving right clears flip")
	igris.sprite_body.advance_state_pose(Vector2(0,1),true,0.0)
	t.check(not igris.sprite_body.flip_h,"ART-02 zero horizontal movement keeps previous flip")
	var rect: Rect2 = igris.sprite_body.display_rect()
	var source: Rect2 = igris.sprite_body.source_rect()
	var baseline_y := rect.position.y+float(igris.config.Sprite_baseline)*(rect.size.y/source.size.y)
	t.check(absf(rect.size.y-211.0)<=1.0 and is_equal_approx(baseline_y,float(igris.config.Sprite_foot_y)),"ART-04 Igris display height211 and baseline meets foot offset")
	igris.global_position = Vector2.ZERO
	igris.motion_picker = func(_size: int) -> int: return 0
	var enemy = t._spawn(f,Vector2(100,0),100)
	igris.tick(0.0)
	t.check(igris.cast_active and not igris.hit_done and igris.sprite_body.frame_row==2 and igris.sprite_body.frame_column==0 and not igris.sprite_body.flip_h,"ART-02 attack windup holds row3 frame1 toward right")
	var hit_time := float(igris.motions[igris.motion_index].Hit_time_sec)
	igris.tick(hit_time)
	t.check(igris.hit_done and enemy.hp==90 and igris.sprite_body.frame_row==2 and igris.sprite_body.frame_column==1,"ART-02 actual hit moment deals original damage and shows row3 frame2")
	igris.tick(0.05)
	t.check(igris.sprite_body.frame_column==2,"ART-02 first after-hit interval shows frame3")
	igris.tick(0.10)
	t.check(igris.sprite_body.frame_column==3,"ART-02 second after-hit interval shows frame4")
	igris.tick(0.06)
	t.check(igris.sprite_body.frame_row==0,"ART-02 attack frames return to idle while original cast timing continues")
	igris.sprite_body.set_attack_pose(Vector2.LEFT,3)
	t.check(igris.sprite_body.flip_h,"ART-02 attack direction left flips state3 sheet")
	var copy = f.summons.leave_afterimage(igris.global_position,igris.snapshot(),float(igris.config.Afterimage_sec))
	t.check(copy.sprite_body!=null and copy.sprite_body.frame_row==2 and copy.sprite_body.frame_column==3 and copy.sprite_body.flip_h and not copy.sprite_body.show_shadow,"ART-02 Igris departure afterimage preserves frame and flip without ground shadow")
	var charger = f.summons.summon("charger_test")
	t.check(charger!=null and charger.sprite_body!=null and charger.snapshot().kind=="charger_test","ART-05 Ber uses connected sprite with unchanged internal kind")
	var charger_copy = f.summons.leave_afterimage(charger.global_position,charger.snapshot(),float(charger.config.Afterimage_sec))
	charger.queue_redraw()
	charger_copy.queue_redraw()
	await t.process_frame
	t.check(charger_copy.sprite_body!=null,"ART-05 Ber afterimage uses captured sprite pose")
	await helper.close(f)
