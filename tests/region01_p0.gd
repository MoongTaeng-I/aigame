extends RefCounted
# REGION-01: region.csv drives each region's look/music/content; spawn, timeline and scaling rows are chosen by
# Region_id; region 1 is unchanged (identity probe against the 623a1cb baseline); a test-only region added as
# rows only (tests/fixtures/region_test) works without code changes.

const Flow = preload("res://scripts/game_flow.gd")
const FlowData = preload("res://scripts/flow_data.gd")
const FIXTURE := "res://tests/fixtures/region_test/"
const REGION_FILES := ["region.csv","spawn.csv","stage_timeline.csv","enemy_scaling.csv"]
var t: SceneTree

func run(tree: SceneTree) -> void:
	t = tree
	var before: int = t.checks
	var failed: int = t.failures
	data_checks()
	await round_checks()
	await flow_checks()
	probes()
	print("REGION-01 NEW RESULT: %d checks, %d failures" % [t.checks-before,t.failures-failed])

# Actual data plus the fixture rows appended, as a new region would be added to the CSVs.
func merged_store() -> CsvDataStore:
	var store: CsvDataStore = t._store()
	var error := store.load_all()
	var rows: CsvDataStore = t._store()
	for file in REGION_FILES:
		var text := FileAccess.get_file_as_string(FIXTURE+file)
		var fixture_error := rows.load_text(file,text)
		if error.is_empty(): error = fixture_error
		var line := 1000
		for id in rows.get_table(file):
			store.tables[file][id] = rows.get_row(file,id)
			store.source_lines[file][id] = line
			line += 1
	t.check(error.is_empty(),"REGION01 actual data and the test region fixture load: "+error)
	return store

func validate(store: CsvDataStore) -> String:
	var main: Node = load("res://scripts/main.gd").new()
	var error: String = main.validate_store(store)
	main.free()
	return error

func case(mutate: Callable) -> String:
	var store := merged_store()
	mutate.call(store)
	return validate(store)

func data_checks() -> void:
	var real: CsvDataStore = t._store()
	t.check(real.load_all().is_empty() and validate(real).is_empty(),"REGION01 actual data validates with the new region columns and Region_id")
	var r1: Dictionary = real.get_row("region.csv","region_01")
	t.check(r1.Card_image=="res://assets/ui/region_ice.png" and r1.Ground_texture=="res://assets/art/env/snow_ground.png" and is_equal_approx(r1.Ground_brightness,0.93) and r1.Props_texture=="res://assets/art/env/env_props.png" and r1.Props_cols==6 and r1.World_tint=="#eef2fa" and r1.Weather=="snow" and is_equal_approx(r1.Snow_alpha,0.65) and is_equal_approx(r1.Fog_strength,0.45) and r1.Bgm_stage=="bgm_stage01" and r1.Bgm_boss=="bgm_boss" and r1.Forest_seed==11015,"REGION01 region_01 carries the values the code used before")
	var r2: Dictionary = real.get_row("region.csv","region_02")
	var blank := true
	for column in FlowData.REGION_COLUMNS: blank = blank and r2[column]==null
	t.check(r2.Locked and blank,"REGION01 locked region_02 leaves every content column blank and still validates")
	for file in ["spawn.csv","stage_timeline.csv","enemy_scaling.csv"]:
		t.check(real.get_table(file).values().all(func(row: Dictionary) -> bool: return row.Region_id=="region_01"),"REGION01 every %s row is region_01" % file)
	t.check(validate(merged_store()).is_empty(),"REGION01 data with the test region rows added validates")
	var cases := [
		["World_tint",func(s: CsvDataStore) -> void: s.tables["region.csv"].region_test.World_tint = null,["region.csv","World_tint","값이 필요"]],
		["Ground_texture",func(s: CsvDataStore) -> void: s.tables["region.csv"].region_test.Ground_texture = "res://assets/none.png",["region.csv","Ground_texture","이미지"]],
		["Card_image",func(s: CsvDataStore) -> void: s.tables["region.csv"].region_test.Card_image = "res://assets/none.png",["Card_image"]],
		["Props_texture",func(s: CsvDataStore) -> void: s.tables["region.csv"].region_test.Props_texture = "res://assets/none.png",["Props_texture"]],
		["Bgm_stage",func(s: CsvDataStore) -> void: s.tables["region.csv"].region_test.Bgm_stage = "bgm_none",["Bgm_stage","sound.csv"]],
		["Bgm_boss",func(s: CsvDataStore) -> void: s.tables["region.csv"].region_test.Bgm_boss = "bgm_none",["Bgm_boss"]],
		["Weather",func(s: CsvDataStore) -> void: s.tables["region.csv"].region_test.Weather = "rain",["Weather"]],
		["Snow_alpha",func(s: CsvDataStore) -> void: s.tables["region.csv"].region_test.Snow_alpha = 1.5,["Snow_alpha"]],
		["Fog_strength",func(s: CsvDataStore) -> void: s.tables["region.csv"].region_test.Fog_strength = -0.1,["Fog_strength"]],
		["Ground_brightness",func(s: CsvDataStore) -> void: s.tables["region.csv"].region_test.Ground_brightness = 1.2,["Ground_brightness"]],
		["Props_cols",func(s: CsvDataStore) -> void: s.tables["region.csv"].region_test.Props_cols = 3,["Props_cols"]],
		["Forest_seed",func(s: CsvDataStore) -> void: s.tables["region.csv"].region_test.Forest_seed = null,["Forest_seed"]],
		["Region_id reference",func(s: CsvDataStore) -> void: s.tables["spawn.csv"].spawn_01_rt.Region_id = "region_zz",["spawn.csv","Region_id","region_zz"]],
		["no spawn rows",drop_test_rows.bind(["spawn.csv"]),["spawn.csv","region_test","생성 행"]],
		["no time-0 scaling",func(s: CsvDataStore) -> void: s.tables["enemy_scaling.csv"].erase("scaling_00_rt"),["enemy_scaling.csv","시각0"]],
		["two time-0 scaling",func(s: CsvDataStore) -> void: s.tables["enemy_scaling.csv"].scaling_01_rt.Time_start = 0.0,["enemy_scaling.csv","Time_start"]],
		["no final boss",func(s: CsvDataStore) -> void: s.tables["stage_timeline.csv"].erase("timeline_final_boss_rt"),["stage_timeline.csv","region_test","최종 보스"]],
	]
	for item in cases:
		var error := case(item[1])
		var ok := not error.is_empty()
		for part in item[2]: ok = ok and error.contains(part)
		t.check(ok,"REGION01 open region rejects %s: %s" % [item[0],error])
	var locked := case(lock_test_region)
	t.check(locked.is_empty(),"REGION01 a locked region needs no content values or rows: "+locked)
	var store := merged_store()
	t.check(FlowData.rows_for(store.get_table("spawn.csv"),"region_01").keys()==real.get_table("spawn.csv").keys() and FlowData.rows_for(store.get_table("spawn.csv"),"region_test").keys().all(func(i: String) -> bool: return i.ends_with("_rt")),"REGION01 rows are picked by Region_id in file order")
	t.check(FlowData.default_region(store)=="region_01","REGION01 a round without a chosen region uses the first open region")

func drop_test_rows(store: CsvDataStore, files: Array) -> void:
	for file in files:
		for id in store.tables[file].keys():
			if String(id).ends_with("_rt"): store.tables[file].erase(id)

func lock_test_region(store: CsvDataStore) -> void:
	store.tables["region.csv"].region_test.Locked = true
	for column in FlowData.REGION_COLUMNS: store.tables["region.csv"].region_test[column] = null
	drop_test_rows(store,["spawn.csv","stage_timeline.csv","enemy_scaling.csv"])

func make_round(store: CsvDataStore, region_id: String) -> Node:
	var main: Node = load("res://main.tscn").instantiate()
	main.supplied_data = store
	main.region_id = region_id
	t.root.add_child(main)
	return main

func round_checks() -> void:
	var store := merged_store()
	var main := make_round(store,"")
	var n: Dictionary = main.round_nodes
	var map: Node2D = n.map
	var weather: Node = map.get_node_or_null("SnowWeather")
	t.check(main.region_id=="region_01" and map.ground.resource_path=="res://assets/art/env/snow_ground.png" and map.props_texture.resource_path=="res://assets/art/env/env_props.png" and map.modulate==Color("#eef2fa") and weather!=null and is_equal_approx(weather.settings.Snow_alpha,0.65) and is_equal_approx(weather.settings.Fog_strength,0.45),"REGION01 region 1 map: ground, props, tint, snow and fog from region.csv")
	t.check(n.manager.bgm_stage=="bgm_stage01" and n.manager.bgm_boss=="bgm_boss","REGION01 region 1 stage/boss music from region.csv")
	t.check(n.manager._spawn_records.keys()==FlowData.rows_for(store.get_table("spawn.csv"),"region_01").keys() and n.director.timeline.all(func(row: Dictionary) -> bool: return row.Region_id=="region_01") and n.manager._scaling_rows.all(func(row: Dictionary) -> bool: return row.Region_id=="region_01"),"REGION01 region 1 round uses only region_01 spawn, timeline and scaling rows")
	main.free()
	main = make_round(store,"region_test")
	n = main.round_nodes
	map = n.map
	t.check(map.modulate==Color("#c8d8ff") and map.get_node_or_null("SnowWeather")==null,"REGION01 test region (rows only): tint #c8d8ff and no snow/fog layer")
	t.check(n.manager.bgm_stage=="bgm_title" and n.manager._spawn_records.keys()==FlowData.rows_for(store.get_table("spawn.csv"),"region_test").keys() and n.manager._spawn_records.size()==5,"REGION01 test region uses its own spawn rows and Bgm_stage")
	t.check(n.director.timeline.size()==3 and n.director.timeline.all(func(row: Dictionary) -> bool: return row.Region_id=="region_test") and n.manager._scaling_rows.size()==4 and n.manager._scaling_rows.all(func(row: Dictionary) -> bool: return row.Region_id=="region_test"),"REGION01 test region uses its own timeline and scaling rows")
	# Boss music crossfade target and the return to the region's stage music.
	var audio: Node = t.root.get_node("GameAudio")
	for child in map.get_children(): if child!=n.director: child.set_physics_process(false)
	n.manager._elapsed_seconds = 60
	n.director.advance(60,0)
	n.manager._elapsed_seconds = 63.5
	n.director.advance(63.5,0)
	var boss: Variant = n.director.actor
	t.check(is_instance_valid(boss) and n.director.phase=="active" and audio.music_id=="bgm_boss","REGION01 test region boss entry plays its Bgm_boss")
	if is_instance_valid(boss): boss.apply_damage(boss.hp)
	t.check(audio.music_id=="bgm_title","REGION01 boss death returns to the test region's Bgm_stage (bgm_title)")
	main.free()
	t.paused = false
	audio.music("")
	await t.process_frame

func flow_checks() -> void:
	var audio: Node = t.root.get_node("GameAudio")
	var flow := Flow.new()
	t.root.add_child(flow)
	var until := Time.get_ticks_msec()+15000
	while (flow.state=="loading" or flow.ui.menu_locked()) and Time.get_ticks_msec()<until: await t.process_frame
	t.check(flow.state=="menu","REGION01 flow reaches the menu")
	# Cards: region 1 picture; the locked region 2 has no picture and shows region 1's, darkened, with the lock.
	flow.region_index = 0
	flow.refresh_region()
	var card: Control = flow.ui.cards[1]
	t.check(card.get_node("Art").texture.resource_path=="res://assets/ui/region_ice.png" and not card.get_node("Lock").visible,"REGION01 region 1 card picture from Card_image")
	flow.region_index = 1
	flow.refresh_region()
	t.check(card.get_node("Art").texture.resource_path=="res://assets/ui/region_ice.png" and card.get_node("Art").material==flow.ui.art_locked and card.get_node("Lock").visible,"REGION01 blank Card_image of the locked region shows region 1 picture darkened with the lock")
	# Start region 1 -> its stage music and Region_id; retry keeps the region; clear time per region.
	flow.region_index = 0
	flow.refresh_region()
	flow.start_region()
	t.check(flow.session.region_id=="region_01" and flow.session.region.Id=="region_01" and audio.music_id=="bgm_stage01","REGION01 start passes region_01 to the round and plays its Bgm_stage")
	flow.session.round_ended.emit({"cleared":false,"seconds":12.0,"level":1,"kills":0,"shadows":[]})
	flow.start_region()
	t.check(flow.state=="playing" and flow.session.region_id=="region_01","REGION01 retry starts the same region")
	flow.session.round_ended.emit({"cleared":true,"seconds":321.0,"level":3,"kills":9,"shadows":[]})
	t.check(is_equal_approx(float(flow.best_times.get("region_01",-1)),321.0) and not flow.best_times.has("region_02") and flow.best_times.size()==1,"REGION01 clear time is recorded for that region only")
	flow.show_menu()
	# A region added as rows only (test fixture, not release data) can be chosen and started.
	var rows: CsvDataStore = t._store()
	for file in REGION_FILES:
		rows.load_text(file,FileAccess.get_file_as_string(FIXTURE+file))
		for id in rows.get_table(file): flow.data_store.tables[file][id] = rows.get_row(file,id)
	flow.regions.append(flow.data_store.get_row("region.csv","region_test"))
	flow.region_index = flow.regions.size()-1
	flow.refresh_region()
	t.check(not flow.ui.start_button.disabled and card.get_node("Art").material==null,"REGION01 test region card is open")
	flow.start_region()
	t.check(flow.session.region_id=="region_test" and audio.music_id=="bgm_title" and flow.session.round_nodes.map.modulate==Color("#c8d8ff"),"REGION01 test region starts with its music and tint")
	flow.show_menu()
	for file in REGION_FILES:
		for id in rows.get_table(file): flow.data_store.tables[file].erase(id)
	flow.queue_free()
	await t.process_frame

func probe(script: String, state_file: String, extra: Array) -> Dictionary:
	var output: Array = []
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://.local/"+state_file))
	var log := "res://.local/godot_logs/%s-%d.log" % [script.get_file().get_basename(),Time.get_ticks_usec()]
	var arguments := PackedStringArray(["--headless"]+extra+["--path",ProjectSettings.globalize_path("res://"),"--script",script,"--log-file",ProjectSettings.globalize_path(log)])
	var code := preload("res://tests/godot_probe_process.gd").execute(arguments,output,log)
	var file := FileAccess.open("res://.local/"+script.get_file().get_basename()+".out",FileAccess.WRITE)
	file.store_string("\n".join(output))
	file.close()
	var state: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.local/"+state_file))
	return {"code":code,"state":state if state is Dictionary else {}}

func probes() -> void:
	var identity := probe("tests/region01_identity_probe.gd","region01-identity-state.json",["--fixed-fps","60"])
	t.check(identity.code==0 and identity.state.get("identical",false),"REGION01 region 1 identical to 623a1cb: spawns, enemy positions, bosses, hp, kills, sounds, music, props, look: "+str(identity.state))
	var error := probe("tests/region01_error_probe.gd","region01-error-state.json",[])
	t.check(error.code==0 and error.state.get("label_matches",false) and error.state.get("no_session",false),"REGION01 invalid open region shows the data error screen and never the menu: "+str(error.state))
