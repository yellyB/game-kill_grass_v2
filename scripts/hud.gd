extends CanvasLayer

@onready var padded_area: Control = $PaddedArea
@onready var money_display = $PaddedArea/MoneyDisplay
@onready var money_label: Label = $PaddedArea/MoneyDisplay/CoinPanel/CoinRow/MoneyLabel
@onready var fury_hbox: HBoxContainer = $PaddedArea/FuryHBox
@onready var fury_progress: ProgressBar = $PaddedArea/FuryHBox/FuryProgressBar
@onready var fury_label: Label = $PaddedArea/FuryHBox/FuryLabel

var displayed_money: int = 0
var target_money: int = 0
var fury_hidden: bool = false
var buff_labels: Dictionary = {}  # type -> Label
var perm_buff_icons: Array = []  # ordered list of icons


func _ready() -> void:
  GameManager.session_money_changed.connect(_on_session_money_changed)
  GameManager.powerup_acquired.connect(_on_powerup_acquired)
  GameManager.timed_buff_started.connect(_on_timed_buff_started)
  GameManager.timed_buff_ended.connect(_on_timed_buff_ended)

  # Create buff timer container (below timer, centered)
  _create_buff_container()

  # 세션 금액 표시: 초록색으로 변경, total money 자동 업데이트 해제
  money_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5, 1.0))
  if GameManager.money_changed.is_connected(money_display._on_money_changed):
    GameManager.money_changed.disconnect(money_display._on_money_changed)

  # Initialize display (session earnings)
  displayed_money = GameManager.session_money
  target_money = GameManager.session_money
  update_money_display()

  # 초월 레벨 표시 (보유 코인 아래)
  _setup_strength_label()

  # 인게임 디버그 버튼 (debug build only)
  if OS.is_debug_build():
    _build_debug_buttons()

  # 몬스터 분노 bar styling
  _setup_fury_bar()
  GameManager.fury_changed.connect(_on_fury_changed)
  GameManager.fury_boss_requested.connect(_on_fury_boss_spawned)
  GameManager.fury_feed_requested.connect(_on_fury_feed_requested)

func _process(delta: float) -> void:
  # Update timed buff countdowns
  _update_buff_timers()

  # Smooth money counter
  if displayed_money != target_money:
    var diff = target_money - displayed_money
    var change = int(max(abs(diff) * delta * 10, 1))
    if diff > 0:
      displayed_money = min(displayed_money + change, target_money)
    else:
      displayed_money = max(displayed_money - change, target_money)
    update_money_display()

func _on_session_money_changed(_new_amount: int) -> void:
  target_money = GameManager.session_money
  # Pop effect on money label
  var tween = create_tween()
  tween.tween_property(money_display, "scale", Vector2(1.2, 1.2), 0.05)
  tween.tween_property(money_display, "scale", Vector2(1.0, 1.0), 0.1)

func update_money_display() -> void:
  money_label.text = GameManager.format_number(displayed_money)


const PERSISTENT_BUFFS = ["attack_speed", "attack_range", "magnet_range", "move_speed"]

func _on_powerup_acquired(type: String, level: int) -> void:
  if type in PERSISTENT_BUFFS:
    _update_perm_buff(type, level)
  _show_powerup_notification(type, level)

const WORLD_NAMES: Array = ["슬라임 늪", "들판", "기사의 성벽", "마법의 숲", "수정 호수", "고대 유적", "용의 봉우리"]



var buff_container: VBoxContainer
var perm_icons_hbox: HBoxContainer

func _create_buff_container() -> void:
  buff_container = VBoxContainer.new()
  buff_container.anchors_preset = Control.PRESET_CENTER_TOP
  buff_container.anchor_left = 0.5
  buff_container.anchor_right = 0.5
  buff_container.offset_left = -200.0
  buff_container.offset_top = 130.0
  buff_container.offset_right = 200.0
  buff_container.offset_bottom = 400.0
  buff_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
  buff_container.add_theme_constant_override("separation", 4)
  padded_area.add_child(buff_container)

  # Persistent buff icons row (horizontal)
  perm_icons_hbox = HBoxContainer.new()
  perm_icons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
  perm_icons_hbox.add_theme_constant_override("separation", 0)
  buff_container.add_child(perm_icons_hbox)

func _on_timed_buff_started(type: String, _duration: float) -> void:
  if buff_labels.has(type):
    return

  var hbox = HBoxContainer.new()
  hbox.alignment = BoxContainer.ALIGNMENT_CENTER
  hbox.add_theme_constant_override("separation", 6)

  var PowerupSelection = preload("res://scripts/powerup_selection.gd")
  var data = PowerupSelection.get_powerup_data_by_type(type)
  var pcolor = data.get("color", Color.WHITE)
  var tex = PowerupSelection.get_powerup_texture(data) if not data.is_empty() else null
  if tex:
    var icon = TextureRect.new()
    icon.texture = tex
    icon.custom_minimum_size = Vector2(64, 64)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    hbox.add_child(icon)

  var label = Label.new()
  label.name = "Label"
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  label.add_theme_font_size_override("font_size", 28)
  label.add_theme_color_override("font_color", pcolor)
  label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  label.add_theme_constant_override("outline_size", 3)
  hbox.add_child(label)

  buff_container.add_child(hbox)
  buff_labels[type] = hbox

func _on_timed_buff_ended(type: String) -> void:
  if buff_labels.has(type):
    buff_labels[type].queue_free()
    buff_labels.erase(type)

func _update_buff_timers() -> void:
  for type in buff_labels:
    var container = buff_labels[type]
    if not is_instance_valid(container):
      continue
    var label = container.get_node_or_null("Label")
    if not label:
      continue
    var remaining = GameManager.get_timed_buff_remaining(type)
    label.text = "%.1fs" % remaining

func _update_perm_buff(type: String, _level: int) -> void:
  var PowerupSelection = preload("res://scripts/powerup_selection.gd")
  var data = PowerupSelection.get_powerup_data_by_type(type)
  var tex = PowerupSelection.get_powerup_texture(data) if not data.is_empty() else null
  var icon = TextureRect.new()
  icon.custom_minimum_size = Vector2(64, 64)
  icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  if tex:
    icon.texture = tex
  perm_icons_hbox.add_child(icon)

# ── 몬스터 분노 Bar ──

func _setup_fury_bar() -> void:
  fury_progress.max_value = 100.0
  fury_progress.value = 0.0

  # Fill style (red)
  var fill_style = StyleBoxFlat.new()
  fill_style.bg_color = Color(0.85, 0.2, 0.15)
  fill_style.set_corner_radius_all(6)
  fury_progress.add_theme_stylebox_override("fill", fill_style)

  # Background style
  var bg_style = StyleBoxFlat.new()
  bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
  bg_style.set_corner_radius_all(6)
  fury_progress.add_theme_stylebox_override("background", bg_style)

  fury_label.text = "0%"

func _on_fury_changed(value: float) -> void:
  if fury_hidden:
    return
  var pct = value / GameManager.get_fury_max() * 100.0
  fury_progress.value = pct
  if OS.is_debug_build():
    fury_label.text = "%d%% (%d/%d)" % [int(pct), int(value), int(GameManager.get_fury_max())]
  else:
    fury_label.text = "%d%%" % int(pct)

func _on_fury_boss_spawned() -> void:
  fury_hidden = true

  # Vibrate on mobile
  if OS.has_feature("mobile"):
    GameManager.vibrate(200)

  # Fade out fury bar (no shake)
  var fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
  fade_tween.tween_property(fury_hbox, "modulate:a", 0.0, 0.8)
  fade_tween.tween_callback(func():
    fury_hbox.visible = false
  )

  # Icon flash: fury icon appears at screen center, scales up huge + fades out
  var viewport_size = get_viewport().get_visible_rect().size
  var icon_texture = preload("res://resources/images/icon/monster.png")
  var icon = TextureRect.new()
  icon.texture = icon_texture
  icon.expand_mode = 3  # EXPAND_FIT_WIDTH_PROPORTIONAL
  icon.stretch_mode = 5  # STRETCH_KEEP_ASPECT_CENTERED
  icon.custom_minimum_size = Vector2(80, 80)
  icon.size = Vector2(80, 80)
  icon.pivot_offset = Vector2(40, 40)
  icon.position = viewport_size / 2.0 - Vector2(40, 40)
  icon.modulate = Color(1, 0.3, 0.2, 0.9)
  add_child(icon)

  var center_pos = icon.position
  # Phase 1: 중앙에서 흔들림 (0.8초)
  var shake_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
  for i in 12:
    var offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
    shake_tween.tween_property(icon, "position", center_pos + offset, 0.035)
    shake_tween.tween_property(icon, "position", center_pos, 0.035)
  await shake_tween.finished

  # Phase 2: 확대 + 흐려짐 (1.2초)
  var icon_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
  icon_tween.set_parallel(true)
  var target_scale = viewport_size.x / 80.0
  icon_tween.tween_property(icon, "scale", Vector2(target_scale, target_scale), 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
  icon_tween.tween_property(icon, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
  icon_tween.chain().tween_callback(func():
    icon.queue_free()
    GameManager.fury_gauge_dismissed.emit()
  )

# ── 분노 파티클 (풀 → 게이지) ──

func _on_fury_feed_requested(amount: float, from_pos: Vector2) -> void:
  if fury_hidden:
    return
  _spawn_fury_particles(amount, from_pos)

func _spawn_fury_particles(amount: float, from_pos: Vector2) -> void:
  var target_pos = fury_progress.global_position + fury_progress.size * 0.5

  # 소형: 50당 1개, 최대 3개 / 대형: 150당 1개 (소형 3개 초과분), 최대 3개
  var small_count = clampi(ceili(amount / 50.0), 1, 3)
  var large_count = clampi(ceili((amount - 150.0) / 150.0), 0, 3)
  var total = small_count + large_count
  var per_particle = amount / float(total)

  var idx = 0
  for i in small_count:
    _launch_fury_dot(from_pos, target_pos, 14.0, per_particle, idx)
    idx += 1
  for i in large_count:
    _launch_fury_dot(from_pos, target_pos, 26.0, per_particle, idx)
    idx += 1

func _launch_fury_dot(from_pos: Vector2, target_pos: Vector2, radius: float, fury_val: float, idx: int) -> void:
  var dot = Polygon2D.new()
  var points: PackedVector2Array = []
  for j in 8:
    var a = TAU / 8.0 * j
    points.append(Vector2(cos(a), sin(a)) * radius)
  dot.polygon = points
  dot.color = Color(1.0, 0.3, 0.15, 0.9)

  var spread = Vector2(randf_range(-40, 40), randf_range(-30, 30))
  dot.position = from_pos + spread
  add_child(dot)

  var delay = idx * 0.03
  var duration = randf_range(0.3, 0.5)

  var tween = create_tween()
  tween.tween_property(dot, "position", target_pos, duration) \
    .set_delay(delay) \
    .set_ease(Tween.EASE_IN) \
    .set_trans(Tween.TRANS_QUAD)
  tween.parallel().tween_property(dot, "scale", Vector2(0.5, 0.5), duration) \
    .set_delay(delay)
  tween.tween_callback(func():
    GameManager.add_fury(fury_val)
    _flash_fury_bar()
    dot.queue_free()
  )

func _flash_fury_bar() -> void:
  if fury_hidden:
    return
  fury_progress.modulate = Color(1.5, 1.2, 1.0)
  var tween = create_tween()
  tween.tween_property(fury_progress, "modulate", Color.WHITE, 0.15)

# ── 초월 레벨 표시 ──

func _setup_strength_label() -> void:
  var world = GameManager.selected_world
  var strength = GameManager.get_world_strength_level(world)
  if strength <= 0:
    return
  # Add strength label inside MoneyDisplay VBox (below gem panel)
  var label = Label.new()
  label.text = "초월 Lv.%d" % strength
  label.add_theme_font_size_override("font_size", 48)
  label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
  label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  label.add_theme_constant_override("outline_size", 4)
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  label.size_flags_horizontal = Control.SIZE_SHRINK_END
  label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  money_display.add_child(label)


# ── 파워업 획득 알림 ──

var _notif_container: VBoxContainer = null
var _notif_queue: Array = []  # 대기 중인 알림

func _setup_notif_container() -> void:
  _notif_container = VBoxContainer.new()
  _notif_container.anchors_preset = Control.PRESET_CENTER
  _notif_container.anchor_left = 0.5
  _notif_container.anchor_right = 0.5
  _notif_container.anchor_top = 0.5
  _notif_container.anchor_bottom = 0.5
  _notif_container.offset_left = -250.0
  _notif_container.offset_top = -280.0
  _notif_container.offset_right = 250.0
  _notif_container.offset_bottom = -140.0
  _notif_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
  _notif_container.add_theme_constant_override("separation", 6)
  _notif_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
  padded_area.add_child(_notif_container)

func _show_powerup_notification(type: String, level: int) -> void:
  if not _notif_container:
    _setup_notif_container()

  var PowerupSelection = preload("res://scripts/powerup_selection.gd")
  var data = PowerupSelection.get_powerup_data_by_type(type)
  if data.is_empty():
    return

  var text = data.get("name", type)

  # 더블 오어 더스트: 결과 표시
  if type == "double_or_dust":
    if level == 1:
      text = "더블! 코인 x2"
    else:
      text = "낫싱! 코인 -30%"

  var hbox = HBoxContainer.new()
  hbox.alignment = BoxContainer.ALIGNMENT_CENTER
  hbox.add_theme_constant_override("separation", 8)
  hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
  hbox.modulate = Color(1, 1, 1, 0)

  # 아이콘
  var tex = PowerupSelection.get_powerup_texture(data)
  if tex:
    var icon = TextureRect.new()
    icon.texture = tex
    icon.custom_minimum_size = Vector2(56, 56)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hbox.add_child(icon)

  # 텍스트 (외광선 + 내부색 고정)
  var label = Label.new()
  label.text = text
  label.add_theme_font_size_override("font_size", 44)
  if type == "double_or_dust" and level == 0:
    label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
    label.add_theme_color_override("font_outline_color", Color(0.4, 0.0, 0.0))
  else:
    label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.85))
    label.add_theme_color_override("font_outline_color", Color(0.15, 0.35, 0.1))
  label.add_theme_constant_override("outline_size", 8)
  label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
  label.add_theme_constant_override("shadow_offset_x", 2)
  label.add_theme_constant_override("shadow_offset_y", 2)
  label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  hbox.add_child(label)

  _notif_container.add_child(hbox)

  # 페이드인 → 유지 → 페이드아웃 → 높이 접기
  var tween = create_tween()
  tween.tween_property(hbox, "modulate:a", 1.0, 0.2)
  tween.tween_interval(1.5)
  tween.tween_property(hbox, "modulate:a", 0.0, 0.5)
  tween.tween_callback(func():
    var h = hbox.size.y
    for child in hbox.get_children():
      child.free()
    hbox.custom_minimum_size.y = h
  )
  tween.tween_property(hbox, "custom_minimum_size:y", 0.0, 0.2)
  tween.tween_callback(hbox.queue_free)

# ── 인게임 디버그 버튼 ──

func _build_debug_buttons() -> void:
  var btn = Button.new()
  btn.text = "파워업"
  btn.add_theme_font_size_override("font_size", 18)
  GameManager.style_button(btn, "sub")
  btn.pressed.connect(_on_debug_powerup)
  btn.anchors_preset = Control.PRESET_BOTTOM_LEFT
  btn.anchor_left = 0.0
  btn.anchor_top = 1.0
  btn.anchor_right = 0.0
  btn.anchor_bottom = 1.0
  btn.offset_left = 16.0
  btn.offset_top = -56.0
  btn.offset_right = 100.0
  btn.offset_bottom = -8.0
  padded_area.add_child(btn)

func _on_debug_powerup() -> void:
  var selection = preload("res://scenes/ui/powerup_selection.tscn").instantiate()
  get_tree().root.add_child(selection)
