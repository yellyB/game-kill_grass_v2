extends Node

signal weapon_changed(weapon_level: int)

# Preload weapon textures
var weapon_textures: Array[Texture2D] = []

const WEAPONS = [
  {"name": "나뭇가지", "price": 0, "max_targets": 1, "texture": "res://resources/images/weapon/나뭇가지.png"},
  {"name": "녹슨 식칼", "price": 90, "max_targets": 5, "texture": "res://resources/images/weapon/녹슨식칼.png"},
  {"name": "피자 커터", "price": 450, "max_targets": 7, "texture": "res://resources/images/weapon/피자커터.png"},
  {"name": "전기 파리채", "price": 1200, "max_targets": 9, "texture": "res://resources/images/weapon/전기파리채.png"},
  {"name": "뜨거운 다리미", "price": 2600, "max_targets": 12, "texture": "res://resources/images/weapon/뜨거운다리미.png"},
  {"name": "매우 화난 고양이", "price": 6000, "max_targets": 15, "texture": "res://resources/images/weapon/매우화난고양이.png"},
  {"name": "체인소", "price": 13000, "max_targets": 18, "texture": "res://resources/images/weapon/체인소.png"},
  {"name": "마법 지팡이", "price": 29000, "max_targets": 22, "texture": "res://resources/images/weapon/마법지팡이.png"},
  {"name": "날개달린 선풍기", "price": 60000, "max_targets": 26, "texture": "res://resources/images/weapon/날개달린선풍기.png"},
  {"name": "위성 레이저 제초기", "price": 120000, "max_targets": 30, "texture": "res://resources/images/weapon/위성레이저제초기.png"},
]

var current_weapon_level: int = 0

func _ready() -> void:
  process_mode = Node.PROCESS_MODE_ALWAYS
  _load_weapon_textures()

func _load_weapon_textures() -> void:
  for weapon in WEAPONS:
    var texture = load(weapon.texture) as Texture2D
    weapon_textures.append(texture)

func get_current_weapon() -> Dictionary:
  return WEAPONS[current_weapon_level]

func get_weapon(level: int) -> Dictionary:
  if level >= 0 and level < WEAPONS.size():
    return WEAPONS[level]
  return WEAPONS[0]

func get_next_weapon() -> Dictionary:
  if current_weapon_level + 1 < WEAPONS.size():
    return WEAPONS[current_weapon_level + 1]
  return {}

func get_next_weapon_price() -> int:
  var next = get_next_weapon()
  if next.is_empty():
    return -1  # Max level
  return next.price

func can_upgrade() -> bool:
  var price = get_next_weapon_price()
  if price < 0:
    return false
  if not has_enough_skill_points():
    return false
  return GameManager.money >= price

func has_enough_skill_points() -> bool:
  var next_level = current_weapon_level + 1
  if next_level >= WEAPONS.size():
    return true
  var required = GameManager.get_weapon_skill_requirement(next_level)
  return GameManager.get_total_skill_level() >= required

func get_next_weapon_skill_requirement() -> int:
  var next_level = current_weapon_level + 1
  if next_level >= WEAPONS.size():
    return 0
  return GameManager.get_weapon_skill_requirement(next_level)

func purchase_next_weapon() -> bool:
  if not can_upgrade():
    return false

  var price = get_next_weapon_price()
  GameManager.money -= price
  GameManager.money_changed.emit(GameManager.money)

  current_weapon_level += 1
  weapon_changed.emit(current_weapon_level)
  return true

func get_weapon_damage() -> int:
  var level = GameManager.upgrade_levels.get("attack_power", 0)
  var sub = GameManager.upgrade_sub_levels.get("attack_power", 0)
  # 레벨별 틱당 증가분: Lv.1~3 +1, Lv.4~5 +2, Lv.6~7 +3, Lv.8~9 +4
  var total = 0
  var sub_max = 5
  for lv in range(1, level + 1):
    var per_tick = _attack_power_per_tick(lv)
    total += per_tick * sub_max
  # 현재 레벨 진행 중인 틱
  total += _attack_power_per_tick(level + 1) * sub
  return 1 + total

static func _attack_power_per_tick(user_level: int) -> int:
  if user_level <= 3:
    return 1
  if user_level <= 5:
    return 2
  if user_level <= 7:
    return 3
  return 4

func get_weapon_max_targets() -> int:
  return get_current_weapon().max_targets

func get_weapon_texture() -> Texture2D:
  if current_weapon_level < weapon_textures.size():
    return weapon_textures[current_weapon_level]
  return null

func is_max_level() -> bool:
  return current_weapon_level >= WEAPONS.size() - 1

func get_save_data() -> Dictionary:
  return {
    "weapon_level": current_weapon_level
  }

func load_save_data(data: Dictionary) -> void:
  current_weapon_level = data.get("weapon_level", 0)
  weapon_changed.emit(current_weapon_level)
