extends RefCounted

# Approved AGENTS policy; only execution/capture, never probe expectations.
static func execute(arguments: PackedStringArray, output: Array, log: String) -> int:
	var code := -1
	for execution in range(1,3):
		output.clear()
		code = OS.execute(OS.get_executable_path(),arguments,output,true)
		var text := "\n".join(output)
		var prefix := log.trim_suffix(".log")+"-execution"+str(execution)
		var raw := FileAccess.open(prefix+".out",FileAccess.WRITE)
		raw.store_string(text)
		raw.close()
		var metadata := FileAccess.open(prefix+".json",FileAccess.WRITE)
		metadata.store_string(JSON.stringify({"exit_code":code,"execution":execution,"command":arguments,"stdout_stderr":prefix+".out"}))
		metadata.close()
		print("GODOT PROBE execution=",execution," exit_code=",code," raw=",prefix)
		if (code&0xffffffff)==0xc0000005 and execution==1 and not text.contains("FAIL") and not text.contains("SCRIPT ERROR") and not text.contains("Parse Error"): continue
		break
	if (code&0xffffffff)==0xc0000005: Engine.get_main_loop().quit(1)
	return code
