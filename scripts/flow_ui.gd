extends Control
const UI = preload("res://scripts/system_ui.gd")

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
var values: Dictionary
var backdrop: TextureRect
var backdrop_shade: TextureRect
var logo: TextureRect
var loading_caption: Label
var notice: Label
var cards: Array[Control] = []
var card_rows: Array = []
# REGION-01: card pictures by path, loaded once (layout runs only on menu changes).
var card_textures: Dictionary = {}
var card_index := -1
var slide_remaining := 0.0
var slide_direction := 0.0
var visual_clock := 0.0
var dust: PackedVector2Array
var dust_view: Control
var art_menu: ShaderMaterial
var art_side: ShaderMaterial
var art_locked: ShaderMaterial
var logo_material: ShaderMaterial
var closing_modals: Array[Control] = []
var sound_sliders: Dictionary = {}
# Every live volume slider (menu settings and ESC pause) per bus; one value is shared.
var volume_sliders: Dictionary = {"BGM":[],"SFX":[]}
var pause_sliders: Dictionary = {}
var transition: CanvasLayer
const SETTINGS_WIDTH := 540.0
const MODAL_WIDTH := 580.0

func configure(flow: Node) -> void:
	owner_flow = flow

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.THEME
	values = UI.settings()
	art_menu = art_material(float(values.Ui_menu_blur_px),float(values.Ui_menu_brightness),0)
	art_side = art_material(float(values.Ui_menu_blur_px),float(values.Ui_side_brightness),0)
	art_locked = art_material(float(values.Ui_menu_blur_px),float(values.Ui_locked_brightness),1)
	backdrop = picture(preload("res://assets/ui/title_bg.png"),Rect2(0,0,1280,720))
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var gradient := Gradient.new()
	gradient.set_color(0,Color(0,0,0,0)); gradient.set_color(1,Color(0.01,0.02,0.06,float(values.Ui_title_dim_alpha)))
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0,0); gradient_texture.fill_to = Vector2(0,1)
	backdrop_shade = picture(gradient_texture,Rect2(0,360,1280,360))
	logo = picture(preload("res://assets/ui/logo.png"),Rect2(320,380,640,640.0*734/1394))
	logo_material = ShaderMaterial.new()
	logo_material.shader = preload("res://scripts/ui_logo.gdshader")
	logo_material.set_shader_parameter("width",float(values.Ui_logo_sheen_width))
	logo_material.set_shader_parameter("strength",float(values.Ui_logo_sheen_strength))
	logo_material.set_shader_parameter("tilt",float(values.Ui_logo_tilt))
	logo.material = logo_material
	loading_nodes.append(logo)
	dust_view = Control.new()
	dust_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dust_view)
	dust_view.draw.connect(draw_dust)
	var random := RandomNumberGenerator.new()
	random.seed = 7101
	for i in range(int(values.Ui_dust_count)): dust.append(Vector2(random.randf()*1280,random.randf()*720))
	progress = ProgressBar.new()
	progress.position = Vector2(260,650)
	progress.size = Vector2(760,20)
	progress.max_value = 1
	progress.show_percentage = false
	add_child(progress)
	loading_nodes.append(progress)
	place_logo()
	loading_caption = text("던전 입장 준비 중… 0%",Rect2(100,674,1080,26),18,true)
	loading_nodes.append(loading_caption)
	# FIX-03: the text line (drawn at the top of the label) ends on the screen bottom; it grows upward with the font size.
	var notice_size := int(values.Ui_notice_font_size)
	var notice_height := ceilf(UI.BOLD.get_height(notice_size))
	notice = text(UI.NOTICE,Rect2(50,720-notice_height,1180,notice_height),notice_size,true)
	notice.autowrap_mode = TextServer.AUTOWRAP_OFF
	notice.add_theme_color_override("font_color",Color(values.Ui_secondary_color,float(values.Ui_notice_alpha)))
	var header := Panel.new()
	header.position = Vector2(440,12); header.size = Vector2(400,86)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header); UI.crest(header)
	var header_label := text("지역 선택",Rect2(440,32,400,46),24,true)
	header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_label.add_theme_font_override("font",UI.BLACK)
	menu_nodes.append(header); menu_nodes.append(header_label)
	for i in range(3):
		var card := Control.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(card)
		var image := picture(preload("res://assets/ui/region_ice.png"),Rect2(0,0,560,315),card)
		image.name = "Art"
		var frame := NinePatchRect.new()
		frame.texture = preload("res://assets/ui/ui_frame_overlay.png")
		frame.patch_margin_left = 40; frame.patch_margin_right = 40; frame.patch_margin_top = 40; frame.patch_margin_bottom = 40
		frame.position = Vector2(-40,-40)
		frame.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
		frame.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
		frame.size = Vector2(640,395); frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(frame)
		var lock_image := picture(preload("res://assets/ui/ui_lock.png"),Rect2(248,125,64,64),card)
		lock_image.name = "Lock"
		cards.append(card); menu_nodes.append(card)
	region_title = text("",Rect2(350,500,580,44),34,true)
	best_label = text("",Rect2(390,544,500,30),24,true)
	locked_label = text("",Rect2(390,574,500,26),22,true)
	start_button = button("게임 시작",Rect2(440,610,400,68),begin_start)
	locked_click = Control.new()
	locked_click.position = start_button.position
	locked_click.size = start_button.size
	locked_click.mouse_filter = Control.MOUSE_FILTER_STOP
	locked_click.gui_input.connect(_locked_input)
	add_child(locked_click)
	var left := button("‹",Rect2(240,268,64,64),owner_flow.change_region.bind(-1))
	var right := button("›",Rect2(976,268,64,64),owner_flow.change_region.bind(1))
	var gear := button("설정",Rect2(1140,24,112,56),toggle_settings)
	gear.name = "SettingsButton"
	gear.add_theme_font_size_override("font_size",int(values.Ui_gear_font_size))
	settings = PanelContainer.new()
	settings.name = "SettingsWindow"
	settings.z_index = 5
	settings.position = Vector2(1252-SETTINGS_WIDTH,60)
	settings.size = Vector2(SETTINGS_WIDTH,0)
	UI.pad_window(settings)
	add_child(settings)
	var quit := Button.new()
	quit.text = "게임 종료"
	quit.custom_minimum_size.y = UI.button_height(20,4)
	quit.pressed.connect(func() -> void: get_tree().quit())
	var settings_column := VBoxContainer.new()
	settings_column.add_theme_constant_override("separation",14)
	settings.add_child(settings_column)
	add_sound_settings(settings_column)
	settings_column.add_child(quit)
	UI.animate_button(quit)
	UI.animate_window(settings)
	settings.hide()
	menu_nodes.append_array([region_title,best_label,locked_label,start_button,locked_click,left,right,gear])
	hint = text("",Rect2(340,680,600,24),22,true)
	hint.add_theme_color_override("font_color",Color("#c8e1ff"))
	hint.hide()
	transition = preload("res://scripts/stage_transition.gd").new()
	add_child(transition)
	show_screen("loading")

# Loading -> region select: cover, switch to the menu, then reveal. Menu buttons stay blocked meanwhile.
func enter_menu(action: Callable) -> void:
	if transition.enabled: preload("res://scripts/audio_events.gd").sfx(self,"transition_menu")
	transition.cover_blocking(func() -> void:
		action.call()
		if transition.mode=="covered": transition.reveal())

func menu_locked() -> bool:
	return transition.blocking

func begin_start() -> void:
	if transition.busy() or menu_locked(): return
	if transition.enabled: preload("res://scripts/audio_events.gd").sfx(self,"transition_stage")
	transition.cover(func() -> void:
		owner_flow.start_region()
		if transition.mode=="covered": transition.reveal())

# entering=true marks a stage entry. When no cover came first (retry), the reveal itself is the
# entry effect and plays transition_stage; after a cover the sound has already started.
func reveal_stage(entering: bool = false) -> void:
	if entering and transition.enabled and transition.mode!="covered": preload("res://scripts/audio_events.gd").sfx(self,"transition_stage")
	transition.reveal()

func text(value: String, box: Rect2, font_size: int, centered: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.position = box.position
	label.size = box.size
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("#ebf8ff"))
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
	view.pressed.connect(action)
	add_child(view)
	UI.animate_button(view)
	return view

func show_screen(value: String) -> void:
	screen = value
	for view in loading_nodes: view.visible = value=="loading"
	for view in menu_nodes: view.visible = value=="menu"
	if value!="menu": settings.hide()
	locked_click.visible = value=="menu" and locked
	if value!="menu": hint.hide()
	backdrop.visible = value in ["loading","menu"]
	backdrop_shade.visible = backdrop.visible
	dust_view.queue_redraw()
	notice.visible = value in ["loading","menu"]
	backdrop.material = art_menu if value=="menu" else null
	set_process(true)
	queue_redraw()

func show_region(row: Dictionary, best: float) -> void:
	locked = bool(row.Locked)
	region_title.text = String(row.Name_ko)
	locked_label.text = String(row.Locked_text) if locked else ""
	best_label.text = "최고 클리어 타임  "+("-" if best<0 else preload("res://scripts/temporary_hud.gd").format_elapsed(best))
	start_button.disabled = locked
	locked_click.visible = locked and screen=="menu"
	region_title.add_theme_font_override("font",UI.BLACK)
	var previous := card_index
	card_index = owner_flow.region_index
	card_rows = owner_flow.regions
	if previous>=0 and previous!=card_index and int(values.Ui_fx_enabled)!=0:
		slide_remaining = float(values.Ui_card_slide_sec)
		slide_direction = signf(card_index-previous)
	layout_cards()
	queue_redraw()

func toggle_settings() -> void:
	if menu_locked(): return
	if not settings.visible:
		settings.show()
		return
	if int(values.Ui_fx_enabled)!=0:
		var copy := settings.duplicate(0) as PanelContainer
		add_child(copy)
		copy.show()
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for node in copy.find_children("*","Button",true,false): node.disabled = true; node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.animate_window(copy).close()
	settings.hide()

func inner_width(window_width: float) -> float:
	var margin := UI.window_margin()
	return window_width-margin.x-margin.z

func add_sound_settings(column: VBoxContainer, in_pause: bool = false) -> void:
	var audio := preload("res://scripts/audio_events.gd").manager(self)
	if audio==null: return
	var registry: Dictionary = pause_sliders if in_pause else sound_sliders
	for bus in ["BGM","SFX"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		var label := Label.new()
		label.text = "배경음악" if bus=="BGM" else "효과음"
		label.custom_minimum_size.x = 84
		label.add_theme_font_size_override("font_size",18)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.value = float(audio.levels[bus])
		slider.custom_minimum_size = Vector2(0,28)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var number := Label.new()
		number.name = "Value"
		number.text = "%d" % slider.value
		number.custom_minimum_size.x = 44
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		number.add_theme_font_size_override("font_size",18)
		slider.value_changed.connect(func(level: float) -> void:
			audio.set_level(bus,level)
			sync_volume(bus,level))
		row.add_child(label); row.add_child(slider); row.add_child(number)
		column.add_child(row)
		registry[bus] = slider
		volume_sliders[bus].append(slider)

# Mirror one bus level into every other live slider without re-sending it to the audio manager.
func sync_volume(bus: String, level: float) -> void:
	var live: Array = []
	for slider in volume_sliders[bus]:
		if not is_instance_valid(slider) or slider.is_queued_for_deletion(): continue
		live.append(slider)
		if slider.value!=level: slider.set_value_no_signal(level)
		slider.get_parent().get_node("Value").text = "%d" % level
	volume_sliders[bus] = live

func _locked_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		owner_flow.locked_hint()

func notify(message: String) -> void:
	if message.strip_edges().is_empty(): return
	hint.text = message
	hint.modulate.a = 1
	hint_remaining = float(owner_flow.data_store.get_row("combat_presentation.csv","Toast_sec").Value)
	hint.show()

func _process(delta: float) -> void:
	if screen=="loading": loading_caption.text = "던전 입장 준비 중… %d%%" % roundi(progress.value*100)
	if screen in ["loading","menu"] and int(values.Ui_fx_enabled)!=0:
		visual_clock+=delta
		if screen=="loading":
			var phase := fposmod(visual_clock,float(values.Ui_logo_sheen_interval_sec))
			logo_material.set_shader_parameter("sweep",lerpf(-0.3,1.3,phase/float(values.Ui_logo_sheen_sec)) if phase<float(values.Ui_logo_sheen_sec) else -1.0)
		dust_view.queue_redraw()
	if slide_remaining>0:
		slide_remaining = maxf(0,slide_remaining-delta)
		layout_cards()
	if hint_remaining>0:
		hint_remaining = maxf(0,hint_remaining-delta)
		hint.modulate.a = minf(1,hint_remaining/0.2)
		if hint_remaining==0: hint.hide()

func close_modal() -> void:
	if is_instance_valid(modal):
		var old := modal
		old.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for node in old.find_children("*","Button",true,false): node.disabled = true; node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if int(values.Ui_fx_enabled)==0: old.free()
		else:
			var motion := UI.animate_window(old)
			motion.close()
			closing_modals.append(old)
	modal = null

func show_modal(title: String, details: String, actions: Array, sound: bool = false) -> void:
	close_modal()
	modal = PanelContainer.new()
	modal.name = "ModalWindow"
	modal.z_index = 10
	modal.position = Vector2((1280-MODAL_WIDTH)/2,180)
	modal.size = Vector2(MODAL_WIDTH,0)
	UI.pad_window(modal)
	add_child(modal)
	UI.crest(modal)
	# Keep the window centred when its content (sliders, wrapped text) sets the height.
	var window := modal
	modal.resized.connect(func() -> void: window.position.y = roundf((720-window.size.y)/2))
	UI.animate_window(modal)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	modal.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_override("font",UI.BLACK)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size",36)
	column.add_child(heading)
	result_text = Label.new()
	result_text.name = "Details"
	result_text.text = details
	result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_text.custom_minimum_size.x = inner_width(MODAL_WIDTH)
	result_text.add_theme_font_size_override("font_size",23)
	result_text.visible = not details.is_empty()
	column.add_child(result_text)
	if sound: add_sound_settings(column,true)
	for action in actions:
		var view := Button.new()
		view.text = action.text
		view.custom_minimum_size.y = UI.button_height(23,4)
		view.add_theme_font_size_override("font_size",23)
		view.pressed.connect(action["call"],CONNECT_DEFERRED)
		column.add_child(view)
		UI.animate_button(view)
	modal.size = Vector2(MODAL_WIDTH,0)
	queue_redraw()

# FIX-05: the logo's lower edge sits Logo_bar_gap_px above the loading bar's top and its top at least
# Logo_top_min_px below the screen top; the size only shrinks (centred) when both cannot hold.
func place_logo() -> void:
	var gap := float(values.Logo_bar_gap_px)
	var top_min := float(values.Logo_top_min_px)
	var bottom := progress.position.y-gap
	var size := logo.size
	if bottom-size.y<top_min:
		var height := maxf(bottom-top_min,1.0)
		size = Vector2(size.x*height/size.y,height)
	var center_x := logo.position.x+logo.size.x/2
	logo.size = size
	logo.position = Vector2(center_x-size.x/2,bottom-size.y)

func picture(texture: Texture2D, box: Rect2, parent: Control = null) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.position = box.position; image.size = box.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent==null: parent = self
	parent.add_child(image)
	return image

func art_material(blur: float, brightness: float, gray: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/ui_art.gdshader")
	material.set_shader_parameter("blur_px",blur)
	material.set_shader_parameter("brightness",brightness)
	material.set_shader_parameter("grayscale",gray)
	return material

func layout_cards() -> void:
	for i in range(cards.size()):
		var index := card_index+i-1
		var card := cards[i]
		card.visible = screen=="menu" and index>=0 and index<card_rows.size()
		if not card.visible: continue
		var is_locked: bool = card_rows[index].Locked
		card.get_node("Art").texture = card_texture(card_rows[index])
		card.get_node("Art").material = art_locked if is_locked else (art_side if i!=1 else null)
		card.get_node("Lock").visible = is_locked
		var factor := 1.0 if i==1 else float(values.Ui_side_scale)
		card.scale = Vector2.ONE*factor
		card.modulate.a = 1 if i==1 else float(values.Ui_side_alpha)
		var slide := slide_direction*float(values.Ui_card_slide_px)*pow(slide_remaining/maxf(float(values.Ui_card_slide_sec),0.000001),2)
		card.position = Vector2(640+(i-1)*608-280*factor+slide,300-157.5*factor)
	# Keep the selected card above the small previews.
	cards[0].z_index = 0; cards[2].z_index = 0; cards[1].z_index = 1

# region.csv Card_image; a blank one (locked regions) shows the first region picture, darkened by the lock material.
func card_texture(row: Dictionary) -> Texture2D:
	var path: Variant = row.get("Card_image")
	if path==null or String(path).is_empty():
		for other in card_rows:
			if other.get("Card_image")!=null and not String(other.Card_image).is_empty():
				path = other.Card_image
				break
	if path==null: return preload("res://assets/ui/region_ice.png")
	if not card_textures.has(path): card_textures[path] = load(String(path))
	return card_textures[path]

func draw_dust() -> void:
	if screen in ["loading","menu"] and int(values.Ui_fx_enabled)!=0:
		for i in range(dust.size()):
			var point := Vector2(dust[i].x,fposmod(dust[i].y-visual_clock*float(values.Ui_dust_speed),720))
			dust_view.draw_circle(point,lerpf(float(values.Ui_dust_min_px),float(values.Ui_dust_max_px),float(i%3)/2),Color.WHITE if i%2 else Color(values.Ui_dust_color,float(values.Ui_dust_alpha)))

func _draw() -> void:
	if screen not in ["loading","menu"] and is_instance_valid(modal): draw_rect(Rect2(0,0,1280,720),Color(0.015,0.01,0.03,0.78))
