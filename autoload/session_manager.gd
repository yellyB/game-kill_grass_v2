extends Node
## SessionManager (v2 린) — 세션 시작/종료/메뉴 복귀.
signal session_started()
signal session_ending()
signal session_ended()

var is_session_active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_session_active:
			end_session()
		get_tree().quit()

func start_session(world: int = -1) -> void:
	if is_session_active:
		return
	if world >= 0:
		GameManager.selected_world = world
	is_session_active = true
	GameManager.reset_session_data()
	session_started.emit()
	get_tree().change_scene_to_file("res://scenes/core/main.tscn")

func end_session(do_save: bool = true) -> void:
	if not is_session_active:
		return
	session_ending.emit()
	if do_save:
		GameManager.finalize_session()
		SaveManager.save_game()
	else:
		GameManager.reset_session_data()
	is_session_active = false
	session_ended.emit()

func quit_to_menu() -> void:
	end_session(false)
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
