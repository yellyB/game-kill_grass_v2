extends Node2D

const SESSION_TIME: float = 45.0

const BGM_PATHS: Array = [
  "res://resources/sounds/bgm_슬라임늪.ogg",          # 0: 슬라임 늪
  "res://resources/sounds/bgm_들판.ogg",              # 1: 들판
  "res://resources/sounds/bgm_기사의성벽.ogg",         # 2: 기사의 성벽
  "res://resources/sounds/bgm_마법의숲.ogg",           # 3: 마법의 숲
  "res://resources/sounds/bgm_수정호수.ogg",           # 4: 수정 호수
  "res://resources/sounds/bgm_고대유적.ogg",            # 5: 고대 유적
  "res://resources/sounds/bgm_용의봉우리.ogg",          # 6: 용의 봉우리
]

@onready var world_root: Node2D = $WorldRoot
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/GameCamera
@onready var upgrade_panel: Control = $UpgradePanel/Control
@onready var back_to_menu_btn: Button = $BackToMenuUI/BackToMenuBtn
@onready var confirm_dialog: Control = $BackToMenuUI/ConfirmDialog
@onready var session_end_overlay: Control = $BackToMenuUI/SessionEndOverlay
@onready var touch_button: Button = $BackToMenuUI/SessionEndOverlay/TouchButton
@onready var session_earnings_label: Label = $BackToMenuUI/SessionEndOverlay/SessionEarningsLabel
@onready var bonus_label: Label = $BackToMenuUI/SessionEndOverlay/BonusLabel
@onready var tap_to_return_label: Label = $BackToMenuUI/SessionEndOverlay/TapToReturnLabel
@onready var timer_label: Label = $HUD/PaddedArea/TimerHBox/TimerLabel
@onready var timer_progress: ProgressBar = $HUD/PaddedArea/TimerHBox/TimerProgressBar

var session_time_remaining: float = SESSION_TIME + GameManager.get_session_time_bonus()
var session_total_time: float = SESSION_TIME + GameManager.get_session_time_bonus()
var session_ended: bool = false
var session_ready: bool = false
var bgm_player: AudioStreamPlayer
var _tick_sfx: AudioStreamPlayer = null
var _last_tick_second: int = -1
var _timer_warning_applied: bool = false

func _ready() -> void:
  camera.add_to_group("camera")

  # Hide the toggle buttons on panels (moved to main menu)
  upgrade_panel.set_toggle_button_visible(false)

  # Setup back to menu button and dialog
  back_to_menu_btn.pressed.connect(_on_back_to_menu_pressed)
  confirm_dialog.dialog_confirmed.connect(_on_confirm_back_to_menu)
  confirm_dialog.dialog_cancelled.connect(_on_cancel_back_to_menu)

  # Button styles
  back_to_menu_btn.text = ""
  back_to_menu_btn.icon = preload("res://resources/images/icon/go_home.png")
  back_to_menu_btn.expand_icon = true
  back_to_menu_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
  GameManager.style_button(back_to_menu_btn, "muted")

  # Setup session end overlay
  touch_button.pressed.connect(_on_session_end_touch)

  # Extra time powerup
  GameManager.extra_time_requested.connect(_on_extra_time)

  # Boss key → session end
  GameManager.boss_key_collected.connect(_on_boss_key_collected)

  # Style progress bar
  var bg_style = StyleBoxFlat.new()
  bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
  bg_style.set_corner_radius_all(6)
  timer_progress.add_theme_stylebox_override("background", bg_style)
  var fill_style = StyleBoxFlat.new()
  fill_style.bg_color = Color(0.4, 0.8, 1.0)
  fill_style.set_corner_radius_all(6)
  timer_progress.add_theme_stylebox_override("fill", fill_style)

  # Initialize timer display
  update_timer_display()

  SessionManager.start_session()

  # 1초 후 세션 시작
  get_tree().create_timer(1.0).timeout.connect(_on_session_ready)

  # Start BGM
  _start_bgm()

func _process(delta: float) -> void:
  if session_ended or not session_ready:
    return

  session_time_remaining -= delta
  if session_time_remaining <= 0:
    session_time_remaining = 0
    end_session()

  # 종료 5초 전부터 화면 흔들림
  if session_time_remaining <= 5.0 and session_time_remaining > 0:
    var intensity = (5.0 - session_time_remaining) / 5.0 * 0.4
    camera.shake(intensity)

  # 종료 10초 전부터 1초마다 틱톡 효과음
  if session_time_remaining <= 10.0 and session_time_remaining > 0:
    var sec = int(ceil(session_time_remaining))
    if sec != _last_tick_second:
      _last_tick_second = sec
      _play_tick()

  update_timer_display()

func update_timer_display() -> void:
  var seconds = int(ceil(session_time_remaining))
  timer_label.text = str(seconds)

  # Update progress bar
  timer_progress.value = clampf((session_time_remaining / session_total_time) * 100.0, 0.0, 100.0)

  # Change color when time is low (apply once)
  if seconds <= 10 and not _timer_warning_applied:
    _timer_warning_applied = true
    timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
    var fill_style = StyleBoxFlat.new()
    fill_style.bg_color = Color(1, 0.3, 0.3)
    fill_style.set_corner_radius_all(6)
    timer_progress.add_theme_stylebox_override("fill", fill_style)

func _play_tick() -> void:
  if not GameManager.sfx_enabled:
    return
  if not _tick_sfx:
    _tick_sfx = AudioStreamPlayer.new()
    _tick_sfx.stream = preload("res://resources/sounds/effect/clock_tick_tock.wav")
    _tick_sfx.bus = "Master"
    add_child(_tick_sfx)
  _tick_sfx.play()

func _start_bgm() -> void:
  var world = GameManager.selected_world
  var path = BGM_PATHS[world] if world < BGM_PATHS.size() else BGM_PATHS[0]
  bgm_player = AudioStreamPlayer.new()
  bgm_player.stream = load(path)
  bgm_player.volume_db = -10.0
  bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
  bgm_player.finished.connect(bgm_player.play)
  add_child(bgm_player)
  await get_tree().create_timer(1.0).timeout
  if GameManager.bgm_enabled:
    bgm_player.play()

func end_session() -> void:
  session_ended = true
  get_tree().paused = true
  back_to_menu_btn.visible = false

  # Remove player hit overlay so it doesn't block session end touch
  var player = get_tree().get_first_node_in_group("player")
  if player and player.has_method("_remove_hit_overlay"):
    player._remove_hit_overlay()

  # Fade out BGM
  if bgm_player:
    var bgm_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    bgm_tween.tween_property(bgm_player, "volume_db", -40.0, 1.5)
    bgm_tween.tween_callback(bgm_player.stop)

  var earnings = GameManager.session_money

  # Phase 1: Coins pop and disappear
  await animate_coins_disappear()

  # Phase 2: Show overlay with animations
  show_session_end_overlay(earnings)

func animate_coins_disappear() -> void:
  var coins = get_tree().get_nodes_in_group("coins")

  if coins.is_empty():
    await get_tree().create_timer(0.3).timeout
    return

  coins.shuffle()
  var total_duration = min(2.0, coins.size() * 0.05)
  var pop_interval = total_duration / coins.size()

  for i in coins.size():
    var coin = coins[i]
    if not is_instance_valid(coin):
      continue

    var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_interval(i * pop_interval)
    tween.tween_property(coin, "scale", Vector2(1.8, 1.8), 0.08)
    tween.tween_property(coin, "scale", Vector2(0, 0), 0.12)
    tween.tween_callback(coin.queue_free)

  await get_tree().create_timer(total_duration + 0.3).timeout

func show_session_end_overlay(earnings: int) -> void:
  # Play fanfare
  if GameManager.sfx_enabled:
    var sfx = AudioStreamPlayer.new()
    sfx.stream = preload("res://resources/sounds/effect/end_session_fanfare.wav")
    sfx.volume_db = -3.0
    sfx.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(sfx)
    sfx.play()
    sfx.finished.connect(sfx.queue_free)

  # Hide scene labels (replaced by dynamic container)
  session_earnings_label.visible = false
  bonus_label.visible = false
  tap_to_return_label.visible = false
  touch_button.disabled = true
  # Hide the scene's SessionEndLabel too
  var scene_end_label = session_end_overlay.get_node_or_null("SessionEndLabel")
  if scene_end_label:
    scene_end_label.visible = false

  # Main container: 세션종료 / 획득정보 / 터치하여돌아가기 를 하나의 VBox로 관리
  var main_vbox = VBoxContainer.new()
  main_vbox.name = "MainResultsVBox"
  main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
  main_vbox.set_anchors_preset(Control.PRESET_CENTER)
  main_vbox.offset_left = -300
  main_vbox.offset_right = 300
  main_vbox.offset_top = -280
  main_vbox.offset_bottom = 280
  main_vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
  main_vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
  main_vbox.add_theme_constant_override("separation", 0)
  main_vbox.modulate = Color(1, 1, 1, 0)

  # ── Section 1: 세션 종료 ──
  var end_label = Label.new()
  end_label.text = "세션 종료"
  end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  end_label.add_theme_font_size_override("font_size", 58)
  end_label.add_theme_color_override("font_color", Color.WHITE)
  end_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  end_label.add_theme_constant_override("outline_size", 4)
  main_vbox.add_child(end_label)

  # Gap: 세션종료 ↔ 획득정보 (60px)
  var gap1 = Control.new()
  gap1.custom_minimum_size = Vector2(0, 60)
  main_vbox.add_child(gap1)

  # ── Section 2: 획득 정보 ──
  # 순차 fade-in 대상 목록
  var fade_rows: Array[Control] = []

  # 모든 획득 정보를 하나의 VBox에 담아 너비 통일 + 화면 중앙 배치
  var info_block = VBoxContainer.new()
  info_block.add_theme_constant_override("separation", 10)
  info_block.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

  # "{코인} {전체 코인}" (합계, 큰 글씨, 가운데 정렬)
  var earnings_container = HBoxContainer.new()
  earnings_container.add_theme_constant_override("separation", 4)
  earnings_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
  earnings_container.modulate = Color(1, 1, 1, 0)
  var prefix_label = Label.new()
  prefix_label.text = "총 획득 코인: "
  prefix_label.add_theme_font_size_override("font_size", 42)
  prefix_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
  prefix_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  prefix_label.add_theme_constant_override("outline_size", 4)
  earnings_container.add_child(prefix_label)
  var coin_hbox = GameManager.create_coin_label(
    GameManager.format_number(earnings), 42, Color(0.3, 1.0, 0.5), 4)
  earnings_container.add_child(coin_hbox)
  info_block.add_child(earnings_container)
  fade_rows.append(earnings_container)

  # "+ 수집 n" (오른쪽 정렬)
  var collect_amount = earnings - GameManager.session_boss_reward
  var collect_label = Label.new()
  collect_label.text = "+ 수집 %s" % GameManager.format_number(collect_amount)
  collect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  collect_label.add_theme_font_size_override("font_size", 30)
  collect_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
  collect_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  collect_label.add_theme_constant_override("outline_size", 3)
  collect_label.modulate = Color(1, 1, 1, 0)
  info_block.add_child(collect_label)
  fade_rows.append(collect_label)

  # "+ 보너스 n" (오른쪽 정렬)
  var boss_label = Label.new()
  boss_label.text = "+ 보너스 %s" % GameManager.format_number(GameManager.session_boss_reward)
  boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  boss_label.add_theme_font_size_override("font_size", 30)
  boss_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
  boss_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  boss_label.add_theme_constant_override("outline_size", 3)
  boss_label.modulate = Color(1, 1, 1, 0)
  info_block.add_child(boss_label)
  fade_rows.append(boss_label)

  # {보석}x{개수} (가운데 정렬)
  if GameManager.session_gems > 0:
    var gem_container = HBoxContainer.new()
    gem_container.add_theme_constant_override("separation", 6)
    gem_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    gem_container.modulate = Color(1, 1, 1, 0)

    gem_container.add_child(_create_gem_icon(42))

    var gem_count = Label.new()
    gem_count.text = "x%d" % GameManager.session_gems
    gem_count.add_theme_font_size_override("font_size", 42)
    gem_count.add_theme_color_override("font_color", Color(0.95, 0.3, 0.5))
    gem_count.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    gem_count.add_theme_constant_override("outline_size", 4)
    gem_container.add_child(gem_count)

    info_block.add_child(gem_container)
    fade_rows.append(gem_container)

  # {열쇠}({월드}) (가운데 정렬)
  var key_world = GameManager.session_key_acquired
  if key_world >= 0:
    var world_names = ["슬라임 늪", "들판", "기사의 성벽", "마법의 숲", "수정 호수", "고대 유적", "용의 봉우리"]
    var world_name = world_names[key_world] if key_world < world_names.size() else "월드 %d" % key_world
    var key_row = HBoxContainer.new()
    key_row.add_theme_constant_override("separation", 10)
    key_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    key_row.modulate = Color(1, 1, 1, 0)

    var key_icon = _create_key_icon(42)
    key_row.add_child(key_icon)

    var key_label = Label.new()
    key_label.text = "(%s)" % world_name
    key_label.add_theme_font_size_override("font_size", 42)
    key_label.add_theme_color_override("font_color", Color(0.3, 1.0, 1.0))
    key_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    key_label.add_theme_constant_override("outline_size", 4)
    key_row.add_child(key_label)

    info_block.add_child(key_row)
    fade_rows.append(key_row)

  # {왕관} 황금 왕관 (가운데 정렬)
  if GameManager.session_crown_acquired:
    var crown_row = HBoxContainer.new()
    crown_row.add_theme_constant_override("separation", 10)
    crown_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    crown_row.modulate = Color(1, 1, 1, 0)

    var crown_icon = TextureRect.new()
    crown_icon.texture = preload("res://resources/images/icon/crown.png")
    crown_icon.custom_minimum_size = Vector2(42, 42)
    crown_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    crown_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    crown_row.add_child(crown_icon)

    var crown_label = Label.new()
    crown_label.text = "황금 왕관"
    crown_label.add_theme_font_size_override("font_size", 42)
    crown_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
    crown_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    crown_label.add_theme_constant_override("outline_size", 4)
    crown_row.add_child(crown_label)

    info_block.add_child(crown_row)
    fade_rows.append(crown_row)

  main_vbox.add_child(info_block)

  # Gap: 획득정보 ↔ 터치하여돌아가기 (110px)
  var gap2 = Control.new()
  gap2.custom_minimum_size = Vector2(0, 110)
  main_vbox.add_child(gap2)

  # ── Section 3: 터치하여 돌아가기 ──
  var tap_label = Label.new()
  tap_label.name = "TapLabel"
  tap_label.text = "터치하여 돌아가기"
  tap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  tap_label.add_theme_font_size_override("font_size", 36)
  tap_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
  tap_label.modulate = Color(1, 1, 1, 0)
  main_vbox.add_child(tap_label)

  session_end_overlay.add_child(main_vbox)

  # Show overlay
  session_end_overlay.visible = true

  # "세션 종료" 먼저 표시
  var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
  tween.tween_property(main_vbox, "modulate:a", 1.0, 0.3)
  tween.tween_interval(0.3)

  # 획득 정보 한 줄씩 순차 fade-in
  for row in fade_rows:
    tween.tween_property(row, "modulate:a", 1.0, 0.3)
    tween.tween_interval(0.15)

  # 터치하여 돌아가기
  tween.tween_interval(0.3)
  tween.tween_property(tap_label, "modulate:a", 1.0, 0.3)
  tween.tween_callback(func():
    touch_button.disabled = false
    _animate_tap_label(tap_label)
  )

func _create_gem_icon(icon_size: int) -> Control:
  return GameManager._create_gem_display_icon(icon_size)

func _create_key_icon(icon_size: int) -> Control:
  var container = Control.new()
  container.custom_minimum_size = Vector2(icon_size, icon_size)
  var s = icon_size / 28.0  # scale factor (original design is ~28px)
  var cx = icon_size * 0.5
  var cy = icon_size * 0.5
  # Head (rectangle)
  var head = Polygon2D.new()
  head.color = Color(0.3, 1.0, 1.0)
  head.polygon = PackedVector2Array([
    Vector2(cx - 8 * s, cy - 14 * s), Vector2(cx + 8 * s, cy - 14 * s),
    Vector2(cx + 8 * s, cy - 2 * s), Vector2(cx - 8 * s, cy - 2 * s)
  ])
  container.add_child(head)
  # Shaft
  var shaft = Polygon2D.new()
  shaft.color = Color(0.2, 0.8, 0.8)
  shaft.polygon = PackedVector2Array([
    Vector2(cx - 3 * s, cy - 2 * s), Vector2(cx + 3 * s, cy - 2 * s),
    Vector2(cx + 3 * s, cy + 14 * s), Vector2(cx - 3 * s, cy + 14 * s)
  ])
  container.add_child(shaft)
  # Tooth
  var tooth = Polygon2D.new()
  tooth.color = Color(0.2, 0.8, 0.8)
  tooth.polygon = PackedVector2Array([
    Vector2(cx + 3 * s, cy + 8 * s), Vector2(cx + 8 * s, cy + 8 * s),
    Vector2(cx + 8 * s, cy + 12 * s), Vector2(cx + 3 * s, cy + 12 * s)
  ])
  container.add_child(tooth)
  return container

func _animate_tap_label(label: Label) -> void:
  var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
  tween.set_loops()
  tween.tween_property(label, "modulate:a", 0.3, 0.7)
  tween.tween_property(label, "modulate:a", 1.0, 0.7)

func _on_session_end_touch() -> void:
  GameManager.play_confirm_click()
  get_tree().paused = false
  # Normal session end - finalize and save
  GameManager.finalize_session()
  SaveManager.save_game()
  SessionManager.quit_to_menu()

func _notification(what: int) -> void:
  if what == NOTIFICATION_WM_GO_BACK_REQUEST:
    # Android back button
    if session_ended:
      _on_session_end_touch()
    elif confirm_dialog.visible:
      _on_cancel_back_to_menu()
    else:
      _on_back_to_menu_pressed()

func _on_session_ready() -> void:
  session_ready = true

func _on_back_to_menu_pressed() -> void:
  GameManager.play_button_click()
  confirm_dialog.show_dialog("첫 화면으로 돌아갈까요?", "처음으로", "게임 계속하기", true)
  get_tree().paused = true

func _on_confirm_back_to_menu() -> void:
  get_tree().paused = false
  var p = get_tree().get_first_node_in_group("player")
  if p and p.has_method("_remove_hit_overlay"):
    p._remove_hit_overlay()
  SessionManager.quit_to_menu()

func _on_cancel_back_to_menu() -> void:
  get_tree().paused = false

func _on_boss_key_collected(_world_index: int) -> void:
  if session_ended:
    return
  _boss_end_session()

func _boss_end_session() -> void:
  session_ended = true
  get_tree().paused = true
  back_to_menu_btn.visible = false

  var player = get_tree().get_first_node_in_group("player")
  if player and player.has_method("_remove_hit_overlay"):
    player._remove_hit_overlay()

  # 1초 정지 연출 (보스 처치 여운)
  await get_tree().create_timer(1.0).timeout

  if bgm_player:
    var bgm_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    bgm_tween.tween_property(bgm_player, "volume_db", -40.0, 1.5)
    bgm_tween.tween_callback(bgm_player.stop)

  var earnings = GameManager.session_money
  await animate_coins_disappear()
  show_session_end_overlay(earnings)

func _on_extra_time(seconds: float) -> void:
  session_time_remaining += seconds
  session_total_time += seconds
