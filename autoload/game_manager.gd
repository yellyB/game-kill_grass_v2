extends Node
## GameManager (v2 린 버전) — 상태 보유 + 밸런스는 core/에 위임(SSOT).
## M0 범위: 돈·스킬틱·설정·세이브 + 필드가 쓰는 밸런스 getter. 몬스터/분노/파워업/보석/초월은 M2에서 확장.
const Skills = preload("res://core/skills.gd")
const Economy = preload("res://core/economy.gd")
const Balance = preload("res://core/balance_data.gd")
const Progression = preload("res://core/progression.gd")

signal money_changed(money: int)
signal session_money_changed(session_money: int)
signal upgrade_purchased(skill: String)

# ── 영구 상태 ──
var money: int = 0
var upgrade_levels: Dictionary = {}   # 스킬명 → 누적 틱
var selected_world: int = 0
var unlocked_worlds: Array = [0]

# ── 메타(M2): 보석·초월·게임레벨 ──
var owned_gems: int = 0
var world_strength_levels: Dictionary = {}   # world(int) → 초월 레벨
var collected_gem_levels: Dictionary = {}     # "world:trans" → true (보석 1회 지급 추적)
var unlocked_gem_skills: Array = []            # "skill:userlevel" 해금됨
var game_level_xp: float = 0.0
var equipped_rune: String = ""                 # 장착 룬(게임레벨로 해금, 기본 없음)

signal gems_changed(gems: int)
signal game_level_changed(level: int)
signal world_cleared(world: int, trans: int)

# ── 세션(인런) 상태 ──
var session_money: int = 0
var session_gems: int = 0
var level_gauge: float = 0.0     # 레벨업 게이지(구 분노)
var session_level: int = 1
var session_lv_cap: int = 10     # 만개 룬 시 +2
signal level_up(new_level: int)

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
	if skill_tier_locked(sk, t):   # 보석으로 상위 티어 먼저 해금 필요
		return false
	var cost := Skills.tick_cost(sk, t)
	if cost < 0 or money < cost:
		return false
	money -= cost
	upgrade_levels[sk] = t + 1
	money_changed.emit(money)
	upgrade_purchased.emit(sk)
	return true

# ── 월드/초월 ──
func get_world_trans(world: int) -> int:
	return int(world_strength_levels.get(world, 0))

func get_world_hp_mult(world: int) -> float:
	return float(Balance.WORLD_HP_MULT[world]) * (1.0 + 0.4 * get_world_trans(world))

func get_world_reward_mult(world: int) -> float:
	return float(Balance.WORLD_REWARD_MULT[world]) * (1.0 + 0.5 * get_world_trans(world))

func is_world_unlocked(world: int) -> bool:
	return world in unlocked_worlds

func can_unlock_next() -> bool:
	var nw: int = int(unlocked_worlds.max()) + 1
	return nw < 7 and money >= Progression.unlock_cost(nw)

func unlock_next_world() -> bool:
	var nw: int = int(unlocked_worlds.max()) + 1
	if nw >= 7 or money < Progression.unlock_cost(nw):
		return false
	money -= Progression.unlock_cost(nw)
	unlocked_worlds.append(nw)
	money_changed.emit(money)
	return true

# ── 거목 클리어 = 3중 보상(월드클리어 + 게임레벨XP + [최초]보석) ──
func on_goomok_cleared(world: int) -> void:
	var tr := get_world_trans(world)
	# 게임 레벨 XP
	add_game_level_xp(Progression.goomok_xp(world, tr))
	# 최초 클리어 보석
	var key := "%d:%d" % [world, tr]
	if not collected_gem_levels.has(key):
		collected_gem_levels[key] = true
		var gem := maxi(1, tr)
		owned_gems += gem
		session_gems += gem
		gems_changed.emit(owned_gems)
	world_cleared.emit(world, tr)

func add_game_level_xp(xp: float) -> void:
	game_level_xp += xp
	game_level_changed.emit(get_game_level())

func get_game_level() -> int:
	return Progression.glevel_from_xp(game_level_xp, Balance.GLEVEL_TOTAL_XP)

# ── 초월 ──
func can_transcend(world: int) -> bool:
	if not is_world_unlocked(world):
		return false
	var L := get_world_trans(world)
	if L >= Balance.MAX_TRANS:
		return false
	return money >= Progression.trans_cost(world, L)

func do_transcend(world: int) -> bool:
	if not can_transcend(world):
		return false
	var L := get_world_trans(world)
	money -= Progression.trans_cost(world, L)
	world_strength_levels[world] = L + 1
	money_changed.emit(money)
	return true

# ── 보석 게이트(스킬 상위 티어 해금) ──
func skill_tier_locked(sk: String, ticks_now: int) -> bool:
	var sm: int = Skills.COSTS[sk][1]
	var ulv := ticks_now / sm + 1   # 다음 틱의 유저레벨(1-base)
	var cost: int = int(Balance.GEM_LOCK.get(sk, {}).get(ulv, 0))
	return cost > 0 and not ("%s:%d" % [sk, ulv] in unlocked_gem_skills)

func gem_unlock_cost(sk: String, ticks_now: int) -> int:
	var sm: int = Skills.COSTS[sk][1]
	var ulv := ticks_now / sm + 1
	return int(Balance.GEM_LOCK.get(sk, {}).get(ulv, 0))

func unlock_skill_tier(sk: String, ticks_now: int) -> bool:
	var sm: int = Skills.COSTS[sk][1]
	var ulv := ticks_now / sm + 1
	var cost: int = int(Balance.GEM_LOCK.get(sk, {}).get(ulv, 0))
	var key := "%s:%d" % [sk, ulv]
	if cost <= 0 or key in unlocked_gem_skills or owned_gems < cost:
		return false
	owned_gems -= cost
	unlocked_gem_skills.append(key)
	gems_changed.emit(owned_gems)
	return true

# ── 세션 레벨 게이지(구 분노) ──
func add_level_xp(xp: float) -> void:
	if session_level >= session_lv_cap:
		return
	level_gauge += xp
	while session_level < session_lv_cap and level_gauge >= Progression.slevel_need(session_level):
		level_gauge -= Progression.slevel_need(session_level)
		session_level += 1
		level_up.emit(session_level)

# ── 세션 리셋/정산 ──
func reset_session_data() -> void:
	session_money = 0
	session_gems = 0
	level_gauge = 0.0
	session_level = 1
	session_lv_cap = 10
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
		"owned_gems": owned_gems,
		"world_strength_levels": world_strength_levels,
		"collected_gem_levels": collected_gem_levels,
		"unlocked_gem_skills": unlocked_gem_skills,
		"game_level_xp": game_level_xp,
		"equipped_rune": equipped_rune,
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
	unlocked_worlds = []
	for w in data.get("unlocked_worlds", [0]):
		unlocked_worlds.append(int(w))
	if unlocked_worlds.is_empty():
		unlocked_worlds = [0]
	owned_gems = int(data.get("owned_gems", 0))
	var wsl: Dictionary = data.get("world_strength_levels", {})
	world_strength_levels = {}
	for k in wsl:
		world_strength_levels[int(k)] = int(wsl[k])
	collected_gem_levels = data.get("collected_gem_levels", {})
	unlocked_gem_skills = data.get("unlocked_gem_skills", [])
	game_level_xp = float(data.get("game_level_xp", 0.0))
	equipped_rune = str(data.get("equipped_rune", ""))
	bgm_enabled = bool(data.get("bgm_enabled", true))
	sfx_enabled = bool(data.get("sfx_enabled", true))
	vibration_enabled = bool(data.get("vibration_enabled", true))
	locale = str(data.get("locale", ""))
	money_changed.emit(money)
