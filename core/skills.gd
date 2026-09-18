extends RefCounted
## 스킬 수치 공식 + 비용 테이블. balance_sim.py의 s_* / COSTS 포팅.
## 순수 함수(정적). preload로 참조: const Skills = preload("res://core/skills.gd")
const Balance = preload("res://core/balance_data.gd")

# ── 스킬 효과 공식 (틱 t → 실효값) ──
static func attack_speed(t: int) -> float:    # 공격 간격 0.70→0.10초
	return maxf(0.1, 0.7 - t * 0.02)

static func attack_range(t: int) -> float:    # 60→340
	return 60.0 + t * 7.0

static func attack_count(t: int) -> int:      # 스윙당 대상 수 1→46
	var lv := t / 3
	var sub := t % 3
	var c := 1
	for l in range(lv):
		c += (l + 1) * 3
	if lv < 5:
		c += (lv + 1) * sub
	return c

static func density(t: int) -> int:           # 밀도 1→181
	if t <= 0:
		return 1
	var v := 0
	var r := t
	for lv in range(1, 9):
		var x: int = mini(r, 5)
		v += x * lv
		r -= x
		if r <= 0:
			break
	return 1 + v

static func attack_power(t: int) -> int:      # 데미지 1→
	var lv := t / 5
	var sub := t % 5
	var c := 1
	for l in range(1, lv + 1):
		c += _per(l) * 5
	c += _per(lv + 1) * sub
	return c

static func _per(l: int) -> int:
	if l <= 3: return 1
	elif l <= 5: return 2
	elif l <= 7: return 3
	else: return 4

static func crit_chance(t: int) -> float:     # 0→100% (자연 한계 100%)
	return minf(1.0, t * 0.05)

static func crit_mult(t: int) -> float:       # 1.2→3.7
	return 1.2 + t * 0.10

static func goomok_dmg(t: int) -> float:      # 거목피해 100→450%
	return 1.0 + t * 0.10

static func move(t: int) -> float:            # 300→750
	return 300.0 + t * 15.0

static func session(t: int) -> float:         # 45→65초
	return Balance.SESSION_TIME + t * (20.0 / 15.0)

static func golden(t: int) -> float:          # 0→5%
	return t * 0.005

static func magnet(t: int) -> float:          # 50→400 (수입엔 미반영)
	return 50.0 + t * (350.0 / 30.0)

static func quality_dist(t: int) -> Array:    # 등급 분포 [P0..P4]
	var lv := t / 8
	var sub := t % 8
	var p := [0.0, 0.0, 0.0, 0.0, 0.0]
	if lv >= 8:
		p[4] = 1.0
		return p
	var base: int = mini(lv / 2, 4)
	var nxt: float
	if lv % 2 == 0:
		nxt = sub / 8.0 * 0.5
	else:
		nxt = 0.5 + sub / 8.0 * 0.5
	p[base] += 1.0 - nxt
	p[mini(base + 1, 4)] += nxt
	return p

# ── 비용 테이블: 각 [ [base, per_sub]... ], sub_max ──
const COSTS := {
	"attack_power": [[[1,1],[15,4],[300,70],[4500,1125],[27000,4950],[81000,14850],[288000,52200],[900000,162000],[3060000,550800]], 5],
	"attack_speed": [[[15,2],[28,5],[200,28],[6500,980],[220000,33000],[800000,120000]], 5],
	"attack_range": [[[10,1],[25,2],[60,5],[800,60],[3000,230],[32000,2460],[140000,10780],[370000,28490]], 5],
	"attack_count": [[[20,5],[300,100],[8000,2000],[300000,75000],[2500000,625000]], 3],
	"grass_density": [[[1,1],[15,2],[85,12],[1000,120],[28000,3360],[196000,23520],[710000,85200],[2800000,336000]], 5],
	"grass_quality": [[[15,1],[20,1],[80,5],[480,38],[5000,400],[42000,3360],[275000,22000],[670000,53600]], 8],
	"crit_chance": [[[20,2],[150,12],[2400,320],[23000,2300]], 5],
	"crit_damage": [[[50,5],[1000,80],[6000,500],[60000,5000],[580000,46400]], 5],
	"goomok_dmg": [[[50,6],[120,10],[500,50],[12000,1200],[45000,4500],[100000,10000],[260000,26000]], 5],
	"move_speed": [[[30,5],[60,10],[300,40],[6000,900],[200000,30000]], 6],
	"session_time": [[[50,10],[200,40],[3000,500],[40000,6000],[400000,60000]], 3],
	"golden_chance": [[[20,2],[150,30],[1800,220],[21000,2500],[250000,30000]], 2],
}

const DPS_SKILLS := ["attack_power", "attack_speed", "crit_chance", "crit_damage", "goomok_dmg"]
const INCOME_SKILLS := ["grass_density", "grass_quality", "attack_count", "golden_chance", "attack_range", "move_speed", "session_time"]

static func max_ticks(sk: String) -> int:
	var entry: Array = COSTS[sk]
	return entry[0].size() * (entry[1] as int)

## 틱 t 구매 비용. 티어 초과면 -1. grass_density만 DENSITY_COST_MULT, 전체 COIN_COST_MULT 적용.
static func tick_cost(sk: String, t: int) -> int:
	var entry: Array = COSTS[sk]
	var tbl: Array = entry[0]
	var sm: int = entry[1]
	var lv := t / sm
	var sub := t % sm
	if lv >= tbl.size():
		return -1
	var b: int = tbl[lv][0]
	var p: int = tbl[lv][1]
	var c := float(b + sub * p)
	if sk == "grass_density":
		c = int(c * Balance.DENSITY_COST_MULT)
	return maxi(1, int(c * Balance.COIN_COST_MULT))
