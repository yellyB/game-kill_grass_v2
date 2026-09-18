extends Node
## SaveManager (v2 린) — user:// JSON 저장/불러오기. Godot가 플랫폼별 경로 자동 처리.
const SAVE_PATH := "user://savegame.json"

signal game_saved()
signal game_loaded()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()

func save_game() -> void:
	var data := GameManager.get_save_data()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		game_saved.emit()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) == OK:
		GameManager.load_save_data(json.get_data())
		game_loaded.emit()

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func reset_all_data() -> void:
	delete_save()
	GameManager.money = 0
	for sk in GameManager.upgrade_levels:
		GameManager.upgrade_levels[sk] = 0
	GameManager.selected_world = 0
	GameManager.unlocked_worlds = [0]
	GameManager.money_changed.emit(0)
