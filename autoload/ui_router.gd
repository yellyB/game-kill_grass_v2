extends Node
## 플랫폼별 UI 씬 세트 로더 (전략 B). 논리 이름 → 플랫폼별 씬 경로.
## 부팅/전환은 goto(logical)만 호출 → 플랫폼에 맞는 세트가 로드된다.
## 새 플랫폼은 SETS에 세트를 추가하고 씬만 만들면 됨(코드 변경 최소). Phase 3.

const SETS := {
	"pc": {
		"main_menu": "res://scenes/pc/main_menu.tscn",
		"game": "res://scenes/pc/main.tscn",
	},
	# 모바일(Phase 5): 현재는 가로 UI 세트를 공유하되 터치 입력(HUD 온스크린 액티브 버튼)만 분기.
	# 전용 세로 레이아웃이 필요해지면 아래 경로를 mobile 전용 씬으로 교체하면 됨(로직/입력/밸런스는 그대로 공유).
	"mobile": {
		"main_menu": "res://scenes/pc/main_menu.tscn",
		"game": "res://scenes/pc/main.tscn",
	},
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func current_set() -> String:
	var s = "mobile" if PlatformService.uses_touch() else "pc"
	return s if SETS.has(s) else "pc"

func path(logical: String) -> String:
	var scene_set = SETS[current_set()]
	return scene_set.get(logical, SETS["pc"].get(logical, ""))

func goto(logical: String) -> void:
	var p = path(logical)
	if p == "":
		push_error("UIRouter: unknown scene '%s'" % logical)
		return
	get_tree().change_scene_to_file(p)
