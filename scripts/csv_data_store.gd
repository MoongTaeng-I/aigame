extends RefCounted
class_name CsvDataStore

var schemas: Dictionary = {}
var tables: Dictionary = {}
var source_lines: Dictionary = {}

func register_schema(file_name: String, column_types: Dictionary) -> void:
	schemas[file_name] = column_types.duplicate(true)

func load_all() -> String:
	var plan := prepare_load()
	if not String(plan.error).is_empty(): return plan.error
	for file_name in plan.files:
		var error_message := _load_file(file_name)
		if not error_message.is_empty():
			tables.clear()
			return error_message
	return ""

# The loading screen uses the same discovery/validation and parser one file per frame.
func prepare_load() -> Dictionary:
	tables.clear()
	source_lines.clear()
	var data_dir := DirAccess.open("res://data")
	if data_dir == null:
		return {"files":[],"error":_format_error("res://data", 1, "Id", "데이터 폴더를 열 수 없습니다.")}
	var file_names: Array[String] = []
	data_dir.list_dir_begin()
	var entry := data_dir.get_next()
	while entry != "":
		if not data_dir.current_is_dir() and entry.to_lower().ends_with(".csv"):
			file_names.append(entry)
		entry = data_dir.get_next()
	data_dir.list_dir_end()
	file_names.sort()
	for required_name in schemas.keys():
		if not file_names.has(String(required_name)):
			return {"files":[],"error":_format_error("res://data/" + String(required_name), 1, "Id", "필요한 CSV 파일이 없습니다.")}
	for file_name in file_names:
		if not schemas.has(file_name):
			return {"files":[],"error":_format_error("res://data/" + file_name, 1, "Id", "등록된 테이블 스키마가 없습니다.")}
	return {"files":file_names,"error":""}

func get_row(file_name: String, row_id: String) -> Dictionary:
	if not tables.has(file_name):
		return {}
	return tables[file_name].get(row_id, {})

func get_table(file_name: String) -> Dictionary:
	return tables.get(file_name, {})

func get_source_line(file_name: String, row_id: String) -> int:
	return int(source_lines.get(file_name, {}).get(row_id, 0))

func _load_file(file_name: String) -> String:
	var path := "res://data/" + file_name
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _format_error(path, 1, "Id", "파일을 읽을 수 없습니다. 오류 코드: %d" % FileAccess.get_open_error())
	var text := file.get_as_text()
	file.close()
	return load_text(file_name, text)

func load_text(file_name: String, text: String) -> String:
	# Use the same parser and schema validation for files and in-memory checks.
	var path := "res://data/" + file_name
	var schema: Dictionary = schemas[file_name]
	if not text.is_empty() and text.unicode_at(0) == 0xFEFF:
		text = text.substr(1)
	var parsed := _parse_csv(text, path)
	if not String(parsed.get("error", "")).is_empty():
		return String(parsed["error"])
	var rows: Array = parsed["rows"]
	var line_numbers: Array = parsed["line_numbers"]
	if rows.is_empty():
		return _format_error(path, 1, "Id", "CSV 헤더가 없습니다.")
	var headers: Array = rows[0]
	if headers.is_empty() or headers[0] != "Id":
		return _format_error(path, 1, "Id", "첫 번째 열은 Id여야 합니다.")
	var header_indexes: Dictionary = {}
	for index in range(headers.size()):
		var header := String(headers[index])
		if header.is_empty():
			return _format_error(path, 1, "열 %d" % (index + 1), "열 이름이 비어 있습니다.")
		if header_indexes.has(header):
			return _format_error(path, 1, header, "열 이름이 중복되었습니다.")
		header_indexes[header] = index
	for column_name in schema.keys():
		if not header_indexes.has(String(column_name)):
			return _format_error(path, 1, String(column_name), "필요한 열이 없습니다.")
	var records: Dictionary = {}
	var row_source_lines: Dictionary = {}
	for row_index in range(1, rows.size()):
		var row: Array = rows[row_index]
		var source_line := int(line_numbers[row_index])
		if row.size() != headers.size():
			var problem_column := "열 개수"
			if row.size() < headers.size():
				problem_column = String(headers[row.size()])
			return _format_error(path, source_line, problem_column, "행의 값 개수가 헤더와 다릅니다.")
		var record: Dictionary = {}
		for column_index in range(headers.size()):
			var column_name := String(headers[column_index])
			var raw_value := String(row[column_index])
			var kind: Variant = schema.get(column_name, "String")
			var conversion := _convert_value(raw_value, kind)
			if not bool(conversion["ok"]):
				var error_detail := String(conversion.get("error", "자료형이 %s와 맞지 않습니다: %s" % [_type_label(kind), raw_value]))
				return _format_error(path, source_line, column_name, error_detail)
			record[column_name] = conversion["value"]
		var row_id := String(record.get("Id", ""))
		if row_id.is_empty():
			return _format_error(path, source_line, "Id", "Id 값이 비어 있습니다.")
		if records.has(row_id):
			return _format_error(path, source_line, "Id", "같은 파일 안에서 Id가 중복되었습니다: %s" % row_id)
		records[row_id] = record
		row_source_lines[row_id] = source_line
	tables[file_name] = records
	source_lines[file_name] = row_source_lines
	return ""

func _convert_value(raw_value: String, kind: Variant) -> Dictionary:
	if kind is Dictionary and String(kind.get("type", "")) == "Optional":
		if raw_value.is_empty():
			return {"ok": true, "value": null}
		return _convert_value(raw_value, kind.get("inner", "String"))
	if kind is Dictionary and String(kind.get("type", "")) == "Enum":
		var enum_values: Dictionary = kind.get("values", {})
		if enum_values.has(raw_value):
			return {"ok": true, "value": int(enum_values[raw_value])}
		var allowed_values := PackedStringArray()
		for value in enum_values.keys():
			allowed_values.append(String(value))
		allowed_values.sort()
		return {"ok": false, "value": null, "error": "자료형이 Enum과 맞지 않습니다: %s (허용값: %s)" % [raw_value, ", ".join(allowed_values)]}
	var kind_name := String(kind)
	match kind_name:
		"String":
			return {"ok": true, "value": raw_value}
		"Int":
			if raw_value.strip_edges().is_valid_int():
				return {"ok": true, "value": raw_value.strip_edges().to_int()}
		"Float":
			if raw_value.strip_edges().is_valid_float():
				return {"ok": true, "value": raw_value.strip_edges().to_float()}
		"Bool":
			if raw_value == "0":
				return {"ok": true, "value": false}
			if raw_value == "1":
				return {"ok": true, "value": true}
		"Path":
			if raw_value.begins_with("res://") and not raw_value.contains("\\"):
				return {"ok": true, "value": raw_value}
	return {"ok": false, "value": null}

func _type_label(kind: Variant) -> String:
	if kind is Dictionary:
		return String(kind.get("type", "String"))
	return String(kind)

func _parse_csv(text: String, file_path: String) -> Dictionary:
	var rows: Array = []
	var line_numbers: Array[int] = []
	var row: Array[String] = []
	var field := ""
	var in_quotes := false
	var line_number := 1
	var row_start_line := 1
	var index := 0
	while index < text.length():
		var character := text.substr(index, 1)
		if in_quotes:
			if character == "\"":
				if index + 1 < text.length() and text.substr(index + 1, 1) == "\"":
					field += "\""
					index += 1
				else:
					in_quotes = false
			elif character == "\n":
				field += "\n"
				line_number += 1
			elif character == "\r":
				field += "\n"
				if index + 1 < text.length() and text.substr(index + 1, 1) == "\n":
					index += 1
				line_number += 1
			else:
				field += character
		elif character == "\"":
			if not field.is_empty():
				return {"rows": rows, "line_numbers": line_numbers, "error": _format_error(file_path, line_number, "CSV 문법", "따옴표가 잘못된 위치에 있습니다.")}
			in_quotes = true
		elif character == ",":
			row.append(field)
			field = ""
		elif character == "\n" or character == "\r":
			row.append(field)
			if not (row.size() == 1 and row[0].is_empty()):
				rows.append(row)
				line_numbers.append(row_start_line)
			row = []
			field = ""
			if character == "\r" and index + 1 < text.length() and text.substr(index + 1, 1) == "\n":
				index += 1
			line_number += 1
			row_start_line = line_number
		else:
			field += character
		index += 1
	if in_quotes:
		return {"rows": rows, "line_numbers": line_numbers, "error": _format_error(file_path, row_start_line, "CSV 문법", "따옴표가 닫히지 않았습니다.")}
	if not row.is_empty() or not field.is_empty():
		row.append(field)
		rows.append(row)
		line_numbers.append(row_start_line)
	return {"rows": rows, "line_numbers": line_numbers, "error": ""}

func _format_error(file_path: String, row_number: int, column_name: String, detail: String) -> String:
	return "%s, 행 %d, 열 %s: %s" % [file_path, row_number, column_name, detail]
