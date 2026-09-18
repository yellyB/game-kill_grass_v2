extends CanvasLayer
## 공유 설정 팝업 — 메뉴/인게임 공용. 배경음/효과음 토글 + 데이터 초기화 + 닫기.
## paused 대응(PROCESS_MODE_ALWAYS). 언어 드롭다운은 i18n 데이터 확보 후 확장.
signal closed()

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.add_theme_constant_override("separation", 18)
	add_child(box)

	var title := Label.new()
	title.text = "설정"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	box.add_child(title)

	box.add_child(_toggle("배경음", GameManager.bgm_enabled, func(v):
		GameManager.bgm_enabled = v; SaveManager.save_game()))
	box.add_child(_toggle("효과음", GameManager.sfx_enabled, func(v):
		GameManager.sfx_enabled = v; SaveManager.save_game()))

	var reset := Button.new()
	reset.text = "데이터 초기화"
	reset.custom_minimum_size = Vector2(320, 70)
	reset.pressed.connect(_confirm_reset)
	box.add_child(reset)

	var close := Button.new()
	close.text = "닫기"
	close.custom_minimum_size = Vector2(320, 70)
	close.pressed.connect(_close)
	box.add_child(close)

func _toggle(label: String, initial: bool, cb: Callable) -> Control:
	var cb_box := CheckButton.new()
	cb_box.text = label
	cb_box.button_pressed = initial
	cb_box.add_theme_font_size_override("font_size", 30)
	cb_box.toggled.connect(cb)
	return cb_box

func _confirm_reset() -> void:
	var c := ConfirmationDialog.new()
	c.dialog_text = "모든 게임 데이터가 삭제됩니다."
	add_child(c)
	c.confirmed.connect(func():
		SaveManager.reset_all_data()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	c.popup_centered()

func _close() -> void:
	closed.emit()
	queue_free()
