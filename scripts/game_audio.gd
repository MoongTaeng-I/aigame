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
var levels := {"BGM":100.0,"SFX":100.0}
# JUICE-01 xp_pickup pitch ladder: +1 semitone per pickup within Xp_pitch_reset_sec, up to the max.
var xp_semitones := 0
var xp_last_pickup := -INF
# JUICE-01 low-hp BGM low-pass: 0 = off, 1 = fully at Low_hp_bgm_lowpass_hz.
var lowpass: AudioEffectLowPassFilter
var lowpass_amount := 0.0
var lowpass_target := 0.0
const LOWPASS_OPEN_HZ := 20500.0
# FIX-05: every successful SFX play gets a serial; callers can fade exactly the plays they made.
var play_serial := 0
var last_voice: AudioStreamPlayer
var last_play_id := 0
var fades: Array = []

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
	for i in range(16):
		var voice := AudioStreamPlayer.new()
		voice.bus = "BGM" if i<2 else "SFX"
		voice.name = "BgmVoice"+str(i) if i<2 else "SfxVoice"+str(i-2)
		voice.set_meta(&"sound","")
		add_child(voice); pool.append(voice)
		voice.finished.connect(func() -> void: voice.set_meta(&"sound",""))
	_setup_lowpass()
	update_buses(false)

func _setup_lowpass() -> void:
	var bgm := AudioServer.get_bus_index("BGM")
	for i in range(AudioServer.get_bus_effect_count(bgm)):
		if AudioServer.get_bus_effect(bgm,i) is AudioEffectLowPassFilter: lowpass = AudioServer.get_bus_effect(bgm,i)
	if lowpass==null:
		lowpass = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(bgm,lowpass)
	reset_low_hp()

func lowpass_index() -> int:
	var bgm := AudioServer.get_bus_index("BGM")
	for i in range(AudioServer.get_bus_effect_count(bgm)):
		if AudioServer.get_bus_effect(bgm,i)==lowpass: return i
	return -1

# Low-hp warning: slide the BGM low-pass in (true) or out (false) over Low_hp_fade_sec.
func set_low_hp(active: bool) -> void:
	lowpass_target = 1.0 if active else 0.0
	_apply_lowpass(0)

# Round start/end and menu: the filter is off at once.
func reset_low_hp() -> void:
	lowpass_target = 0.0
	lowpass_amount = 0.0
	_apply_lowpass(0)

func _apply_lowpass(delta: float) -> void:
	if lowpass==null: return
	lowpass_amount = move_toward(lowpass_amount,lowpass_target,delta/maxf(float(settings.Low_hp_fade_sec),0.000001))
	# Exponential sweep sounds even between 20.5kHz (open) and the target cutoff.
	lowpass.cutoff_hz = LOWPASS_OPEN_HZ*pow(float(settings.Low_hp_bgm_lowpass_hz)/LOWPASS_OPEN_HZ,lowpass_amount)
	var index := lowpass_index()
	if index>=0: AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("BGM"),index,lowpass_amount>0)

func request(id: String) -> bool:
	request_counts[id] = int(request_counts.get(id,0))+1
	var semitones := 0
	if id=="xp_pickup":
		xp_semitones = mini(xp_semitones+1,int(settings.Xp_pitch_max_semitones)) if clock-xp_last_pickup<=float(settings.Xp_pitch_reset_sec) else 0
		xp_last_pickup = clock
		semitones = xp_semitones
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
	free.pitch_scale = pow(2.0,semitones/12.0)*(1+rng.randf_range(-float(row.pitch),float(row.pitch)))
	free.set_meta(&"sound",id)
	play_serial += 1
	free.set_meta(&"play_id",play_serial)
	last_voice = free
	last_play_id = play_serial
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

# 0 mutes the bus; 100 is the CSV default volume (Sound_bgm_db / Sound_sfx_db).
func set_level(bus: String, level: float) -> void:
	if not levels.has(bus): return
	levels[bus] = clampf(level,0,100)
	var default_db := float(settings.Sound_bgm_db if bus=="BGM" else settings.Sound_sfx_db)
	set_volume(bus,default_db+linear_to_db(maxf(levels[bus],0.0001)/100.0))

func update_buses(paused: bool) -> void:
	var bgm := AudioServer.get_bus_index("BGM")
	var sfx := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(bgm,bgm_db+(linear_to_db(float(settings.Sound_pause_bgm_ratio)) if paused else 0))
	AudioServer.set_bus_volume_db(sfx,sfx_db)
	AudioServer.set_bus_mute(bgm,float(levels.BGM)<=0)
	AudioServer.set_bus_mute(sfx,float(levels.SFX)<=0)

func choice_pause() -> bool:
	for view in get_tree().get_nodes_in_group("audio_choice_ui"):
		if view.visible and view.manager.active: return true
	return false

# handles: [[voice, play_id], ...]. After delay seconds, fade those exact plays out over fade seconds
# and stop them; a voice already reused for another play is left alone.
func fade_handles(handles: Array, delay: float, fade: float) -> void:
	if handles.is_empty(): return
	fades.append({"handles":handles.duplicate(),"delay":maxf(delay,0),"fade":maxf(fade,0.000001),"age":0.0,"base":{}})

func handle_playing(handle: Array) -> bool:
	var voice: AudioStreamPlayer = handle[0]
	return is_instance_valid(voice) and voice.playing and int(voice.get_meta(&"play_id",0))==int(handle[1])

func _advance_fades(delta: float) -> void:
	for index in range(fades.size()-1,-1,-1):
		var entry: Dictionary = fades[index]
		entry.age += delta
		if entry.age<entry.delay: continue
		var t := clampf((entry.age-entry.delay)/entry.fade,0,1)
		for i in range(entry.handles.size()):
			var handle: Array = entry.handles[i]
			if not handle_playing(handle): continue
			var voice: AudioStreamPlayer = handle[0]
			if not entry.base.has(i): entry.base[i] = voice.volume_db
			if t>=1:
				voice.stop()
				voice.set_meta(&"sound","")
			else: voice.volume_db = float(entry.base[i])+linear_to_db(maxf(1.0-t,0.0001))
		if t>=1: fades.remove_at(index)

func _process(delta: float) -> void:
	clock+=delta
	if not fades.is_empty(): _advance_fades(delta)
	if lowpass_amount!=lowpass_target: _apply_lowpass(delta)
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
