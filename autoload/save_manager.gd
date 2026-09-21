extends Node

const SAVE_PATH = "user://savegame.json"

signal game_saved()
signal game_loaded()

func _ready() -> void:
  process_mode = Node.PROCESS_MODE_ALWAYS
  load_game()

func save_game() -> void:
  var save_data = GameManager.get_save_data()
  save_data.merge(WeaponManager.get_save_data())

  var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
  if file:
    var json_string = JSON.stringify(save_data, "\t")
    file.store_string(json_string)
    file.close()
    game_saved.emit()

func load_game() -> void:
  if not FileAccess.file_exists(SAVE_PATH):
    return

  var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
  if file:
    var json_string = file.get_as_text()
    file.close()

    var json = JSON.new()
    var parse_result = json.parse(json_string)
    if parse_result == OK:
      var save_data = json.get_data()
      GameManager.load_save_data(save_data)
      WeaponManager.load_save_data(save_data)
      game_loaded.emit()

func delete_save() -> void:
  if FileAccess.file_exists(SAVE_PATH):
    DirAccess.remove_absolute(SAVE_PATH)

func has_save() -> bool:
  return FileAccess.file_exists(SAVE_PATH)

func reset_all_data() -> void:
  # Delete save file
  delete_save()
  # Reset GameManager
  GameManager.money = 0
  for type in GameManager.upgrade_levels:
    GameManager.upgrade_levels[type] = 0
  for type in GameManager.upgrade_sub_levels:
    GameManager.upgrade_sub_levels[type] = 0
  GameManager.selected_world = 0
  GameManager.unlocked_worlds = [0]
  GameManager.owned_keys = []
  GameManager.has_potion = false
  GameManager.owned_gems = 0
  GameManager.unlocked_gem_skills = []
  GameManager.world_strength_levels = {}
  GameManager.collected_gem_levels = {}
  GameManager.has_ever_transcended = false
  GameManager.bgm_enabled = true
  GameManager.sfx_enabled = true
  GameManager.vibration_enabled = true
  GameManager.money_changed.emit(0)
  # Reset WeaponManager
  WeaponManager.current_weapon_level = 0
  WeaponManager.weapon_changed.emit(0)
