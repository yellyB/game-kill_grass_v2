extends Node
## 플랫폼별 UI 씬 세트 로더 (전략 B). 논리 이름 → 플랫폼별 씬 경로.
## 부팅/전환은 goto(logical)만 호출 → 플랫폼에 맞는 세트가 로드된다.
## 새 플랫폼은 SETS에 세트를 추가하고 씬만 만들면 됨(코드 변경 최소). Phase 3.

const SETS := {
	"pc": {
		"main_menu": "res://scenes/pc/main_menu.tscn",
		"game": "res://scenes/pc/main.tscn",
	},
	# ── 모바일 UI 세트는 별도 제작 예정(scenes/mobile/) ──
	# PC 씬을 공유하지 않는다. 아래처럼 mobile 전용 씬을 만들면 자동으로 그 세트를 로드:
	#   "mobile": { "main_menu": "res://scenes/mobile/main_menu.tscn", "game": "res://scenes/mobile/main.tscn" }
	# 공유되는 것은 core/·매니저·scenes/game/world.tscn(게임플레이 월드)뿐.
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func current_set() -> String:
	var s = "mobile" if PlatformService.uses_touch() else "pc"
	if SETS.has(s):
		return s
	# 해당 플랫폼 UI 세트 미제작 → PC로 안전 폴백(정식 공유가 아니라 개발용 임시).
	push_warning("UIRouter: '%s' UI 세트 없음 → pc로 폴백(미구현)" % s)
	return "pc"

func path(logical: String) -> String:
	var scene_set = SETS[current_set()]
	return scene_set.get(logical, SETS["pc"].get(logical, ""))

func goto(logical: String) -> void:
	var p = path(logical)
	if p == "":
		push_error("UIRouter: unknown scene '%s'" % logical)
		return
	get_tree().change_scene_to_file(p)
