extends CanvasLayer

const POWERUP_IMAGE_PATH = "res://resources/images/powerup/"

# 파워업(지속, item:false) + 아이템(즉발, item:true) 통합 데이터.
# enabled:false = 아직 효과 미구현(배치2) → 추첨/드롭 풀에서 제외.
# 이미지 없으면 색상 폴백. 상세 설계: docs/powerups.md
const POWERUP_DATA = [
  # ── 공격 (파워업) ──
  {"type": "sharp_blade", "name": "예리한 날", "desc": "공격력 +15%", "color": Color(1.0, 0.5, 0.2), "image": "", "stackable": true, "item": false, "weight": 20, "enabled": true},
  {"type": "pu_attack_speed", "name": "어택 부스트", "desc": "공격 속도 +12%", "color": Color(1.0, 0.5, 0.2), "image": "어택부스트.png", "stackable": true, "item": false, "weight": 20, "enabled": true},
  {"type": "pu_attack_range", "name": "와이드 스윙", "desc": "공격 범위 +15%", "color": Color(0.3, 0.6, 1.0), "image": "와이드어택.png", "stackable": true, "item": false, "weight": 20, "enabled": true},
  {"type": "timber", "name": "벌목", "desc": "거목·정예 피해 +30%", "color": Color(0.6, 0.4, 0.2), "image": "", "stackable": true, "item": false, "weight": 10, "enabled": true},
  {"type": "chain_reaction", "name": "연쇄 반응", "desc": "풀 처치 시 30% 확률로 인접 풀 즉시 처치", "color": Color(0.9, 0.6, 0.2), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": false},
  # ── 치명타 (파워업) ──
  {"type": "pu_crit_chance", "name": "치명 감각", "desc": "치명타 확률 +8%", "color": Color(1.0, 0.2, 0.4), "image": "", "stackable": true, "item": false, "weight": 10, "enabled": true},
  {"type": "pu_crit_damage", "name": "치명 강타", "desc": "치명타 피해 +40%", "color": Color(1.0, 0.2, 0.4), "image": "", "stackable": true, "item": false, "weight": 10, "enabled": true},
  {"type": "critical_reaper", "name": "크리티컬 리퍼", "desc": "치명타 시 범위 내 풀 30% 즉사", "color": Color(0.6, 0.1, 0.3), "image": "크리티컬리퍼.png", "stackable": false, "item": false, "weight": 10, "enabled": true},
  {"type": "execute", "name": "참수", "desc": "체력 20% 이하 풀 즉시 처치", "color": Color(0.7, 0.1, 0.2), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": false},
  # ── 수확·경제 (파워업) ──
  {"type": "coin_value", "name": "황금 손길", "desc": "코인 가치 +12%", "color": Color(1.0, 0.85, 0.2), "image": "", "stackable": true, "item": false, "weight": 20, "enabled": true},
  {"type": "pu_magnet_range", "name": "메가 마그넷", "desc": "수집 범위 +25%", "color": Color(0.2, 1.0, 0.8), "image": "메가마그넷.png", "stackable": true, "item": false, "weight": 20, "enabled": true},
  {"type": "regrow_speed", "name": "비옥한 흙", "desc": "풀 재생 속도 +20%", "color": Color(0.4, 0.8, 0.3), "image": "", "stackable": true, "item": false, "weight": 20, "enabled": true},
  {"type": "coin_leech", "name": "흡혈 수확", "desc": "벤 풀 코인 +8%", "color": Color(0.8, 0.7, 0.2), "image": "", "stackable": true, "item": false, "weight": 20, "enabled": true},
  {"type": "combo_harvest", "name": "콤보 수확", "desc": "연속 처치 10마다 코인 +5% (최대 +50%)", "color": Color(1.0, 0.7, 0.3), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": true},
  {"type": "interest", "name": "이자", "desc": "세션 종료 시 보유 코인 +8%", "color": Color(0.9, 0.8, 0.3), "image": "", "stackable": true, "item": false, "weight": 10, "enabled": true},
  {"type": "overkill", "name": "오버킬 환원", "desc": "처치 초과 데미지만큼 코인 보너스", "color": Color(0.9, 0.5, 0.2), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": false},
  # ── 황금풀 (파워업) ──
  {"type": "pu_golden_chance", "name": "황금 씨앗", "desc": "황금풀 등장 확률 +2%", "color": Color(1.0, 0.9, 0.2), "image": "", "stackable": true, "item": false, "weight": 10, "enabled": true},
  {"type": "golden_luck", "name": "골든 럭", "desc": "황금풀 제거 시 30% 확률 커먼 파워업 획득", "color": Color(1.0, 0.85, 0.0), "image": "골든럭.png", "stackable": false, "item": false, "weight": 10, "enabled": true},
  {"type": "midas", "name": "미다스", "desc": "벤 풀이 낮은 확률로 즉석 황금 보상", "color": Color(1.0, 0.8, 0.1), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": false},
  # ── 기동 (파워업) ──
  {"type": "pu_move_speed", "name": "라이트닝 대시", "desc": "이동 속도 +12%", "color": Color(1.0, 1.0, 0.3), "image": "라이트닝대시.png", "stackable": true, "item": false, "weight": 20, "enabled": true},
  {"type": "momentum", "name": "질주 본능", "desc": "이동 중 공격력 +25%", "color": Color(1.0, 0.9, 0.4), "image": "", "stackable": false, "item": false, "weight": 10, "enabled": true},
  {"type": "stun_resist", "name": "굳은 심지", "desc": "거목 스턴 시간 -25% (최대 -75%)", "color": Color(0.6, 0.6, 0.7), "image": "", "stackable": true, "item": false, "weight": 20, "max_stacks": 3, "enabled": true},
  {"type": "thorns", "name": "가시 반격", "desc": "스턴될 때 거목 최대 체력 2% 반사", "color": Color(0.5, 0.7, 0.4), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": false},
  # ── 시간 (파워업) ──
  {"type": "finale", "name": "막판 스퍼트", "desc": "마지막 10초간 전 스탯 +50%", "color": Color(0.4, 1.0, 0.4), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": true},
  # ── 도박 (파워업) ──
  {"type": "cursed_scythe", "name": "저주받은 낫", "desc": "코인 +50%, 경험치 -40%", "color": Color(0.6, 0.2, 0.6), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": true},
  # ── 성장 (파워업) ──
  {"type": "level_burst", "name": "레벨업 충격", "desc": "레벨업 시 주변 풀 즉시 처치", "color": Color(0.7, 0.9, 1.0), "image": "", "stackable": false, "item": false, "weight": 10, "enabled": false},
  {"type": "seed_blessing", "name": "씨앗 축복", "desc": "씨앗 획득 시 8초간 전 스탯 +15%", "color": Color(0.5, 0.9, 0.5), "image": "", "stackable": false, "item": false, "weight": 10, "enabled": true},
  {"type": "xp_gain", "name": "떡잎 부적", "desc": "레벨업 게이지 획득량 +20%", "color": Color(0.6, 0.9, 0.6), "image": "", "stackable": true, "item": false, "weight": 20, "enabled": true},
  {"type": "reroll", "name": "리롤 토큰", "desc": "파워업 3택 다시 뽑기 +1", "color": Color(0.5, 0.7, 1.0), "image": "", "stackable": true, "item": false, "weight": 10, "enabled": false},
  {"type": "extra_choice", "name": "안목", "desc": "파워업 선택지 3→4개", "color": Color(0.6, 0.8, 1.0), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": true},
  {"type": "luck", "name": "행운의 편자", "desc": "레어 이상 등장 확률 증가", "color": Color(0.9, 0.9, 0.4), "image": "", "stackable": true, "item": false, "weight": 4, "enabled": true},
  {"type": "snowball", "name": "눈덩이", "desc": "풀 100개마다 공격력 +2% (세션 내)", "color": Color(0.8, 0.9, 1.0), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": true},
  {"type": "compound", "name": "복리 성장", "desc": "레벨업마다 전 스탯 소폭 영구 증가", "color": Color(0.9, 0.7, 1.0), "image": "", "stackable": false, "item": false, "weight": 1, "enabled": true},
  # ── 아이템 (즉발, 컨테이너/상점) ──
  {"type": "gold_rush", "name": "골드 러시", "desc": "10초간 코인 가치 2배", "color": Color(1.0, 0.85, 0.0), "image": "골드러시.png", "stackable": false, "item": true, "weight": 10, "enabled": true},
  {"type": "blackhole", "name": "블랙홀", "desc": "드롭 코인 즉시 흡수", "color": Color(0.2, 0.0, 0.4), "image": "블랙홀.png", "stackable": false, "item": true, "weight": 10, "enabled": true},
  {"type": "golden_bloom", "name": "골든 블룸", "desc": "주변 풀을 황금풀로", "color": Color(1.0, 0.9, 0.2), "image": "골든블룸.png", "stackable": false, "item": true, "weight": 10, "enabled": true},
  {"type": "overdrive", "name": "오버드라이브", "desc": "10초간 공속 2배, 이속 -30%", "color": Color(1.0, 0.3, 0.5), "image": "오버드라이브.png", "stackable": false, "item": true, "weight": 10, "enabled": true},
  {"type": "heavy_blade", "name": "강철 심", "desc": "10초간 공격력 +80%, 공속 -20%", "color": Color(0.7, 0.4, 0.3), "image": "", "stackable": false, "item": true, "weight": 10, "enabled": true},
  {"type": "harvest_madness", "name": "하베스트 매드니스", "desc": "8초간 모든 스탯 대폭 증가", "color": Color(1.0, 0.5, 1.0), "image": "하베스트매드니스.png", "stackable": false, "item": true, "weight": 4, "enabled": true},
  {"type": "field_clear", "name": "필드 클리어", "desc": "맵 전체 풀 즉시 클리어", "color": Color(0.3, 1.0, 0.3), "image": "필드클리어.png", "stackable": false, "item": true, "weight": 1, "enabled": true},
  {"type": "growth_spurt", "name": "그로스 스퍼트", "desc": "레벨업 게이지 35% 충전", "color": Color(0.9, 0.6, 0.9), "image": "몬스터퓨리.png", "stackable": false, "item": true, "weight": 10, "enabled": true},
  {"type": "extra_time", "name": "엑스트라 타임", "desc": "세션 시간 +5초", "color": Color(0.4, 1.0, 0.4), "image": "엑스트라타임.png", "stackable": false, "item": true, "weight": 10, "enabled": true},
  {"type": "double_or_nothing", "name": "더블 오어 낫싱", "desc": "50% 코인 2배 / 50% 전부 잃음", "color": Color(0.8, 0.2, 0.8), "image": "더블오어더스트.png", "stackable": false, "item": true, "weight": 10, "enabled": true},
  {"type": "all_in", "name": "올인", "desc": "8초간 전 스탯 +80%", "color": Color(0.9, 0.3, 0.5), "image": "", "stackable": false, "item": true, "weight": 4, "enabled": true},
  {"type": "instant_level", "name": "즉시 레벨업", "desc": "즉시 레벨업 1회", "color": Color(0.7, 0.9, 1.0), "image": "", "stackable": false, "item": true, "weight": 4, "enabled": true},
  {"type": "uproot", "name": "뿌리 뽑기", "desc": "거목/정예에 즉시 큰 피해", "color": Color(0.6, 0.4, 0.2), "image": "", "stackable": false, "item": true, "weight": 4, "enabled": false},
  {"type": "lightning_mow", "name": "번개 벌초", "desc": "랜덤 다수 풀 즉시 처치", "color": Color(0.8, 0.9, 1.0), "image": "", "stackable": false, "item": true, "weight": 10, "enabled": false},
  {"type": "time_freeze", "name": "시간 정지", "desc": "타이머 잠깐 정지, 수확 계속", "color": Color(0.6, 0.8, 1.0), "image": "", "stackable": false, "item": true, "weight": 4, "enabled": false},
  {"type": "fertilizer", "name": "거름 살포", "desc": "짧은 시간 풀 재생·밀도 폭증", "color": Color(0.5, 0.8, 0.3), "image": "", "stackable": false, "item": true, "weight": 10, "enabled": false},
  {"type": "golden_rain", "name": "황금비", "desc": "잠깐 코인·황금풀이 쏟아짐", "color": Color(1.0, 0.9, 0.3), "image": "", "stackable": false, "item": true, "weight": 4, "enabled": false},
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
  return GameManager.pu(type)

func _on_selected(type: String) -> void:
  GameManager.play_confirm_click()
  GameManager.apply_powerup(type)
  get_tree().paused = false
  queue_free()
