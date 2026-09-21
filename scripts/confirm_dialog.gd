extends Control

signal dialog_confirmed
signal dialog_cancelled

@onready var overlay: ColorRect = $Overlay
@onready var dialog_panel: Panel = $DialogPanel
@onready var message_label: Label = $DialogPanel/VBox/MessageLabel
@onready var confirm_btn: Button = $DialogPanel/VBox/BtnRow/ConfirmBtn
@onready var cancel_btn: Button = $DialogPanel/VBox/BtnRow/CancelBtn

func _ready() -> void:
  visible = false
  confirm_btn.pressed.connect(_on_confirm)
  cancel_btn.pressed.connect(_on_cancel)

func show_dialog(message: String, confirm_text: String = "확인", cancel_text: String = "취소", destructive: bool = false) -> void:
  message_label.text = message
  confirm_btn.text = confirm_text
  cancel_btn.text = cancel_text
  var btn_row = confirm_btn.get_parent()
  if destructive:
    GameManager.style_button(confirm_btn, "muted")
    GameManager.style_button(cancel_btn, "main")
    # destructive: confirm(불리)=왼쪽, cancel(유리)=오른쪽 → tscn 기본 순서
    btn_row.move_child(confirm_btn, 0)
  else:
    GameManager.style_button(confirm_btn, "main")
    GameManager.style_button(cancel_btn, "muted")
    # non-destructive: cancel(불리)=왼쪽, confirm(유리)=오른쪽
    btn_row.move_child(cancel_btn, 0)
  visible = true

func hide_dialog() -> void:
  visible = false

func _on_confirm() -> void:
  GameManager.play_confirm_click()
  visible = false
  dialog_confirmed.emit()

func _on_cancel() -> void:
  GameManager.play_button_click()
  visible = false
  dialog_cancelled.emit()
