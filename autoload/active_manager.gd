extends Node
## 액티브(1/2) 시스템 로직 — 매니저(SSOT). UI는 signal 구독 + 이 메서드 호출만.
## 자동 충전 → 만충 시 발동(효과는 signal로 위임). 강화(정수): 충전 단축 / 효과 크기.
## 슬롯 해금 = 게임 레벨. 강화 레벨은 영구(세이브), 충전은 세션 상태.

const Balance = preload("res://core/balance_data.gd")

# 영구: 액티브별 강화 레벨 {id: {"charge": int, "effect": int}}
var upgrades: Dictionary = {}
# 세션: 액티브별 충전 0.0~1.0
var charge: Dictionary = {}

signal charge_changed(id: String, ratio: float)  # 충전 진행(HUD 게이지)
signal active_ready(id: String)                  # 만충
signal active_fired(id: String)                  # 발동(효과 트리거)
signal active_upgraded(id: String)               # 강화 완료(UI 갱신)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for d in Balance.ACTIVE_DEFS:
		if not upgrades.has(d.id):
			upgrades[d.id] = {"charge": 0, "effect": 0}
		charge[d.id] = 0.0

func _process(delta: float) -> void:
	if not SessionManager.is_session_active or get_tree().paused:
		return
	for d in Balance.ACTIVE_DEFS:
		var id: String = d.id
		if not is_unlocked(id) or charge[id] >= 1.0:
			continue
		charge[id] = minf(1.0, charge[id] + delta / charge_time(id))
		charge_changed.emit(id, charge[id])
		if charge[id] >= 1.0:
			active_ready.emit(id)

# ── 정의/상태 ──
func _def(id: String) -> Dictionary:
	for d in Balance.ACTIVE_DEFS:
		if d.id == id:
			return d
	return {}

func active_ids() -> Array:
	var ids: Array = []
	for d in Balance.ACTIVE_DEFS:
		ids.append(d.id)
	return ids

func is_unlocked(id: String) -> bool:
	return GameManager.get_game_level() >= int(_def(id).get("unlock_lv", 1))

func charge_time(id: String) -> float:
	var d = _def(id)
	var lv: int = upgrades[id]["charge"]
	return maxf(Balance.ACTIVE_CHARGE_MIN, float(d.get("charge", 20.0)) * pow(Balance.ACTIVE_CHARGE_STEP, lv))

func effect_value(id: String) -> float:
	var d = _def(id)
	var lv: int = upgrades[id]["effect"]
	return float(d.get("effect_base", 1.0)) * (1.0 + Balance.ACTIVE_EFFECT_STEP * lv)

func get_charge(id: String) -> float:
	return charge.get(id, 0.0)

# ── 발동 (슬롯 index 0=1키, 1=2키) ──
func can_fire(id: String) -> bool:
	return is_unlocked(id) and charge.get(id, 0.0) >= 1.0

func fire(id: String) -> void:
	if not can_fire(id):
		return
	charge[id] = 0.0
	charge_changed.emit(id, 0.0)
	active_fired.emit(id)

func fire_slot(index: int) -> void:
	var ids = active_ids()
	if index >= 0 and index < ids.size():
		fire(ids[index])

func reset_session() -> void:
	for id in charge:
		charge[id] = 0.0

# ── 강화 (정수 소비) ──
func upgrade_cost(id: String, stat: String) -> int:
	var lv: int = upgrades[id][stat]
	if lv >= Balance.ACTIVE_MAX_UP_LV or lv >= Balance.ACTIVE_UPGRADE_COST.size():
		return -1  # 최대
	return int(Balance.ACTIVE_UPGRADE_COST[lv])

func can_upgrade(id: String, stat: String) -> bool:
	var c = upgrade_cost(id, stat)
	return c > 0 and GameManager.owned_tokens >= c

func upgrade(id: String, stat: String) -> bool:
	if not can_upgrade(id, stat):
		return false
	GameManager.owned_tokens -= upgrade_cost(id, stat)
	GameManager.token_changed.emit(GameManager.owned_tokens)
	upgrades[id][stat] += 1
	active_upgraded.emit(id)
	SaveManager.save_game()
	return true

# ── 세이브 ──
func get_save_data() -> Dictionary:
	return {"active_upgrades": upgrades.duplicate(true)}

func load_save_data(data: Dictionary) -> void:
	var saved = data.get("active_upgrades", {})
	for id in upgrades:
		if saved.has(id):
			upgrades[id]["charge"] = int(saved[id].get("charge", 0))
			upgrades[id]["effect"] = int(saved[id].get("effect", 0))
