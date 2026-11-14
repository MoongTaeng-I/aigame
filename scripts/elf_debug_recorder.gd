extends Node

# Development-only observer: never calls behavior, targeting or RNG functions.
var manager: EnemyManager
var file: FileAccess
var output_path := ""
var previous_branch := ""
var actor_id := 0

static func requested() -> bool:
	return OS.get_cmdline_user_args().has("--elf-debug") or FileAccess.file_exists("res://.local/elf-debug.enabled")

func configure(owner_manager: EnemyManager, path: String = "") -> void:
	manager = owner_manager
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 100
	if path.is_empty():
		var stamp := Time.get_datetime_string_from_system().replace(":", "-")
		path = "res://.local/elf-debug-%s-%d-%d.jsonl" % [stamp,OS.get_process_id(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	output_path = path
	file = FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		push_warning("Elf debug log unavailable: "+path)

func _physics_process(_delta: float) -> void:
	# F9 remains available during pause/death; physics sampling does not advance time.
	if get_tree().paused: return
	observe()

func elf_actor() -> Node2D:
	if not is_instance_valid(manager) or not is_instance_valid(manager.boss_director): return null
	var actor: Variant = manager.boss_director.actor
	if not is_instance_valid(actor) or actor.elf==null: return null
	return actor

func observe() -> void:
	if file==null: return
	var actor := elf_actor()
	if actor==null: return
	if actor_id!=actor.get_instance_id():
		actor_id = actor.get_instance_id()
		previous_branch = ""
	var branch: String = actor.elf.last_branch
	if branch==previous_branch: return
	var state := snapshot(actor)
	state.event = "branch_change"
	state.previous_branch = previous_branch
	state.next_branch = branch
	state.reason = branch_reason(branch)
	write_state(state)
	previous_branch = branch

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F9:
		mark()

func mark() -> void:
	if file==null: return
	var actor := elf_actor()
	var state := snapshot(actor)
	state.event = "user_marker"
	state.label = "사용자 표시"
	state.previous_branch = actor.elf.last_branch if actor!=null else ""
	state.next_branch = state.previous_branch
	state.reason = "F9"
	write_state(state)

func write_state(state: Dictionary) -> void:
	file.store_line(JSON.stringify(state))
	# Preserve the last marker/transition even if the process later crashes.
	file.flush()

func point(value: Vector2) -> Array:
	return [value.x,value.y]

func edge_distances(position: Vector2, radius: float, bounds: Rect2) -> Dictionary:
	return {"left":position.x-radius-bounds.position.x,"right":bounds.end.x-position.x-radius,"top":position.y-radius-bounds.position.y,"bottom":bounds.end.y-position.y-radius}

func snapshot(actor: Node2D) -> Dictionary:
	var player: Variant = manager._player
	var bounds: Rect2 = manager._get_map_world_rect()
	var state := {"wall_time":Time.get_datetime_string_from_system(),"ticks_usec":Time.get_ticks_usec(),"time":manager._elapsed_seconds,"paused":get_tree().paused,"elf_present":actor!=null,"player_position":point(player.global_position),"player_stealth":player.is_stealthed(),"player_stealth_remaining":player.stealth_remaining,"player_frozen":player.is_frozen(),"player_freeze_remaining":player.freeze_remaining,"player_dead":player.is_dead,"player_hp":player.hp,"player_map_edges":edge_distances(player.global_position,player.body_radius,bounds),"map_bounds":{"position":point(bounds.position),"size":point(bounds.size)},"normal_enemy_count":manager.get_alive_count()}
	if actor==null: return state
	var e: Variant = actor.elf
	var distance := actor.global_position.distance_to(player.global_position)
	var cooldowns := {}
	for row in actor.actions: cooldowns[row.Id] = maxf(0,float(actor.ready_at[row.Id])-manager._elapsed_seconds)
	state.merge({"elf_position":point(actor.global_position),"elf_map_edges":edge_distances(actor.global_position,actor.body_radius,bounds),"distance":distance,"inside416":distance<=416.0,"detect_range":e.detect_range,"inside_detect_range":distance<=e.detect_range,"elf_hidden":e.hidden,"elf_hidden_remaining":maxf(0,e.hidden_until-manager._elapsed_seconds) if e.hidden else 0.0,"flee":e.fleeing,"flee_distance":e.flee_travelled,"flee_reselections":e.flee_reselections,"burst":e.burst,"fear":actor.is_feared(),"fear_remaining":actor.fear_remaining,"cooldowns":cooldowns,"recovery_remaining":maxf(0,e.recovery_until-manager._elapsed_seconds),"shots":e.shots_fired,"burst_shot_index":e.shot_index,"branch":e.last_branch,"elf_active":actor.is_active,"elf_dead":actor.is_logically_dead,"elf_hp":actor.hp})
	return state

func branch_reason(branch: String) -> String:
	match branch:
		"fear": return "fear lock has priority; flee/burst interrupted"
		"stealth_wait": return "player stealth; flee/burst interrupted; wait"
		"flee": return "committed flee precedes new attacks"
		"burst": return "committed burst; shots depend on telegraph/interval"
		"recovery": return "burst recovery deadline not reached"
		"stealth": return "self stealth ready; priority before burst/basic"
		"follow": return "outside Detect_range or basic Use_range; approach"
		"push": return "inside push Use_range and ready; priority before attacks"
		"burst_start": return "burst ready and inside Detect_range/Use_range"
		"basic": return "inside basic Use_range; fire only when basic cooldown ready"
	return "no branch selected yet"
