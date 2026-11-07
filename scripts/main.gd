extends Node2D

const CsvDataStore = preload("res://scripts/csv_data_store.gd")
const MapScene = preload("res://scenes/map.tscn")
const PlayerScene = preload("res://scenes/player.tscn")

func _ready() -> void:
	_configure_window()
	var data_store = CsvDataStore.new()
	data_store.register_schema("player.csv", {
		"Id": "String",
		"Name_ko": "String",
		"Move_speed": "Float",
		"Note": "String",
	})
	var load_error: String = data_store.load_all()
	if not load_error.is_empty():
		_show_data_error(load_error)
		return
	var player_record: Dictionary = data_store.get_row("player.csv", "player_01")
	if player_record.is_empty():
		_show_data_error("res://data/player.csv, 행 1, 열 Id: 플레이어 ID player_01이 없습니다.")
		return
	var map = MapScene.instantiate()
	add_child(map)
	var player = PlayerScene.instantiate()
	player.move_speed = float(player_record["Move_speed"])
	map.add_child(player)
	player.position = Vector2.ZERO

func _configure_window() -> void:
	var window := get_window()
	window.title = "나 혼자만 서바이벌"
	window.mode = Window.MODE_WINDOWED
	window.unresizable = true
	window.size = Vector2i(1280, 720)

func _show_data_error(message: String) -> void:
	push_error(message)
	get_tree().paused = true
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var background := ColorRect.new()
	background.color = Color("#111018")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)
	var label := Label.new()
	label.text = "데이터 오류\n\n" + message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("#ff7b83"))
	label.add_theme_font_size_override("font_size", 24)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 32
	label.offset_top = 32
	label.offset_right = -32
	label.offset_bottom = -32
	layer.add_child(label)
