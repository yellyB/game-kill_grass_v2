extends Node

# UI constants
const SCREEN_PADDING_H: float = 40.0
const SCREEN_PADDING_V: float = 60.0

# Debug mode (toggled by tapping coin display 5 times on main menu)
var debug_mode: bool = false

# Settings
var bgm_enabled: bool = true
var sfx_enabled: bool = true
var vibration_enabled: bool = true

# Game state
var money: int = 0
var session_money: int = 0
var session_boss_reward: int = 0

# World selection
var selected_world: int = 0
var unlocked_worlds: Array = [0]
var owned_keys: Array = []  # 소유 열쇠 목록 (예: [1] = 월드1 열쇠 보유)
var has_potion: bool = false  # 황금 왕관 획득 여부 (엔딩 아이템)
var owned_gems: int = 0
var session_gems: int = 0  # 세션 중 획득한 보석 수
var unlocked_gem_skills: Array = []  # 보석으로 해금한 스킬 (예: "attack_power:2")
const WORLD_UNLOCK_COSTS: Array = [0, 100, 1000, 10000, 25000, 50000, 100000]

# 월드별 풀 체력/보상 기본 배율 (매 월드 x1.3 균일 증가, 황금풀 제외)
const WORLD_GRASS_HP_MULT: Array = [1.0, 1.3, 1.69, 2.2, 2.86, 3.71, 4.83]
const WORLD_GRASS_REWARD_MULT: Array = [1.0, 1.3, 1.69, 2.2, 2.86, 3.71, 4.83]

# 월드 초월 시스템
var world_strength_levels: Dictionary = {}  # {world_index: level}
var collected_gem_levels: Dictionary = {}  # {world_index: [strength_levels...]} 이미 보석 획득한 초월 레벨
var has_ever_transcended: bool = false  # 최초 초월 여부 (툴팁 표시용)
func is_world_cleared(world: int) -> bool:
  var next = world + 1
  var is_last = next >= WORLD_UNLOCK_COSTS.size()
  if is_last:
    return has_potion
  return next in unlocked_worlds or has_key(next)

func get_world_strength_level(world: int) -> int:
  return world_strength_levels.get(world, 0)

func get_strengthen_cost(world: int) -> int:
  var next = world + 1
  var base: int
  if next < WORLD_UNLOCK_COSTS.size():
    base = int(WORLD_UNLOCK_COSTS[next] * 2.0)
  else:
    base = int(WORLD_UNLOCK_COSTS[world] * 5.0)
  var level = get_world_strength_level(world)
  return int(base * pow(3, level))

const MAX_STRENGTH_LEVEL: int = 3

func can_strengthen_world(world: int) -> bool:
  if not is_world_cleared(world):
    return false
  var level = get_world_strength_level(world)
  if level >= MAX_STRENGTH_LEVEL:
    return false
  # 현재 초월 레벨에서 보석을 획득해야 다음 초월 가능 (Lv.0은 보석 없으므로 제외)
  if level > 0 and not has_collected_gems(world, level):
    return false
  if money < get_strengthen_cost(world):
    return false
  return true

func strengthen_world(world: int) -> bool:
  if not can_strengthen_world(world):
    return false
  var cost = get_strengthen_cost(world)
  money -= cost
  world_strength_levels[world] = get_world_strength_level(world) + 1
  has_ever_transcended = true
  money_changed.emit(money)
  SaveManager.save_game()
  return true

func get_world_grass_hp_mult() -> float:
  var w = selected_world
  var base = WORLD_GRASS_HP_MULT[w] if w < WORLD_GRASS_HP_MULT.size() else 1.0
  var strength = get_world_strength_level(w)
  return base * (1.0 + strength * 0.4)

func get_world_grass_reward_mult() -> float:
  var w = selected_world
  var base = WORLD_GRASS_REWARD_MULT[w] if w < WORLD_GRASS_REWARD_MULT.size() else 1.0
  var strength = get_world_strength_level(w)
  return base * (1.0 + strength * 0.5)

signal world_unlocked(index: int)

# Skill definitions — single source of truth for all skills
const SKILL_DEFS: Array = [
  {"type": "attack_speed", "name": "공격 속도", "short_name": "공속", "sub_max": 5, "max_level": 6,
   "description": "다음 공격까지의 대기 시간이 짧아집니다.\n공격 간격: 0.70초 → 0.10초 (틱당 -0.02초)\n단계 5 | 최대 Lv.6"},
  {"type": "attack_range", "name": "공격 범위", "short_name": "범위", "sub_max": 5, "max_level": 8,
   "description": "공격 범위가 넓어집니다.\n범위: 60 → 340 (틱당 +7)\n단계 5 | 최대 Lv.8"},
  {"type": "attack_count", "name": "공격 개수", "short_name": "개수", "sub_max": 3, "max_level": 5,
   "description": "한 번에 베는 풀의 개수가 증가합니다.\n횟수: 1 → 46 (레벨별 +1/+2/+3/+4/+5)\n단계 3 | 최대 Lv.5"},
  {"type": "magnet_range", "name": "수집 범위", "short_name": "수집", "sub_max": 5, "max_level": 6,
   "description": "코인을 끌어당기는 범위가 넓어집니다.\n범위: 50 → 260 (틱당 +7)\n단계 5 | 최대 Lv.6"},
  {"type": "grass_density", "name": "풀 밀도", "short_name": "밀도", "sub_max": 5, "max_level": 8,
   "description": "맵 구획당 자라는 풀의 수가 증가합니다.\n구획당 풀: 1개 → 181개 (Lv별 틱당 +1/+2/.../+8)\n단계 5 | 최대 Lv.8"},
  {"type": "grass_quality", "name": "풀 등급", "short_name": "등급", "sub_max": 8, "max_level": 8,
   "description": "높은 등급의 풀로 자라날 확률이 높아집니다.\n홀수 레벨: 다음 등급 50%까지\n짝수 레벨: 다음 등급 100%까지\n단계 8 | 최대 Lv.8"},
  {"type": "chest_chance", "name": "상자 확률", "short_name": "상자", "sub_max": 5, "max_level": 5,
   "description": "맵 구획당 상자 등장 확률이 높아집니다.\n확률: 0% → 5% (틱당 +0.2%)\n단계 5 | 최대 Lv.5"},
  {"type": "crit_chance", "name": "치명타 확률", "short_name": "치확", "sub_max": 5, "max_level": 4,
   "description": "치명타 발생 확률이 높아집니다.\n확률: 0% → 100% (틱당 +5%)\n단계 5 | 최대 Lv.4"},
  {"type": "crit_damage", "name": "치명타 피해", "short_name": "치피", "sub_max": 5, "max_level": 5,
   "description": "치명타 피해량이 증가합니다.\n배율: 120% → 370% (틱당 +10%)\n단계 5 | 최대 Lv.5"},
  {"type": "attack_power", "name": "공격력", "short_name": "공격력", "sub_max": 5, "max_level": 9,
   "description": "공격력이 증가합니다.\nLv.1~3: +1/틱, Lv.4~5: +2/틱\nLv.6~7: +3/틱, Lv.8~9: +4/틱\n단계 5 | 최대 Lv.9"},
  {"type": "monster_damage", "name": "몬스터 피해", "short_name": "몬피", "sub_max": 5, "max_level": 7,
   "description": "몬스터에게 주는 피해가 증가합니다.\n배율: 100% → 450% (틱당 +10%) (미정)\n단계 5 | 최대 Lv.7"},
  {"type": "fury_rate", "name": "분노 속도", "short_name": "분노", "sub_max": 4, "max_level": 4,
   "description": "몬스터 분노 게이지가 더 빨리 찹니다.\n배율: 100% → 340% (틱당 +15%) (미정)\n단계 4 | 최대 Lv.4"},
  {"type": "golden_chance", "name": "황금풀 확률", "short_name": "황금", "sub_max": 2, "max_level": 5,
   "description": "풀이 황금풀로 자라날 확률이 높아집니다.\n확률: 0% → 1.0% (틱당 +0.1%)\n단계 2 | 최대 Lv.5"},
  {"type": "golden_reward", "name": "황금풀 보상", "short_name": "황보", "sub_max": 5, "max_level": 5,
   "description": "황금풀에서 떨어지는 코인이 증가합니다.\n보상: 100원 → ~1,696원 (단계별 10~14% 복리)\n단계 5 | 최대 Lv.5"},
  {"type": "move_speed", "name": "이동 속도", "short_name": "이속", "sub_max": 6, "max_level": 5,
   "description": "플레이어의 이동 속도가 빨라집니다.\n속도: 300 → 600 (틱당 +10)\n단계 6 | 최대 Lv.5"},
  {"type": "session_time", "name": "세션 시간", "short_name": "시간", "sub_max": 3, "max_level": 5,
   "description": "세션 시간이 증가합니다.\n+3초\n단계 3 | 최대 Lv.5"},
]

const SKILL_GROUPS: Array = [
  {
    "name": "무기",
    "skills": ["attack_power", "attack_speed", "attack_range", "crit_chance", "monster_damage", "crit_damage"],
    "columns": 2,
  },
  {
    "name": "수확",
    "skills": ["grass_density", "grass_quality", "attack_count", "golden_chance", "magnet_range", "golden_reward"],
    "columns": 2,
  },
  {
    "name": "탐험",
    "skills": ["move_speed", "session_time", "chest_chance", "fury_rate"],
    "columns": 2,
  },
]

# Upgrades — Dictionary-based level management
var upgrade_levels: Dictionary = {}  # {"grass_density": 0, "grass_quality": 0, ...}
var upgrade_sub_levels: Dictionary = {}  # {"grass_density": 0, ...}  값 범위 0~4
func get_skill_sub_max(type: String) -> int:
  var def = get_skill_def(type)
  return def.get("sub_max", 5)

# Session powerup buffs (reset each session)
var session_buff_attack_speed: int = 0
var session_buff_attack_range: int = 0
var session_buff_magnet_range: int = 0
var session_buff_move_speed: int = 0
var session_buff_critical_surge: bool = false
var session_buff_critical_reaper: bool = false
var session_buff_golden_luck: bool = false

# Timed buffs: { "gold_rush": remaining_seconds, ... }
var timed_buffs: Dictionary = {}

# Hit penalty (50% attack speed & move speed reduction)
var hit_penalty_active: bool = false

# Upgrade costs (increases each level)

# Game settings
var base_magnet_range: float = 50.0

# Grass settings
const GRASS_DROP_CHANCE: float = 1.0

# Grass data
var grass_data_list: Array[GrassData] = []

# Signals
signal money_changed(new_amount: int)
signal session_money_changed(new_amount: int)
signal upgrade_purchased(upgrade_type: String, level: int)
signal powerup_acquired(type: String, level: int)
signal timed_buff_started(type: String, duration: float)
signal timed_buff_ended(type: String)
signal extra_time_requested(seconds: float)
signal golden_bloom_requested()
signal golden_grass_cut()
signal field_clear_requested()
signal blackhole_requested()

signal fury_changed(value: float)
signal fury_boss_requested()
signal fury_gauge_dismissed()
signal fury_feed_requested(amount: float, screen_pos: Vector2)
signal boss_key_collected(world_index: int)

# 몬스터 분노 시스템
var fury: float = 0.0
var fury_boss_alive: bool = false
var session_key_acquired: int = -1  # 세션 중 보스 드롭 열쇠 (-1 = 없음)
var session_crown_acquired: bool = false  # 세션 중 황금 왕관 획득 여부
# 월드별 분노 필요 수치 (0초월 기준)
const FURY_THRESHOLDS: Array = [300.0, 1500.0, 6000.0, 18750.0, 105000.0, 168000.0, 280000.0]

const STRENGTH_MULTIPLIERS: Array = [1.0, 1.5, 2.0, 3.0]

func get_fury_max() -> float:
  var idx = clampi(selected_world, 0, FURY_THRESHOLDS.size() - 1)
  var base = FURY_THRESHOLDS[idx]
  var strength = get_world_strength_level(selected_world)
  if strength == 0:
    return base
  # 1초월 = +2월드의 0초월 분노치
  var ref_idx = idx + 2
  var result: float
  if ref_idx >= FURY_THRESHOLDS.size():
    result = base * (1.0 + strength * 0.3)
  else:
    var target = FURY_THRESHOLDS[ref_idx]
    var gap = target - base
    if strength == 1:
      result = target
    elif strength == 2:
      result = target + gap
    else:
      result = target + gap + gap * 1.46
  # 초월 배율 적용
  var mult = STRENGTH_MULTIPLIERS[clampi(strength, 0, STRENGTH_MULTIPLIERS.size() - 1)]
  return result * mult

var _sfx_click: AudioStreamPlayer
var _sfx_confirm: AudioStreamPlayer
var _sfx_skill_upgrade: AudioStreamPlayer
var _sfx_unlock: AudioStreamPlayer
var _sfx_skill_click: AudioStreamPlayer

func _ready() -> void:
  process_mode = Node.PROCESS_MODE_ALWAYS
  # Initialize upgrade_levels and sub_levels from SKILL_DEFS
  for def in SKILL_DEFS:
    if not upgrade_levels.has(def.type):
      upgrade_levels[def.type] = 0
    if not upgrade_sub_levels.has(def.type):
      upgrade_sub_levels[def.type] = 0
  # Sync WeaponManager visual from weapon skill level
  WeaponManager.current_weapon_level = upgrade_levels.get("attack_power", 0)
  _init_grass_data()
  _sfx_click = AudioStreamPlayer.new()
  _sfx_click.stream = preload("res://resources/sounds/effect/button_click.wav")
  _sfx_click.volume_db = -5.0
  add_child(_sfx_click)
  _sfx_confirm = AudioStreamPlayer.new()
  _sfx_confirm.stream = preload("res://resources/sounds/effect/confirm_button_click.wav")
  _sfx_confirm.volume_db = -3.0
  add_child(_sfx_confirm)
  _sfx_skill_upgrade = AudioStreamPlayer.new()
  _sfx_skill_upgrade.stream = preload("res://resources/sounds/effect/skill_upgrade_success.wav")
  _sfx_skill_upgrade.volume_db = -3.0
  add_child(_sfx_skill_upgrade)
  _sfx_unlock = AudioStreamPlayer.new()
  _sfx_unlock.stream = preload("res://resources/sounds/effect/unlock_world.wav")
  _sfx_unlock.volume_db = -3.0
  add_child(_sfx_unlock)
  _sfx_skill_click = AudioStreamPlayer.new()
  _sfx_skill_click.stream = preload("res://resources/sounds/effect/skill_click.wav")
  _sfx_skill_click.volume_db = -5.0
  add_child(_sfx_skill_click)
  golden_grass_cut.connect(_on_golden_grass_cut)

# 골든 럭: 황금풀 절단 시 랜덤 파워업 자동 적용
const GOLDEN_LUCK_POOL: Array = [
  {"type": "attack_speed", "weight": 20},
  {"type": "attack_range", "weight": 20},
  {"type": "magnet_range", "weight": 20},
  {"type": "move_speed", "weight": 20},
  {"type": "critical_surge", "weight": 20},
  {"type": "critical_reaper", "weight": 10},
  {"type": "extra_time", "weight": 10},
  {"type": "gold_rush", "weight": 10},
]

func _on_golden_grass_cut() -> void:
  if randf() > 0.3:
    return
  var total_weight = 0
  for item in GOLDEN_LUCK_POOL:
    total_weight += item.weight
  var roll = randi() % total_weight
  var cumulative = 0
  for item in GOLDEN_LUCK_POOL:
    cumulative += item.weight
    if roll < cumulative:
      apply_powerup(item.type)
      return

func play_skill_click() -> void:
  if not sfx_enabled: return
  _sfx_skill_click.play()

func play_button_click() -> void:
  if not sfx_enabled: return
  _sfx_click.play()

func play_confirm_click() -> void:
  if not sfx_enabled: return
  _sfx_confirm.play()

func play_skill_upgrade_sound() -> void:
  if not sfx_enabled: return
  _sfx_skill_upgrade.play()

func play_unlock_sound() -> void:
  if not sfx_enabled: return
  _sfx_unlock.play()

func vibrate(duration_ms: int) -> void:
  if vibration_enabled:
    Input.vibrate_handheld(duration_ms)

# ── Shared Button Style ──

const BUTTON_COLORS = {
  "main": Color(0.3, 0.75, 0.45),
  "muted": Color(0.45, 0.45, 0.5),
  "sub": Color(0.45, 0.62, 0.78),
}

const COIN_TEXTURE = preload("res://resources/images/coin.png")

func format_number(num: int) -> String:
  var str_num = str(num)
  var result = ""
  var count = 0
  for i in range(str_num.length() - 1, -1, -1):
    if count > 0 and count % 3 == 0:
      result = "," + result
    result = str_num[i] + result
    count += 1
  return result

# 코인 아이콘 + 금액 텍스트를 담은 HBoxContainer 생성
func create_coin_label(amount_text: String, font_size: int = 30,
    font_color: Color = Color(1, 0.9, 0.3), outline_size: int = 0,
    center: bool = false) -> HBoxContainer:
  var icon_size = int(font_size * 0.85)
  var hbox = HBoxContainer.new()
  hbox.add_theme_constant_override("separation", int(font_size * 0.2))
  hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
  if center:
    hbox.alignment = BoxContainer.ALIGNMENT_CENTER

  var icon = TextureRect.new()
  icon.texture = COIN_TEXTURE
  icon.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
  icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  icon.custom_minimum_size = Vector2(icon_size, icon_size)
  icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
  hbox.add_child(icon)

  var label = Label.new()
  label.text = amount_text
  label.add_theme_font_size_override("font_size", font_size)
  label.add_theme_color_override("font_color", font_color)
  label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  if outline_size > 0:
    label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    label.add_theme_constant_override("outline_size", outline_size)
  hbox.add_child(label)

  return hbox

func _create_gem_display_icon(icon_size: int, tint: Color = Color(0.9, 0.2, 0.4)) -> Control:
  var container = Control.new()
  container.custom_minimum_size = Vector2(icon_size, icon_size)
  container.mouse_filter = Control.MOUSE_FILTER_IGNORE
  var cx = icon_size * 0.5
  var cy = icon_size * 0.5
  var sx = icon_size * 0.38
  var sy = icon_size * 0.5
  var body = Polygon2D.new()
  body.color = tint
  body.polygon = PackedVector2Array([
    Vector2(cx, cy - sy), Vector2(cx + sx, cy - sy * 0.35),
    Vector2(cx + sx, cy + sy * 0.35), Vector2(cx, cy + sy),
    Vector2(cx - sx, cy + sy * 0.35), Vector2(cx - sx, cy - sy * 0.35),
  ])
  container.add_child(body)
  var hl = Polygon2D.new()
  hl.color = Color(tint.r + 0.1, tint.g + 0.3, tint.b + 0.2, 0.5)
  hl.polygon = PackedVector2Array([
    Vector2(cx, cy - sy), Vector2(cx + sx, cy - sy * 0.35),
    Vector2(cx, cy), Vector2(cx - sx, cy - sy * 0.35),
  ])
  container.add_child(hl)
  return container

func style_button(btn: Button, color_type: String = "main", btn_size: Vector2 = Vector2.ZERO) -> void:
  var main_color = BUTTON_COLORS.get(color_type, BUTTON_COLORS["main"])
  if btn_size != Vector2.ZERO:
    var font_size = int(btn_size.y * 35.0 / 75.0)
    btn.custom_minimum_size = btn_size
    btn.add_theme_font_size_override("font_size", font_size)
    if btn.icon:
      var aspect = float(btn.icon.get_width()) / float(btn.icon.get_height())
      btn.add_theme_constant_override("icon_max_width", int(font_size * aspect))
    else:
      btn.add_theme_constant_override("icon_max_width", font_size)
  var shadow_color = main_color.darkened(0.3)

  # Normal
  var style_n = StyleBoxFlat.new()
  style_n.bg_color = main_color
  style_n.corner_radius_top_left = 18
  style_n.corner_radius_top_right = 18
  style_n.corner_radius_bottom_left = 18
  style_n.corner_radius_bottom_right = 18
  style_n.border_width_bottom = 6
  style_n.border_color = shadow_color
  style_n.content_margin_left = 48
  style_n.content_margin_right = 48
  style_n.content_margin_top = 12
  style_n.content_margin_bottom = 14
  btn.add_theme_stylebox_override("normal", style_n)

  # Hover
  var style_h = style_n.duplicate()
  style_h.bg_color = main_color.lightened(0.1)
  btn.add_theme_stylebox_override("hover", style_h)

  # Pressed
  var style_p = StyleBoxFlat.new()
  style_p.bg_color = main_color.darkened(0.1)
  style_p.corner_radius_top_left = 18
  style_p.corner_radius_top_right = 18
  style_p.corner_radius_bottom_left = 18
  style_p.corner_radius_bottom_right = 18
  style_p.border_width_bottom = 2
  style_p.border_color = shadow_color
  style_p.content_margin_left = 48
  style_p.content_margin_right = 48
  style_p.content_margin_top = 16
  style_p.content_margin_bottom = 10
  btn.add_theme_stylebox_override("pressed", style_p)

  # Disabled
  var style_d = style_n.duplicate()
  style_d.bg_color = main_color.darkened(0.4)
  style_d.border_color = shadow_color.darkened(0.4)
  btn.add_theme_stylebox_override("disabled", style_d)

  # Focus (remove default outline)
  var style_f = StyleBoxEmpty.new()
  btn.add_theme_stylebox_override("focus", style_f)

  # Font colors
  btn.add_theme_color_override("font_color", Color.WHITE)
  btn.add_theme_color_override("font_hover_color", Color.WHITE)
  btn.add_theme_color_override("font_pressed_color", Color.WHITE)
  btn.add_theme_color_override("font_disabled_color", Color(0.65, 0.65, 0.7))

func _process(delta: float) -> void:
  # Don't tick timed buffs while game is paused
  if get_tree().paused:
    return
  var expired: Array = []
  for buff_type in timed_buffs:
    timed_buffs[buff_type] -= delta
    if timed_buffs[buff_type] <= 0:
      expired.append(buff_type)
  for buff_type in expired:
    timed_buffs.erase(buff_type)
    timed_buff_ended.emit(buff_type)

func _init_grass_data() -> void:
  # 0: 새싹 - 체력 낮음, 보상 적음
  var g0 = GrassData.new()
  g0.grass_name = "새싹"
  g0.max_health = 4
  g0.regen_time = 22.0
  g0.min_drop_value = 1
  g0.max_drop_value = 1
  g0.drop_chance = GRASS_DROP_CHANCE
  g0.color = Color(0.3, 0.7, 0.3)
  g0.cut_color = Color(0.5, 0.4, 0.2)

  # 1: 잔디 - 체력 중간, 보상 보통
  var g1 = GrassData.new()
  g1.grass_name = "잔디"
  g1.max_health = 18
  g1.regen_time = 23.0
  g1.min_drop_value = 5
  g1.max_drop_value = 5
  g1.drop_chance = GRASS_DROP_CHANCE
  g1.color = Color(0.15, 0.5, 0.35)
  g1.cut_color = Color(0.3, 0.35, 0.25)

  # 2: 여린풀 - 체력 높음, 보상 좋음
  var g2 = GrassData.new()
  g2.grass_name = "여린풀"
  g2.max_health = 38
  g2.regen_time = 24.0
  g2.min_drop_value = 30
  g2.max_drop_value = 30
  g2.drop_chance = GRASS_DROP_CHANCE
  g2.color = Color(0.1, 0.35, 0.5)
  g2.cut_color = Color(0.2, 0.3, 0.35)

  # 3: 강한풀 - 체력 매우 높음, 보상 매우 좋음
  var g3 = GrassData.new()
  g3.grass_name = "강한풀"
  g3.max_health = 75
  g3.regen_time = 25.0
  g3.min_drop_value = 80
  g3.max_drop_value = 80
  g3.drop_chance = GRASS_DROP_CHANCE
  g3.color = Color(0.1, 0.25, 0.55)
  g3.cut_color = Color(0.15, 0.25, 0.4)

  # 4: 초강풀 - 최고 등급, 보상 최고
  var g4 = GrassData.new()
  g4.grass_name = "초강풀"
  g4.max_health = 130
  g4.regen_time = 26.0
  g4.min_drop_value = 200
  g4.max_drop_value = 200
  g4.drop_chance = GRASS_DROP_CHANCE
  g4.color = Color(0.15, 0.2, 0.55)
  g4.cut_color = Color(0.12, 0.2, 0.4)

  # 5: 황금풀 - 예외적 존재, 황금풀 확률 스킬로만 등장
  var g5 = GrassData.new()
  g5.grass_name = "황금풀"
  g5.max_health = 80
  g5.regen_time = 25.0
  g5.min_drop_value = 100
  g5.max_drop_value = 100
  g5.guaranteed_drop = true
  g5.color = Color(1.0, 0.85, 0.1)
  g5.cut_color = Color(0.7, 0.6, 0.1)

  grass_data_list.append(g0)
  grass_data_list.append(g1)
  grass_data_list.append(g2)
  grass_data_list.append(g3)
  grass_data_list.append(g4)
  grass_data_list.append(g5)

# 풀 등급 이름 (UI 표시용)
const GRASS_TYPE_NAMES: Array = ["새싹", "잔디", "여린풀", "강한풀", "초강풀"]

func get_random_grass_data() -> GrassData:
  if randf() < get_golden_grass_chance():
    return grass_data_list[5]  # 황금풀

  # 레벨별 풀 등급 전환 (8레벨, 2레벨당 1등급 전환)
  # 짝수 코드레벨(유저 홀수): 현재 100% → 현재 50% + 다음 50%
  # 홀수 코드레벨(유저 짝수): 현재 50% + 다음 50% → 다음 100%
  var level = upgrade_levels.get("grass_quality", 0)
  var sub = upgrade_sub_levels.get("grass_quality", 0)

  # 현재 기본 등급 (2레벨마다 1등급씩 올라감)
  var base_type = mini(level / 2, 4)

  if level >= 8:
    return grass_data_list[4]  # 초강풀 100%

  var is_first_half = (level % 2 == 0)  # 코드 짝수 = 유저 홀수 = 0→50%
  var half_transition = float(sub) / 8.0 * 0.5

  if is_first_half:
    # 현재 등급 100% → 현재 50% + 다음 50%
    var next_chance = half_transition  # 0% → 50%
    if randf() < next_chance:
      return grass_data_list[mini(base_type + 1, 4)]
    return grass_data_list[base_type]
  else:
    # 현재 50% + 다음 50% → 다음 100%
    var next_chance = 0.5 + half_transition  # 50% → 100%
    if randf() < next_chance:
      return grass_data_list[mini(base_type + 1, 4)]
    return grass_data_list[base_type]

func add_fury(amount: float) -> void:
  if fury_boss_alive:
    return
  var fury_max = get_fury_max()
  fury = minf(fury + amount * get_fury_rate_mult(), fury_max)
  fury_changed.emit(fury)
  if fury >= fury_max:
    fury_boss_alive = true
    fury_boss_requested.emit()
    fury = 0.0
    fury_changed.emit(fury)

func add_money(amount: int) -> void:
  session_money = max(0, session_money + amount)
  session_money_changed.emit(session_money)

# ── Skill total progress helper ──
# Combines level and sub_level into a single progress value
func get_skill_total_progress(type: String) -> int:
  var level = upgrade_levels.get(type, 0)
  var sub = upgrade_sub_levels.get(type, 0)
  var def = get_skill_def(type)
  var sub_max = def.get("sub_max", 5)
  return level * sub_max + sub

# ── Permanent upgrade getters ──

# 공격 속도: 0.7s → 0.1s, 틱당 -0.02s (총 30틱)
func get_attack_interval() -> float:
  var ticks = get_skill_total_progress("attack_speed")
  return maxf(0.1, 0.7 - ticks * 0.02)

# 공격 범위: 60 → 340, 틱당 +7 (총 40틱)
func get_attack_range() -> float:
  var ticks = get_skill_total_progress("attack_range")
  return 60.0 + ticks * 7.0

# 공격 횟수: 1 → 46, 레벨별 틱당 +1/+2/+3/+4/+5 (총 15틱)
func get_attack_count() -> int:
  var level = upgrade_levels.get("attack_count", 0)
  var sub = upgrade_sub_levels.get("attack_count", 0)
  var sub_max = 3
  var count = 1
  for lv in range(level):
    count += (lv + 1) * sub_max
  if level < 5:
    count += (level + 1) * sub
  return count

# 수집 범위: 50 → 260, 틱당 +7 (총 30틱)
func get_base_magnet_range() -> float:
  var ticks = get_skill_total_progress("magnet_range")
  return 50.0 + ticks * 7.0

# 풀 밀도: 1 → 181, 레벨별 틱당 +Lv (총 40틱, 5틱×8레벨)
func get_grass_density_value() -> int:
  var ticks = get_skill_total_progress("grass_density")
  if ticks <= 0:
    return 1
  var value = 0
  var remaining = ticks
  for lv in range(1, 9):
    var t = mini(remaining, 5)
    value += t * lv
    remaining -= t
    if remaining <= 0:
      break
  return 1 + value

# 상자 출현률: 0% → 5%, 틱당 +0.2% (총 25틱)
func get_chest_spawn_chance() -> float:
  var ticks = get_skill_total_progress("chest_chance")
  return ticks * 0.002

# 치명타 확률: 0% → 100%, 틱당 +5% (총 20틱)
func get_crit_chance() -> float:
  if session_buff_critical_surge:
    return 1.0
  var ticks = get_skill_total_progress("crit_chance")
  return minf(ticks * 0.05, 1.0)

# 치명타 데미지: 1.2x → 3.7x, 틱당 +0.10 (총 25틱)
func get_crit_damage_mult() -> float:
  var ticks = get_skill_total_progress("crit_damage")
  var mult = 1.2 + ticks * 0.10
  if session_buff_critical_surge:
    mult *= 2.0
  return mult

# 몬스터 피해 배율 (미정 — 임시: 틱당 +0.1, 총 35틱)
func get_monster_damage_mult() -> float:
  var ticks = get_skill_total_progress("monster_damage")
  return 1.0 + ticks * 0.1

# 분노 증가 배율 (미정 — 임시: 틱당 +0.15, 총 16틱)
func get_fury_rate_mult() -> float:
  var ticks = get_skill_total_progress("fury_rate")
  return 1.0 + ticks * 0.15

# 황금풀 확률: 0% → (미정), 틱당 +0.1% (총 10틱 = 최대 1%)
func get_golden_grass_chance() -> float:
  var ticks = get_skill_total_progress("golden_chance")
  if ticks <= 0:
    return 0.0
  return ticks * 0.001

# 황금풀 보상 배율: 단계별 10%/11%/12%/13%/14% 복리 증가 (총 25틱, 최대 ~1,696원)
func get_golden_reward_mult() -> float:
  var level = upgrade_levels.get("golden_reward", 0)
  var sub = upgrade_sub_levels.get("golden_reward", 0)
  var sub_max = 5
  var mult = 1.0
  for lv in range(level):
    mult *= pow(1.0 + 0.10 + lv * 0.01, sub_max)
  if level < 5:
    mult *= pow(1.0 + 0.10 + level * 0.01, sub)
  return mult

# 이동 속도: 300 → 600, 틱당 +10 (총 30틱)
func get_base_move_speed() -> float:
  var ticks = get_skill_total_progress("move_speed")
  return 300.0 + ticks * 10.0

func get_grass_density_level() -> int:
  return upgrade_levels.get("grass_density", 0)

func get_magnet_range() -> float:
  var base = get_base_magnet_range()
  var mult = 1.0 + session_buff_magnet_range * 0.5
  if timed_buffs.has("harvest_madness"):
    mult *= 2.0
  return base * mult

func get_session_attack_speed_mult() -> float:
  var mult = 1.0 + session_buff_attack_speed * 0.25
  if timed_buffs.has("overdrive"):
    mult *= 2.0  # +100%
  if timed_buffs.has("harvest_madness"):
    mult *= 2.0
  if hit_penalty_active:
    mult *= 0.5
  return mult

func get_session_attack_range_mult() -> float:
  var mult = 1.0 + session_buff_attack_range * 0.25
  if timed_buffs.has("harvest_madness"):
    mult *= 1.5
  return mult

func get_session_move_speed_mult() -> float:
  var mult = 1.0 + session_buff_move_speed * 0.5
  if timed_buffs.has("overdrive"):
    mult *= 0.7  # -30%
  if timed_buffs.has("harvest_madness"):
    mult *= 2.0
  if hit_penalty_active:
    mult *= 0.5
  return mult

func get_session_time_bonus() -> float:
  return get_skill_total_progress("session_time") * 3.0

func get_coin_multiplier() -> int:
  if timed_buffs.has("gold_rush"):
    return 2
  return 1

func get_timed_buff_remaining(type: String) -> float:
  return timed_buffs.get(type, 0.0)

func apply_powerup(type: String) -> void:
  match type:
    "attack_speed":
      session_buff_attack_speed += 1
      powerup_acquired.emit(type, session_buff_attack_speed)
    "attack_range":
      session_buff_attack_range += 1
      powerup_acquired.emit(type, session_buff_attack_range)
    "magnet_range":
      session_buff_magnet_range += 1
      powerup_acquired.emit(type, session_buff_magnet_range)
    "move_speed":
      session_buff_move_speed += 1
      powerup_acquired.emit(type, session_buff_move_speed)
    "critical_surge":
      session_buff_critical_surge = true
      powerup_acquired.emit(type, 1)
    "critical_reaper":
      session_buff_critical_reaper = true
      powerup_acquired.emit(type, 1)
    "golden_luck":
      session_buff_golden_luck = true
      powerup_acquired.emit(type, 1)
    "overdrive":
      _start_timed_buff("overdrive", 10.0)
      powerup_acquired.emit(type, 1)
    "extra_time":
      extra_time_requested.emit(5.0)
      powerup_acquired.emit(type, 0)
    "gold_rush":
      _start_timed_buff("gold_rush", 10.0)
      powerup_acquired.emit(type, 0)
    "golden_bloom":
      golden_bloom_requested.emit()
      powerup_acquired.emit(type, 0)
    "double_or_dust":
      _apply_double_or_dust()
    "monster_fury":
      add_fury(get_fury_max() * 0.35 / get_fury_rate_mult())
      powerup_acquired.emit(type, 0)
    "harvest_madness":
      _start_timed_buff("harvest_madness", 8.0)
      powerup_acquired.emit(type, 0)
    "field_clear":
      field_clear_requested.emit()
      powerup_acquired.emit(type, 0)
    "blackhole":
      blackhole_requested.emit()
      powerup_acquired.emit(type, 0)

func _start_timed_buff(type: String, duration: float) -> void:
  timed_buffs[type] = duration
  timed_buff_started.emit(type, duration)

func _apply_double_or_dust() -> void:
  if randf() < 0.5:
    # Double!
    var bonus = session_money
    add_money(bonus)
    powerup_acquired.emit("double_or_dust", 1)  # 1 = success
  else:
    # Dust! 세션 수입의 30%만 잃음
    var lost = int(session_money * 0.3)
    add_money(-lost)
    powerup_acquired.emit("double_or_dust", 0)  # 0 = fail

const BASE_KNOCKBACK: float = 120.0

func get_monster_knockback_strength() -> float:
  return BASE_KNOCKBACK

func get_grass_drop_chance() -> float:
  return GRASS_DROP_CHANCE

# get_golden_grass_chance() is defined above in permanent upgrade getters

func get_total_skill_level() -> int:
  var total = 0
  for type in upgrade_levels:
    if type == "attack_power":
      continue
    total += upgrade_levels[type]
  return total

func get_grass_reward_multiplier() -> float:
  return 1.0

# 무기 레벨별 필요 스킬 포인트 (수동 튜닝)
# Lv0 나뭇가지, Lv1 녹슨식칼, Lv2 피자커터, Lv3 전기파리채,
# Lv4 뜨거운다리미, Lv5 매우화난고양이, Lv6 체인소,
# Lv7 마법지팡이, Lv8 날개달린선풍기, Lv9 위성레이저제초기
const WEAPON_SKILL_REQUIREMENTS = [0, 0, 2, 4, 7, 11, 16, 21, 27, 34]

# Skill tree prerequisites: "type:level" -> Array of {type, level} (all AND)
# Row 0 = root (centered, no prereq). Row 1+ = 2-col grid, prereq = skill above in same column
const SKILL_PREREQS = {
  # 무기: row1 ← root(attack_power)
  "attack_speed:1": [{"type": "attack_power", "level": 1}],
  "attack_range:1": [{"type": "attack_power", "level": 1}],
  # 무기: row2 ← row1 (각 열 직선)
  "crit_chance:1": [{"type": "attack_speed", "level": 1}],
  "monster_damage:1": [{"type": "attack_range", "level": 1}],
  # 무기: row3 ← crit_chance
  "crit_damage:1": [{"type": "crit_chance", "level": 1}],
  # 수확: row1 ← root(grass_density)
  "grass_quality:1": [{"type": "grass_density", "level": 1}],
  "attack_count:1": [{"type": "grass_density", "level": 1}],
  # 수확: row2 ← row1 (각 열 직선)
  "golden_chance:1": [{"type": "grass_quality", "level": 1}],
  "magnet_range:1": [{"type": "attack_count", "level": 1}],
  # 수확: row3 ← golden_chance
  "golden_reward:1": [{"type": "golden_chance", "level": 1}],
  # 탐험: row1 ← root(move_speed)
  "session_time:1": [{"type": "move_speed", "level": 1}],
  "chest_chance:1": [{"type": "move_speed", "level": 1}],
  # 탐험: row2 ← row1 (OR)
  "fury_rate:1": [{"type": "session_time_or_chest_chance", "level": 1}],
}

# Required total skill levels to unlock (해금 게이트)
const SKILL_REQUIRED_TOTAL = {
  # 수확: row1 (Lv.1+)
  "attack_count:1": 7,
  # 수확: row2 (Lv.2+)
  "attack_count:2": 3,
  # 무기: row2 (Lv.2+)
  "crit_damage:2": 3,
  # 무기: row2 (Lv.1+)
  "monster_damage:1": 30,
  # 무기: row2 (Lv.2+)
  "monster_damage:2": 3,
  # 수확: row3 (Lv.2+)
  "golden_reward:2": 3,
  # 수확: row3 (Lv.1+)
  "golden_chance:1": 8,
  # 탐험: root (Lv.2+)
  "move_speed:2": 2,
  # 탐험: row1 (Lv.1+)
  "chest_chance:1": 12,
  # 탐험: row2 (Lv.1+)
  "fury_rate:1": 30,
  # 탐험: row2 (Lv.2+)
  "fury_rate:2": 3,
}

func check_skill_prereqs(type: String, level: int) -> Dictionary:
  var missing: Array = []
  # Check required_total gate (level-specific key first, then type-wide)
  var total_key = "%s:%d" % [type, level]
  var required = -1
  if SKILL_REQUIRED_TOTAL.has(total_key):
    required = SKILL_REQUIRED_TOTAL[total_key]
  elif SKILL_REQUIRED_TOTAL.has(type):
    required = SKILL_REQUIRED_TOTAL[type]
  if required >= 0:
    var total = get_total_skill_level()
    if total < required:
      missing.append({"type": "_total", "level": required, "current": total})
  # Check skill prereqs
  var key = "%s:%d" % [type, level]
  if SKILL_PREREQS.has(key):
    for req in SKILL_PREREQS[key]:
      if "_or_" in req.type:
        # OR condition: any one of the types meeting the level is enough
        var or_types = req.type.split("_or_")
        var any_met = false
        for ot in or_types:
          if get_upgrade_level(ot) >= req.level:
            any_met = true
            break
        if not any_met:
          var names = []
          for ot in or_types:
            names.append(get_skill_def(ot).get("short_name", ot))
          missing.append({"type": req.type, "level": req.level, "current": 0, "or_names": names})
      else:
        var current = get_upgrade_level(req.type)
        if current < req.level:
          missing.append({"type": req.type, "level": req.level, "current": current})
  return {"met": missing.is_empty(), "missing": missing}

func has_any_purchasable_skill() -> bool:
  for def in SKILL_DEFS:
    var type = def.type
    var current_level = upgrade_levels.get(type, 0)
    var max_level = def.max_level
    if max_level >= 0 and current_level >= max_level:
      continue
    var next_level = current_level + 1
    var prereq = check_skill_prereqs(type, next_level)
    if not prereq.met:
      continue
    var sub = upgrade_sub_levels.get(type, 0)
    if sub == 0 and is_gem_locked(type, next_level):
      continue
    var cost = get_upgrade_cost(current_level, type)
    if money >= cost:
      return true
  return false

func get_upgrade_level(type: String) -> int:
  return upgrade_levels.get(type, 0)

func get_upgrade_sub_level(type: String) -> int:
  return upgrade_sub_levels.get(type, 0)

func get_skill_max_level(type: String) -> int:
  for def in SKILL_DEFS:
    if def.type == type:
      return def.max_level
  return -1

func get_skill_def(type: String) -> Dictionary:
  for def in SKILL_DEFS:
    if def.type == type:
      return def
  return {}

func get_weapon_skill_requirement(weapon_level: int) -> int:
  if weapon_level < 0 or weapon_level >= WEAPON_SKILL_REQUIREMENTS.size():
    return 0
  return WEAPON_SKILL_REQUIREMENTS[weapon_level]

func get_grass_regen_time(base_time: float) -> float:
  var level = upgrade_levels.get("grass_regen", 0)
  if level == 0:
    return base_time
  elif level == 1:
    return 13.0
  else:
    return 4.0

# ── 틱 비용 테이블: [시작가, 틱당증가] (인덱스 = 코드 레벨) ──

# ━━ 무기 그룹 ━━
# root: 공격력 (5t×9L)
const ATTACK_POWER_TICK_COSTS: Array = [
  [1, 1],           # Lv.1: 1,2,3,4,5 = 15
  [15, 4],          # Lv.2: 15,19,23,27,31 = 115
  [300, 70],        # Lv.3: 300,370,440,510,580 = 2,200
  [4500, 1125],     # Lv.4: 4500,5625,6750,7875,9000 = 33,750
  [27000, 4950],    # Lv.5: 27000,31950,36900,41850,46800 = 184,500
  [81000, 14850],   # Lv.6: 81000,95850,110700,125550,140400 = 553,500
  [288000, 52200],  # Lv.7: 288000,340200,392400,444600,496800 = 1,962,000
  [900000, 162000], # Lv.8: 900000,1062000,1224000,1386000,1548000 = 6,120,000
  [3060000, 550800], # Lv.9: 3060000,3610800,4161600,4712400,5263200 = 20,808,000
]
# row1: 공격 속도 (5t×6L)
const ATTACK_SPEED_TICK_COSTS: Array = [
  [15, 2],            # Lv.1: 15,17,19,21,23 = 95
  [28, 5],            # Lv.2: 28,33,38,43,48 = 190
  [200, 28],          # Lv.3: 200,228,256,284,312 = 1,280
  [6500, 980],        # Lv.4: 6500,7480,8460,9440,10420 = 42,300
  [220000, 33000],    # Lv.5: 220000,253000,286000,319000,352000 = 1,430,000
  [800000, 120000],   # Lv.6: 800000,920000,1040000,1160000,1280000 = 5,200,000
]
# row1: 공격 범위 (5t×8L)
const ATTACK_RANGE_TICK_COSTS: Array = [
  [10, 1],            # Lv.1: 10,11,12,13,14 = 60
  [25, 2],            # Lv.2: 25,27,29,31,33 = 145
  [60, 5],            # Lv.3: 60,65,70,75,80 = 350
  [800, 60],          # Lv.4: 800,860,920,980,1040 = 4,600
  [3000, 230],        # Lv.5: 3000,3230,3460,3690,3920 = 17,300
  [32000, 2460],      # Lv.6: 32000,34460,36920,39380,41840 = 184,600
  [140000, 10780],    # Lv.7: 140000,150780,161560,172340,183120 = 807,800
  [370000, 28490],    # Lv.8: 370000,398490,426980,455470,483960 = 2,134,900
]
# row2: 치명타 확률 (5t×4L)
const CRIT_CHANCE_TICK_COSTS: Array = [
  [20, 2],          # Lv.1: 20,22,24,26,28 = 120
  [150, 12],        # Lv.2: 150,162,174,186,198 = 870
  [2400, 320],      # Lv.3: 2400,2720,3040,3360,3680 = 15,200
  [23000, 2300],    # Lv.4: 23000,25300,27600,29900,32200 = 138,000
]
# row2: 몬스터 피해 (5t×7L)
const MONSTER_DAMAGE_TICK_COSTS: Array = [
  [50, 6],          # Lv.1: 50,56,62,68,74 = 310
  [120, 10],        # Lv.2: 120,130,140,150,160 = 700
  [500, 50],        # Lv.3: 500,550,600,650,700 = 3,000
  [12000, 1200],    # Lv.4: 12000,13200,14400,15600,16800 = 72,000
  [45000, 4500],    # Lv.5: 45000,49500,54000,58500,63000 = 270,000
  [100000, 10000],  # Lv.6: 100000,110000,120000,130000,140000 = 600,000
  [260000, 26000],  # Lv.7: 260000,286000,312000,338000,364000 = 1,560,000
]
# row3: 치명타 피해 (5t×6L)
const CRIT_DAMAGE_TICK_COSTS: Array = [
  [50, 5],            # Lv.1: 50,55,60,65,70 = 300
  [1000, 80],         # Lv.2: 1000,1080,1160,1240,1320 = 5,800
  [6000, 500],        # Lv.3: 6000,6500,7000,7500,8000 = 35,000
  [60000, 5000],      # Lv.4: 60000,65000,70000,75000,80000 = 350,000
  [580000, 46400],    # Lv.5: 580000,626400,672800,719200,765600 = 3,364,000
]

# ━━ 수확 그룹 ━━
# root: 풀 밀도 (5t×8L)
const DENSITY_TICK_COSTS: Array = [
  [1, 1],           # Lv.1: 1,2,3,4,5 = 15
  [15, 2],          # Lv.2: 15,17,19,21,23 = 95
  [85, 12],         # Lv.3: 85,97,109,121,133 = 545
  [1000, 120],      # Lv.4: 1000,1120,1240,1360,1480 = 6,200
  [28000, 3360],    # Lv.5: 28000,31360,34720,38080,41440 = 173,600
  [196000, 23520],  # Lv.6: 196000,219520,243040,266560,290080 = 1,215,200
  [710000, 85200],  # Lv.7: 710000,795200,880400,965600,1050800 = 4,402,000
  [2800000, 336000], # Lv.8: 2800000,3136000,3472000,3808000,4144000 = 17,360,000
]
# row1: 풀 등급 (8t×8L)
const QUALITY_TICK_COSTS: Array = [
  [15, 1],          # Lv.1: 15,16,17,18,19,20,21,22 = 148
  [20, 1],          # Lv.2: 20,21,22,23,24,25,26,27 = 188
  [80, 5],          # Lv.3: 80,85,90,95,100,105,110,115 = 780
  [480, 38],        # Lv.4: 480,518,556,594,632,670,708,746 = 4,904
  [5000, 400],      # Lv.5: 5000,5400,5800,6200,6600,7000,7400,7800 = 51,200
  [42000, 3360],    # Lv.6: 42000,45360,48720,52080,55440,58800,62160,65520 = 430,080
  [275000, 22000],  # Lv.7: 275000,297000,319000,341000,363000,385000,407000,429000 = 2,816,000
  [670000, 53600],  # Lv.8: 670000,723600,777200,830800,884400,938000,991600,1045200 = 6,860,800
]
# row1: 공격 개수 (3t×5L)
const ATTACK_COUNT_TICK_COSTS: Array = [
  [20, 5],          # Lv.1: 20,25,30 = 75
  [300, 100],       # Lv.2: 300,400,500 = 1,200
  [8000, 2000],     # Lv.3: 8000,10000,12000 = 30,000
  [300000, 75000],  # Lv.4: 300000,375000,450000 = 1,125,000
  [2500000, 625000], # Lv.5: 2500000,3125000,3750000 = 9,375,000
]
# row2: 황금풀 확률 (2t×5L)
const GOLDEN_CHANCE_TICK_COSTS: Array = [
  [20, 2],          # Lv.1: 20,22 = 42
  [150, 30],        # Lv.2: 150,180 = 330
  [1800, 220],      # Lv.3: 1800,2020 = 3,820
  [21000, 2500],    # Lv.4: 21000,23500 = 44,500
  [250000, 30000],  # Lv.5: 250000,280000 = 530,000
]
# row2: 수집 범위 (5t×6L)
const MAGNET_TICK_COSTS: Array = [
  [20, 2],            # Lv.1: 20,22,24,26,28 = 120
  [40, 4],            # Lv.2: 40,44,48,52,56 = 240
  [250, 25],          # Lv.3: 250,275,300,325,350 = 1,500
  [4000, 500],        # Lv.4: 4000,4500,5000,5500,6000 = 25,000
  [40000, 5000],      # Lv.5: 40000,45000,50000,55000,60000 = 250,000
  [200000, 20000],    # Lv.6: 200000,220000,240000,260000,280000 = 1,200,000
]
# row3: 황금풀 보상 (5t×5L)
const GOLDEN_REWARD_TICK_COSTS: Array = [
  [50, 5],          # Lv.1: 50,55,60,65,70 = 300
  [100, 8],         # Lv.2: 100,108,116,124,132 = 580
  [800, 80],        # Lv.3: 800,880,960,1040,1120 = 4,800
  [12000, 1200],    # Lv.4: 12000,13200,14400,15600,16800 = 72,000
  [180000, 18000],  # Lv.5: 180000,198000,216000,234000,252000 = 1,080,000
]

# ━━ 탐험 그룹 ━━
# root: 이동 속도 (6t×5L)
const MOVE_SPEED_TICK_COSTS: Array = [
  [0, 0],           # Lv.1: special (1+sub/2): 1,1,2,2,3,3 = 12
  [10, 1],          # Lv.2: 10,11,12,13,14,15 = 75
  [90, 22],         # Lv.3: 90,112,134,156,178,200 = 870
  [8000, 1920],     # Lv.4: 8000,9920,11840,13760,15680,17600 = 76,800
  [60000, 14400],   # Lv.5: 60000,74400,88800,103200,117600,132000 = 576,000
]
# row1: 세션 시간 (3t×5L)
const SESSION_TIME_TICK_COSTS: Array = [
  [20, 5],          # Lv.1: 20,25,30 = 75
  [200, 50],        # Lv.2: 200,250,300 = 750
  [2200, 550],      # Lv.3: 2200,2750,3300 = 8,250
  [24000, 6000],    # Lv.4: 24000,30000,36000 = 90,000
  [250000, 62500],  # Lv.5: 250000,312500,375000 = 937,500
]
# row1: 상자 확률 (5t×5L)
const CHEST_CHANCE_TICK_COSTS: Array = [
  [20, 2],          # Lv.1: 20,22,24,26,28 = 120
  [200, 20],        # Lv.2: 200,220,240,260,280 = 1,200
  [2200, 220],      # Lv.3: 2200,2420,2640,2860,3080 = 13,200
  [24000, 2400],    # Lv.4: 24000,26400,28800,31200,33600 = 144,000
  [250000, 25000],  # Lv.5: 250000,275000,300000,325000,350000 = 1,500,000
]
# row2: 분노 속도 (4t×4L)
const FURY_RATE_TICK_COSTS: Array = [
  [1000, 100],      # Lv.1: 1000,1100,1200,1300 = 4,600
  [9300, 930],      # Lv.2: 9300,10230,11160,12090 = 42,780
  [86000, 8600],    # Lv.3: 86000,94600,103200,111800 = 395,600
  [800000, 80000],  # Lv.4: 800000,880000,960000,1040000 = 3,680,000
]

# 스킬 레벨 첫 틱 구매 시 필요한 보석 비용
# 형식: { "스킬타입": { 레벨: 보석수 } }
# 예: "attack_power": {6: 1} → Lv.6 첫 틱 구매 시 보석 1개 필요
const SKILL_GEM_COSTS: Dictionary = {
  "attack_power": {4: 1, 6: 2, 8: 3},
  "attack_speed": {4: 1, 5: 2, 6: 3},
  "attack_range": {6: 1},
  "crit_chance": {4: 1},
  "monster_damage": {5: 1},
  "crit_damage": {5: 1},
  "grass_density": {5: 1, 7: 2},
  "grass_quality": {5: 1, 7: 2},
  "attack_count": {3: 1, 4: 2, 5: 3},
  "golden_chance": {5: 1},
  "magnet_range": {5: 1, 6: 2},
  "golden_reward": {4: 1},
  "move_speed": {5: 1},
  "session_time": {3: 1, 5: 2},
  "chest_chance": {4: 1, 5: 2},
  "fury_rate": {4: 1},
}

func get_skill_gem_cost(upgrade_type: String, level: int) -> int:
  if not SKILL_GEM_COSTS.has(upgrade_type):
    return 0
  return SKILL_GEM_COSTS[upgrade_type].get(level, 0)

func is_gem_locked(type: String, level: int) -> bool:
  var gem_cost = get_skill_gem_cost(type, level)
  if gem_cost <= 0:
    return false
  var key = "%s:%d" % [type, level]
  return key not in unlocked_gem_skills

func unlock_gem_skill(type: String, level: int) -> bool:
  var gem_cost = get_skill_gem_cost(type, level)
  if gem_cost <= 0:
    return false
  if owned_gems < gem_cost:
    return false
  var key = "%s:%d" % [type, level]
  if key in unlocked_gem_skills:
    return false
  owned_gems -= gem_cost
  unlocked_gem_skills.append(key)
  SaveManager.save_game()
  return true

func get_upgrade_cost(current_level: int, upgrade_type: String = "") -> int:
  var cost = _get_raw_upgrade_cost(current_level, upgrade_type)
  # 80% 이상 달성 시 최소 5000/틱 (1.6배씩 스케일)
  var max_lvl = get_skill_max_level(upgrade_type)
  if max_lvl > 0:
    var threshold = int(max_lvl * 0.8)  # 80% 유저 레벨
    var user_level = current_level + 1
    if user_level >= threshold:
      var levels_over = user_level - threshold
      var base = int(5000 * pow(1.6, levels_over))
      var sub = upgrade_sub_levels.get(upgrade_type, 0)
      var sub_inc = int(base * 0.06)
      cost = maxi(cost, base + sub * sub_inc)
  return cost

func _get_raw_upgrade_cost(current_level: int, upgrade_type: String = "") -> int:
  var sub = upgrade_sub_levels.get(upgrade_type, 0)

  # Special: move_speed Lv.1 — 2틱마다 1원 증가
  if current_level == 0 and upgrade_type == "move_speed":
    return 1 + sub / 2

  # 스킬별 틱 비용 테이블 선택
  var tier_costs: Array
  var SKILL_TICK_COSTS: Dictionary = {
    "attack_power": ATTACK_POWER_TICK_COSTS,
    "attack_speed": ATTACK_SPEED_TICK_COSTS,
    "attack_range": ATTACK_RANGE_TICK_COSTS,
    "attack_count": ATTACK_COUNT_TICK_COSTS,
    "magnet_range": MAGNET_TICK_COSTS,
    "grass_density": DENSITY_TICK_COSTS,
    "grass_quality": QUALITY_TICK_COSTS,
    "golden_chance": GOLDEN_CHANCE_TICK_COSTS,
    "golden_reward": GOLDEN_REWARD_TICK_COSTS,
    "crit_chance": CRIT_CHANCE_TICK_COSTS,
    "crit_damage": CRIT_DAMAGE_TICK_COSTS,
    "monster_damage": MONSTER_DAMAGE_TICK_COSTS,
    "fury_rate": FURY_RATE_TICK_COSTS,
    "move_speed": MOVE_SPEED_TICK_COSTS,
    "session_time": SESSION_TIME_TICK_COSTS,
    "chest_chance": CHEST_CHANCE_TICK_COSTS,
  }
  tier_costs = SKILL_TICK_COSTS.get(upgrade_type, ATTACK_POWER_TICK_COSTS)

  if current_level < tier_costs.size():
    return tier_costs[current_level][0] + sub * tier_costs[current_level][1]
  # Fallback: 마지막 정의 레벨 기준 1.6배씩 스케일
  var last = tier_costs[-1]
  var extra = current_level - tier_costs.size() + 1
  return int((last[0] + sub * last[1]) * pow(1.6, extra))

func purchase_upgrade(upgrade_type: String) -> bool:
  var current_level = upgrade_levels.get(upgrade_type, -1)
  if current_level < 0:
    return false  # Unknown skill type
  var max_level = get_skill_max_level(upgrade_type)
  if max_level >= 0 and current_level >= max_level:
    return false

  var next_level = current_level + 1
  var prereq_result = check_skill_prereqs(upgrade_type, next_level)
  if not prereq_result.met:
    return false

  var cost = get_upgrade_cost(current_level, upgrade_type)
  if money < cost:
    return false

  # 보석 해금 체크 (첫 틱 시 해금되지 않았으면 구매 불가)
  var sub = upgrade_sub_levels.get(upgrade_type, 0)
  if sub == 0 and is_gem_locked(upgrade_type, next_level):
    return false

  money -= cost
  money_changed.emit(money)
  sub += 1
  upgrade_sub_levels[upgrade_type] = sub
  if sub >= get_skill_sub_max(upgrade_type):
    upgrade_levels[upgrade_type] = next_level
    upgrade_sub_levels[upgrade_type] = 0
    # 무기 레벨 변경 시 WeaponManager 동기화
    if upgrade_type == "attack_power":
      WeaponManager.current_weapon_level = next_level
      WeaponManager.weapon_changed.emit(next_level)
  upgrade_purchased.emit(upgrade_type, next_level)
  return true

func add_key(world_index: int) -> void:
  if world_index not in owned_keys:
    owned_keys.append(world_index)
    SaveManager.save_game()

func has_key(world_index: int) -> bool:
  return world_index in owned_keys

func unlock_world(index: int) -> bool:
  if index < 0 or index >= WORLD_UNLOCK_COSTS.size():
    return false
  if index in unlocked_worlds:
    return false
  var cost = WORLD_UNLOCK_COSTS[index]
  if money < cost:
    return false
  if not has_key(index):
    return false
  money -= cost
  owned_keys.erase(index)
  unlocked_worlds.append(index)
  money_changed.emit(money)
  world_unlocked.emit(index)
  SaveManager.save_game()
  return true

func get_save_data() -> Dictionary:
  return {
    "money": money,
    "upgrade_levels": upgrade_levels.duplicate(),
    "upgrade_sub_levels": upgrade_sub_levels.duplicate(),
    "selected_world": selected_world,
    "unlocked_worlds": unlocked_worlds,
    "owned_keys": owned_keys,
    "has_potion": has_potion,
    "owned_gems": owned_gems,
    "unlocked_gem_skills": unlocked_gem_skills.duplicate(),
    "world_strength_levels": world_strength_levels.duplicate(),
    "collected_gem_levels": collected_gem_levels.duplicate(),
    "has_ever_transcended": has_ever_transcended,
    "bgm_enabled": bgm_enabled,
    "sfx_enabled": sfx_enabled,
    "vibration_enabled": vibration_enabled,
  }

func load_save_data(data: Dictionary) -> void:
  money = data.get("money", 0)
  # New format: upgrade_levels dictionary
  if data.has("upgrade_levels"):
    for type in data.upgrade_levels:
      upgrade_levels[type] = int(data.upgrade_levels[type])
  else:
    # Legacy save migration: individual "upgrade_X" keys
    for def in SKILL_DEFS:
      upgrade_levels[def.type] = int(data.get("upgrade_%s" % def.type, 0))
  # Sub-levels
  var saved_sub = data.get("upgrade_sub_levels", {})
  for type in saved_sub:
    upgrade_sub_levels[type] = int(saved_sub[type])
  selected_world = data.get("selected_world", 0)
  var saved_worlds = data.get("unlocked_worlds", [0])
  unlocked_worlds = []
  for w in saved_worlds:
    unlocked_worlds.append(int(w))
  if 0 not in unlocked_worlds:
    unlocked_worlds.append(0)
  has_potion = data.get("has_potion", false)
  owned_gems = int(data.get("owned_gems", 0))
  var saved_gem_skills = data.get("unlocked_gem_skills", [])
  unlocked_gem_skills = []
  for s in saved_gem_skills:
    unlocked_gem_skills.append(str(s))
  var saved_keys = data.get("owned_keys", [])
  owned_keys = []
  for k in saved_keys:
    owned_keys.append(int(k))
  # 월드 초월 레벨 복원 (JSON 키는 문자열이므로 int 변환)
  world_strength_levels = {}
  var saved_strength = data.get("world_strength_levels", {})
  for k in saved_strength:
    world_strength_levels[int(k)] = int(saved_strength[k])
  has_ever_transcended = data.get("has_ever_transcended", false)
  # 기존 세이브 호환: 초월 레벨이 있으면 이미 초월한 것
  if not has_ever_transcended and not saved_strength.is_empty():
    has_ever_transcended = true
  # 보석 수집 기록 복원
  collected_gem_levels = {}
  var saved_gem_levels = data.get("collected_gem_levels", {})
  for k in saved_gem_levels:
    var levels_arr: Array = []
    for v in saved_gem_levels[k]:
      levels_arr.append(int(v))
    collected_gem_levels[int(k)] = levels_arr
  bgm_enabled = data.get("bgm_enabled", data.get("sound_enabled", true))
  sfx_enabled = data.get("sfx_enabled", data.get("sound_enabled", true))
  vibration_enabled = data.get("vibration_enabled", true)
  money_changed.emit(money)
  # weapon 스킬 레벨에서 WeaponManager 동기화
  WeaponManager.current_weapon_level = upgrade_levels.get("attack_power", 0)
  WeaponManager.weapon_changed.emit(WeaponManager.current_weapon_level)

func has_collected_gems(world: int, strength: int) -> bool:
  if not collected_gem_levels.has(world):
    return false
  return strength in collected_gem_levels[world]

func mark_gems_collected(world: int, strength: int) -> void:
  if not collected_gem_levels.has(world):
    collected_gem_levels[world] = []
  if strength not in collected_gem_levels[world]:
    collected_gem_levels[world].append(strength)

func add_gem(count: int = 1) -> void:
  session_gems += count
  owned_gems += count

func finalize_session() -> void:
  money += session_money
  session_money = 0
  money_changed.emit(money)

func reset_session_data() -> void:
  session_money = 0
  session_buff_attack_speed = 0
  session_buff_attack_range = 0
  session_buff_magnet_range = 0
  session_buff_move_speed = 0
  session_buff_critical_surge = false
  session_buff_critical_reaper = false
  session_buff_golden_luck = false
  timed_buffs.clear()
  hit_penalty_active = false
  fury = 0.0
  session_key_acquired = -1
  session_crown_acquired = false
  session_boss_reward = 0
  session_gems = 0
  session_money_changed.emit(0)
