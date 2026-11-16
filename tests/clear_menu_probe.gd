extends "res://tests/p0_runner.gd"
# CRASH-01 probe: runs only the S9 flow test (death result -> retry -> pause to menu -> final boss clear ->
# confirm -> menu -> start again) in a fresh process. Run with `python tests/run_headless.py <task> probe <n>`.
# A 0xC0000005 exit without FAIL lines is the crash this probe looks for.
func _run() -> void:
	await preload("res://tests/flow_p0.gd").new().run(self)
	print("PROBE RESULT: %d checks, %d failures" % [checks,failures])
	await preload("res://tests/test_exit.gd").finish("clear_menu_probe",0 if failures==0 else 1)
