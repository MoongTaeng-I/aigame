extends RefCounted

const Hud = preload("res://scripts/temporary_hud.gd")
const ShadowData = preload("res://scripts/shadow_data.gd")
var t: SceneTree

func run(tree: SceneTree) -> void:
	t = tree
	var before: int = t.checks
	var failed: int = t.failures
	for pair in [[0,"00:00"],[59,"00:59"],[60,"01:00"],[599,"09:59"],[3600,"60:00"],[6000,"100:00"],[360001,"6000:01"]]:
		t.check(Hud.format_elapsed(float(pair[0]))==pair[1],"S8-B elapsed format "+str(pair))
	var scene: Node = load("res://main.tscn").instantiate()
	t.root.add_child(scene)
	var map: Node = scene.get_child(0)
	for child in map.get_children():
		child.set_physics_process(false)
	var manager: EnemyManager = map.get_node("EnemyManager")
	var d: Node2D = manager.boss_director
	var hud: CanvasLayer = map.get_node("TemporaryHud")
	var shadows: Node2D = map.get_node("ShadowManager")
	var skills: Node2D = map.get_node("SkillManager")
	manager._elapsed_seconds = 0
	await t.process_frame
	hud.refresh()
	t.check(hud.timer_label.anchor_left==1 and hud.timer_label.anchor_right==1 and hud.timer_label.horizontal_alignment==HORIZONTAL_ALIGNMENT_RIGHT,"S8-B timer anchored at top right")
	t.check(manager._count_label.position==Vector2(20,140),"S8-B existing top-left enemy counter retained")
	t.check(d.toast_view.panel is PanelContainer and d.toast_view.panel.anchor_left==0.5 and d.toast_view.panel.anchor_right==0.5,"S8-B toast is top-center anchored panel")
	var panel_style: StyleBoxFlat = d.toast_view.panel.get_theme_stylebox("panel")
	t.check(panel_style.corner_radius_top_left>0 and panel_style.border_width_left>0 and panel_style.bg_color.a<1,"S8-B toast rounded dark translucent panel with border")
	t.check(d.toast.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER and d.toast.vertical_alignment==VERTICAL_ALIGNMENT_CENTER,"S8-B centered toast text")
	t.check(not contains_bar(d.toast_view),"S8-B toast contains no old bar/ProgressBar node")
	t.check(absf(d.toast_view.panel.get_global_rect().get_center().x-d.toast_view.get_viewport_rect().size.x/2)<1,"S8-B toast panel centered in viewport")
	d.timeline = [{"Id":"hud_event","Time_mmss":0,"Boss_id":"boss_middle"}]
	manager._physics_process(0)
	t.check(d.toast_view.visible and d.toast.text.contains("아이스 베어 우두머리") and not d.toast.text.contains("{name}"),"S8-B warning shows panel and substitutes CSV boss name")
	t.check(is_zero_approx(d.toast_view.entries[0].panel.modulate.a),"S8-B fade in begins transparent")
	manager._physics_process(0.2)
	t.check(is_equal_approx(d.toast_view.entries[0].panel.modulate.a,1),"S8-B short fade in reaches full opacity")
	manager._physics_process(1.8)
	t.check(d.phase=="emerge" and d.toast_view.visible,"S8-B toast stays through emergence")
	manager._physics_process(1.4)
	t.check(d.toast_view.visible and d.toast_view.entries[0].panel.modulate.a>0 and d.toast_view.entries[0].panel.modulate.a<1,"S8-B short fade out before emergence ends")
	manager._physics_process(0.1)
	t.check(d.phase=="active" and not d.toast_view.visible,"S8-B toast hidden when boss becomes active")
	var store: CsvDataStore = t._store()
	t.check(store.load_all().is_empty() and ShadowData.validate(store).is_empty(),"S8-B real shadow schema with Name_ko/Icon loads and validates")
	t.check(store.get_row("shadow.csv","igrit").Name_ko=="이그리트" and store.get_row("shadow.csv","igrit").Icon==null,"S8-B actual igrit name and optional empty Path loaded")
	t.check(store.get_row("shadow.csv","charger_test").Name_ko=="베르","S8-B actual beru display name loaded")
	t.check(hud.entries.is_empty(),"S8-B empty roster before summon")
	var a: Node2D = shadows.summon("igrit")
	var b: Node2D = shadows.summon("charger_test")
	t.check(hud.entries.size()==2 and hud.entries[0].name=="이그리트" and hud.entries[1].name=="베르","S8-B real summon signals update roster in summon order")
	t.check(hud.entries[0].fallback and hud.entries[1].fallback and hud.entries[0].icon is Control,"S8-B empty icons use shadow visual portrait nodes")
	t.check(not hud.entries[0].icon.dash_shape and hud.entries[1].icon.dash_shape,"S8-B fallback uses actual fan/dash body pose distinction")
	hud.refresh()
	var last_box: Rect2 = skills.ui.card_rect(3)
	t.check(hud.roster.position.y+hud.ROSTER_CARD.y<last_box.position.y and absf(hud.roster.position.x+hud.roster.size.x-last_box.end.x)<1,"S8-B roster is one row right-aligned above skill icons")
	a.free()
	t.check(hud.entries.size()==1 and hud.entries[0].Id=="charger_test","S8-B actual removal signal updates roster")
	shadows.records.igrit = shadows.records.igrit.duplicate(true)
	shadows.records.igrit.Name_ko = "이름 열 확인"
	shadows.records.igrit.Icon = "res://icon.svg"
	a = shadows.summon("igrit")
	t.check(hud.entries[1].name=="이름 열 확인","S8-B roster reads Name_ko rather than hardcoded names")
	t.check(not hud.entries[1].fallback and hud.entries[1].icon is TextureRect and hud.entries[1].icon.texture is Texture2D,"S8-B valid image path is rendered as TextureRect")
	store.tables["shadow.csv"].igrit.Icon = "res://icon.svg"
	t.check(ShadowData.validate(store).is_empty(),"S8-B valid texture Icon validates")
	store.tables["shadow.csv"].igrit.Icon = "res://missing-shadow-icon.png"
	var error := ShadowData.validate(store)
	t.check(error.contains("Icon") and error.contains("shadow.csv"),"S8-B nonexistent Icon path produces field error")
	store.tables["shadow.csv"].igrit.Icon = "res://scripts/shadow_visual.gd"
	t.check(ShadowData.validate(store).contains("Icon"),"S8-B non-image resource Icon rejected")
	var csv_text := FileAccess.get_file_as_string("res://data/shadow.csv")
	var bad_store: CsvDataStore = t._store()
	t.check(bad_store.load_text("shadow.csv",csv_text.replace(",이그리트,",",이그리트,not-a-resource-path")).contains("Icon"),"S8-B malformed Path rejected by common converter")
	await changed_boss_values(manager,d,store)
	manager._elapsed_seconds = 599
	hud.refresh()
	manager.set_physics_process(true)
	manager._player.add_experience(manager._player.get_xp_to_next())
	var time: float = manager._elapsed_seconds
	var label: String = hud.timer_label.text
	await t.process_frame
	await t.process_frame
	t.check(t.paused and map.get_node("ChoiceManager").active and manager._elapsed_seconds==time and hud.timer_label.text==label and label=="09:59","S8-B real level-up selection pause freezes shared elapsed time and label")
	t.paused = false
	manager._player.apply_damage(manager._player.hp)
	await t.process_frame
	await t.process_frame
	t.check(t.paused and manager._elapsed_seconds==time and hud.timer_label.text==label,"S8-B real player death also freezes shared timer")
	t.paused = false
	manager.set_physics_process(false)
	scene.queue_free()
	await t.process_frame
	var icon_store: CsvDataStore = t._store()
	var loaded: String = icon_store.load_all()
	icon_store.get_row("shadow.csv","igrit").Icon = "res://missing-shadow-icon.png"
	var icon_error: String = ShadowData.validate(icon_store)
	var icon_scene: Node = load("res://main.tscn").instantiate()
	t.root.add_child(icon_scene)
	# Only the intentional synchronous push_error is muted. Startup and checks
	# retain normal error reporting; production error UI is called unchanged.
	var printing: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	icon_scene._show_data_error(icon_error)
	Engine.print_error_messages = printing
	var label_matches := false
	for error_label in icon_scene.find_children("*","Label",true,false):
		if error_label.text=="데이터 오류\n\n"+icon_error: label_matches = true
	var state := {"loaded":loaded.is_empty(),"message":icon_error,"paused":t.paused,"label_matches":label_matches}
	t.check(state.loaded,"S8-B Icon same-process real data load succeeds")
	t.check(state.message.contains("열 Icon"),"S8-B Icon same-process field error message")
	t.check(state.paused,"S8-B Icon same-process error UI pauses tree")
	t.check(state.label_matches,"S8-B Icon same-process real error label matches")
	var raw := FileAccess.open("res://.local/art-06-icon-state.json",FileAccess.WRITE)
	raw.store_string(JSON.stringify(state))
	raw.close()
	t.paused = false
	t.root.remove_child(icon_scene)
	icon_scene.free()
	for frame in range(4): await t.process_frame
	print("S8-B NEW RESULT: %d checks, %d failures" % [t.checks-before,t.failures-failed])

func contains_bar(node: Node) -> bool:
	if node is ProgressBar: return true
	for child in node.get_children():
		if contains_bar(child): return true
	return false

func changed_boss_values(manager: EnemyManager, d: Node2D, store: CsvDataStore) -> void:
	var boss: Variant = d.actor
	var basic := store.get_row("boss_action.csv","ice_bear_basic")
	var dash := store.get_row("boss_action.csv","ice_bear_dash")
	var slam := store.get_row("boss_action.csv","ice_bear_slam")
	t.check(basic.Range==150 and basic.Use_range==140 and dash.Dash_speed==1000 and slam.Slam_radius==320 and slam.Telegraph_sec==0.8 and slam.Use_range==240,"S8-B all six approved actual boss CSV values")
	boss.global_position = Vector2.ZERO
	boss.clock = manager._elapsed_seconds
	manager._player.global_position = Vector2(149,0)
	manager._player.configure_combat(10000,t._attack())
	boss.start_action(basic,manager._player.global_position)
	t.check(boss.telegraph_geometry().range==150,"S8-B real basic geometry reads increased CSV radius")
	manager._elapsed_seconds+=0.4
	boss.boss_tick(0)
	t.check(manager._player.hp==9988,"S8-B basic actually hits beyond old radius using new radius")
	boss.clock = manager._elapsed_seconds
	boss.global_position = Vector2.ZERO
	boss.start_action(dash,Vector2(300,0))
	manager._elapsed_seconds+=0.8
	boss.boss_tick(0)
	manager._elapsed_seconds+=0.1
	boss.boss_tick(0)
	t.check(absf(boss.global_position.x-100)<0.01,"S8-B actual dash travels 100 pixels per 0.1 sec from new speed")
	boss.clock = manager._elapsed_seconds
	boss.global_position = Vector2.ZERO
	manager._player.global_position = Vector2(319,0)
	boss.start_action(slam,manager._player.global_position)
	var hp: int = manager._player.hp
	t.check(boss.telegraph_geometry().slam_radius==320 and is_equal_approx(boss.phase_end-boss.clock,0.8),"S8-B actual slam geometry and telegraph read doubled radius and new cast time")
	manager._elapsed_seconds+=0.79
	boss.boss_tick(0)
	t.check(manager._player.hp==hp,"S8-B slam waits until new cast time")
	manager._elapsed_seconds+=0.01
	boss.boss_tick(0)
	t.check(manager._player.hp==hp-30,"S8-B slam hits within new radius at new cast time")
