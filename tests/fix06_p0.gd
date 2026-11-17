extends RefCounted
# FIX-06: rapid slash effects and sound back to the pre-FIX-04 behaviour; only the 3-beat pose stays.

func run(t: SceneTree) -> void:
	await rapid(t)

func count(audio: Node, id: String) -> int:
	return int(audio.request_counts.get(id,0))

func fixture(t: SceneTree) -> Dictionary:
	return preload("res://tests/fx03_p0.gd").new().fixture(t)

func active_basic_fx(player: Node2D) -> int:
	return player.basic_fx_pool.filter(func(item: Node2D) -> bool: return item.active).size()

# One cast stepped at 60Hz: enemy hp/hit trace, per-hit effect lines, pose sequence, basic effects seen.
func cast(n: Dictionary, enemy: Node2D) -> Dictionary:
	var skills: Node2D = n.skills
	var player: Node2D = n.player
	var slash = skills.skills.skill_rapid_slash
	slash.cooldown_until = 0
	enemy.hp = enemy.max_hp
	skills.effects.clear()
	for item in player.basic_fx_pool: item.finish()
	skills.try_use("skill_rapid_slash")
	var trace: Array = []
	var lines: Array = []
	var seen: Dictionary = {}
	var poses: Array = []
	var basic_fx := 0
	for i in range(60):
		trace.append([snappedf(skills.clock-slash.started_at,0.0001),enemy.hp,slash.hits_done])
		for effect in skills.effects:
			if effect.has("lines") and not seen.has(effect.at):
				seen[effect.at] = true
				lines.append([snappedf(float(effect.at)-slash.started_at,0.0001),effect.lines.size(),effect.stars.size(),effect.finishing])
		if slash.active: poses.append(player.rapid_pose_column())
		basic_fx = maxi(basic_fx,active_basic_fx(player))
		if not slash.active: break
		skills._physics_process(1.0/60.0)
	return {"trace":trace,"lines":lines,"poses":poses,"basic_fx":basic_fx,"span":slash.completed_at-slash.started_at}

func rapid(t: SceneTree) -> void:
	var n := fixture(t)
	var audio: Node = t.root.get_node("GameAudio")
	var skills: Node2D = n.skills
	var player: Node2D = n.player
	n.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":1})
	var enemy: Node2D = n.manager.get_living_enemies().back()
	enemy.global_position = player.global_position+Vector2(40,0)
	enemy.max_hp = 100000
	player.last_move_direction = Vector2.RIGHT
	for i in range(2,audio.pool.size()): audio.pool[i].stop(); audio.pool[i].set_meta(&"sound","")
	var before := {"rapid":count(audio,"rapid_slash"),"slash":count(audio,"slash"),"thrust":count(audio,"thrust"),"finish":count(audio,"rapid_slash_finish")}
	var slash = skills.skills.skill_rapid_slash
	slash.cooldown_until = 0
	skills.try_use("skill_rapid_slash")
	t.check(count(audio,"rapid_slash")==before.rapid+1,"FIX06 rapid_slash requested once at the cast start")
	var voice: AudioStreamPlayer = null
	for i in range(2,audio.pool.size()):
		if audio.pool[i].get_meta(&"sound")=="rapid_slash": voice = audio.pool[i]
	while slash.active: skills._physics_process(1.0/60.0)
	for i in range(30): skills._physics_process(1.0/60.0)
	t.check(count(audio,"rapid_slash")==before.rapid+1 and count(audio,"slash")==before.slash and count(audio,"thrust")==before.thrust and count(audio,"rapid_slash_finish")==before.finish,"FIX06 one cast plays only rapid_slash: no slash, thrust or finish sound")
	t.check(not audio.has_method("fade_handles") and audio.get("fades")==null and voice!=null and voice.get_meta(&"sound")=="rapid_slash" and (voice.playing or voice.stream!=null),"FIX06 nothing asks to stop the rapid slash sound after the cast (no fade mechanism left)")
	var with_pose := cast(n,enemy)
	var hits := int(slash.snapshot.Hits)
	var per_tick := int(skills.presentation.Slash_lines_per_tick)
	var lines_ok: bool = with_pose.lines.size()==hits
	for entry in with_pose.lines: lines_ok = lines_ok and entry[1]==per_tick+(2 if entry[3] else 0)
	t.check(lines_ok,"FIX06 every hit draws the rapid slash lines (4 per hit, +2 finishing): "+str(with_pose.lines))
	t.check(with_pose.basic_fx==0,"FIX06 no basic slash/thrust effect during the rapid slash")
	var sequence: Array = []
	for c in with_pose.poses:
		if sequence.is_empty() or c!=sequence.back(): sequence.append(c)
	t.check(sequence==[23,24,3],"FIX06 the pose still steps 23 -> 24 -> 3: "+str(sequence))
	var span := (hits-1)*float(slash.snapshot.Hit_interval_sec)
	t.check(is_equal_approx(with_pose.span,span) and skills.beat_at(slash.started_at)==0 and skills.beat_at(slash.started_at+span/3.0)==1 and skills.beat_at(slash.started_at+span*2.0/3.0)==2 and skills.beat_at(slash.started_at+span)==2,"FIX06 beat span stays (Hits-1) x interval / 3")
	skills.presentation.Rapid_combo_beats = 0
	var without := cast(n,enemy)
	skills.presentation.Rapid_combo_beats = 3
	t.check(with_pose.trace==without.trace and with_pose.lines==without.lines and is_equal_approx(with_pose.span,without.span),"FIX06 damage, hit times, lines and marks equal the pose-off cast (pre-FIX-04 behaviour)")
	var saved: Dictionary = slash.snapshot
	slash.snapshot = saved.duplicate()
	slash.snapshot.Hits = 1
	slash.started_at = skills.clock
	t.check(skills.beat_at(skills.clock)==2,"FIX06 a one-hit cast is the last beat only")
	slash.snapshot = saved
	slash.cooldown_until = 0
	skills.try_use("skill_rapid_slash")
	player.freeze_remaining = 1.0
	t.check(slash.active and player.rapid_pose_column()==3,"FIX06 freeze returns the pose to the rapid slash pose at once")
	player.freeze_remaining = 0.0
	player.apply_damage(100000)
	t.check(player.is_dead and player.rapid_pose_column()==3,"FIX06 death drops the beat pose at once")
	t.paused = false
	n.host.free()
	await t.process_frame
