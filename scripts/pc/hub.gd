extends Control
## PC 허브(세션 사이 홈). 2페이지: 1)강화(스킬트리+룬+액티브) 2)월드선택+시작.
## ★ 플랫폼 분리 원칙: 이건 PC 전용 뷰(scenes/pc·scripts/pc). 로직은 공유 매니저에서만 읽는다.
## 1차 슬라이스 = 껍데기 + 상단바(게임레벨·XP·코인·보석) + 페이지 전환 + 콘텐츠 자리(placeholder).
##   다음 슬라이스에서 스킬트리/룬/액티브/월드선택 실제 내용 삽입.

const Progression = preload("res://core/progression.gd")
const Balance = preload("res://core/balance_data.gd")

const BG_COLOR := Color(0.10, 0.12, 0.14)
const PANEL_BG := Color(0.14, 0.17, 0.19)
const PANEL_BORDER := Color(0.28, 0.36, 0.42)

var _level_label: Label
var _xp_bar: ProgressBar
var _page1: Control
var _page2: Control

func _ready() -> void:
  # 배경
  var bg := ColorRect.new()
  bg.color = BG_COLOR
  bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
  add_child(bg)
  move_child(bg, 0)

  _build_top_bar()
  _build_pages()
  _show_page(1)

  GameManager.money_changed.connect(func(_m): _refresh_level())
  GameManager.game_level_changed.connect(func(_l): _refresh_level())
  _refresh_level()

# ── 상단 바 ──
func _build_top_bar() -> void:
  # 좌측: 게임레벨 + XP 게이지 (MoneyDisplay는 씬에서 우측 상단에 이미 배치됨)
  var box := VBoxContainer.new()
  box.position = Vector2(40, 30)
  box.add_theme_constant_override("separation", 4)
  box.mouse_filter = Control.MOUSE_FILTER_IGNORE
  add_child(box)

  _level_label = Label.new()
  _level_label.add_theme_font_size_override("font_size", 40)
  _level_label.add_theme_color_override("font_color", Color(1, 0.92, 0.5))
  _level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  _level_label.add_theme_constant_override("outline_size", 4)
  box.add_child(_level_label)

  _xp_bar = ProgressBar.new()
  _xp_bar.custom_minimum_size = Vector2(320, 22)
  _xp_bar.min_value = 0.0
  _xp_bar.max_value = 1.0
  _xp_bar.show_percentage = false
  box.add_child(_xp_bar)

  # 설정 기어 (좌상단 구석)
  var gear := Button.new()
  gear.text = "⚙"
  gear.add_theme_font_size_override("font_size", 30)
  gear.position = Vector2(0, 0)
  gear.custom_minimum_size = Vector2(64, 64)
  gear.flat = true
  gear.pressed.connect(_on_settings)
  add_child(gear)

func _refresh_level() -> void:
  if not is_instance_valid(_level_label):
    return
  var lv := GameManager.get_game_level()
  _level_label.text = "게임 레벨 Lv.%d" % lv
  if lv >= Balance.GLEVEL_CAP:
    _xp_bar.value = 1.0
    return
  var cur := Progression.glevel_threshold(Balance.GLEVEL_TOTAL_XP, lv)
  var nxt := Progression.glevel_threshold(Balance.GLEVEL_TOTAL_XP, lv + 1)
  var denom = maxf(0.001, nxt - cur)
  _xp_bar.value = clampf((GameManager.game_xp - cur) / denom, 0.0, 1.0)

# ── 페이지 ──
func _build_pages() -> void:
  _page1 = _make_page()
  _page2 = _make_page()
  add_child(_page1)
  add_child(_page2)
  _build_page1(_page1)
  _build_page2(_page2)

func _make_page() -> Control:
  var c := Control.new()
  c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  c.offset_top = 110.0
  c.offset_left = 40.0
  c.offset_right = -40.0
  c.offset_bottom = -40.0
  return c

func _show_page(n: int) -> void:
  _page1.visible = n == 1
  _page2.visible = n == 2

# 1페이지: 스킬트리(좌) + 룬(우상) + 액티브(우하)
func _build_page1(p: Control) -> void:
  var skill := _placeholder("스킬 트리\n(다음 슬라이스)", PANEL_BORDER)
  skill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  skill.offset_right = -700.0
  skill.offset_bottom = -90.0
  p.add_child(skill)

  var rune := _placeholder("🔮 룬 슬롯\n(다음 슬라이스)", Color(0.5, 0.4, 0.7))
  rune.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  rune.offset_left = -640.0
  rune.offset_bottom = -540.0
  p.add_child(rune)

  var active := _placeholder("⚡ 액티브 강화\n(다음 슬라이스)", Color(0.45, 0.6, 0.75))
  active.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  active.offset_left = -640.0
  active.offset_top = 480.0
  active.offset_bottom = -90.0
  p.add_child(active)

  var next_btn := Button.new()
  next_btn.text = "월드 선택 ▶"
  next_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
  next_btn.offset_left = -360.0
  next_btn.offset_top = -80.0
  next_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
  next_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
  UIKit.style_button(next_btn, "main", Vector2(340, 76))
  next_btn.pressed.connect(func(): GameManager.play_button_click(); _show_page(2))
  p.add_child(next_btn)

# 2페이지: 월드 선택 + 시작
func _build_page2(p: Control) -> void:
  var world := _placeholder("월드 선택\n(다음 슬라이스)", Color(0.3, 0.5, 0.4))
  world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  world.offset_bottom = -110.0
  p.add_child(world)

  var back_btn := Button.new()
  back_btn.text = "◀ 강화"
  back_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
  back_btn.offset_top = -80.0
  back_btn.offset_right = 260.0
  back_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
  UIKit.style_button(back_btn, "muted", Vector2(240, 76))
  back_btn.pressed.connect(func(): GameManager.play_button_click(); _show_page(1))
  p.add_child(back_btn)

  var start_btn := Button.new()
  start_btn.text = "시작 ▶"
  start_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
  start_btn.offset_left = -420.0
  start_btn.offset_top = -100.0
  start_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
  start_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
  UIKit.style_button(start_btn, "main", Vector2(400, 92))
  start_btn.pressed.connect(_on_start)
  p.add_child(start_btn)

func _placeholder(text: String, border: Color) -> Control:
  var panel := PanelContainer.new()
  var sb := StyleBoxFlat.new()
  sb.bg_color = PANEL_BG
  sb.set_corner_radius_all(16)
  sb.set_border_width_all(2)
  sb.border_color = border
  panel.add_theme_stylebox_override("panel", sb)
  var lbl := Label.new()
  lbl.text = text
  lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  lbl.add_theme_font_size_override("font_size", 30)
  lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
  panel.add_child(lbl)
  return panel

func _on_settings() -> void:
  GameManager.play_button_click()
  # TODO(다음 슬라이스): 설정 오버레이 연결

func _on_start() -> void:
  GameManager.play_confirm_click()
  UIRouter.goto("game")
