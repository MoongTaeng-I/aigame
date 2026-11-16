extends RefCounted

static func manager(source: Node) -> Node:
	return source.get_node_or_null("/root/GameAudio") if source.is_inside_tree() else null

static func sfx(source: Node, id: String) -> void:
	var audio := manager(source)
	if audio!=null: audio.request(id)

static func once(source: Node, id: String, token: Variant) -> void:
	var key := StringName("snd_"+id)
	if source.has_meta(key) and source.get_meta(key)==token: return
	source.set_meta(key,token)
	sfx(source,id)

static func music(source: Node, id: String) -> void:
	var audio := manager(source)
	if audio!=null: audio.music(id)

static func button(button: Button) -> void:
	if not button.has_meta(&"snd_button"):
		button.set_meta(&"snd_button",true)
		button.pressed.connect(sfx.bind(button,"ui_click"))
