extends RefCounted

func run(t: SceneTree) -> void:
	var sources: Dictionary = {}
	# Every literal in game scripts includes all UI templates, toast messages,
	# skill labels and dynamically formatted punctuation; no Unicode range filter.
	var expression := RegEx.new()
	expression.compile("\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'")
	for name in DirAccess.get_files_at("res://scripts"):
		if not name.ends_with(".gd"): continue
		var source := "res://scripts/"+name
		for match in expression.search_all(FileAccess.get_file_as_string(source)):
			var value: String = match.get_string().substr(1,match.get_string().length()-2).c_unescape()
			collect(sources,value,source)
	for name in DirAccess.get_files_at("res://data"):
		if not name.ends_with(".csv"): continue
		var source := "res://data/"+name
		var file := FileAccess.open(source,FileAccess.READ)
		var headers := file.get_csv_line()
		while not file.eof_reached():
			var row := file.get_csv_line()
			for i in range(mini(headers.size(),row.size())):
				if headers[i].ends_with("_ko") or headers[i] in ["Locked_text","Text","Description"]: collect(sources,row[i],source)
		file.close()
	var missing: Array = []
	for code in sources:
		if not preload("res://scripts/system_ui.gd").BOLD.has_char(code) or not preload("res://scripts/system_ui.gd").BLACK.has_char(code):
			missing.append({"char":String.chr(code),"unicode":"U+%04X" % code,"source":sources[code]})
	t.check(missing.is_empty(),"FIX01 complete script/UI/CSV glyph coverage (both supplied fonts): "+JSON.stringify(missing))

func collect(sources: Dictionary, text: String, source: String) -> void:
	for c in text:
		var code := c.unicode_at(0)
		if code>=32: sources[code] = source
