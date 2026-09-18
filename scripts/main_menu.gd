extends Control
## M0 최소 메인 메뉴 — 시작 버튼 + 보유 코인 표시. (스페이스=시작은 M1)

var money_label: Label

func _ready() -> void:
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 24)
	add_child(center)

	var title := Label.new()
	title.text = "풀죽이기"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	center.add_child(title)

	money_label = Label.new()
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_label.add_theme_font_size_override("font_size", 32)
	center.add_child(money_label)

	var start_btn := Button.new()
	start_btn.text = "시작"
	start_btn.custom_minimum_size = Vector2(360, 100)
	start_btn.add_theme_font_size_override("font_size", 40)
	start_btn.pressed.connect(_on_start)
	center.add_child(start_btn)

	_refresh()

func _refresh() -> void:
	money_label.text = "$" + GameManager.format_number(GameManager.money)

func _on_start() -> void:
	SessionManager.start_session(GameManager.selected_world)
