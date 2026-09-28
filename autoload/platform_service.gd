extends Node
## 플랫폼 추상화 서비스 — 플랫폼 차이(입력 방식/진동/종료)를 뷰에서 감춘다.
## 뷰·매니저는 OS.has_feature("mobile")/Input.vibrate_handheld/get_tree().quit()를
## 직접 호출하지 말고 이 서비스를 경유한다. (Phase 2, docs/architecture.md 계약 5)

enum Backend { KEYBOARD_MOUSE, TOUCH }

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## 개발용: 데스크톱에서도 모바일 UI/터치를 미리보기. 실행 인자에 --mobile-ui 추가 시 활성.
##   예) Godot --path . res://scenes/boot.tscn --mobile-ui   (또는 에디터 Run 인자)
func _force_mobile_preview() -> bool:
	return "--mobile-ui" in OS.get_cmdline_args() or "--mobile-ui" in OS.get_cmdline_user_args()

func is_mobile() -> bool:
	return OS.has_feature("mobile")

func platform_name() -> String:
	return OS.get_name()  # "Windows" / "macOS" / "Linux" / "Android" / "iOS"

func input_backend() -> int:
	if is_mobile() or _force_mobile_preview():
		return Backend.TOUCH
	return Backend.KEYBOARD_MOUSE

func uses_touch() -> bool:
	return input_backend() == Backend.TOUCH

# 진동 — 설정(GameManager.vibration_enabled) + 플랫폼 지원 시에만
func vibrate(duration_ms: int) -> void:
	if not GameManager.vibration_enabled:
		return
	if is_mobile():
		Input.vibrate_handheld(duration_ms)

# 앱 종료 (플랫폼 종료 동작)
func request_quit() -> void:
	get_tree().quit()
