extends Node
## 무기 = 자동 비주얼 진행(구매/메뉴 없음). current_weapon_level은 GameManager가
## attack_power 스킬 레벨과 동기화(1:1)한다. 무기는 겉모습일 뿐, 데미지는 attack_power 스킬.
## (구 v1 구매 모델 — purchase/price/skill_requirement — 전부 제거됨)

signal weapon_changed(weapon_level: int)

const WEAPONS = [
  {"name": "나뭇가지", "texture": "res://resources/images/weapon/나뭇가지.png"},
  {"name": "녹슨 식칼", "texture": "res://resources/images/weapon/녹슨식칼.png"},
  {"name": "피자 커터", "texture": "res://resources/images/weapon/피자커터.png"},
  {"name": "전기 파리채", "texture": "res://resources/images/weapon/전기파리채.png"},
  {"name": "뜨거운 다리미", "texture": "res://resources/images/weapon/뜨거운다리미.png"},
  {"name": "매우 화난 고양이", "texture": "res://resources/images/weapon/매우화난고양이.png"},
  {"name": "체인소", "texture": "res://resources/images/weapon/체인소.png"},
  {"name": "마법 지팡이", "texture": "res://resources/images/weapon/마법지팡이.png"},
  {"name": "날개달린 선풍기", "texture": "res://resources/images/weapon/날개달린선풍기.png"},
  {"name": "위성 레이저 제초기", "texture": "res://resources/images/weapon/위성레이저제초기.png"},
]

var weapon_textures: Array[Texture2D] = []
var current_weapon_level: int = 0

func _ready() -> void:
  process_mode = Node.PROCESS_MODE_ALWAYS
  _load_weapon_textures()

func _load_weapon_textures() -> void:
  for weapon in WEAPONS:
    var texture = load(weapon.texture) as Texture2D
    weapon_textures.append(texture)

# 데미지 = attack_power 스킬(무기는 겉모습). 풀/거목 피해 계산에서 사용.
func get_weapon_damage() -> int:
  var level = GameManager.upgrade_levels.get("attack_power", 0)
  var sub = GameManager.upgrade_sub_levels.get("attack_power", 0)
  var total = 0
  var sub_max = 5
  for lv in range(1, level + 1):
    total += _attack_power_per_tick(lv) * sub_max
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

# 플레이어 무기 스프라이트(비주얼). current_weapon_level 범위 밖이면 마지막 무기로 클램프.
func get_weapon_texture() -> Texture2D:
  var idx = clampi(current_weapon_level, 0, weapon_textures.size() - 1)
  if idx >= 0 and idx < weapon_textures.size():
    return weapon_textures[idx]
  return null

func get_save_data() -> Dictionary:
  return {"weapon_level": current_weapon_level}

func load_save_data(data: Dictionary) -> void:
  current_weapon_level = data.get("weapon_level", 0)
  weapon_changed.emit(current_weapon_level)
