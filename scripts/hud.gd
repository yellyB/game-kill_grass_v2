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

  # 세션 레벨 게이지 styling (구 분노 bar 재활용)
  _setup_fury_bar()
  GameManager.fury_changed.connect(_on_fury_changed)
  GameManager.level_up.connect(_on_level_up)
  GameManager.fury_feed_requested.connect(_on_fury_feed_requested)

  # 씨앗 / 거목 진행 표시
  _setup_seed_indicator()

  # 정수(수확의 정수 — 콤보 전용 재화) 카운터
  _setup_token_indicator()

  # 액티브(1/2) 충전 게이지
  _setup_active_gauges()

  # 터치 플랫폼: 액티브 온스크린 버튼(키보드 대체)
  if PlatformService.uses_touch():
    _setup_touch_active_buttons()

  # 콤보 미터 (중앙 상단)
  _setup_combo_meter()
  GameManager.combo_changed.connect(_on_combo_changed)

func _process(delta: float) -> void:
  # Update timed buff countdowns
  _update_buff_timers()

  # 콤보 잔여 시간바
  _update_combo_timer_bar()

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


const PERSISTENT_BUFFS = ["pu_attack_speed", "pu_attack_range", "pu_magnet_range", "pu_move_speed"]

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

# ── 씨앗 / 거목 진행 표시 ──

var seed_label: Label = null
var seed_container: HBoxContainer = null

func _setup_seed_indicator() -> void:
  seed_container = HBoxContainer.new()
  seed_container.add_theme_constant_override("separation", 8)
  seed_container.position = Vector2(0, 108)
  seed_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
  seed_container.add_child(_make_seed_icon())
  seed_label = Label.new()
  seed_label.add_theme_font_size_override("font_size", 28)
  seed_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.5))
  seed_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  seed_label.add_theme_constant_override("outline_size", 3)
  seed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  seed_container.add_child(seed_label)
  padded_area.add_child(seed_container)
  _update_seed_label(GameManager.session_seeds, GameManager.get_seed_need())
  GameManager.seed_changed.connect(_update_seed_label)
  GameManager.goomok_ready.connect(_on_goomok_ready_hud)

var token_label: Label = null

func _setup_token_indicator() -> void:
  var c = HBoxContainer.new()
  c.add_theme_constant_override("separation", 8)
  c.position = Vector2(180, 108)
  c.mouse_filter = Control.MOUSE_FILTER_IGNORE
  c.add_child(_make_token_icon())
  token_label = Label.new()
  token_label.add_theme_font_size_override("font_size", 28)
  token_label.add_theme_color_override("font_color", Color(0.6, 0.95, 1.0))  # 정수 = 시안
  token_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  token_label.add_theme_constant_override("outline_size", 3)
  token_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  c.add_child(token_label)
  padded_area.add_child(c)
  _update_token_label(GameManager.owned_tokens)
  GameManager.token_changed.connect(_update_token_label)

func _make_token_icon() -> Control:
  # 정수 = 시안 응축 물방울(씨앗·보석과 색/모양 구별). 뾰족한 위 꼭지 + 둥근 아래.
  var c = Control.new()
  c.custom_minimum_size = Vector2(26, 26)
  c.mouse_filter = Control.MOUSE_FILTER_IGNORE
  var drop = Polygon2D.new()
  drop.color = Color(0.3, 0.85, 1.0)
  var pts: PackedVector2Array = [Vector2(13, 3)]  # 위 꼭지
  for i in 13:
    var a = deg_to_rad(-45.0 + 270.0 * i / 12.0)  # 위오른쪽 → 아래 → 위왼쪽
    pts.append(Vector2(13 + cos(a) * 7.0, 16 + sin(a) * 7.0))
  drop.polygon = pts
  c.add_child(drop)
  var hi = Polygon2D.new()  # 광택 하이라이트
  hi.color = Color(0.85, 1.0, 1.0, 0.7)
  var hpts: PackedVector2Array = []
  for i in 8:
    var a = TAU / 8.0 * i
    hpts.append(Vector2(10 + cos(a) * 2.2, 14 + sin(a) * 3.0))
  hi.polygon = hpts
  c.add_child(hi)
  return c

func _update_token_label(amount: int) -> void:
  if token_label:
    token_label.text = str(amount)

# ── 액티브(1/2) 충전 게이지 ──
var _active_rows: Dictionary = {}  # id -> {"bar": ProgressBar, "label": Label, "row": Control}

func _setup_active_gauges() -> void:
  var box = VBoxContainer.new()
  box.position = Vector2(0, 200)
  box.add_theme_constant_override("separation", 8)
  box.mouse_filter = Control.MOUSE_FILTER_IGNORE
  padded_area.add_child(box)
  var ids = ActiveManager.active_ids()
  for i in ids.size():
    var id: String = ids[i]
    var row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # 키 배지 (1/2)
    var key = Label.new()
    key.text = str(i + 1)
    key.custom_minimum_size = Vector2(30, 30)
    key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    key.add_theme_font_size_override("font_size", 22)
    key.add_theme_color_override("font_color", Color(1, 1, 1))
    key.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    key.add_theme_constant_override("outline_size", 3)
    key.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(key)
    # 충전 바
    var bar = ProgressBar.new()
    bar.custom_minimum_size = Vector2(120, 22)
    bar.min_value = 0.0
    bar.max_value = 1.0
    bar.show_percentage = false
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(bar)
    # 이름
    var name_label = Label.new()
    name_label.text = ActiveManager.active_name(id)
    name_label.add_theme_font_size_override("font_size", 18)
    name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
    name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    name_label.add_theme_constant_override("outline_size", 3)
    name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(name_label)
    box.add_child(row)
    _active_rows[id] = {"bar": bar, "label": name_label, "row": row}
    row.visible = ActiveManager.is_unlocked(id)  # 해금 = 게임 레벨(세션 중 불변)
    _update_active_gauge(id, ActiveManager.get_charge(id))
  ActiveManager.charge_changed.connect(_update_active_gauge)
  ActiveManager.active_ready.connect(_on_active_ready)

# ── 터치: 액티브 온스크린 버튼 (모바일, 키보드 1/2 대체) ──
var _touch_active_btns: Dictionary = {}  # id -> Button

func _setup_touch_active_buttons() -> void:
  var box = VBoxContainer.new()
  box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
  box.offset_left = -220
  box.offset_top = -320
  box.offset_right = -24
  box.offset_bottom = -24
  box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
  box.grow_vertical = Control.GROW_DIRECTION_BEGIN
  box.alignment = BoxContainer.ALIGNMENT_END
  box.add_theme_constant_override("separation", 16)
  padded_area.add_child(box)
  var ids = ActiveManager.active_ids()
  for i in ids.size():
    var id: String = ids[i]
    var btn = Button.new()
    btn.custom_minimum_size = Vector2(180, 130)
    btn.focus_mode = Control.FOCUS_NONE
    var slot := i
    btn.pressed.connect(func(): ActiveManager.fire_slot(slot))
    UIKit.style_button(btn, "sub")
    box.add_child(btn)
    _touch_active_btns[id] = btn
    btn.visible = ActiveManager.is_unlocked(id)
    _update_touch_active_btn(id, ActiveManager.get_charge(id))
  ActiveManager.charge_changed.connect(_update_touch_active_btn)

func _update_touch_active_btn(id: String, ratio: float) -> void:
  if not _touch_active_btns.has(id):
    return
  var btn: Button = _touch_active_btns[id]
  var ready := ratio >= 1.0
  btn.disabled = not ready
  if ready:
    btn.text = "%s\n▶ 발동" % ActiveManager.active_name(id)
  else:
    btn.text = "%s\n%d%%" % [ActiveManager.active_name(id), int(ratio * 100.0)]

# ── 콤보 미터 (중앙 상단) ──
var _combo_count_label: Label = null
var _combo_mult_label: Label = null
var _combo_timer_bar: ProgressBar = null
var _combo_root: Control = null

func _setup_combo_meter() -> void:
  _combo_root = Control.new()
  _combo_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _combo_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
  _combo_root.modulate.a = 0.0  # 콤보 없을 땐 숨김
  add_child(_combo_root)

  # 콤보 숫자 (큰 글씨, 상단 중앙)
  _combo_count_label = Label.new()
  _combo_count_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
  _combo_count_label.offset_top = 92.0
  _combo_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  _combo_count_label.add_theme_font_size_override("font_size", 52)
  _combo_count_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
  _combo_count_label.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0.0))
  _combo_count_label.add_theme_constant_override("outline_size", 6)
  _combo_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  _combo_count_label.pivot_offset = Vector2(0, 0)
  _combo_root.add_child(_combo_count_label)

  # 배율 표시
  _combo_mult_label = Label.new()
  _combo_mult_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
  _combo_mult_label.offset_top = 150.0
  _combo_mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  _combo_mult_label.add_theme_font_size_override("font_size", 24)
  _combo_mult_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
  _combo_mult_label.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0.0))
  _combo_mult_label.add_theme_constant_override("outline_size", 4)
  _combo_mult_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  _combo_root.add_child(_combo_mult_label)

  # 잔여 시간바 (중앙)
  _combo_timer_bar = ProgressBar.new()
  _combo_timer_bar.anchor_left = 0.5
  _combo_timer_bar.anchor_right = 0.5
  _combo_timer_bar.anchor_top = 0.0
  _combo_timer_bar.anchor_bottom = 0.0
  _combo_timer_bar.offset_left = -90.0
  _combo_timer_bar.offset_right = 90.0
  _combo_timer_bar.offset_top = 186.0
  _combo_timer_bar.offset_bottom = 196.0
  _combo_timer_bar.min_value = 0.0
  _combo_timer_bar.max_value = 1.0
  _combo_timer_bar.show_percentage = false
  _combo_timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
  _combo_root.add_child(_combo_timer_bar)

func _on_combo_changed(count: int, mult: float) -> void:
  if _combo_root == null:
    return
  if count <= 0:
    var tw0 = create_tween()
    tw0.tween_property(_combo_root, "modulate:a", 0.0, 0.25)
    return
  _combo_count_label.text = "%d 콤보" % count
  _combo_mult_label.text = "x%.2f" % mult
  _combo_root.modulate.a = 1.0
  # 팝 애니메이션
  _combo_count_label.pivot_offset = _combo_count_label.size * 0.5
  var tw = create_tween()
  tw.tween_property(_combo_count_label, "scale", Vector2(1.25, 1.25), 0.06)
  tw.tween_property(_combo_count_label, "scale", Vector2(1.0, 1.0), 0.1)

func _update_combo_timer_bar() -> void:
  if _combo_timer_bar == null:
    return
  if GameManager.combo_count <= 0:
    return
  var win = GameManager.get_combo_window()
  _combo_timer_bar.value = clampf(GameManager.combo_timer / win, 0.0, 1.0) if win > 0.0 else 0.0

func _update_active_gauge(id: String, ratio: float) -> void:
  if not _active_rows.has(id):
    return
  var bar: ProgressBar = _active_rows[id]["bar"]
  bar.value = ratio
  var name_label: Label = _active_rows[id]["label"]
  if ratio >= 1.0:
    name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))  # 준비 완료 = 금색
  else:
    name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

func _on_active_ready(id: String) -> void:
  if not _active_rows.has(id):
    return
  var row: Control = _active_rows[id]["row"]
  var tw = create_tween()
  tw.tween_property(row, "modulate", Color(1.4, 1.4, 1.4), 0.15)
  tw.tween_property(row, "modulate", Color(1, 1, 1), 0.15)

func _make_seed_icon() -> Control:
  var c = Control.new()
  c.custom_minimum_size = Vector2(28, 28)
  c.mouse_filter = Control.MOUSE_FILTER_IGNORE
  var body = Polygon2D.new()
  body.color = Color(0.55, 0.38, 0.18)
  var pts: PackedVector2Array = []
  for i in 12:
    var a = TAU / 12.0 * i
    pts.append(Vector2(14 + cos(a) * 7.0, 16 + sin(a) * 9.0))
  body.polygon = pts
  c.add_child(body)
  var sprout = Polygon2D.new()
  sprout.color = Color(0.35, 0.8, 0.35)
  sprout.polygon = PackedVector2Array([
    Vector2(14, 7), Vector2(19, 1), Vector2(15, 0), Vector2(14, 4),
    Vector2(13, 0), Vector2(9, 1)
  ])
  c.add_child(sprout)
  return c

func _update_seed_label(count: int, need: int) -> void:
  if seed_label:
    seed_label.text = "%d / %d" % [count, need]

func _on_goomok_ready_hud() -> void:
  if seed_label:
    seed_label.text = "▲"
    seed_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))

# ── 아이템 슬롯 ──

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
  # 레벨 캡 도달 시 게이지 만충 표시(더 이상 오르지 않음)
  if GameManager.session_level >= GameManager.get_session_level_cap():
    fury_progress.value = 100.0
    fury_label.text = "Lv.%d" % GameManager.session_level
    return
  var need = GameManager.get_fury_max()
  var pct = value / need * 100.0 if need > 0 else 0.0
  fury_progress.value = pct
  if OS.is_debug_build():
    fury_label.text = "Lv.%d %d%% (%d/%d)" % [GameManager.session_level, int(pct), int(value), int(need)]
  else:
    fury_label.text = "Lv.%d %d%%" % [GameManager.session_level, int(pct)]

# 세션 레벨업 → 파워업 3택 오버레이 표시(구 분노 보스 소환 대체)
func _on_level_up(_new_level: int) -> void:
  PlatformService.vibrate(120)  # 데스크톱에선 자동 무시
  _flash_fury_bar()
  var selection = preload("res://scenes/ui/powerup_selection.tscn").instantiate()
  get_tree().root.add_child(selection)

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

func _show_powerup_notification(type: String, level: int, prefix: String = "") -> void:
  if not _notif_container:
    _setup_notif_container()

  var PowerupSelection = preload("res://scripts/powerup_selection.gd")
  var data = PowerupSelection.get_powerup_data_by_type(type)
  if data.is_empty():
    return

  var text = prefix + data.get("name", type)

  # 더블 오어 낫싱: 결과 표시
  if type == "double_or_nothing":
    if level == 1:
      text = "더블! 코인 x2"
    else:
      text = "낫싱! 코인 전부 잃음"

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
  if type == "double_or_nothing" and level == 0:
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
  UIKit.style_button(btn, "sub")
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
