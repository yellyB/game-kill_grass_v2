extends Node
## 부팅 로더 — 플랫폼에 맞는 UI 세트의 메인 메뉴로 진입(전략 B). run/main_scene.

func _ready() -> void:
	UIRouter.goto.call_deferred("main_menu")
