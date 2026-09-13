extends Control

@onready var play_btn: Button = $VBoxContainer/PlayBtn
@onready var upgrade_btn: Button = $VBoxContainer/UpgradeBtn
@onready var quit_btn: Button = $VBoxContainer/QuitBtn
@onready var quit_confirm_dialog: Control = $QuitConfirmDialog
@onready var title_image: TextureRect = $TitleImage
@onready var padded_area: Control = $PaddedArea
@onready var money_display = $PaddedArea/MoneyDisplay
@onready var upgrade_panel: Control = $UpgradePanel/Control

# World selection overlay (built dynamically)
var world_overlay: Control = null
var _ws_selected: int = -1  # Currently highlighted world index in panel
var _ws_cards_container: VBoxContainer = null
var _ws_action_btn: Button = null
var _debug_container: HBoxContainer = null
var _settings_btn: Button = null
var _settings_overlay: Control = null
var _confirm_dialog_mode: String = "quit"  # "quit" or "reset"
var _debug_tap_count: int = 0
var _debug_last_tap_time: float = 0.0
var _upgrade_badge: Label = null

const WORLD_DATA: Array = [
  {"name": "슬라임 늪", "monsters": "슬라임"},
  {"name": "들판", "monsters": "멧돼지"},
  {"name": "기사의 성벽", "monsters": "잔디 기사"},
  {"name": "마법의 숲", "monsters": "마도사"},
  {"name": "수정 호수", "monsters": "수정 사슴"},
  {"name": "고대 유적", "monsters": "잔디 골렘"},
  {"name": "용의 봉우리", "monsters": "드래곤"},
]

func _ready() -> void:
  play_btn.pressed.connect(_on_play_pressed)
  upgrade_btn.pressed.connect(_on_upgrade_pressed)
  quit_btn.pressed.connect(_on_quit_pressed)
  quit_confirm_dialog.dialog_confirmed.connect(_on_confirm_dialog_confirmed)

  # Hide the toggle buttons on panels (we use menu buttons instead)
  upgrade_panel.call_deferred("set_toggle_button_visible", false)

  # Connect panel signals for mutual exclusion
  upgrade_panel.panel_opened.connect(_on_panel_opened)
  upgrade_panel.panel_closed.connect(_on_panel_closed)

  # Money display is handled by MoneyDisplay scene

  # Debug buttons (debug build only)
  if OS.has_feature("debug"):
    _build_debug_buttons()
    _debug_container.visible = false
    money_display.mouse_filter = Control.MOUSE_FILTER_STOP
    money_display.gui_input.connect(_on_money_display_input)

  # 버튼 스타일 적용 (btn_size로 크기+폰트 자동 비례)
  var viewport_w = get_viewport_rect().size.x

  play_btn.text = ""
  play_btn.icon = preload("res://resources/images/icon/start.png")
  play_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
  play_btn.expand_icon = true
  play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
  GameManager.style_button(play_btn, "main", Vector2(460, 288))


  upgrade_btn.text = "강화"
  upgrade_btn.icon = preload("res://resources/images/icon/icon_upgrade.png")
  upgrade_btn.expand_icon = true
  upgrade_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
  GameManager.style_button(upgrade_btn, "sub", Vector2(460, 112))

  # 강화 버튼 느낌표 뱃지
  _upgrade_badge = Label.new()
  _upgrade_badge.text = "!"
  _upgrade_badge.add_theme_font_size_override("font_size", 48)
  _upgrade_badge.add_theme_color_override("font_color", Color.WHITE)
  _upgrade_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  _upgrade_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  var badge_bg = StyleBoxFlat.new()
  badge_bg.bg_color = Color(0.9, 0.2, 0.2)
  badge_bg.corner_radius_top_left = 30
  badge_bg.corner_radius_top_right = 30
  badge_bg.corner_radius_bottom_left = 30
  badge_bg.corner_radius_bottom_right = 30
  badge_bg.content_margin_left = 12
  badge_bg.content_margin_right = 12
  badge_bg.content_margin_top = 4
  badge_bg.content_margin_bottom = 4
  _upgrade_badge.add_theme_stylebox_override("normal", badge_bg)
  _upgrade_badge.custom_minimum_size = Vector2(60, 60)
  upgrade_btn.add_child(_upgrade_badge)
  _upgrade_badge.position = Vector2(upgrade_btn.custom_minimum_size.x - 60, -18)
  _update_upgrade_badge()

  GameManager.money_changed.connect(_on_money_changed_badge)
  GameManager.upgrade_purchased.connect(_on_upgrade_purchased_badge)

  # 설정 버튼 (좌측 상단 톱니 아이콘)
  _settings_btn = Button.new()
  _settings_btn.text = ""
  _settings_btn.icon = preload("res://resources/images/icon/settings.png")
  _settings_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
  _settings_btn.expand_icon = true
  _settings_btn.flat = true
  _settings_btn.custom_minimum_size = Vector2(80, 80)
  _settings_btn.position = Vector2(0, 0)
  _settings_btn.pressed.connect(_on_settings_pressed)
  _settings_btn.modulate = Color(0.7, 0.7, 0.7)
  padded_area.add_child(_settings_btn)

  quit_btn.text = "종료"
  quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
  GameManager.style_button(quit_btn, "muted", Vector2(460, 112))

  # Title animation
  animate_title()

  # Main menu BGM
  _start_menu_bgm()


var _menu_bgm: AudioStreamPlayer

func _start_menu_bgm() -> void:
  _menu_bgm = AudioStreamPlayer.new()
  _menu_bgm.stream = load("res://resources/sounds/bgm_main.ogg")
  _menu_bgm.volume_db = -10.0
  _menu_bgm.finished.connect(_menu_bgm.play)
  add_child(_menu_bgm)
  if GameManager.bgm_enabled:
    _menu_bgm.play()


func animate_title() -> void:
  title_image.pivot_offset = title_image.size / 2.0
  var tween = create_tween()
  tween.set_loops()
  tween.tween_property(title_image, "scale", Vector2(1.05, 1.05), 1.0)
  tween.tween_property(title_image, "scale", Vector2(1.0, 1.0), 1.0)

func _on_play_pressed() -> void:
  GameManager.play_button_click()
  _open_world_select()

func _start_game() -> void:
  if _menu_bgm:
    _menu_bgm.stop()
  get_tree().change_scene_to_file("res://scenes/core/main.tscn")

func _notification(what: int) -> void:
  if what == NOTIFICATION_WM_GO_BACK_REQUEST:
    if quit_confirm_dialog.visible:
      quit_confirm_dialog.hide_dialog()
    elif _settings_overlay != null:
      _close_settings()
    elif upgrade_panel.is_open:
      upgrade_panel._on_close_pressed()
    elif world_overlay != null:
      _close_world_select()

func _on_upgrade_pressed() -> void:
  GameManager.play_button_click()
  upgrade_panel.open_panel()

func _on_quit_pressed() -> void:
  GameManager.play_button_click()
  _confirm_dialog_mode = "quit"
  quit_confirm_dialog.show_dialog("게임을 종료할까요?", "종료", "취소", true)

func _on_confirm_dialog_confirmed() -> void:
  if _confirm_dialog_mode == "reset":
    _close_settings()
    SaveManager.reset_all_data()
    update_money_display()
  else:
    get_tree().quit()

func _on_panel_opened() -> void:
  play_btn.disabled = true
  upgrade_btn.disabled = true
  quit_btn.disabled = true
  if _settings_btn: _settings_btn.disabled = true

func _on_panel_closed() -> void:
  play_btn.disabled = false
  upgrade_btn.disabled = false
  quit_btn.disabled = false
  if _settings_btn: _settings_btn.disabled = false
  _update_upgrade_badge()

func update_money_display() -> void:
  money_display.update_display()

func _update_upgrade_badge() -> void:
  if _upgrade_badge:
    _upgrade_badge.visible = GameManager.has_any_purchasable_skill()

func _on_money_changed_badge(_money: int) -> void:
  _update_upgrade_badge()

func _on_upgrade_purchased_badge(_type: String, _level: int) -> void:
  _update_upgrade_badge()

# ── World Selection Panel ──

func _open_world_select() -> void:
  if world_overlay != null:
    return
  _on_panel_opened()
  _ws_selected = GameManager.selected_world

  world_overlay = Control.new()
  world_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
  world_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
  add_child(world_overlay)

  # Dim background
  var bg = ColorRect.new()
  bg.color = Color(0.04, 0.07, 0.08, 0.8)
  bg.set_anchors_preset(Control.PRESET_FULL_RECT)
  world_overlay.add_child(bg)

  # Center panel — fixed size
  var center = CenterContainer.new()
  center.set_anchors_preset(Control.PRESET_FULL_RECT)
  world_overlay.add_child(center)

  var panel = PanelContainer.new()
  panel.custom_minimum_size = Vector2(780, 1550)
  var panel_style = StyleBoxFlat.new()
  panel_style.bg_color = Color(0.09, 0.12, 0.12)
  panel_style.corner_radius_top_left = 20
  panel_style.corner_radius_top_right = 20
  panel_style.corner_radius_bottom_left = 20
  panel_style.corner_radius_bottom_right = 20
  panel_style.border_width_top = 3
  panel_style.border_width_bottom = 3
  panel_style.border_width_left = 3
  panel_style.border_width_right = 3
  panel_style.border_color = Color(0.25, 0.47, 0.4)
  panel_style.content_margin_left = 30
  panel_style.content_margin_right = 30
  panel_style.content_margin_top = 44
  panel_style.content_margin_bottom = 0
  panel.add_theme_stylebox_override("panel", panel_style)
  center.add_child(panel)

  var vbox = VBoxContainer.new()
  vbox.add_theme_constant_override("separation", 7)
  panel.add_child(vbox)

  # Header
  var header = Label.new()
  header.text = "월드 선택"
  header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  header.add_theme_font_size_override("font_size", 50)
  header.add_theme_color_override("font_color", Color.WHITE)
  header.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  header.add_theme_constant_override("outline_size", 3)
  vbox.add_child(header)

  # Separator (with 12px top/bottom margin via MarginContainer)
  var sep_margin = MarginContainer.new()
  sep_margin.add_theme_constant_override("margin_top", 16)
  sep_margin.add_theme_constant_override("margin_bottom", 16)
  vbox.add_child(sep_margin)
  var sep = ColorRect.new()
  sep.color = Color(0.24, 0.24, 0.32)
  sep.custom_minimum_size = Vector2(0, 2)
  sep_margin.add_child(sep)

  # World cards container (for rebuilding cards on selection change)
  _ws_cards_container = VBoxContainer.new()
  _ws_cards_container.add_theme_constant_override("separation", 20)
  vbox.add_child(_ws_cards_container)

  _ws_rebuild_cards()

  # Spacer between cards and buttons
  var spacer = Control.new()
  spacer.custom_minimum_size = Vector2(0, 40)
  vbox.add_child(spacer)

  # Action button (게임 입장 / 해금)
  var action_center = CenterContainer.new()
  action_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  vbox.add_child(action_center)

  _ws_action_btn = Button.new()
  _ws_action_btn.custom_minimum_size = Vector2(420, 90)
  _ws_action_btn.add_theme_font_size_override("font_size", 38)
  _ws_action_btn.pressed.connect(_on_action_btn_pressed)
  GameManager.style_button(_ws_action_btn)
  action_center.add_child(_ws_action_btn)
  _ws_update_action_btn()

  # Close button
  var close_center = CenterContainer.new()
  close_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  vbox.add_child(close_center)

  var close_btn = Button.new()
  close_btn.text = "닫기"
  close_btn.custom_minimum_size = Vector2(420, 90)
  close_btn.add_theme_font_size_override("font_size", 38)
  close_btn.pressed.connect(_close_world_select)
  GameManager.style_button(close_btn, "muted")
  close_center.add_child(close_btn)

func _ws_rebuild_cards() -> void:
  for child in _ws_cards_container.get_children():
    child.queue_free()
  for i in range(WORLD_DATA.size()):
    var card = _create_world_card(i)
    _ws_cards_container.add_child(card)

func _create_world_card(index: int) -> PanelContainer:
  var world = WORLD_DATA[index]
  var unlocked = index in GameManager.unlocked_worlds
  var cost = GameManager.WORLD_UNLOCK_COSTS[index]
  var selected = index == _ws_selected

  var card = PanelContainer.new()
  card.custom_minimum_size = Vector2(0, 143)

  var style = StyleBoxFlat.new()
  if selected:
    if unlocked:
      style.bg_color = Color(0.12, 0.24, 0.2)
      style.border_color = Color(0.35, 0.85, 0.62)
    else:
      style.bg_color = Color(0.15, 0.15, 0.22)
      style.border_color = Color(0.45, 0.45, 0.7)
    style.border_width_top = 3
    style.border_width_bottom = 3
    style.border_width_left = 3
    style.border_width_right = 3
  else:
    if unlocked:
      style.bg_color = Color(0.1, 0.17, 0.15)
      style.border_color = Color(0.25, 0.55, 0.42)
    else:
      style.bg_color = Color(0.09, 0.1, 0.14)
      style.border_color = Color(0.22, 0.26, 0.35)
    style.border_width_top = 2
    style.border_width_bottom = 2
    style.border_width_left = 2
    style.border_width_right = 2
  style.corner_radius_top_left = 14
  style.corner_radius_top_right = 14
  style.corner_radius_bottom_left = 14
  style.corner_radius_bottom_right = 14
  style.content_margin_left = 26
  style.content_margin_right = 26
  style.content_margin_top = 18
  style.content_margin_bottom = 18
  card.add_theme_stylebox_override("panel", style)

  var has_key = GameManager.has_key(index)
  var fully_locked = not unlocked and not has_key

  if fully_locked:
    # Locked without key: show only lock icon centered
    var lock_container = CenterContainer.new()
    lock_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    lock_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    card.add_child(lock_container)
    var lock_icon = TextureRect.new()
    lock_icon.texture = preload("res://resources/images/icon/lock.png")
    lock_icon.custom_minimum_size = Vector2(108, 108)
    lock_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    lock_icon.modulate = Color(0.4, 0.4, 0.5)
    lock_container.add_child(lock_icon)
  else:
    var hbox = HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 14)
    hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.add_child(hbox)

    # Status icon
    var icon_label = Label.new()
    icon_label.add_theme_font_size_override("font_size", 43)
    icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if unlocked:
      icon_label.text = "O"
      icon_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.55))
    else:
      icon_label.text = "X"
      icon_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
    hbox.add_child(icon_label)

    # Info column
    var info_vbox = VBoxContainer.new()
    info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    info_vbox.add_theme_constant_override("separation", 8)
    info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hbox.add_child(info_vbox)

    var name_label = Label.new()
    name_label.text = world.name
    name_label.add_theme_font_size_override("font_size", 38)
    name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if unlocked:
      name_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
    else:
      name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
    name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    name_label.add_theme_constant_override("outline_size", 2)
    info_vbox.add_child(name_label)

    var monster_label = Label.new()
    monster_label.text = world.monsters
    monster_label.add_theme_font_size_override("font_size", 26)
    monster_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if unlocked:
      monster_label.add_theme_color_override("font_color", Color(0.62, 0.7, 0.66))
    else:
      monster_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
    info_vbox.add_child(monster_label)

    var strength = GameManager.get_world_strength_level(index)

    # 초월 UI (클리어된 월드만)
    if unlocked and GameManager.is_world_cleared(index):
      var str_hbox = HBoxContainer.new()
      str_hbox.add_theme_constant_override("separation", 10)
      str_hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
      str_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
      hbox.add_child(str_hbox)

      # 텍스트 두줄: 초월 레벨 + 효과
      var str_info = VBoxContainer.new()
      str_info.add_theme_constant_override("separation", 1)
      str_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
      str_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
      str_hbox.add_child(str_info)

      if strength > 0:
        var str_row = HBoxContainer.new()
        str_row.add_theme_constant_override("separation", 6)
        str_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
        str_info.add_child(str_row)

        var str_label = Label.new()
        str_label.text = "초월 Lv.%d" % strength
        str_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        str_label.add_theme_font_size_override("font_size", 28)
        str_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
        str_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
        str_label.add_theme_constant_override("outline_size", 2)
        # 현재 초월 레벨 보석 수집 완료 시 ✓ 표시 (레벨 왼쪽)
        if GameManager.has_collected_gems(index, strength):
          var gem_mark = Label.new()
          gem_mark.text = "✓"
          gem_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
          gem_mark.add_theme_font_size_override("font_size", 28)
          gem_mark.add_theme_color_override("font_color", Color(0.95, 0.3, 0.5))
          gem_mark.add_theme_color_override("font_outline_color", Color(0, 0, 0))
          gem_mark.add_theme_constant_override("outline_size", 2)
          gem_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
          str_row.add_child(gem_mark)

        str_row.add_child(str_label)

      if strength > 0:
        var str_spacer = Control.new()
        str_spacer.custom_minimum_size = Vector2(0, 8)
        str_info.add_child(str_spacer)
        var hp_bonus = int(strength * 40)
        var rw_bonus = int(strength * 50)
        var hp_label = Label.new()
        hp_label.text = "체력+%d%%" % hp_bonus
        hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        hp_label.add_theme_font_size_override("font_size", 23)
        hp_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.4))
        str_info.add_child(hp_label)
        var rw_label = Label.new()
        rw_label.text = "보상+%d%%" % rw_bonus
        rw_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        rw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        rw_label.add_theme_font_size_override("font_size", 23)
        rw_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.4))
        str_info.add_child(rw_label)

      var str_btn = Button.new()
      str_btn.add_theme_font_size_override("font_size", 36)
      str_btn.custom_minimum_size = Vector2(150, 108)
      if strength >= GameManager.MAX_STRENGTH_LEVEL:
        str_btn.text = "MAX"
        str_btn.disabled = true
        GameManager.style_button(str_btn, "muted")
      else:
        str_btn.text = "초월"
        str_btn.pressed.connect(_on_strengthen_pressed.bind(index))
        GameManager.style_button(str_btn, "main")

      str_hbox.add_child(str_btn)

      # 첫 초월 전 말풍선 툴팁 (절대 위치 — 카드 레이아웃에 영향 없음)
      if strength == 0 and not GameManager.has_ever_transcended:
        var bubble_root = VBoxContainer.new()
        bubble_root.add_theme_constant_override("separation", -5)
        bubble_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
        str_btn.add_child(bubble_root)

        # 말풍선 본체
        var bubble = PanelContainer.new()
        bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var bstyle = StyleBoxFlat.new()
        bstyle.bg_color = Color(0.95, 0.92, 0.82)
        bstyle.corner_radius_top_left = 10
        bstyle.corner_radius_top_right = 10
        bstyle.corner_radius_bottom_left = 10
        bstyle.corner_radius_bottom_right = 10
        bstyle.content_margin_left = 12
        bstyle.content_margin_right = 12
        bstyle.content_margin_top = 8
        bstyle.content_margin_bottom = 8
        bstyle.border_width_top = 3
        bstyle.border_width_bottom = 3
        bstyle.border_width_left = 3
        bstyle.border_width_right = 3
        bstyle.border_color = Color(0.7, 0.55, 0.2)
        bubble.add_theme_stylebox_override("panel", bstyle)
        bubble_root.add_child(bubble)

        var tip = Label.new()
        tip.text = "보상이 늘어나고\n특별한 무언가를 발견할지도..."
        tip.add_theme_font_size_override("font_size", 18)
        tip.add_theme_color_override("font_color", Color(0.2, 0.15, 0.05))
        tip.add_theme_color_override("font_outline_color", Color(0.7, 0.55, 0.2))
        tip.add_theme_constant_override("outline_size", 2)
        tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bubble.add_child(tip)

        # 말풍선 꼭지 (▼)
        var arrow = Label.new()
        arrow.text = "▼"
        arrow.add_theme_font_size_override("font_size", 14)
        arrow.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82))
        arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bubble_root.add_child(arrow)

        # 버튼 기준 위쪽 오른쪽에 배치 (레이아웃 완료 후)
        var _reposition = func():
          if str_btn.size.x > 0 and bubble_root.size.y > 0:
            bubble_root.position = Vector2(
              (str_btn.size.x - bubble_root.size.x) * 0.5 + str_btn.size.x * 0.5,
              -bubble_root.size.y - 4
            )
        bubble_root.resized.connect(_reposition)
        str_btn.resized.connect(_reposition)

    # Cost / key status (locked with key)
    if not unlocked:
      var status_vbox = VBoxContainer.new()
      status_vbox.add_theme_constant_override("separation", 8)
      status_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
      status_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
      hbox.add_child(status_vbox)

      var cost_color = Color(1, 0.9, 0.3) if GameManager.money >= cost else Color(0.5, 0.4, 0.4)
      var cost_hbox = GameManager.create_coin_label(GameManager.format_number(cost), 38, cost_color)
      cost_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
      status_vbox.add_child(cost_hbox)

      var key_label = Label.new()
      key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
      key_label.add_theme_font_size_override("font_size", 26)
      key_label.text = "열쇠 보유"
      key_label.add_theme_color_override("font_color", Color(0.3, 1.0, 1.0))
      key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
      status_vbox.add_child(key_label)

  # Clickable overlay button (disabled for fully locked worlds)
  # 초월 버튼보다 먼저 추가하여, 초월 버튼이 위에 오도록 함
  if not fully_locked:
    var btn = Button.new()
    btn.flat = true
    btn.anchors_preset = Control.PRESET_FULL_RECT
    btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    btn.pressed.connect(_on_world_card_pressed.bind(index))
    card.add_child(btn)
    card.move_child(btn, 0)

  return card

func _on_world_card_pressed(index: int) -> void:
  GameManager.play_button_click()
  _ws_selected = index
  _ws_rebuild_cards()
  _ws_update_action_btn()

var _strengthen_dialog: Control = null

func _on_strengthen_pressed(index: int) -> void:
  GameManager.play_button_click()
  _show_strengthen_dialog(index)

func _show_strengthen_dialog(world: int) -> void:
  if _strengthen_dialog:
    _strengthen_dialog.queue_free()

  var level = GameManager.get_world_strength_level(world)
  var cost = GameManager.get_strengthen_cost(world)
  var needs_gems = level > 0 and not GameManager.has_collected_gems(world, level)
  var can_afford = GameManager.money >= cost and not needs_gems

  var base_hp = GameManager.WORLD_GRASS_HP_MULT[world] if world < GameManager.WORLD_GRASS_HP_MULT.size() else 1.0
  var base_rw = GameManager.WORLD_GRASS_REWARD_MULT[world] if world < GameManager.WORLD_GRASS_REWARD_MULT.size() else 1.0
  var cur_hp = base_hp * (1.0 + level * 0.4)
  var cur_rw = base_rw * (1.0 + level * 0.5)
  var next_hp = base_hp * (1.0 + (level + 1) * 0.4)
  var next_rw = base_rw * (1.0 + (level + 1) * 0.5)

  # Root overlay
  var root = Control.new()
  root.set_anchors_preset(Control.PRESET_FULL_RECT)
  root.mouse_filter = Control.MOUSE_FILTER_STOP

  var overlay = ColorRect.new()
  overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
  overlay.color = Color(0, 0, 0, 0.6)
  root.add_child(overlay)

  # Dialog panel
  var panel_style = StyleBoxFlat.new()
  panel_style.bg_color = Color(0.15, 0.15, 0.2, 0.98)
  panel_style.corner_radius_top_left = 15
  panel_style.corner_radius_top_right = 15
  panel_style.corner_radius_bottom_right = 15
  panel_style.corner_radius_bottom_left = 15

  var panel = Panel.new()
  panel.set_anchors_preset(Control.PRESET_CENTER)
  panel.offset_left = -300
  panel.offset_top = -185
  panel.offset_right = 300
  panel.offset_bottom = 185
  panel.add_theme_stylebox_override("panel", panel_style)
  root.add_child(panel)

  var vbox = VBoxContainer.new()
  vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
  vbox.offset_left = 28
  vbox.offset_top = 24
  vbox.offset_right = -28
  vbox.offset_bottom = -24
  vbox.add_theme_constant_override("separation", 14)
  panel.add_child(vbox)

  # Title
  var title = Label.new()
  title.text = "초월 Lv.%d → Lv.%d" % [level, level + 1]
  title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  title.add_theme_font_size_override("font_size", 32)
  title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
  title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  title.add_theme_constant_override("outline_size", 3)
  vbox.add_child(title)

  # Cost row
  var cost_row = HBoxContainer.new()
  cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
  cost_row.add_theme_constant_override("separation", 8)
  var cost_label = Label.new()
  cost_label.text = "비용  "
  cost_label.add_theme_font_size_override("font_size", 28)
  cost_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
  cost_row.add_child(cost_label)
  var cost_color = Color(1, 0.9, 0.3) if can_afford else Color(0.8, 0.3, 0.3)
  var coin_label = GameManager.create_coin_label(GameManager.format_number(cost), 28, cost_color)
  cost_row.add_child(coin_label)
  vbox.add_child(cost_row)

  # Separator
  var sep = ColorRect.new()
  sep.color = Color(0.24, 0.24, 0.32)
  sep.custom_minimum_size = Vector2(0, 2)
  vbox.add_child(sep)

  # Effects
  var effects_vbox = VBoxContainer.new()
  effects_vbox.add_theme_constant_override("separation", 6)

  var hp_rt = RichTextLabel.new()
  hp_rt.bbcode_enabled = true
  hp_rt.fit_content = true
  hp_rt.scroll_active = false
  hp_rt.text = "[center]풀 체력   x%.1f → [color=#ff6655]x%.1f[/color][/center]" % [cur_hp, next_hp]
  hp_rt.add_theme_font_size_override("normal_font_size", 25)
  hp_rt.add_theme_color_override("default_color", Color(0.85, 0.85, 0.9))
  effects_vbox.add_child(hp_rt)

  var rw_rt = RichTextLabel.new()
  rw_rt.bbcode_enabled = true
  rw_rt.fit_content = true
  rw_rt.scroll_active = false
  rw_rt.text = "[center]풀 보상   x%.1f → [color=#ff6655]x%.1f[/color][/center]" % [cur_rw, next_rw]
  rw_rt.add_theme_font_size_override("normal_font_size", 25)
  rw_rt.add_theme_color_override("default_color", Color(0.85, 0.85, 0.9))
  effects_vbox.add_child(rw_rt)

  vbox.add_child(effects_vbox)

  # Warning messages
  if needs_gems:
    var warn = Label.new()
    warn.text = "초월 Lv.%d 보석을 먼저 획득하세요" % level
    warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    warn.add_theme_font_size_override("font_size", 22)
    warn.add_theme_color_override("font_color", Color(0.95, 0.3, 0.5))
    vbox.add_child(warn)
  elif GameManager.money < cost:
    var warn = Label.new()
    warn.text = "돈이 부족합니다"
    warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    warn.add_theme_font_size_override("font_size", 22)
    warn.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
    vbox.add_child(warn)

  # Spacer
  var spacer = Control.new()
  spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
  vbox.add_child(spacer)

  # Buttons
  var btn_row = HBoxContainer.new()
  btn_row.add_theme_constant_override("separation", 20)
  var cancel_btn = Button.new()
  cancel_btn.text = "취소"
  cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  cancel_btn.custom_minimum_size = Vector2(0, 80)
  cancel_btn.add_theme_font_size_override("font_size", 28)
  GameManager.style_button(cancel_btn, "muted")
  cancel_btn.pressed.connect(_on_strengthen_cancelled)
  btn_row.add_child(cancel_btn)

  var confirm_btn = Button.new()
  confirm_btn.text = "초월하기"
  confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  confirm_btn.custom_minimum_size = Vector2(0, 80)
  confirm_btn.add_theme_font_size_override("font_size", 28)
  confirm_btn.disabled = not can_afford
  GameManager.style_button(confirm_btn, "main" if can_afford else "muted")
  confirm_btn.pressed.connect(_on_strengthen_confirmed.bind(world))
  btn_row.add_child(confirm_btn)

  vbox.add_child(btn_row)

  _strengthen_dialog = root
  add_child(root)

func _on_strengthen_confirmed(world: int) -> void:
  if _strengthen_dialog:
    _strengthen_dialog.queue_free()
    _strengthen_dialog = null
  if GameManager.strengthen_world(world):
    GameManager.play_skill_upgrade_sound()
    update_money_display()
    _ws_rebuild_cards()

func _on_strengthen_cancelled() -> void:
  GameManager.play_button_click()
  if _strengthen_dialog:
    _strengthen_dialog.queue_free()
    _strengthen_dialog = null

func _ws_update_action_btn() -> void:
  if _ws_action_btn == null:
    return

  var unlocked = _ws_selected in GameManager.unlocked_worlds
  if unlocked:
    _ws_action_btn.text = "게임 입장"
    _ws_action_btn.disabled = false
  else:
    var cost = GameManager.WORLD_UNLOCK_COSTS[_ws_selected]
    var has_key = GameManager.has_key(_ws_selected)
    if has_key:
      _ws_action_btn.text = "해금"
      _ws_action_btn.disabled = GameManager.money < cost
    else:
      _ws_action_btn.text = "열쇠 필요"
      _ws_action_btn.disabled = true

func _on_action_btn_pressed() -> void:
  GameManager.play_confirm_click()
  if _ws_selected < 0:
    return
  var unlocked = _ws_selected in GameManager.unlocked_worlds
  if unlocked:
    GameManager.selected_world = _ws_selected
    SaveManager.save_game()
    _close_world_select()
    _start_game()
  else:
    if GameManager.unlock_world(_ws_selected):
      GameManager.play_unlock_sound()
      update_money_display()
      _ws_rebuild_cards()
      _ws_update_action_btn()

func _close_world_select() -> void:
  GameManager.play_button_click()
  if world_overlay != null:
    world_overlay.queue_free()
    world_overlay = null
  _ws_cards_container = null
  _ws_action_btn = null
  _on_panel_closed()

# ── Settings Popup ──

func _on_settings_pressed() -> void:
  GameManager.play_button_click()
  _open_settings()

var _bgm_toggle_btn: CheckButton = null
var _sfx_toggle_btn: CheckButton = null
var _vibration_toggle_btn: CheckButton = null

func _open_settings() -> void:
  if _settings_overlay != null:
    return
  _on_panel_opened()

  _settings_overlay = Control.new()
  _settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
  _settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
  add_child(_settings_overlay)

  # Dim background
  var bg = ColorRect.new()
  bg.color = Color(0.04, 0.07, 0.08, 0.8)
  bg.set_anchors_preset(Control.PRESET_FULL_RECT)
  _settings_overlay.add_child(bg)

  # Center container
  var center = CenterContainer.new()
  center.set_anchors_preset(Control.PRESET_FULL_RECT)
  _settings_overlay.add_child(center)

  # Panel
  var panel = PanelContainer.new()
  panel.custom_minimum_size = Vector2(640, 0)
  var panel_style = StyleBoxFlat.new()
  panel_style.bg_color = Color(0.09, 0.12, 0.12)
  panel_style.corner_radius_top_left = 20
  panel_style.corner_radius_top_right = 20
  panel_style.corner_radius_bottom_left = 20
  panel_style.corner_radius_bottom_right = 20
  panel_style.border_width_top = 3
  panel_style.border_width_bottom = 3
  panel_style.border_width_left = 3
  panel_style.border_width_right = 3
  panel_style.border_color = Color(0.25, 0.47, 0.4)
  panel_style.content_margin_left = 40
  panel_style.content_margin_right = 40
  panel_style.content_margin_top = 44
  panel_style.content_margin_bottom = 40
  panel.add_theme_stylebox_override("panel", panel_style)
  center.add_child(panel)

  var vbox = VBoxContainer.new()
  vbox.add_theme_constant_override("separation", 14)
  panel.add_child(vbox)

  # Header
  var header = Label.new()
  header.text = "설정"
  header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  header.add_theme_font_size_override("font_size", 42)
  header.add_theme_color_override("font_color", Color.WHITE)
  header.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  header.add_theme_constant_override("outline_size", 3)
  vbox.add_child(header)

  # Separator
  var sep1 = ColorRect.new()
  sep1.color = Color(0.24, 0.24, 0.32)
  sep1.custom_minimum_size = Vector2(0, 2)
  vbox.add_child(sep1)

  # BGM toggle row
  var bgm_row = HBoxContainer.new()
  bgm_row.add_theme_constant_override("separation", 20)
  var bgm_label = Label.new()
  bgm_label.text = "배경음"
  bgm_label.add_theme_font_size_override("font_size", 36)
  bgm_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
  bgm_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  bgm_row.add_child(bgm_label)
  _bgm_toggle_btn = _create_toggle(GameManager.bgm_enabled, _on_bgm_toggled)
  bgm_row.add_child(_bgm_toggle_btn.get_parent())
  vbox.add_child(bgm_row)

  # SFX toggle row
  var sfx_row = HBoxContainer.new()
  sfx_row.add_theme_constant_override("separation", 20)
  var sfx_label = Label.new()
  sfx_label.text = "효과음"
  sfx_label.add_theme_font_size_override("font_size", 36)
  sfx_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
  sfx_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  sfx_row.add_child(sfx_label)
  _sfx_toggle_btn = _create_toggle(GameManager.sfx_enabled, _on_sfx_toggled)
  sfx_row.add_child(_sfx_toggle_btn.get_parent())
  vbox.add_child(sfx_row)

  # Vibration toggle row
  var vib_row = HBoxContainer.new()
  vib_row.add_theme_constant_override("separation", 20)
  var vib_label = Label.new()
  vib_label.text = "진동"
  vib_label.add_theme_font_size_override("font_size", 36)
  vib_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
  vib_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  vib_row.add_child(vib_label)
  _vibration_toggle_btn = _create_toggle(GameManager.vibration_enabled, _on_vibration_toggled)
  vib_row.add_child(_vibration_toggle_btn.get_parent())
  vbox.add_child(vib_row)

  var gap_danger = Control.new()
  gap_danger.custom_minimum_size = Vector2(0, 20)
  vbox.add_child(gap_danger)

  # ── 위험 섹션 (별도 배경 박스) ──
  var danger_box = PanelContainer.new()
  var danger_style = StyleBoxFlat.new()
  danger_style.bg_color = Color(0.25, 0.08, 0.08)
  danger_style.corner_radius_top_left = 12
  danger_style.corner_radius_top_right = 12
  danger_style.corner_radius_bottom_left = 12
  danger_style.corner_radius_bottom_right = 12
  danger_style.border_width_top = 1
  danger_style.border_width_bottom = 1
  danger_style.border_width_left = 1
  danger_style.border_width_right = 1
  danger_style.border_color = Color(0.5, 0.15, 0.15)
  danger_style.content_margin_left = 24
  danger_style.content_margin_right = 24
  danger_style.content_margin_top = 18
  danger_style.content_margin_bottom = 18
  danger_box.add_theme_stylebox_override("panel", danger_style)
  vbox.add_child(danger_box)

  var danger_vbox = VBoxContainer.new()
  danger_vbox.add_theme_constant_override("separation", 24)
  danger_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
  danger_box.add_child(danger_vbox)

  var danger_label = Label.new()
  danger_label.text = "▼ 위험"
  danger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  danger_label.add_theme_font_size_override("font_size", 26)
  danger_label.add_theme_color_override("font_color", Color(0.8, 0.35, 0.35))
  danger_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  danger_vbox.add_child(danger_label)

  var reset_center = CenterContainer.new()
  reset_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  reset_center.visible = false
  danger_vbox.add_child(reset_center)

  danger_box.gui_input.connect(func(event: InputEvent):
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
      reset_center.visible = not reset_center.visible
      danger_label.text = "▲ 위험" if reset_center.visible else "▼ 위험"
      GameManager.play_button_click()
  )
  var reset_btn = Button.new()
  reset_btn.text = "게임 데이터 초기화"
  reset_btn.custom_minimum_size = Vector2(420, 70)
  reset_btn.add_theme_font_size_override("font_size", 30)
  var reset_style = StyleBoxFlat.new()
  reset_style.bg_color = Color(0.55, 0.12, 0.12)
  reset_style.corner_radius_top_left = 10
  reset_style.corner_radius_top_right = 10
  reset_style.corner_radius_bottom_left = 10
  reset_style.corner_radius_bottom_right = 10
  reset_style.content_margin_left = 16
  reset_style.content_margin_right = 16
  reset_style.content_margin_top = 8
  reset_style.content_margin_bottom = 8
  reset_btn.add_theme_stylebox_override("normal", reset_style)
  var reset_hover = reset_style.duplicate()
  reset_hover.bg_color = Color(0.65, 0.18, 0.18)
  reset_btn.add_theme_stylebox_override("hover", reset_hover)
  var reset_pressed = reset_style.duplicate()
  reset_pressed.bg_color = Color(0.45, 0.08, 0.08)
  reset_btn.add_theme_stylebox_override("pressed", reset_pressed)
  reset_btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
  reset_btn.pressed.connect(_on_settings_reset_pressed)
  reset_center.add_child(reset_btn)

  # Spacer
  var spacer = Control.new()
  spacer.custom_minimum_size = Vector2(0, 20)
  vbox.add_child(spacer)

  # Close button
  var close_center = CenterContainer.new()
  close_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  vbox.add_child(close_center)
  var close_btn = Button.new()
  close_btn.text = "닫기"
  close_btn.custom_minimum_size = Vector2(420, 90)
  close_btn.add_theme_font_size_override("font_size", 38)
  close_btn.pressed.connect(_close_settings)
  GameManager.style_button(close_btn, "muted")
  close_center.add_child(close_btn)

func _create_toggle(initial: bool, callback: Callable) -> CheckButton:
  var wrapper = Control.new()
  wrapper.custom_minimum_size = Vector2(140, 70)
  var btn = CheckButton.new()
  btn.button_pressed = initial
  btn.scale = Vector2(3.25, 3.25)
  btn.position = Vector2(25, 10)
  btn.toggled.connect(callback)
  wrapper.add_child(btn)
  return btn

func _on_bgm_toggled(enabled: bool) -> void:
  GameManager.bgm_enabled = enabled
  if _menu_bgm:
    if enabled:
      if not _menu_bgm.playing:
        _menu_bgm.play()
    else:
      _menu_bgm.stop()
  GameManager.play_button_click()
  SaveManager.save_game()

func _on_sfx_toggled(enabled: bool) -> void:
  GameManager.sfx_enabled = enabled
  GameManager.play_button_click()
  SaveManager.save_game()

func _on_vibration_toggled(enabled: bool) -> void:
  GameManager.vibration_enabled = enabled
  GameManager.play_button_click()
  SaveManager.save_game()

func _on_settings_reset_pressed() -> void:
  GameManager.play_button_click()
  _confirm_dialog_mode = "reset"
  # 설정 팝업보다 앞에 표시되도록 맨 앞으로 이동
  move_child(quit_confirm_dialog, get_child_count() - 1)
  quit_confirm_dialog.show_dialog("코인, 스킬, 무기, 월드 진행 등\n모든 게임 데이터가 삭제됩니다.", "초기화", "취소", true)

func _close_settings() -> void:
  GameManager.play_button_click()
  if _settings_overlay != null:
    _settings_overlay.queue_free()
    _settings_overlay = null
  _bgm_toggle_btn = null
  _sfx_toggle_btn = null
  _vibration_toggle_btn = null
  _on_panel_closed()

# ── Debug Buttons ──

func _on_money_display_input(event: InputEvent) -> void:
  if not OS.has_feature("debug"):
    return
  if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
    var now = Time.get_ticks_msec() / 1000.0
    if now - _debug_last_tap_time > 3.0:
      _debug_tap_count = 0
    _debug_last_tap_time = now
    _debug_tap_count += 1
    if _debug_tap_count >= 5:
      _debug_container.visible = !_debug_container.visible
      GameManager.debug_mode = _debug_container.visible
      _debug_tap_count = 0

func _build_debug_buttons() -> void:
  _debug_container = HBoxContainer.new()
  _debug_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
  _debug_container.offset_top = -50.0
  _debug_container.alignment = BoxContainer.ALIGNMENT_CENTER
  _debug_container.add_theme_constant_override("separation", 12)
  padded_area.add_child(_debug_container)

  var reset_btn = Button.new()
  reset_btn.text = "초기화"
  reset_btn.add_theme_font_size_override("font_size", 18)
  reset_btn.pressed.connect(_on_debug_reset)
  GameManager.style_button(reset_btn, "sub")
  _debug_container.add_child(reset_btn)

  var money_btn = Button.new()
  money_btn.text = "+$10000000"
  money_btn.add_theme_font_size_override("font_size", 18)
  money_btn.pressed.connect(_on_debug_add_money)
  GameManager.style_button(money_btn, "sub")
  _debug_container.add_child(money_btn)

  var maxskill_btn = Button.new()
  maxskill_btn.text = "스킬MAX"
  maxskill_btn.add_theme_font_size_override("font_size", 18)
  maxskill_btn.pressed.connect(_on_debug_max_skills)
  GameManager.style_button(maxskill_btn, "sub")
  _debug_container.add_child(maxskill_btn)

  var gem_btn = Button.new()
  gem_btn.text = "+보석30"
  gem_btn.add_theme_font_size_override("font_size", 18)
  gem_btn.pressed.connect(_on_debug_add_gems)
  GameManager.style_button(gem_btn, "sub")
  _debug_container.add_child(gem_btn)

  var unlock_btn = Button.new()
  unlock_btn.text = "월드 전체해금"
  unlock_btn.add_theme_font_size_override("font_size", 18)
  unlock_btn.pressed.connect(_on_debug_unlock_all)
  GameManager.style_button(unlock_btn, "sub")
  _debug_container.add_child(unlock_btn)

func _on_debug_reset() -> void:
  SaveManager.reset_all_data()
  update_money_display()

func _on_debug_add_money() -> void:
  GameManager.money += 10000000
  GameManager.money_changed.emit(GameManager.money)
  SaveManager.save_game()

func _on_debug_max_skills() -> void:
  for def in GameManager.SKILL_DEFS:
    GameManager.upgrade_levels[def.type] = def.max_level
    GameManager.upgrade_sub_levels[def.type] = 0
  WeaponManager.current_weapon_level = GameManager.upgrade_levels.get("attack_power", 0)
  GameManager.owned_gems = 99
  SaveManager.save_game()
  update_money_display()

func _on_debug_add_gems() -> void:
  GameManager.owned_gems += 30
  GameManager.money_changed.emit(GameManager.money)
  SaveManager.save_game()
  update_money_display()

func _on_debug_unlock_all() -> void:
  for i in range(GameManager.WORLD_UNLOCK_COSTS.size()):
    if i not in GameManager.unlocked_worlds:
      GameManager.unlocked_worlds.append(i)
  SaveManager.save_game()
