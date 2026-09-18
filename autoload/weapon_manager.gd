extends Node
## WeaponManager (v2 린) — 무기 비주얼 진행. 데미지는 attack_power 스킬(무기는 겉모습/마일스톤).
## 구매 = 코인 + 총 스킬레벨 게이트. 강화 패널 안에서 구매.
signal weapon_changed(level: int)

const WEAPONS := [
	{"name": "나뭇가지", "price": 0, "texture": "res://resources/images/weapon/나뭇가지.png"},
	{"name": "녹슨 식칼", "price": 90, "texture": "res://resources/images/weapon/녹슨식칼.png"},
	{"name": "피자 커터", "price": 450, "texture": "res://resources/images/weapon/피자커터.png"},
	{"name": "전기 파리채", "price": 1200, "texture": "res://resources/images/weapon/전기파리채.png"},
	{"name": "뜨거운 다리미", "price": 2600, "texture": "res://resources/images/weapon/뜨거운다리미.png"},
	{"name": "매우 화난 고양이", "price": 6000, "texture": "res://resources/images/weapon/매우화난고양이.png"},
	{"name": "체인소", "price": 13000, "texture": "res://resources/images/weapon/체인소.png"},
	{"name": "마법 지팡이", "price": 29000, "texture": "res://resources/images/weapon/마법지팡이.png"},
	{"name": "날개달린 선풍기", "price": 60000, "texture": "res://resources/images/weapon/날개달린선풍기.png"},
	{"name": "위성 레이저 제초기", "price": 120000, "texture": "res://resources/images/weapon/위성레이저제초기.png"},
]
const SKILL_REQ := [0, 0, 2, 4, 7, 11, 16, 21, 27, 34]

var current_weapon_level: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func get_current() -> Dictionary: return WEAPONS[current_weapon_level]
func get_texture(level: int = -1) -> Texture2D:
	var lv := current_weapon_level if level < 0 else level
	return load(WEAPONS[lv].texture) as Texture2D

func has_next() -> bool: return current_weapon_level + 1 < WEAPONS.size()
func next_price() -> int: return WEAPONS[current_weapon_level + 1].price if has_next() else -1
func next_skill_req() -> int: return SKILL_REQ[current_weapon_level + 1] if has_next() else 0

func can_buy() -> bool:
	if not has_next(): return false
	return GameManager.get_total_skill_level() >= next_skill_req() and GameManager.money >= next_price()

func buy_next() -> bool:
	if not can_buy(): return false
	GameManager.money -= next_price()
	GameManager.money_changed.emit(GameManager.money)
	current_weapon_level += 1
	weapon_changed.emit(current_weapon_level)
	return true

func get_save_data() -> Dictionary: return {"weapon_level": current_weapon_level}
func load_save_data(data: Dictionary) -> void:
	current_weapon_level = int(data.get("weapon_level", 0))
	weapon_changed.emit(current_weapon_level)
