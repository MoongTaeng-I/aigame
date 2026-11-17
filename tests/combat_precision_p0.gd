extends RefCounted

const Geometry = preload("res://scripts/combat_geometry.gd")
const Toast = preload("res://scripts/boss_toast.gd")
var t: SceneTree
var baruka: RefCounted
var elf: RefCounted

func run(tree: SceneTree) -> void:
	t = tree
	var before: int = t.checks
	var failures: int = t.failures
	baruka = preload("res://tests/baruka_boss_p0.gd").new()
	baruka.t = t
	baruka.base = preload("res://tests/boss_p0.gd").new()
	baruka.base.t = t
	baruka.store = t._store()
	t.check(baruka.store.load_all().is_empty(),"S8-I3-C real CSV load")
	baruka.base.store = baruka.store
	elf = preload("res://tests/elf_boss_p0.gd").new()
	elf.t = t
	elf.helper = baruka.base
	elf.store = baruka.store
	data_and_imports()
	await dash_checks()
	await blink_checks()
	await flee_checks()
	await player_checks()
	await toast_checks()
	print("S8-IMPL-03-C NEW RESULT: %d checks, %d failures" % [t.checks-before,t.failures-failures])

func data_and_imports() -> void:
	for pair in [["baruka_blink","Strike_interval_sec",0.04],["baruka_blink","Area_radius",894.4],["baruka_blink","Dash_speed",8064],["baruka_blink","Strike_count",20],["baruka_basic","Dash_speed",1560],["baruka_basic","Cooldown_sec",0.63],["ice_elf_basic","Flee_distance",100]]:
		t.check(is_equal_approx(float(baruka.store.get_row("boss_action.csv",pair[0])[pair[1]]),float(pair[2])),"S8-I3-C exact fixed value "+pair[0]+"."+pair[1])
	var attack: Dictionary = baruka.store.get_row("basic_attack.csv","attack_01")
	t.check(float(attack.Tri_width_ratio)==0.381 and attack.Range==90,"S8-I3-C ratio and unchanged range")
	t.check(baruka.store.get_row("combat_presentation.csv","Blink_trail_count").Value=="8","S8-I3-C eight trail data")
	var files := DirAccess.get_files_at("res://data")
	for file in files:
		if not file.ends_with(".csv"): continue
		var config := ConfigFile.new()
		var loaded := config.load("res://data/"+file+".import")
		t.check(loaded==OK and config.get_value("remap","importer","")=="keep" and config.get_value("remap","type","")=="TextFile" and config.get_value("deps","source_file","")=="res://data/"+file and config.get_value("deps","dest_files",[])==["res://data/"+file],"S8-I3-C CSV keep import "+file)

func dash_checks() -> void:
	for id in ["baruka_basic","baruka_blink","baruka_chase"]:
		for outside in [false,true]:
			var f: Dictionary = baruka.fixture()
			var b: Variant = f.boss
			b.body_radius = 43.0
			f.player.configure_body(13.0,3.0)
			f.player.global_position = Vector2(500,0)
			baruka.start(f,id)
			baruka.step(f,float(b.current.Telegraph_sec))
			var midpoint: Vector2 = b.origin.lerp(b.dash_end,0.5)
			f.player.global_position = midpoint+b.facing.orthogonal()*(56.01 if outside else 55.99)
			var hp: int = f.player.hp
			var damage: int = b.current.Damage
			var duration: float = b.dash_length/float(b.current.Dash_speed)
			baruka.step(f,duration)
			t.check(f.player.hp==hp-(0 if outside else damage),"S8-I3-C swept whole frame actual43+13 radius boundary "+id+str(outside))
			baruka.step(f,0)
			t.check(f.player.hp==hp-(0 if outside else damage),"S8-I3-C same movement never repeats damage "+id+str(outside))
			await baruka.base.cleanup(f)
	# Hit the path, then move into the still-pending arrival triangle.
	var f: Dictionary = baruka.fixture()
	var b: Variant = f.boss
	f.player.global_position = Vector2(250,0)
	baruka.start(f,"baruka_basic")
	baruka.step(f,0.23)
	f.player.global_position = Vector2(40,0)
	var hp: int = f.player.hp
	# BAL-02: speed 2340 -> 1560, so the same 46.8px of travel takes 0.03s instead of 0.02s.
	baruka.step(f,0.03)
	t.check(b.dash_hit and f.player.hp==hp-15 and b.is_boss_dashing(),"S8-I3-C basic path damages before arrival")
	f.player.global_position = Vector2(250,0)
	baruka.step(f,160.0/1560.0-0.03)
	t.check(f.player.hp==hp-15 and b.current.is_empty(),"S8-I3-C path and arrival share a single hit")
	await baruka.base.cleanup(f)
	f = baruka.fixture()
	b = f.boss
	f.player.global_position = Vector2(250,0)
	baruka.start(f,"baruka_basic")
	hp = f.player.hp
	baruka.step(f,1)
	t.check(f.player.hp==hp-15,"S8-I3-C missed path still hits arrival triangle")
	await baruka.base.cleanup(f)
	for id in ["baruka_basic","baruka_blink","baruka_chase"]:
		f = baruka.fixture()
		b = f.boss
		b.global_position = Vector2(1960,1960)
		f.player.global_position = Vector2(3000,3000)
		baruka.start(f,id)
		baruka.step(f,10)
		var bounds: Rect2 = b.map_bounds.grow(-b.body_radius)
		t.check(b.global_position.x<=bounds.end.x and b.global_position.y<=bounds.end.y and b.global_position.x>=bounds.position.x and b.global_position.y>=bounds.position.y,"S8-I3-C high speed stays inside map "+id)
		await baruka.base.cleanup(f)

func blink_checks() -> void:
	var paths: Array = []
	for player_position in [Vector2(50,0),Vector2(-700,900)]:
		var f: Dictionary = baruka.fixture()
		var b: Variant = f.boss
		b.rng.seed = 735
		f.player.global_position = player_position
		baruka.start(f,"baruka_blink")
		baruka.step(f,10)
		var v: Variant = b.baruka
		paths.append(v.destinations.duplicate())
		t.check(v.strike_index==20 and v.trails.size()==160,"S8-I3-C twenty moves times eight trails")
		var origin := Vector2.ZERO
		for i in range(20):
			var end: Vector2 = v.destinations[i]
			for j in range(8):
				t.check(v.trails[i*8+j].global_position.is_equal_approx(origin.lerp(end,(j+1)/8.0)),"S8-I3-C trail equally spaced %d/%d" % [i,j])
			origin = end
		await baruka.base.cleanup(f)
	t.check(paths[0]==paths[1],"S8-I3-C all20 destinations ignore player location")

func flee_checks() -> void:
	for pair in [[Vector2(-1972,0),Vector2(-1900,0)],[Vector2(-1972,0),Vector2(-1900,-100)],[Vector2(-1972,-1972),Vector2(-1900,-1900)],[Vector2.ZERO,Vector2(150,0)]]:
		var f: Dictionary = elf.fixture()
		elf.disable_skills(f)
		f.boss.global_position = pair[0]
		f.player.global_position = pair[1]
		var start: Vector2 = f.boss.global_position
		elf.step(f,0)
		var e: Variant = f.boss.elf
		var turns := 0
		var direction: Vector2 = e.flee_direction
		for i in range(30):
			if not e.fleeing: break
			elf.step(f,0.02)
			if e.flee_direction!=direction: turns+=1
			direction = e.flee_direction
		t.check(not e.fleeing and (f.boss.global_position==start or f.boss.global_position.distance_to(pair[1])>start.distance_to(pair[1])),"S8-I3-C wall/diagonal/corner/open ends farther or skips "+str(start)+str(pair[1]))
		t.check(e.flee_travelled<=100.000001 and e.flee_reselections<=1 and turns==0,"S8-I3-C bounded distance and no direction oscillation")
		await baruka.base.cleanup(f)
	# External displacement introduces a new wall after the initial choice.
	var f: Dictionary = elf.fixture()
	elf.disable_skills(f)
	f.player.global_position = Vector2(100,0)
	elf.step(f,0)
	f.boss.global_position = Vector2(-1972,0)
	elf.step(f,0.1)
	var e: Variant = f.boss.elf
	t.check(e.flee_reselections==1 and e.fleeing and e.flee_direction.x==0,"S8-I3-C new wall allows exactly one reselection")
	f.boss.global_position.y = -1972 if e.flee_direction.y<0 else 1972
	elf.step(f,0.1)
	t.check(not e.fleeing and e.flee_reselections==1 and e.flee_travelled<=100,"S8-I3-C second wall ends without another turn")
	await baruka.base.cleanup(f)

func player_checks() -> void:
	for angle in [0.0,PI/2,PI,PI/4,-PI/3]:
		var f: Dictionary = t._fixture()
		f.player.configure_combat(100,baruka.store.get_row("basic_attack.csv","attack_01"))
		var direction := Vector2.RIGHT.rotated(angle)
		var base: Vector2 = direction*f.player.body_radius
		var side := direction.orthogonal()
		var target: EnemyActor = t._spawn(f,direction*70,20)
		var inside: EnemyActor = t._spawn(f,base+direction*45+side*(34.29/4-0.01))
		var outside: EnemyActor = t._spawn(f,base+direction*45+side*(34.29/4+0.01))
		f.player.update_basic_attack(0,[target,inside,outside])
		t.check(target.hp==10 and inside.hp==90 and outside.hp==100,"S8-I3-C rotated narrow34.29 boundary "+str(angle))
		var polygons: Array = f.host.get_children().filter(func(n: Node) -> bool: return n is Polygon2D and n.visible)
		var expected := Geometry.triangle_points(base,direction,90,34.29)
		var same := polygons.size()==1
		if same:
			for i in range(3): same = same and polygons[0].polygon[i].is_equal_approx(expected[i])
		t.check(same,"S8-I3-C displayed and hit geometry share exact snapshot "+str(angle))
		t.check(polygons[0].get_child(0).wait_time==0.2,"S8-I3-C visual lifetime Hit_effect_sec")
		f.player.update_basic_attack(0.15,[])
		t.check(f.player._remaining_hits==0 and f.host.get_children().filter(func(n: Node) -> bool: return n is Polygon2D and n.visible).size()==1,"S8-I3-C skipped second hit emits no triangle")
		await baruka.base.cleanup(f)
	var f: Dictionary = t._fixture()
	f.player.configure_combat(100,baruka.store.get_row("basic_attack.csv","attack_01"))
	f.player.presentation = f.player.presentation.duplicate()
	f.player.presentation.Basic_fx_enabled = "0" # Retain old node-deletion coverage on the supported legacy renderer.
	f.player.apply_choice_modifiers(30,0,0)
	var target: EnemyActor = t._spawn(f,Vector2(110,0))
	f.player.update_basic_attack(0,[target])
	var polygons: Array = f.host.get_children().filter(func(n: Node) -> bool: return n is Polygon2D and n.visible)
	t.check(is_equal_approx(polygons[0].polygon[0].distance_to(polygons[0].polygon[1]),120*0.381),"S8-I3-C range choice scales width at same ratio")
	await t.create_timer(0.21).timeout
	t.check(not is_instance_valid(polygons[0]),"S8-I3-C triangle removed after effect lifetime")
	await baruka.base.cleanup(f)

func toast_checks() -> void:
	var view := Toast.new()
	t.root.add_child(view)
	view.set_process(false)
	var long_text := "[아이스 엘프 정예병이 나타납니다. 매우 긴 보스 경고 문구의 줄바꿈과 패널 안 표시를 확인합니다.]".repeat(4)
	for i in range(4): view.push_message(long_text+str(i))
	await t.process_frame
	await t.process_frame
	view._refresh()
	await t.process_frame
	for i in range(4):
		var panel: PanelContainer = view.entries[i].panel
		var label: Label = panel.get_child(0)
		print("S8-I3-C toast layout ",panel.size," label=",label.position,"/",label.size," min=",label.get_minimum_size()," lines=",label.get_line_count())
		var border := float(view.presentation.Ui_window_border_px)
		var frame := panel.size-Vector2.ONE*border*2
		t.check(frame.x<=view.size.x-80+0.01 and frame.x>=420 and is_equal_approx(frame.y,Toast.visible_height(view.presentation,label.get_theme_font_size("font_size"))) and label.get_line_count()==1 and label.get_theme_font_size("font_size")>=16,"S8-I3-C toast one line auto width and minimum16px (FIX02 frame 420..screen-80, padded height)")
		t.check(label.position.y>=18 and label.position.y+label.size.y<=panel.size.y-18+0.01 and label.get_minimum_size().y<=label.size.y+0.01,"S8-I3-C long label fits panel padding")
		if i>0:
			t.check(panel.offset_top>=view.entries[i-1].panel.offset_bottom+8,"S8-I3-C actual heights stack without overlap")
	t.check(view.entries[0].text.ends_with("3") and view.entries[3].text.ends_with("0"),"S8-I3-C newest toast on top")
	view.queue_free()
	await t.process_frame
