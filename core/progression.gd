extends RefCounted
## 진행 곡선 (결정적). 세션 레벨/게임 레벨 XP/해금·초월 비용. balance_sim.py 포팅.
## 순수 함수(정적). preload로 참조.
const Balance = preload("res://core/balance_data.gd")

# ── 세션 레벨(인런) XP 곡선 ──
static func slevel_cum(L: int) -> float:      # Lv 도달 누적 XP (L=1→0, cap→TOTAL)
	return Balance.SLEVEL_TOTAL * pow(float(L - 1) / float(Balance.SESSION_LV_CAP - 1), Balance.SLEVEL_P)

static func slevel_need(lv: int) -> float:    # lv→lv+1 필요 XP (캡 초과=마지막 증분 절반, 만개룬)
	var last := slevel_cum(Balance.SESSION_LV_CAP) - slevel_cum(Balance.SESSION_LV_CAP - 1)
	if lv >= Balance.SESSION_LV_CAP:
		return last * 0.5
	return slevel_cum(lv + 1) - slevel_cum(lv)

static func session_level(xp: float, lv_cap := -1) -> int:  # 누적 XP → 도달 세션 레벨
	var cap: int = lv_cap if lv_cap > 0 else Balance.SESSION_LV_CAP
	var lv := 1
	var acc := xp
	for l in range(1, cap):
		var need := slevel_need(l)
		if acc >= need:
			acc -= need
			lv += 1
		else:
			break
	return mini(lv, cap)

# ── 게임 레벨(계정 메타) XP 곡선 ──
static func goomok_xp(w: int, L: int) -> float:   # 거목 처치 XP = K × √(거목HP)
	return Balance.GLEVEL_GOOMOK_K * sqrt(_goomok_hp_at(w, L))

static func _goomok_hp_at(w: int, L: int) -> float:
	return Balance.GOOMOK_HP_BASE * float(Balance.GOOMOK_WORLD_SCALE[w]) * (1.0 + 0.4 * L)

static func glevel_threshold(total_xp: float, lv: int) -> float:
	return total_xp * pow(float(lv - 1) / float(Balance.GLEVEL_CAP - 1), Balance.GLEVEL_XP_CURVE_P)

static func glevel_from_xp(cum_xp: float, total_xp: float) -> int:
	var lv := 1
	for L in range(2, Balance.GLEVEL_CAP + 1):
		if cum_xp >= glevel_threshold(total_xp, L):
			lv = L
		else:
			break
	return lv

# ── 해금/초월 비용 ──
static func unlock_cost(w: int) -> int:
	return int(float(Balance.WORLD_UNLOCK_COST[w]) * Balance.COIN_COST_MULT)

static func trans_cost(w: int, L: int) -> int:
	var base: int = Balance.WORLD_UNLOCK_COST[mini(w + 2, 6)]
	return int(maxf(500.0, float(base)) * (1.0 + L) * Balance.COIN_COST_MULT)
