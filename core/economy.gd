extends RefCounted
## 경제·전투 계산 (결정적). balance_sim.py의 eff_damage/_analytic_rate/goomok/seed 포팅.
## 순수 함수(정적). st = {스킬명: 틱}, active_rune = "" | "onslaught"|"avarice"|"woodcutter"|"sowing"|"windfury".
const Balance = preload("res://core/balance_data.gd")
const Skills = preload("res://core/skills.gd")

static func _tick(st: Dictionary, sk: String) -> int:
	return int(st.get(sk, 0))

# ── 룬 배율 헬퍼 ──
static func _rune(active_rune: String, name: String) -> float:
	if active_rune == name and Balance.RUNE_VAL.has(name):
		return 1.0 + float(Balance.RUNE_VAL[name])
	return 1.0

static func _rune_atkspd(st: Dictionary, active_rune: String) -> float:
	if active_rune != "windfury":
		return 0.0
	var cc := Skills.crit_chance(_tick(st, "crit_chance"))
	return Balance.WINDFURY_MAX * minf(1.0, cc / Balance.WINDFURY_CRIT_REF)

# ── 유효 데미지(크릿 기대) ──
static func eff_damage(st: Dictionary) -> float:
	var d := float(Skills.attack_power(_tick(st, "attack_power")))
	var cc := Skills.crit_chance(_tick(st, "crit_chance"))
	var cm := Skills.crit_mult(_tick(st, "crit_damage"))
	return d * (1.0 + cc * (cm - 1.0))

# ── 거목 DPS (벌목꾼=거목피해, 질풍=공속; 맹공은 거목엔 X) ──
static func goomok_dps(st: Dictionary, active_rune := "") -> float:
	var iv := Skills.attack_speed(_tick(st, "attack_speed"))
	var gdmg := Skills.goomok_dmg(_tick(st, "goomok_dmg"))
	return eff_damage(st) / iv * (1.0 + _rune_atkspd(st, active_rune)) * gdmg * _rune(active_rune, "woodcutter")

# ── 평균 풀 체력(월드/초월 배율) ──
static func avg_grass_hp(st: Dictionary, world: int, trans: int) -> float:
	var hp_mult := float(Balance.WORLD_HP_MULT[world]) * (1.0 + 0.4 * trans)
	var dist: Array = Skills.quality_dist(_tick(st, "grass_quality"))
	var gc := Skills.golden(_tick(st, "golden_chance"))
	var s := 0.0
	for k in range(5):
		s += float(dist[k]) * float(Balance.GRASS[k][0])
	return (gc * float(Balance.GOLD[0]) + (1.0 - gc) * s) * hp_mult

# ── 정상상태 수입 (파워업 미적용, 기본 스킬만) → {rate, avg_val, avg_xp, T} ──
static func analytic_rate(st: Dictionary, world: int, trans: int, active_rune := "") -> Dictionary:
	var hp_mult := float(Balance.WORLD_HP_MULT[world]) * (1.0 + 0.4 * trans)
	var rw_mult := float(Balance.WORLD_REWARD_MULT[world]) * (1.0 + 0.5 * trans)
	var R := Skills.attack_range(_tick(st, "attack_range"))
	var v := Skills.move(_tick(st, "move_speed"))
	var iv := Skills.attack_speed(_tick(st, "attack_speed")) / (1.0 + _rune_atkspd(st, active_rune))
	var cnt := Skills.attack_count(_tick(st, "attack_count"))
	var dmg := eff_damage(st) * _rune(active_rune, "onslaught")
	var dens: int = mini(Skills.density(_tick(st, "grass_density")), Balance.GRID_SIDE * Balance.GRID_SIDE)
	var D := float(dens) / Balance.CHUNK_AREA
	var dist: Array = Skills.quality_dist(_tick(st, "grass_quality"))
	var gc := Skills.golden(_tick(st, "golden_chance"))
	var T := Skills.session(_tick(st, "session_time"))
	var hp_s := 0.0
	var val_s := 0.0
	var xp_s := 0.0
	for k in range(5):
		hp_s += float(dist[k]) * float(Balance.GRASS[k][0])
		val_s += float(dist[k]) * float(Balance.GRASS[k][1])
		xp_s += float(dist[k]) * float(Balance.GRASS_XP[k])
	var avg_hp := (gc * float(Balance.GOLD[0]) + (1.0 - gc) * hp_s) * hp_mult
	var avg_val := (gc * float(Balance.GOLD[1]) + (1.0 - gc) * val_s) * rw_mult * _rune(active_rune, "avarice")
	var avg_xp := gc * float(Balance.GOLD_XP) + (1.0 - gc) * xp_s
	var encounter := 2.0 * R * v * D
	var capacity := cnt / (float(ceili(avg_hp / maxf(1e-9, dmg))) * iv)
	var rate := minf(encounter, capacity)
	return {"rate": rate, "avg_val": avg_val, "avg_xp": avg_xp, "T": T}

# ── 씨앗 수집(정예 처치) ──
static func seed_rate(st: Dictionary, world := 0, trans := 0, active_rune := "") -> float:
	var R := Skills.attack_range(_tick(st, "attack_range"))
	var v := Skills.move(_tick(st, "move_speed"))
	var iv := Skills.attack_speed(_tick(st, "attack_speed"))
	var dmg := eff_damage(st)
	var encounter := 2.0 * R * v * Balance.elite_density(world)
	var elite_hp := Balance.ELITE_HP_MULT * avg_grass_hp(st, world, trans)
	var kill_time := float(ceili(elite_hp / maxf(1e-9, dmg))) * iv
	if encounter <= 0.0:
		return 0.0
	var t_per_seed := 1.0 / encounter + kill_time
	return _rune(active_rune, "sowing") / t_per_seed

static func goomok_summon_time(st: Dictionary, world: int, trans := 0, active_rune := "") -> float:
	var r := seed_rate(st, world, trans, active_rune)
	if r > 0.0:
		return float(Balance.SEED_NEED[world]) / r
	return 1e9

static func goomok_hp_at(w: int, L: int) -> float:
	return Balance.GOOMOK_HP_BASE * float(Balance.GOOMOK_WORLD_SCALE[w]) * (1.0 + 0.4 * L)

## 거목 클리어 가능 여부. use_powerups=true면 인런 파워업+슬롯 DPS 기여 반영.
static func can_clear_goomok(st: Dictionary, goomok_hp: float, world := 0, trans := 0, active_rune := "", use_powerups := true) -> bool:
	var T := Skills.session(_tick(st, "session_time"))
	var window := T - goomok_summon_time(st, world, trans, active_rune)
	if window <= 0.0:
		return false
	var mult := Balance.POWERUP_GOOMOK_MULT if use_powerups else 1.0
	var dps := goomok_dps(st, active_rune) * mult
	return dps * window >= goomok_hp
