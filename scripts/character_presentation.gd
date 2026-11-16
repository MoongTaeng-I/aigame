extends Node2D

# Only artwork joins the shared y-sort layer. Physics and effects stay in place.
var actor: Node2D
var last_body_state: Array = []

static func attach(source: Node2D) -> Node2D:
	var view: Node2D = load("res://scripts/character_presentation.gd").new()
	view.actor = source
	view.name = "CharacterPresentation"
	var host: Node = source
	while host!=null and host.get_node_or_null("CharacterBodies")==null:
		host = host.get_parent()
	if host==null:
		source.add_child(view)
	else:
		host.get_node("CharacterBodies").add_child(view)
	if source.get("sprite_body")!=null:
		source.sprite_body.reparent(view,false)
	source.tree_exiting.connect(view.queue_free)
	view.process_mode = Node.PROCESS_MODE_ALWAYS
	view.sync_pose()
	return view

func sync_pose() -> void:
	if not is_instance_valid(actor):
		hide()
		return
	global_transform = actor.global_transform
	if actor.get("sprite_body")!=null and actor.sprite_body.visible:
		var offset := Vector2(0,actor.sprite_body.foot_y)
		global_position = actor.to_global(offset)
		actor.sprite_body.position = -offset
	visible = actor.is_visible_in_tree()
	# An external artwork node must also inherit the actor's fade/stealth tint.
	modulate = actor.modulate if get_parent()!=actor else Color.WHITE
	self_modulate = actor.self_modulate if get_parent()!=actor else Color.WHITE
	# Sprites redraw their own commands; moving the parent updates transforms
	# without rebuilding this empty body's draw list.
	if actor.get("sprite_body")==null or not actor.sprite_body.visible:
		var state := [global_transform,modulate,self_modulate,visible,actor.get("facing"),actor.get("fear_remaining"),actor.get("hp"),actor.get("phase")]
		if actor.has_method("snapshot"): state.append(actor.snapshot())
		if actor.get("elf")!=null:
			state.append([actor.elf.hidden,actor.elf.burst,actor.elf.now()<actor.elf.burst_first])
		if state!=last_body_state:
			last_body_state = state
			queue_redraw()
	elif not last_body_state.is_empty():
		last_body_state.clear()
		queue_redraw()

func _process(_delta: float) -> void:
	sync_pose()

func _draw() -> void:
	if is_instance_valid(actor): actor.draw_body(self)
