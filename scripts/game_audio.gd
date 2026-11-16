extends Node

var settings: Dictionary
var sounds: Dictionary = {}
var pool: Array[AudioStreamPlayer] = []
var last_play: Dictionary = {}
var request_counts: Dictionary = {}
var play_counts: Dictionary = {}
var clock := 0.0
var rng := RandomNumberGenerator.new()
var music_id := ""
var music_history: Array[String] = []
var gains := [0.0,0.0]
var from_gains := [0.0,0.0]
var targets := [0.0,0.0]
var fade_age := 1.0
var paused_before := false
var choice_before := false
var bgm_db := -6.0
var sfx_db := 0.0
var credits := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("BGM")<0 or AudioServer.get_bus_index("SFX")<0:
		AudioServer.set_bus_layout(preload("res://assets/audio/default_bus_layout.tres"))
	settings = preload("res://scripts/shadow_afterimage.gd").compiled_presentation()
	bgm_db = float(settings.Sound_bgm_db); sfx_db = float(settings.Sound_sfx_db)
	rng.seed = Time.get_ticks_usec()^get_instance_id()
	var file := FileAccess.open("res://data/sound.csv",FileAccess.READ)
	file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size()!=6: continue
		var stream := load(row[1]) as AudioStream
		if stream==null: push_error("sound.csv Path: "+row[1]); continue
		if stream is AudioStreamOggVorbis: stream.loop = true
		sounds[row[0]] = {"stream":stream,"volume":float(row[2]),"max":int(row[3]),"interval":float(row[4]),"pitch":float(row[5])}
	file.close()
	credits = FileAccess.get_file_as_string("res://assets/audio/CREDITS.txt")
	for i in range(16):
		var voice := AudioStreamPlayer.new()
		voice.bus = "BGM" if i<2 else "SFX"
		voice.name = "BgmVoice"+str(i) if i<2 else "SfxVoice"+str(i-2)
		voice.set_meta(&"sound","")
		add_child(voice); pool.append(voice)
		voice.finished.connect(func() -> void: voice.set_meta(&"sound",""))
	update_buses(false)

func request(id: String) -> bool:
	request_counts[id] = int(request_counts.get(id,0))+1
	if not sounds.has(id): return false
	if get_tree().paused and not (id in ["ui_click","level_up"] and choice_pause()): return false
	var row: Dictionary = sounds[id]
	if clock-float(last_play.get(id,-INF))+0.000000001<float(row.interval): return false
	var count := 0
	var free: AudioStreamPlayer
	for i in range(2,pool.size()):
		var voice := pool[i]
		if voice.playing and voice.get_meta(&"sound")==id: count+=1
		if not voice.playing and free==null: free = voice
	if count>=int(row.max) or free==null: return false
	free.stream = row.stream
	free.volume_db = row.volume
	free.pitch_scale = 1+rng.randf_range(-float(row.pitch),float(row.pitch))
	free.set_meta(&"sound",id)
	free.play()
	last_play[id] = clock
	play_counts[id] = int(play_counts.get(id,0))+1
	return true

func music(id: String) -> void:
	if id==music_id: return
	if not id.is_empty() and not sounds.has(id): return
	music_id = id
	music_history.append(id)
	if music_history.size()>32: music_history.pop_front()
	from_gains = gains.duplicate()
	targets = [0.0,0.0]
	fade_age = 0.0
	if id.is_empty(): return
	var selected := -1
	for i in range(2):
		if pool[i].get_meta(&"sound")==id: selected = i
	if selected<0:
		selected = 0 if gains[0]<=gains[1] else 1
		pool[selected].stop()
		pool[selected].stream = sounds[id].stream
		pool[selected].set_meta(&"sound",id)
		gains[selected] = 0.0; from_gains[selected] = 0.0
		pool[selected].volume_db = -80
		pool[selected].play()
	targets[selected] = 1.0

func set_volume(bus: String, db: float) -> void:
	if bus=="BGM": bgm_db = db
	elif bus=="SFX": sfx_db = db
	update_buses(get_tree().paused)

func update_buses(paused: bool) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("BGM"),bgm_db+(linear_to_db(float(settings.Sound_pause_bgm_ratio)) if paused else 0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"),sfx_db)

func choice_pause() -> bool:
	for view in get_tree().get_nodes_in_group("audio_choice_ui"):
		if view.visible and view.manager.active: return true
	return false

func _process(delta: float) -> void:
	clock+=delta
	var paused := get_tree().paused
	var choice := paused and choice_pause()
	if paused!=paused_before or choice!=choice_before:
		paused_before = paused
		choice_before = choice
		update_buses(paused)
		if paused:
			for i in range(2,pool.size()):
				if choice and pool[i].get_meta(&"sound") in ["ui_click","level_up"]: continue
				pool[i].stop(); pool[i].set_meta(&"sound","")
	if fade_age<float(settings.Sound_bgm_fade_sec):
		fade_age = minf(float(settings.Sound_bgm_fade_sec),fade_age+delta)
		var t := fade_age/maxf(0.000001,float(settings.Sound_bgm_fade_sec))
		for i in range(2):
			gains[i] = lerpf(from_gains[i],targets[i],t)
			var id: String = pool[i].get_meta(&"sound")
			pool[i].volume_db = linear_to_db(maxf(0.0001,gains[i]))+(float(sounds[id].volume) if sounds.has(id) else 0)
			if t>=1 and gains[i]==0:
				pool[i].stop(); pool[i].set_meta(&"sound","")
