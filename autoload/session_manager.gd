extends Node

signal session_started()
signal session_ending()
signal session_ended()
# 세션 클록(공유 로직) — 뷰(main.gd 등)는 아래 signal 구독 + 메서드 호출만.
signal time_changed(remaining: float, total: float)  # 매 프레임 남은/총 시간
signal session_time_up()                             # 제한시간 소진 → 종료 트리거

const SESSION_TIME: float = 45.0

var is_session_active: bool = false

# 세션 클록 상태
var time_remaining: float = 0.0
var total_time: float = 0.0
var clock_running: bool = false   # 시작 딜레이(1초) 후 뷰가 set_clock_ready()로 개시
var _freeze: float = 0.0          # 시간 정지 아이템 잔여

func _ready() -> void:
  process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
  if not is_session_active or not clock_running:
    return
  if get_tree().paused:
    return
  # 시간 정지: 타이머만 멈추고 수확은 계속(뷰에서 처리)
  if _freeze > 0.0:
    _freeze -= delta
  else:
    time_remaining -= delta
  # 막판 스퍼트: 마지막 10초
  GameManager.finale_active = time_remaining <= 10.0
  if time_remaining <= 0.0:
    time_remaining = 0.0
    clock_running = false
    time_changed.emit(time_remaining, total_time)
    session_time_up.emit()
    return
  time_changed.emit(time_remaining, total_time)

# ── 세션 클록 제어 (뷰가 호출) ──
func set_clock_ready() -> void:
  clock_running = true

func stop_clock() -> void:
  clock_running = false

func add_time(seconds: float) -> void:
  time_remaining += seconds
  total_time += seconds
  time_changed.emit(time_remaining, total_time)

func set_freeze(seconds: float) -> void:
  _freeze = seconds

func _notification(what: int) -> void:
  if what == NOTIFICATION_WM_CLOSE_REQUEST:
    # 세션 중 앱 종료 = 미완료 → 세션 코인 버림(save=false). 완료(결과 화면)만 총액 편입.
    end_session(false)
    PlatformService.request_quit()

func start_session() -> void:
  if is_session_active:
    return

  is_session_active = true
  GameManager.reset_session_data()
  ActiveManager.reset_session()
  # 세션 클록 초기화 (개시는 뷰의 시작 딜레이 후 set_clock_ready())
  total_time = SESSION_TIME + GameManager.get_session_time_bonus()
  time_remaining = total_time
  _freeze = 0.0
  clock_running = false
  session_started.emit()

func end_session(save: bool = true) -> void:
  if not is_session_active:
    return

  session_ending.emit()
  if save:
    GameManager.finalize_session()
    SaveManager.save_game()
  else:
    GameManager.reset_session_data()
  is_session_active = false
  session_ended.emit()

func quit_to_menu() -> void:
  end_session(false)
  UIRouter.goto("main_menu")

# 세션 자연 종료(결과 화면 → 복귀) 전용: 허브로 복귀(§3.87). "처음으로"는 quit_to_menu 유지.
func quit_to_hub() -> void:
  end_session(false)
  UIRouter.goto("hub")

func quit_game() -> void:
  end_session()
  PlatformService.request_quit()
