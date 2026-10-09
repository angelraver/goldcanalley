extends Node

# Logger reutilizable para generar highlights/promos a partir del gameplay.
# Cada ejecución crea una sesión en user://promo_recordings/<session_id>/events.jsonl

var session_id: String = ""
var session_dir: String = ""
var events_path: String = ""
var _started_at_msec: int = 0
var _file: FileAccess = null

var _game_time: float = 0.0

func _ready() -> void:
	start_session()

func _process(delta: float) -> void:
	_game_time += delta
	
func recording_started() -> void:
	event("recording_start")
	print("[PROMO] 🎥 Recording started")
	
func start_session(metadata: Dictionary = {}) -> void:
	stop_session()
	_started_at_msec = Time.get_ticks_msec()
	_game_time = 0.0
	var now := Time.get_datetime_dict_from_system()
	session_id = "%04d-%02d-%02d_%02d-%02d-%02d" % [now.year, now.month, now.day, now.hour, now.minute, now.second]
	session_dir = "user://promo_recordings/" + session_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(session_dir))
	events_path = session_dir + "/events.jsonl"
	_file = FileAccess.open(events_path, FileAccess.WRITE)
	if _file == null:
		push_error("PromoLogger: no se pudo crear " + events_path)
		return
	var base_metadata := {
		"session_id": session_id,
		"started_at": Time.get_datetime_string_from_system(),
		"project": ProjectSettings.get_setting("application/config/name", "Godot Project")
	}
	base_metadata.merge(metadata, true)
	var meta_file := FileAccess.open(session_dir + "/session.json", FileAccess.WRITE)
	if meta_file:
		meta_file.store_string(JSON.stringify(base_metadata, "\t"))
		meta_file.close()
	print("[PROMO] Session: ", session_id)
	print("[PROMO] Folder: ", ProjectSettings.globalize_path(session_dir))
	event("session_start", base_metadata)

func event(type: String, data: Dictionary = {}) -> void:
	if _file == null:
		return
	var entry := {
		"time": _game_time,
		"event": type,
		"data": data
	}
	_file.store_line(JSON.stringify(entry))
	_file.flush()
	print("[PROMO] ", JSON.stringify(entry))

func stop_session() -> void:
	if _file != null:
		event("session_end")
		_file.close()
		_file = null

func get_session_dir_absolute() -> String:
	return ProjectSettings.globalize_path(session_dir)

func _exit_tree() -> void:
	stop_session()
