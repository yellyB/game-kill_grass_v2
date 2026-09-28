extends CanvasLayer


func _ready() -> void:
  process_mode = Node.PROCESS_MODE_ALWAYS
  get_tree().paused = true
  _build_ui()

func _pick_random_powerups(count: int) -> Array:
  var pool: Array = []
  for data in PowerupData.POWERUP_DATA:
    # 레벨업 3택 = 지속 파워업(item:false)만, 구현된(enabled) 것만
    if data.get("item", false):
      continue
    if not data.get("enabled", true):
      continue
    # 이미 보유한 비누적 파워업 제외
    if not data.stackable:
      if data.type == "critical_reaper" and GameManager.session_buff_critical_reaper:
        continue
      if data.type == "golden_luck" and GameManager.session_buff_golden_luck:
        continue
      if GameManager.pu(data.type) > 0:
        continue
    else:
      # 누적 상한 도달 제외
      var mx = data.get("max_stacks", 0)
      if mx > 0 and GameManager.pu(data.type) >= mx:
        continue
    pool.append(data)

  # 행운의 편자: 레어 이상(가중치 낮은 항목) 등장 확률 증가
  var luck = GameManager.pu("luck")
  var result: Array = []
  for i in count:
    if pool.is_empty():
      break
    var total_weight: float = 0.0
    for item in pool:
      total_weight += _weighted(item, luck)
    var roll = randf() * total_weight
    var cumulative: float = 0.0
    for j in pool.size():
      cumulative += _weighted(pool[j], luck)
      if roll < cumulative:
        result.append(pool[j])
        pool.remove_at(j)
        break
  return result

func _weighted(item: Dictionary, luck: int) -> float:
  var w = float(item.weight)
  if luck > 0 and item.weight <= 4:  # 레어(4)·에픽(1) 부스트
    w *= 1.0 + 0.5 * luck
  return w

func _build_ui() -> void:
  # 리롤 재구성 시 기존 UI 제거
  for c in get_children():
    c.queue_free()
  # 안목: 선택지 3→4개
  var count = 4 if GameManager.pu("extra_choice") > 0 else 3
  var selected = _pick_random_powerups(count)

  # Full-screen root
  var root = Control.new()
  root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  root.mouse_filter = Control.MOUSE_FILTER_STOP
  add_child(root)

  # Dim overlay
  var overlay = ColorRect.new()
  overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  overlay.color = Color(0, 0, 0, 0.7)
  root.add_child(overlay)

  # Center container
  var center = VBoxContainer.new()
  center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
  center.offset_left = -345
  center.offset_right = 345
  center.offset_top = -500
  center.offset_bottom = 500
  center.add_theme_constant_override("separation", 24)
  root.add_child(center)

  # Title
  var title = Label.new()
  title.text = "파워업 선택"
  title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  title.add_theme_font_size_override("font_size", 48)
  title.add_theme_color_override("font_color", Color(1, 1, 1))
  title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  title.add_theme_constant_override("outline_size", 4)
  center.add_child(title)

  # Bold font for powerup names
  var bold_font = SystemFont.new()
  bold_font.font_weight = 700

  # Buttons
  for data in selected:
    var btn = Button.new()
    btn.custom_minimum_size = Vector2(560, 240)
    btn.text = ""

    # Color tint via stylebox — desaturated version of powerup color
    var hsv_color = data.color
    var main_color = Color.from_hsv(hsv_color.h, hsv_color.s * 0.45, hsv_color.v * 0.55, 0.85)
    var shadow_color = Color.from_hsv(hsv_color.h, hsv_color.s * 0.4, hsv_color.v * 0.35, 0.9)

    var style = StyleBoxFlat.new()
    style.bg_color = main_color
    style.set_corner_radius_all(18)
    style.border_width_bottom = 6
    style.border_color = shadow_color
    style.content_margin_left = 20
    style.content_margin_right = 20
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    btn.add_theme_stylebox_override("normal", style)

    var hover_style = style.duplicate()
    hover_style.bg_color = Color.from_hsv(hsv_color.h, hsv_color.s * 0.5, hsv_color.v * 0.65, 0.9)
    btn.add_theme_stylebox_override("hover", hover_style)

    var pressed_style = StyleBoxFlat.new()
    pressed_style.bg_color = Color.from_hsv(hsv_color.h, hsv_color.s * 0.55, hsv_color.v * 0.7, 0.9)
    pressed_style.set_corner_radius_all(18)
    pressed_style.border_width_bottom = 2
    pressed_style.border_color = shadow_color
    pressed_style.content_margin_left = 20
    pressed_style.content_margin_right = 20
    pressed_style.content_margin_top = 12
    pressed_style.content_margin_bottom = 4
    btn.add_theme_stylebox_override("pressed", pressed_style)
    btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

    # Build button content: [icon] [text]
    var hbox = HBoxContainer.new()
    hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
    hbox.add_theme_constant_override("separation", 0)
    hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var tex = PowerupData.get_powerup_texture(data)
    if tex:
      var icon = TextureRect.new()
      icon.texture = tex
      icon.custom_minimum_size = Vector2(200, 200)
      icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
      icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
      icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
      icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
      hbox.add_child(icon)
    else:
      var placeholder = Control.new()
      placeholder.custom_minimum_size = Vector2(200, 200)
      placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
      hbox.add_child(placeholder)

    var text_vbox = VBoxContainer.new()
    text_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    text_vbox.add_theme_constant_override("separation", 0)
    text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

    # Line 1: Name (bold, large)
    var name_label = Label.new()
    name_label.text = data.name
    name_label.add_theme_font_override("font", bold_font)
    name_label.add_theme_font_size_override("font_size", 40)
    name_label.add_theme_color_override("font_color", Color.WHITE)
    name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    name_label.add_theme_constant_override("outline_size", 3)
    name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    text_vbox.add_child(name_label)

    # Spacer
    var spacer = Control.new()
    spacer.custom_minimum_size = Vector2(0, 6)
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    text_vbox.add_child(spacer)

    # Line 2: Description
    var desc_label = Label.new()
    desc_label.text = data.desc
    desc_label.add_theme_font_size_override("font_size", 26)
    desc_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
    desc_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    desc_label.add_theme_constant_override("outline_size", 2)
    desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    text_vbox.add_child(desc_label)

    # Line 3: Level (stackable only)
    if data.stackable:
      var level = _get_current_level(data.type)
      var next_level = level + 1
      var level_rtl = RichTextLabel.new()
      level_rtl.bbcode_enabled = true
      level_rtl.fit_content = true
      level_rtl.scroll_active = false
      level_rtl.text = "Lv.%d → [color=lime]Lv.%d[/color]" % [level, next_level]
      level_rtl.add_theme_font_size_override("normal_font_size", 26)
      level_rtl.add_theme_color_override("default_color", Color(1, 1, 1, 0.75))
      level_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
      text_vbox.add_child(level_rtl)

    hbox.add_child(text_vbox)

    btn.add_child(hbox)
    btn.pressed.connect(_on_selected.bind(data.type))
    center.add_child(btn)

  # 리롤 토큰 보유 시: 다시 뽑기 버튼
  if GameManager.pu("reroll") > 0:
    var reroll_btn = Button.new()
    reroll_btn.text = "다시 뽑기 (%d)" % GameManager.pu("reroll")
    reroll_btn.custom_minimum_size = Vector2(360, 90)
    reroll_btn.add_theme_font_size_override("font_size", 34)
    UIKit.style_button(reroll_btn, "sub")
    reroll_btn.pressed.connect(func():
      GameManager.play_button_click()
      GameManager.session_pu["reroll"] = GameManager.pu("reroll") - 1
      _build_ui()
    )
    center.add_child(reroll_btn)

  # Fade in
  root.modulate = Color(1, 1, 1, 0)
  var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
  tween.tween_property(root, "modulate:a", 1.0, 0.15)

func _get_current_level(type: String) -> int:
  return GameManager.pu(type)

func _on_selected(type: String) -> void:
  GameManager.play_confirm_click()
  GameManager.apply_powerup(type)
  get_tree().paused = false
  queue_free()
