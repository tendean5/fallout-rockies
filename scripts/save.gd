# Save/load — JSON in user://fallout_rockies.save.json
class_name FalloutSave

const SAVE_PATH := "user://fallout_rockies.save.json"

static func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	if text.is_empty():
		return {}
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	if int(data.get("version", -1)) != 1:
		return {}
	return data

static func write_game(data: Dictionary) -> Dictionary:
	var existing := load_game()
	var out := {"version": 1}
	for k in existing:
		out[k] = existing[k]
	for k in data:
		out[k] = data[k]
	out["savedAt"] = Time.get_datetime_string_from_system()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return {}
	f.store_string(JSON.stringify(out))
	f.close()
	return out

static func clear() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
