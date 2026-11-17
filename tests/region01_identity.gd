extends RefCounted
# REGION-01 identity scenario: region 1 with fixed seeds through the windows that cross every spawn row,
# scaling row and boss entry. Uses only members that exist before and after REGION-01 so the same
# scenario gives the baseline (623a1cb) and the current result. Returns a JSON-safe Dictionary.

const WINDOWS := [[0.0,360],[56.0,600],[176.0,600],[326.0,840]]

static func run(tree: SceneTree) -> Dictionary:
	var audio: Node = tree.root.get_node("GameAudio")
	var main: Node = load("res://main.tscn").instantiate()
	tree.root.add_child(main)
	var n: Dictionary = main.round_nodes
	n.manager._random.seed = 20261117
	# Fix the three user-tuned cells in memory so the result does not depend on which copy's CSVs are loaded.
	n.manager._enemy_records["enemy_01"]["Max_hp"] = 42
	n.manager._spawn_records["spawn_01"]["Spawn_interval"] = 1.4
	n.manager._max_alive = 80
	n.choices.random.seed = 20261117
	# configure_combat also sets the base max hp the max-hp choice scales from.
	n.player.configure_combat(100000,n.player._attack_data)
	var kills := [0]
	n.manager.enemy_died.connect(func(_enemy: Node) -> void: kills[0] += 1)
	var map: Node2D = n.map
	var weather: Node = map.get_node_or_null("SnowWeather")
	var props: Array = []
	for item in map.prop_layout: props.append([snappedf(item.position.x,0.001),snappedf(item.position.y,0.001),int(item.column),bool(item.mirrored),snappedf(float(item.factor),0.0001)])
	var look := {
		"ground":map.ground.resource_path if map.ground!=null else "",
		"brightness":snappedf(float(map.settings.get("Ground_brightness",-1)),0.0001),
		"tint":map.modulate.to_html(),
		"props_texture":map.get_node("CharacterBodies").get_children().filter(func(c: Node) -> bool: return c.get("texture")!=null and c.get("column")!=null)[0].texture.resource_path,
		"weather":weather!=null,
		"snow_alpha":snappedf(float(weather.settings.get("Snow_alpha",-1)),0.0001) if weather!=null else -1.0,
		"fog":snappedf(float(weather.settings.get("Fog_strength",-1)),0.0001) if weather!=null else -1.0,
		"snow_seed":int(weather.settings.get("Forest_seed",-1)) if weather!=null else -1,
	}
	var counts_before: Dictionary = audio.request_counts.duplicate()
	var music_before: int = audio.music_history.size()
	var sounds: Array = []
	var samples: Array = []
	var bosses: Array = []
	var last_actor: Variant = null
	var frame := 0
	for window in WINDOWS:
		n.manager._elapsed_seconds = float(window[0])
		for i in range(int(window[1])):
			await tree.physics_frame
			while tree.paused and n.choices.active:
				n.choices.select(0)
				await tree.process_frame
			frame += 1
			var now: Dictionary = audio.request_counts
			var ids: Array = now.keys()
			ids.sort()
			for id in ids:
				var delta := int(now[id])-int(counts_before.get(id,0))
				if delta>0: sounds.append([frame,String(id),delta])
			counts_before = now.duplicate()
			var actor: Variant = n.director.actor
			if is_instance_valid(actor) and actor!=last_actor:
				bosses.append([snappedf(n.manager._elapsed_seconds,0.0001),String(n.director.active_id),n.director.phase])
				last_actor = actor
				# Boss AI randomizes its own generator; fix it before the boss acts (emerge phase).
				actor.rng.seed = 20261117+bosses.size()
			if frame%30==0:
				var sum := Vector2.ZERO
				for enemy in n.manager.get_living_enemies(): sum += enemy.global_position
				samples.append([frame,snappedf(n.manager._elapsed_seconds,0.0001),n.manager.get_alive_count(),snappedf(sum.x,0.01),snappedf(sum.y,0.01),int(n.player.hp),kills[0],n.player.level])
		# Clear the active boss so the next timeline boss (and the boss -> stage music switch) can run.
		var boss: Variant = n.director.actor
		if is_instance_valid(boss) and n.director.phase=="active" and int(boss.hp)>0:
			bosses.append([snappedf(n.manager._elapsed_seconds,0.0001),String(n.director.active_id),"killed"])
			boss.apply_damage(boss.hp)
	var music: Array = audio.music_history.slice(music_before)
	var result := {"look":look,"props":props,"samples":samples,"sounds":sounds,"bosses":bosses,"music":music,"kills":kills[0],"hp":int(n.player.hp)}
	tree.paused = false
	main.queue_free()
	await tree.process_frame
	return result
