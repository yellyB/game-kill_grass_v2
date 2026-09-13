extends CanvasLayer

const POWERUP_IMAGE_PATH = "res://resources/images/powerup/"

const POWERUP_DATA = [
  {
    "type": "attack_speed",
    "name": "어택 부스트",
    "desc": "공격 속도 +25%",
    "color": Color(1.0, 0.5, 0.2),
    "image": "어택부스트.png",
    "stackable": true,
    "weight": 20,
  },
  {
    "type": "attack_range",
    "name": "와이드 어택",
    "desc": "공격 범위 +25%",
    "color": Color(0.3, 0.6, 1.0),
    "image": "와이드어택.png",
    "stackable": true,
    "weight": 20,
  },
  {
    "type": "magnet_range",
    "name": "메가 마그넷",
    "desc": "수집 범위 +50%",
    "color": Color(0.2, 1.0, 0.8),
    "image": "메가마그넷.png",
    "stackable": true,
    "weight": 20,
  },
  {
    "type": "move_speed",
    "name": "라이트닝 대시",
    "desc": "이동 속도 +50%",
    "color": Color(1.0, 1.0, 0.3),
    "image": "라이트닝대시.png",
    "stackable": true,
    "weight": 20,
  },
  {
    "type": "critical_surge",
    "name": "크리티컬 서지",
    "desc": "치명타 100% 증가 & 치명타 피해 x2",
    "color": Color(1.0, 0.2, 0.4),
    "image": "크리티컬서지.png",
    "stackable": false,
    "weight": 20,
  },
  {
    "type": "golden_luck",
    "name": "골든 럭",
    "desc": "황금풀 제거 시 30% 확률로 파워업 획득",
    "color": Color(1.0, 0.85, 0.0),
    "image": "골든럭.png",
    "stackable": false,
    "weight": 10,
  },
  {
    "type": "critical_reaper",
    "name": "크리티컬 리퍼",
    "desc": "치명타 시 범위 내 풀 30% 즉사",
    "color": Color(0.6, 0.1, 0.3),
    "image": "크리티컬리퍼.png",
    "stackable": false,
    "weight": 10,
  },
  {
    "type": "extra_time",
    "name": "엑스트라 타임",
    "desc": "세션 시간 +5초",
    "color": Color(0.4, 1.0, 0.4),
    "image": "엑스트라타임.png",
    "stackable": false,
    "weight": 10,
  },
  {
    "type": "gold_rush",
    "name": "골드 러시",
    "desc": "10초간 획득하는 코인의 가치 2배",
    "color": Color(1.0, 0.85, 0.0),
    "image": "골드러시.png",
    "stackable": false,
    "weight": 10,
  },
  {
    "type": "golden_bloom",
    "name": "골든 블룸",
    "desc": "주변 풀을 황금풀로",
    "color": Color(1.0, 0.9, 0.2),
    "image": "골든블룸.png",
    "stackable": false,
    "weight": 10,
  },
  {
    "type": "double_or_dust",
    "name": "더블 오어 낫싱",
    "desc": "50% 코인 2배 or 50% 코인 30% 손실",
    "color": Color(0.8, 0.2, 0.8),
    "image": "더블오어더스트.png",
    "stackable": false,
    "weight": 10,
  },
  {
    "type": "monster_fury",
    "name": "몬스터 퓨리",
    "desc": "분노 게이지 35% 충전",
    "color": Color(0.9, 0.2, 0.2),
    "image": "몬스터퓨리.png",
    "stackable": false,
    "weight": 10,
  },
  {
    "type": "overdrive",
    "name": "오버드라이브",
    "desc": "10초간 공속 2배, 이속 -30%",
    "color": Color(1.0, 0.3, 0.5),
    "image": "오버드라이브.png",
    "stackable": false,
    "weight": 10,
  },
  {
    "type": "harvest_madness",
    "name": "하베스트 매드니스",
    "desc": "8초간 모든 스탯 대폭 증가",
    "color": Color(1.0, 0.5, 1.0),
    "image": "하베스트매드니스.png",
    "stackable": false,
    "weight": 4,
  },
  {
    "type": "field_clear",
    "name": "필드 클리어",
    "desc": "맵 전체 풀 클리어",
    "color": Color(0.3, 1.0, 0.3),
    "image": "필드클리어.png",
    "stackable": false,
    "weight": 1,
  },
  {
    "type": "blackhole",
    "name": "블랙홀",
    "desc": "모든 드롭 코인 흡수",
    "color": Color(0.2, 0.0, 0.4),
    "image": "블랙홀.png",
    "stackable": false,
    "weight": 10,
  },
]

static func get_powerup_texture(data: Dictionary) -> Texture2D:
  if data.image != "":
    return load(POWERUP_IMAGE_PATH + data.image)
  return null

static func get_powerup_data_by_type(type: String) -> Dictionary:
  for data in POWERUP_DATA:
    if data.type == type:
      return data
  return {}

func _ready() -> void:
  process_mode = Node.PROCESS_MODE_ALWAYS
  get_tree().paused = true
  _build_ui()

func _pick_random_powerups(count: int) -> Array:
  var pool: Array = []
  for data in POWERUP_DATA:
    if not data.stackable:
      if data.type == "overdrive" and GameManager.timed_buffs.has("overdrive"):
        continue
      if data.type == "critical_reaper" and GameManager.session_buff_critical_reaper:
        continue
      if data.type == "critical_surge" and GameManager.session_buff_critical_surge:
        continue
      if data.type == "golden_luck" and GameManager.session_buff_golden_luck:
        continue
    pool.append(data)

  var result: Array = []
  for i in count:
    if pool.is_empty():
      break
    var total_weight: int = 0
    for item in pool:
      total_weight += item.weight
    var roll = randi() % total_weight
    var cumulative: int = 0
    for j in pool.size():
      cumulative += pool[j].weight
      if roll < cumulative:
        result.append(pool[j])
        pool.remove_at(j)
        break
  return result

func _build_ui() -> void:
  var selected = _pick_random_powerups(3)

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

    var tex = get_powerup_texture(data)
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

  # Fade in
  root.modulate = Color(1, 1, 1, 0)
  var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
  tween.tween_property(root, "modulate:a", 1.0, 0.15)

func _get_current_level(type: String) -> int:
  match type:
    "attack_speed":
      return GameManager.session_buff_attack_speed
    "attack_range":
      return GameManager.session_buff_attack_range
    "magnet_range":
      return GameManager.session_buff_magnet_range
    "move_speed":
      return GameManager.session_buff_move_speed
  return 0

func _on_selected(type: String) -> void:
  GameManager.play_confirm_click()
  GameManager.apply_powerup(type)
  get_tree().paused = false
  queue_free()
