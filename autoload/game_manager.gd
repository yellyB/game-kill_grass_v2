extends Node
## GameManager (v2 린 버전) — 상태 보유 + 밸런스는 core/에 위임(SSOT).
## M0 범위: 돈·스킬틱·설정·세이브 + 필드가 쓰는 밸런스 getter. 몬스터/분노/파워업/보석/초월은 M2에서 확장.
const Skills = preload("res://core/skills.gd")
const Economy = preload("res://core/economy.gd")
const Balance = preload("res://core/balance_data.gd")

signal money_changed(money: int)
signal session_money_changed(session_money: int)
signal upgrade_purchased(skill: String)

# ── 영구 상태 ──
var money: int = 0
var upgrade_levels: Dictionary = {}   # 스킬명 → 누적 틱
var selected_world: int = 0
var unlocked_worlds: Array = [0]

# ── 세션(인런) 상태 ──
var session_money: int = 0

# ── 설정 ──
var bgm_enabled: bool = true
var sfx_enabled: bool = true
var vibration_enabled: bool = true
var locale: String = ""

# ── 공용 SFX 플레이어(root 부착, queue_free 후에도 재생 보장) ──
var _sfx_player: AudioStreamPlayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sk in Skills.COSTS:
		if not upgrade_levels.has(sk):
			upgrade_levels[sk] = 0

# ── 스킬 틱 ──
func ticks(sk: String) -> int:
	return int(upgrade_levels.get(sk, 0))

func _st() -> Dictionary:
	return upgrade_levels

# ── 밸런스 getter (core/ 위임) ──
func get_attack_range() -> float: return Skills.attack_range(ticks("attack_range"))
func get_attack_interval() -> float: return Skills.attack_speed(ticks("attack_speed"))
func get_attack_count() -> int: return Skills.attack_count(ticks("attack_count"))
func get_attack_power() -> int: return Skills.attack_power(ticks("attack_power"))
func get_eff_damage() -> float: return Economy.eff_damage(_st())
func get_crit_chance() -> float: return Skills.crit_chance(ticks("crit_chance"))
func get_crit_damage_mult() -> float: return Skills.crit_mult(ticks("crit_damage"))
func get_base_move_speed() -> float: return Skills.move(ticks("move_speed"))
func get_magnet_range() -> float: return Skills.magnet(ticks("magnet_range"))
func get_grass_density_value() -> int: return Skills.density(ticks("grass_density"))
func get_session_time() -> float: return Skills.session(ticks("session_time"))
func get_golden_chance() -> float: return Skills.golden(ticks("golden_chance"))
func get_quality_dist() -> Array: return Skills.quality_dist(ticks("grass_quality"))

# ── 돈 ──
func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)

func add_session_money(amount: int) -> void:
	session_money += amount
	session_money_changed.emit(session_money)

func spend_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	money_changed.emit(money)
	return true

# ── 스킬 구매(1틱) ──
func buy_skill_tick(sk: String) -> bool:
	var t := ticks(sk)
	if t >= Skills.max_ticks(sk):
		return false
	var cost := Skills.tick_cost(sk, t)
	if cost < 0 or money < cost:
		return false
	money -= cost
	upgrade_levels[sk] = t + 1
	money_changed.emit(money)
	upgrade_purchased.emit(sk)
	return true

# ── 세션 리셋/정산 ──
func reset_session_data() -> void:
	session_money = 0
	session_money_changed.emit(0)

func finalize_session() -> void:
	add_money(session_money)
	session_money = 0

# ── 숫자 포맷 ──
func format_number(n: int) -> String:
	var neg := n < 0
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if neg else "") + out

# ── SFX (공용, root 부착) ──
func play_sfx(stream: AudioStream) -> void:
	if not sfx_enabled or stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	get_tree().root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func vibrate(ms: int = 50) -> void:
	if vibration_enabled:
		Input.vibrate_handheld(ms)

# ── 세이브 ──
func get_save_data() -> Dictionary:
	return {
		"money": money,
		"upgrade_levels": upgrade_levels,
		"selected_world": selected_world,
		"unlocked_worlds": unlocked_worlds,
		"bgm_enabled": bgm_enabled,
		"sfx_enabled": sfx_enabled,
		"vibration_enabled": vibration_enabled,
		"locale": locale,
	}

func load_save_data(data: Dictionary) -> void:
	money = int(data.get("money", 0))
	var ul: Dictionary = data.get("upgrade_levels", {})
	for sk in Skills.COSTS:
		upgrade_levels[sk] = int(ul.get(sk, 0))
	selected_world = int(data.get("selected_world", 0))
	unlocked_worlds = data.get("unlocked_worlds", [0])
	bgm_enabled = bool(data.get("bgm_enabled", true))
	sfx_enabled = bool(data.get("sfx_enabled", true))
	vibration_enabled = bool(data.get("vibration_enabled", true))
	locale = str(data.get("locale", ""))
	money_changed.emit(money)
