extends SceneTree
# REGION-01 identity probe (run with --fixed-fps 60 so the 2,400 physics steps do not wait for real time):
# the region 1 scenario must equal the baseline recorded from the pre-REGION-01 commit 623a1cb.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var result: Dictionary = await preload("res://tests/region01_identity.gd").run(self)
	var text := JSON.stringify(result,"	",true)
	var baseline := FileAccess.get_file_as_string("res://tests/fixtures/region01_identity_baseline.json")
	var file := FileAccess.open("res://.local/region01-identity-result.json",FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var expected: Variant = JSON.parse_string(baseline)
	var differing: Array = []
	if expected is Dictionary:
		for key in expected:
			if JSON.stringify(expected[key],"",true)!=JSON.stringify(result.get(key),"",true): differing.append(key)
	var state := {"identical":text==baseline,"differing":differing,"samples":result.samples.size(),"sounds":result.sounds.size(),"bosses":result.bosses.size(),"props":result.props.size()}
	file = FileAccess.open("res://.local/region01-identity-state.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(state))
	file.close()
	await preload("res://tests/test_exit.gd").finish("region01_identity_probe",0 if text==baseline else 1)
