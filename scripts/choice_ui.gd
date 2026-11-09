extends Control

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

func configure(choice_manager: Node) -> void:
	manager = choice_manager

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func(): hovered=-1; queue_redraw())

func card_rect(index: int) -> Rect2:
	var width := CARD_SIZE.x*3.0+CARD_GAP*2.0
	return Rect2(Vector2((size.x-width)/2.0+index*(CARD_SIZE.x+CARD_GAP),CARD_TOP),CARD_SIZE)

func reroll_rect() -> Rect2:
	return Rect2(Vector2((size.x-REROLL_SIZE.x)/2.0,REROLL_TOP),REROLL_SIZE)

func _process(_delta: float) -> void:
	if visible: queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not manager.active or manager.player.is_dead: return
	if event is InputEventMouseMotion:
		hovered = -1
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
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO,size),DIM)
	var title := Rect2(Vector2((size.x-TITLE_SIZE.x)/2.0,TITLE_TOP),TITLE_SIZE)
	var p := title.position
	var s := title.size
	draw_colored_polygon(PackedVector2Array([p+Vector2(RIBBON_CUT,0),p+Vector2(s.x-RIBBON_CUT,0),p+s*Vector2(1,0.5),p+Vector2(s.x-RIBBON_CUT,s.y),p+Vector2(RIBBON_CUT,s.y),p+s*Vector2(0,0.5)]),GROWTH_STRIP)
	_centered("레벨업! 능력 선택",title,TITLE_FONT_SIZE,INK)
	for index in range(manager.cards.size()):
		var state: Dictionary = manager.card_state(index)
		var box := card_rect(index)
		draw_rect(box,CARD_BG)
		if hovered==index:
			for layer in range(1,GLOW_LAYERS+1):
				draw_rect(box.grow(layer*HOVER_WIDTH),Color(GLOW,GLOW_ALPHA),false,HOVER_WIDTH)
		draw_rect(box,GLOW if hovered==index else BORDER,false,HOVER_WIDTH if hovered==index else BORDER_WIDTH)
		_centered(state.name,Rect2(box.position,Vector2(CARD_SIZE.x,NAME_HEIGHT)),FONT_SIZE,INK,true,HEAL_STRIP if state.heal else GROWTH_STRIP)
		var icon := Rect2(box.position+ICON_BOX.position,ICON_BOX.size)
		draw_rect(icon,PANEL_BG)
		var center := icon.get_center()
		if state.heal:
			draw_line(center-Vector2(ICON_RADIUS,0),center+Vector2(ICON_RADIUS,0),HEAL_STRIP,HOVER_WIDTH*2.0,true)
			draw_line(center-Vector2(0,ICON_RADIUS),center+Vector2(0,ICON_RADIUS),HEAL_STRIP,HOVER_WIDTH*2.0,true)
		else:
			draw_arc(center,ICON_RADIUS,0,TAU,ARC_SEGMENTS,GLOW,HOVER_WIDTH,true)
			draw_line(center,center+Vector2(ICON_RADIUS,0).rotated(-PI/4),GLOW,BORDER_WIDTH,true)
		var desc := Rect2(box.position+DESCRIPTION_BOX.position,DESCRIPTION_BOX.size)
		draw_rect(desc,PANEL_BG)
		_wrapped(state.description,desc.grow(-PADDING),font)
		var level_box := Rect2(box.position+LEVEL_BOX.position,LEVEL_BOX.size)
		if state.heal:
			_centered("체력 %d → %d / %d" % [state.hp_before,state.hp_after,state.max_hp],level_box,SMALL_FONT_SIZE,INK)
		else:
			var max_level: int = state.max
			var square_width := minf(BOX_SIZE.x,(level_box.size.x-BOX_GAP*(max_level-1))/max_level)
			for level in range(max_level):
				var square := Rect2(level_box.position+Vector2(level*(square_width+BOX_GAP),0),Vector2(square_width,BOX_SIZE.y))
				draw_rect(square,FILLED if level<int(state.level) else PANEL_BG)
				draw_rect(square,NEXT if level==int(state.level) else BORDER,false,HOVER_WIDTH if level==int(state.level) else BORDER_WIDTH)
			draw_string(font,level_box.position+Vector2(0,BOX_TEXT_Y),"Lv %d → %d" % [state.level,state.next],HORIZONTAL_ALIGNMENT_LEFT,level_box.size.x,SMALL_FONT_SIZE,INK)
	_centered("다시 뽑기 (%d/%d 남음)" % [manager.rerolls,manager.total_rerolls],reroll_rect(),FONT_SIZE,INK if manager.can_reroll() else MUTED,true,BUTTON if manager.can_reroll() else DISABLED)

func _centered(text: String, box: Rect2, font_size: int, color: Color, filled: bool = false, background: Color = CARD_BG) -> void:
	if filled: draw_rect(box,background)
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(font,Vector2(box.get_center().x-width/2.0,box.get_center().y+font.get_ascent(font_size)/2.0),text,HORIZONTAL_ALIGNMENT_LEFT,box.size.x,font_size,color)

func _wrapped(text: String, box: Rect2, font: Font) -> void:
	var line := ""
	var y := box.position.y+font.get_ascent(SMALL_FONT_SIZE)
	for character in text:
		if character=="\n" or font.get_string_size(line+character,HORIZONTAL_ALIGNMENT_LEFT,-1,SMALL_FONT_SIZE).x>box.size.x:
			draw_string(font,Vector2(box.position.x,y),line,HORIZONTAL_ALIGNMENT_LEFT,box.size.x,SMALL_FONT_SIZE,INK)
			y += SMALL_FONT_SIZE+LINE_GAP
			line = ""
		if character!="\n": line += character
	draw_string(font,Vector2(box.position.x,y),line,HORIZONTAL_ALIGNMENT_LEFT,box.size.x,SMALL_FONT_SIZE,INK)
