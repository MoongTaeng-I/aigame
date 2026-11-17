extends Node2D

const Main = preload("res://scripts/main.gd")
const Hud = preload("res://scripts/temporary_hud.gd")
var state := "loading"
var data_store: CsvDataStore
var ui: Control
var session: Node2D
var region_index := 0
var regions: Array = []
var best_times: Dictionary = {}
var result: Dictionary = {}
var load_progress := 0.0
var loading_started := 0
var loading_elapsed := 0.0
var loading_minimum := 0.0
var data_error := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	preload("res://scripts/audio_events.gd").music(self,"bgm_title")
	var window := get_window()
	window.title = "나 혼자만 서바이벌"
	window.mode = Window.MODE_WINDOWED
	window.unresizable = true
	window.size = Vector2i(1280,720)
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	ui = preload("res://scripts/flow_ui.gd").new()
	ui.configure(self)
	layer.add_child(ui)
	loading_started = Time.get_ticks_msec()
	call_deferred("_load_data")

func _load_data() -> void:
	data_store = CsvDataStore.new()
	preload("res://scripts/combat_data.gd").register_schemas(data_store)
	var plan := data_store.prepare_load()
	if not String(plan.error).is_empty():
		fail_loading(plan.error)
		return
	var completed := 0
	# The last work unit is cross-table validation, not an artificial time-based fill.
	for file_name in plan.files:
		var error := data_store._load_file(file_name)
		if not error.is_empty():
			fail_loading(error)
			return
		completed+=1
		set_load_progress(float(completed)/(plan.files.size()+1))
		await get_tree().process_frame
		if not is_inside_tree(): return
	var error := validate_loaded_data()
	if not error.is_empty():
		fail_loading(error)
		return
	loading_minimum = float(data_store.get_row("combat_presentation.csv","Loading_sec").Value)
	preload("res://scripts/shadow_afterimage.gd").cache_presentation(data_store.get_table("combat_presentation.csv"))
	set_load_progress(1)
	while (Time.get_ticks_msec()-loading_started)/1000.0<loading_minimum:
		await get_tree().process_frame
		if not is_inside_tree(): return
		show_load_progress()
	show_load_progress()
	loading_elapsed = (Time.get_ticks_msec()-loading_started)/1000.0
	regions = data_store.get_table("region.csv").values()
	regions.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return String(a.Id)<String(b.Id))
	# BAL-02: the shadow cover starts only after the loading hold has ended; the menu appears under it.
	ui.enter_menu(show_menu)

func validate_loaded_data() -> String:
	var validator := Main.new()
	var error := validator.validate_store(data_store)
	validator.free()
	return error

func set_load_progress(value: float) -> void:
	load_progress = value
	show_load_progress()

# The bar fills over Loading_sec of real time and never runs ahead of the actual load work.
func show_load_progress() -> void:
	var timed := 0.0
	if loading_minimum>0: timed = clampf((Time.get_ticks_msec()-loading_started)/1000.0/loading_minimum,0,1)
	ui.progress.value = minf(load_progress,timed)

func fail_loading(message: String) -> void:
	state = "error"
	data_error = message
	Main.show_data_error(self,message)

func show_menu() -> void:
	var returning := is_instance_valid(session)
	_dispose_round()
	state = "menu"
	preload("res://scripts/audio_events.gd").music(self,"bgm_title")
	result = {}
	ui.close_modal()
	ui.show_screen("menu")
	refresh_region()
	if returning: ui.reveal_stage()

func refresh_region() -> void:
	var row: Dictionary = regions[region_index]
	ui.show_region(row,float(best_times.get(row.Id,-1)))

func change_region(direction: int) -> void:
	if state!="menu" or ui.menu_locked(): return
	region_index = posmod(region_index+direction,regions.size())
	refresh_region()

func locked_hint() -> void:
	if state=="menu" and regions[region_index].Locked:
		ui.notify(String(regions[region_index].Locked_text))

func start_region() -> void:
	if state!="menu" and state!="result": return
	if regions[region_index].Locked:
		locked_hint()
		return
	_dispose_round()
	state = "playing"
	preload("res://scripts/audio_events.gd").music(self,"bgm_stage01")
	result = {}
	ui.close_modal()
	ui.show_screen("playing")
	session = load("res://main.tscn").instantiate()
	session.supplied_data = data_store
	session.managed_flow = true
	# Explicitly pausable: the shell itself must still handle UI while paused.
	session.process_mode = Node.PROCESS_MODE_PAUSABLE
	session.round_ended.connect(_on_round_ended)
	add_child(session)
	ui.reveal_stage()

func _dispose_round() -> void:
	if is_instance_valid(session):
		remove_child(session)
		session.free()
	session = null
	get_tree().paused = false
	for action in ["move_up","move_down","move_left","move_right"]: Input.action_release(action)

func _on_round_ended(summary: Dictionary) -> void:
	if state!="playing" and state!="paused": return
	result = summary.duplicate(true)
	var id: String = regions[region_index].Id
	best_times[id] = maxf(float(best_times.get(id,0)),float(result.seconds))
	state = "result"
	ui.show_screen("result")
	var names := ", ".join(result.shadows) if not result.shadows.is_empty() else "-"
	var details := "시간  %s\n레벨  %d\n처치 수  %d\n보유 그림자  %s" % [Hud.format_elapsed(result.seconds),result.level,result.kills,names]
	var actions: Array = [{"text":"확인","call":show_menu}] if result.cleared else [{"text":"다시 하기","call":start_region},{"text":"메인으로","call":show_menu}]
	ui.show_modal("클리어" if result.cleared else "실패",details,actions)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		toggle_pause()

func toggle_pause() -> void:
	if is_instance_valid(session) and session.round_finished: return
	if state=="paused":
		resume()
		return
	if state!="playing" or not is_instance_valid(session) or session.round_nodes.choices.active: return
	state = "paused"
	get_tree().paused = true
	ui.show_modal("일시정지","",[{"text":"계속","call":resume},{"text":"메인으로","call":show_menu}],true)

func resume() -> void:
	if is_instance_valid(session) and session.round_finished: return
	if state!="paused": return
	ui.close_modal()
	ui.queue_redraw()
	state = "playing"
	get_tree().paused = false
