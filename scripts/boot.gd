extends Node
## 부팅 로더 — 플랫폼에 맞는 UI 세트의 메인 메뉴로 진입(전략 B). run/main_scene.

func _ready() -> void:
	# 모바일(또는 --mobile-ui 프리뷰): 원본과 동일한 세로 1080×1920 캔버스로 전환.
	# PC(데스크톱)는 project.godot 기본(가로 1920×1080) 유지.
	if PlatformService.uses_touch():
		var w := get_window()
		w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH
		w.content_scale_size = Vector2i(1080, 1920)
		w.content_scale_factor = 1.0  # PC 전역 배율(0.6) 무시 — 원본 세로는 1.0
	UIRouter.goto.call_deferred("main_menu")
