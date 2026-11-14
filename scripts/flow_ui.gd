extends Control

var owner_flow: Node
var screen := "loading"
var progress: ProgressBar
var region_title: Label
var best_label: Label
var locked_label: Label
var start_button: Button
var locked_click: Control
var settings: PanelContainer
var menu_nodes: Array[Control] = []
var loading_nodes: Array[Control] = []
var modal: PanelContainer
var result_text: Label
var hint: Label
var hint_remaining := 0.0
var locked := false

func configure(flow: Node) -> void:
	owner_flow = flow

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := text("나 혼자만\n서바이벌",Rect2(96,218,660,180),58)
	loading_nodes.append(title)
	progress = ProgressBar.new()
	progress.position = Vector2(100,622)
	progress.size = Vector2(1080,8)
	progress.max_value = 1
	progress.show_percentage = false
	add_child(progress)
	loading_nodes.append(progress)
	loading_nodes.append(text("로딩 중…",Rect2(100,647,1080,30),20))
	region_title = text("",Rect2(350,80,580,55),34,true)
	best_label = text("",Rect2(390,470,500,42),24,true)
	locked_label = text("",Rect2(390,424,500,36),22,true)
	start_button = button("게임 시작",Rect2(440,551,400,68),owner_flow.start_region)
	locked_click = Control.new()
	locked_click.position = start_button.position
	locked_click.size = start_button.size
	locked_click.mouse_filter = Control.MOUSE_FILTER_STOP
	locked_click.gui_input.connect(_locked_input)
	add_child(locked_click)
	var left := button("‹",Rect2(275,265,68,68),owner_flow.change_region.bind(-1))
	var right := button("›",Rect2(937,265,68,68),owner_flow.change_region.bind(1))
	var gear := button("⚙",Rect2(1196,24,56,48),toggle_settings)
	settings = PanelContainer.new()
	settings.position = Vector2(1052,82)
	settings.size = Vector2(200,72)
	add_child(settings)
	var quit := Button.new()
	quit.text = "게임 종료"
	quit.pressed.connect(func() -> void: get_tree().quit())
	settings.add_child(quit)
	settings.hide()
	menu_nodes.assign([region_title,best_label,locked_label,start_button,locked_click,left,right,gear])
	hint = text("",Rect2(340,645,600,42),22,true)
	hint.add_theme_color_override("font_color",Color("#cdb4ff"))
	hint.hide()
	show_screen("loading")

func text(value: String, box: Rect2, font_size: int, centered: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.position = box.position
	label.size = box.size
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("#eee7ff"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centered: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	return label

func button(value: String, box: Rect2, action: Callable) -> Button:
	var view := Button.new()
	view.text = value
	view.position = box.position
	view.size = box.size
	view.add_theme_font_size_override("font_size",26)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#493578")
	style.border_color = Color("#9778d4")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	view.add_theme_stylebox_override("normal",style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#614895")
	view.add_theme_stylebox_override("hover",hover)
	view.pressed.connect(action)
	add_child(view)
	return view

func show_screen(value: String) -> void:
	screen = value
	for view in loading_nodes: view.visible = value=="loading"
	for view in menu_nodes: view.visible = value=="menu"
	if value!="menu": settings.hide()
	locked_click.visible = value=="menu" and locked
	if value!="menu": hint.hide()
	queue_redraw()

func show_region(row: Dictionary, best: float) -> void:
	locked = bool(row.Locked)
	region_title.text = String(row.Name_ko)
	locked_label.text = String(row.Locked_text) if locked else ""
	best_label.text = "최장 생존 시간  "+("-" if best<0 else preload("res://scripts/temporary_hud.gd").format_elapsed(best))
	start_button.disabled = locked
	locked_click.visible = locked and screen=="menu"
	queue_redraw()

func toggle_settings() -> void:
	settings.visible = not settings.visible

func _locked_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		owner_flow.locked_hint()

func notify(message: String) -> void:
	hint.text = message
	hint.modulate.a = 1
	hint_remaining = float(owner_flow.data_store.get_row("combat_presentation.csv","Toast_sec").Value)
	hint.show()

func _process(delta: float) -> void:
	if hint_remaining>0:
		hint_remaining = maxf(0,hint_remaining-delta)
		hint.modulate.a = minf(1,hint_remaining/0.2)
		if hint_remaining==0: hint.hide()

func close_modal() -> void:
	if is_instance_valid(modal): modal.free()
	modal = null

func show_modal(title: String, details: String, actions: Array) -> void:
	close_modal()
	modal = PanelContainer.new()
	modal.position = Vector2(350,180)
	modal.size = Vector2(580,390)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07,0.05,0.12,0.98)
	style.border_color = Color("#9870dc")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	modal.add_theme_stylebox_override("panel",style)
	add_child(modal)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	modal.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size",36)
	column.add_child(heading)
	result_text = Label.new()
	result_text.text = details
	result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_text.add_theme_font_size_override("font_size",23)
	result_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(result_text)
	for action in actions:
		var view := Button.new()
		view.text = action.text
		view.custom_minimum_size.y = 48
		view.add_theme_font_size_override("font_size",23)
		view.pressed.connect(action["call"],CONNECT_DEFERRED)
		column.add_child(view)
	queue_redraw()

func _draw() -> void:
	if screen in ["loading","menu"]:
		for y in range(0,720,8):
			draw_rect(Rect2(0,y,1280,8),Color("#101528").lerp(Color("#31204d"),float(y)/720.0))
		for i in range(72):
			var at := Vector2(fposmod(i*173.3+37,1280),fposmod(i*97.7+19,720))
			draw_circle(at,1.0 if i%4 else 1.8,Color(0.65,0.72,1,0.3 if i%3 else 0.65))
	if screen=="loading":
		for radius in range(160,105,-4): draw_circle(Vector2(978,342),radius,Color(0.12,0.43,1,0.018))
		draw_arc(Vector2(978,342),127,0,TAU,96,Color("#648dff"),2)
		draw_circle(Vector2(978,283),28,Color("#090d1e"))
		draw_colored_polygon(PackedVector2Array([Vector2(955,313),Vector2(1000,313),Vector2(1026,424),Vector2(989,411),Vector2(976,466),Vector2(950,418),Vector2(923,428)]),Color("#090d1e"))
	elif screen=="menu":
		draw_style_box(art_style(),Rect2(400,155,480,260))
		var ice := Color("#203044") if locked else Color("#739eb8")
		for i in range(6):
			var x := 420+i*77
			draw_colored_polygon(PackedVector2Array([Vector2(x,397),Vector2(x+32,184+i%3*45),Vector2(x+68,397)]),ice)
		if locked:
			draw_rect(Rect2(400,155,480,260),Color(0,0,0,0.55))
			draw_arc(Vector2(640,274),25,PI,TAU,32,Color("#c2b4dc"),6)
			draw_rect(Rect2(611,274,58,48),Color("#c2b4dc"))
			draw_circle(Vector2(640,291),5,Color("#201a30"))
	elif is_instance_valid(modal):
		draw_rect(Rect2(0,0,1280,720),Color(0.015,0.01,0.03,0.78))

func art_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#18233c")
	style.border_color = Color("#6c5e98")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	return style
