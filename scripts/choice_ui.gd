extends Control
const UI = preload("res://scripts/system_ui.gd")

# Temporary layout and presentation constants; all progression values come from CSV.
const LAYER := 100
const CARD_SIZE := Vector2(280,380)
const CARD_GAP := 28.0
const CARD_TOP := 190.0
const TITLE_SIZE := Vector2(920,64)
const TITLE_TOP := 72.0
const RIBBON_CUT := 22.0
const NAME_HEIGHT := 48.0
const ICON_BOX := Rect2(90,66,100,100)
const ICON_RADIUS := 32.0
const DESCRIPTION_BOX := Rect2(18,186,244,100)
const LEVEL_BOX := Rect2(18,306,244,60)
const REROLL_SIZE := Vector2(440,56)
const REROLL_TOP := 606.0
const PADDING := 12.0
const FONT_SIZE := 20
const TITLE_FONT_SIZE := 28
const SMALL_FONT_SIZE := 17
const LINE_GAP := 6.0
const BORDER_WIDTH := 2.0
const HOVER_WIDTH := 4.0
const GLOW_LAYERS := 3
const GLOW_ALPHA := 0.08
const BOX_SIZE := Vector2(18,18)
const BOX_GAP := 8.0
const BOX_TEXT_Y := 50.0
const ARC_SEGMENTS := 48
const DIM := Color(0.02,0.01,0.04,0.83)
const CARD_BG := Color("#181320")
const PANEL_BG := Color("#241b30")
const GROWTH_STRIP := Color("#61428b")
const HEAL_STRIP := Color("#306f66")
const INK := Color("#f1e9ff")
const MUTED := Color("#8e819f")
const BORDER := Color("#775a9d")
const GLOW := Color("#d9b6ff")
const FILLED := Color("#9564ce")
const NEXT := Color("#ebc7ff")
const BUTTON := Color("#5b347d")
const DISABLED := Color("#302839")

var manager: Node
var hovered: int = -1
var values: Dictionary
var cached_states: Array = []
var signature: Array = []
var open_age := 0.0
var hover_scales := [1.0,1.0,1.0,1.0]
var reroll_hover := false
var was_visible := false
var closing_copy: Control

func configure(choice_manager: Node) -> void: manager = choice_manager

func _ready() -> void:
	theme = UI.THEME
	values = UI.settings()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func() -> void: hovered=-1; queue_redraw())
	visibility_changed.connect(on_visibility)

func card_rect(index: int) -> Rect2:
	var width := CARD_SIZE.x*3.0+CARD_GAP*2.0
	return Rect2(Vector2((size.x-width)/2.0+index*(CARD_SIZE.x+CARD_GAP),CARD_TOP),CARD_SIZE)

func reroll_rect() -> Rect2:
	return Rect2(Vector2((size.x-REROLL_SIZE.x)/2.0,REROLL_TOP),REROLL_SIZE)

func on_visibility() -> void:
	if visible:
		open_age = 0.0
		self_modulate.a = 1.0
		was_visible = true
		if is_instance_valid(closing_copy): closing_copy.queue_free()
	elif was_visible and not cached_states.is_empty() and int(values.Ui_fx_enabled)!=0:
		was_visible = false
		closing_copy = Control.new()
		closing_copy.size = size
		closing_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_parent().add_child(closing_copy)
		var copy := closing_copy
		var states := cached_states.duplicate(true)
		var caption := reroll_caption()
		var allowed: bool = manager.can_reroll()
		copy.draw.connect(func() -> void: paint(copy,states,caption,allowed,false))
		UI.animate_window(copy).close()

func reroll_caption() -> String:
	return "다시 뽑기 (%d/%d 남음)" % [manager.rerolls,manager.total_rerolls]

func _process(delta: float) -> void:
	if not visible or manager==null or not manager.active: return
	var states: Array = []
	for i in range(manager.cards.size()): states.append(manager.card_state(i))
	var next: Array = [states,manager.rerolls,hovered,reroll_hover,size]
	var animating := false
	if int(values.Ui_fx_enabled)!=0:
		if open_age<float(values.Ui_open_sec): open_age+=delta; animating = true
		var progress := clampf(open_age/float(values.Ui_open_sec),0,1)
		self_modulate.a = float(values.Ui_flicker_alpha) if progress<1 and sin(progress*TAU*int(values.Ui_flicker_count))<0 else 1.0
		for i in range(4):
			var selected := hovered==i if i<3 else reroll_hover
			var target := float(values.Ui_hover_scale) if selected else 1.0
			if selected and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): target = float(values.Ui_press_scale)
			if not is_equal_approx(hover_scales[i],target):
				hover_scales[i] = move_toward(hover_scales[i],target,delta*0.04/float(values.Ui_hover_sec))
				animating = true
	if next!=signature or animating:
		signature = next.duplicate(true)
		cached_states = states
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not manager.active or manager.player.is_dead: return
	if event is InputEventMouseMotion:
		hovered = -1
		reroll_hover = reroll_rect().has_point(event.position)
		for index in range(manager.cards.size()):
			if card_rect(index).has_point(event.position): hovered=index
		queue_redraw()
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		for index in range(manager.cards.size()):
			if card_rect(index).has_point(event.position):
				manager.select(index)
				accept_event()
				return
		if reroll_rect().has_point(event.position): manager.reroll()
		accept_event()

func _draw() -> void:
	if manager==null or not manager.active: return
	var states: Array = []
	for i in range(manager.cards.size()): states.append(manager.card_state(i))
	cached_states = states
	paint(self,states,reroll_caption(),manager.can_reroll(),true)

func paint(node: Control, states: Array, caption: String, can_reroll: bool, animate: bool) -> void:
	node.draw_rect(Rect2(Vector2.ZERO,size),DIM)
	if animate and int(values.Ui_fx_enabled)!=0:
		var p := clampf(open_age/float(values.Ui_open_sec),0,1)
		var scale_y := lerpf(float(values.Ui_open_scale_y),1,p)
		var x := sin(p*TAU*int(values.Ui_flicker_count))*float(values.Ui_jitter_px)*(1-p)
		node.draw_set_transform(Vector2(x,size.y*(1-scale_y)/2),0,Vector2(1,scale_y))
	UI.panel(node,Rect2((size.x-1000)/2,62,1000,612),true)
	centered(node,"! 레벨 업 !",Rect2((size.x-TITLE_SIZE.x)/2,TITLE_TOP,TITLE_SIZE.x,TITLE_SIZE.y),TITLE_FONT_SIZE,UI.BLACK)
	for i in range(states.size()):
		var state: Dictionary = states[i]
		var box := card_rect(i)
		var factor := float(hover_scales[i]) if animate else 1.0
		box = Rect2(box.get_center()-box.size*factor/2,box.size*factor)
		UI.panel(node,box)
		centered(node,state.name,Rect2(box.position+Vector2(0,20),Vector2(box.size.x,NAME_HEIGHT)),FONT_SIZE,UI.BLACK)
		UI.icon_draw(node,UI.icon(state.id),Rect2(box.position+ICON_BOX.position,ICON_BOX.size))
		wrapped(node,state.description,Rect2(box.position+DESCRIPTION_BOX.position,DESCRIPTION_BOX.size).grow(-PADDING))
		var level_box := Rect2(box.position+LEVEL_BOX.position-Vector2(0,12),LEVEL_BOX.size)
		if state.heal:
			centered(node,"체력 %d → %d / %d" % [state.hp_before,state.hp_after,state.max_hp],level_box,SMALL_FONT_SIZE)
		elif state.get("summon",false):
			centered(node,"소환 %d → %d / %d" % [state.level,state.next,state.max],level_box,SMALL_FONT_SIZE)
		else:
			var max_level: int = state.max
			var width := minf(BOX_SIZE.x,(level_box.size.x-BOX_GAP*(max_level-1))/max_level)
			for level in range(max_level):
				var square := Rect2(level_box.position+Vector2(level*(width+BOX_GAP),0),Vector2(width,BOX_SIZE.y))
				node.draw_rect(square,FILLED if level<int(state.level) else PANEL_BG)
				node.draw_rect(square,NEXT if level==int(state.level) else BORDER,false,2)
			node.draw_string(UI.BOLD,level_box.position+Vector2(0,BOX_TEXT_Y),"Lv %d → %d" % [state.level,state.next],HORIZONTAL_ALIGNMENT_LEFT,level_box.size.x,SMALL_FONT_SIZE,Color(values.Ui_color))
	var button := reroll_rect()
	if animate and int(values.Ui_fx_enabled)!=0: button = Rect2(button.get_center()-button.size*hover_scales[3]/2,button.size*hover_scales[3])
	var style := "disabled" if not can_reroll else ("pressed" if reroll_hover and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else ("hover" if reroll_hover else "normal"))
	node.draw_style_box(UI.THEME.get_stylebox(style,"Button"),button)
	centered(node,caption,button,FONT_SIZE)
	node.draw_set_transform(Vector2.ZERO)

func centered(node: Control, value: String, box: Rect2, font_size: int, font: Font = UI.BOLD) -> void:
	var width := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	node.draw_string_outline(font,Vector2(box.get_center().x-width/2,box.get_center().y+font.get_ascent(font_size)/2),value,HORIZONTAL_ALIGNMENT_LEFT,box.size.x,font_size,2,Color(values.Ui_glow_color,0.3))
	node.draw_string(font,Vector2(box.get_center().x-width/2,box.get_center().y+font.get_ascent(font_size)/2),value,HORIZONTAL_ALIGNMENT_LEFT,box.size.x,font_size,Color(values.Ui_color))

func wrapped(node: Control, value: String, box: Rect2) -> void:
	var line := ""
	var y := box.position.y+UI.BOLD.get_ascent(SMALL_FONT_SIZE)
	for character in value:
		if character=="\n" or UI.BOLD.get_string_size(line+character,HORIZONTAL_ALIGNMENT_LEFT,-1,SMALL_FONT_SIZE).x>box.size.x:
			node.draw_string(UI.BOLD,Vector2(box.position.x,y),line,HORIZONTAL_ALIGNMENT_LEFT,box.size.x,SMALL_FONT_SIZE,Color(values.Ui_color))
			y+=SMALL_FONT_SIZE+LINE_GAP; line = ""
		if character!="\n": line+=character
	node.draw_string(UI.BOLD,Vector2(box.position.x,y),line,HORIZONTAL_ALIGNMENT_LEFT,box.size.x,SMALL_FONT_SIZE,Color(values.Ui_color))
