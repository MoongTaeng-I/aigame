extends RefCounted

# Fresh done marker decides success; native exit is recorded by Python. No retry.
static func execute(arguments: PackedStringArray, output: Array, log: String) -> int:
	output.clear()
	var launcher := PackedStringArray([ProjectSettings.globalize_path("res://tests/probe_process.py"),OS.get_executable_path(),ProjectSettings.globalize_path(log)])
	launcher.append_array(arguments)
	return OS.execute("python",launcher,output,true,false)
