extends RefCounted
## 밸런스 데이터 상수 (SSOT). preload로 참조: const Balance = preload("res://core/balance_data.gd") balance_sim.py의 CONFIG/GRASS/WORLD/SEED 등을 포팅.
## 순수 데이터·상수만. Node/렌더 의존 0. 게임과 시뮬이 공유.
## ⚠️ 밸런스 원칙: 상한(cap/clamp) 금지 — 과성장은 수치 조정으로 해결(game-spec §9.3).

# ── 세션/전역 ──
const SESSION_TIME := 45.0            # 세션 길이(초, 세션시간 스킬 전)
const GOOMOK_HP_BASE := 900.0         # 월드1 거목 HP
const GOOMOK_KILL_FRACTION := 0.55    # (구 근사) 세션 중 거목전 시간 비율
const SPEND_FRAC := 0.6               # 매 세션 보유금 중 스킬 재투자 비율
const COIN_COST_MULT := 1.70          # 코인 비용 배수(스킬틱·해금·초월)

# ── 파워업(인런) ──
const PU_SEEDS := 10                  # 코인배율 = 랜덤 드래프트 이 횟수 평균
const POWERUP_GOOMOK_MULT := 1.5      # 거목전 인런 파워업+슬롯 DPS 기여

# ── 룬(키스톤) 실효값 ──
const RUNE_VAL := {                   # 배율형 룬
	"onslaught": 0.15,   # 맹공: 파밍 공격력
	"avarice": 0.15,     # 축재: 코인
	"woodcutter": 0.30,  # 벌목꾼: 거목 DPS
	"sowing": 0.40,      # 파종: 씨앗 수집
}
const WINDFURY_MAX := 0.15            # 질풍: 실효 최대 공속(치명 램프)
const WINDFURY_CRIT_REF := 0.5        # 이 치명확률에서 최대치

# ── 맵/밀도 ──
const CHUNK := 400.0
const CHUNK_AREA := CHUNK * CHUNK
const GRID_SIDE := 15                 # 청크당 15x15=225셀 (밀도 상한)
const DENSITY_COST_MULT := 1.0

# ── 풀 티어: [HP, 코인값, 재생초] ──
const GRASS := [
	[4, 1, 22.0],      # 새싹
	[18, 5, 23.0],     # 잔디
	[38, 30, 24.0],    # 여린풀
	[75, 80, 25.0],    # 강한풀
	[130, 200, 26.0],  # 초강풀
]
const GOLD := [80, 100, 25.0]         # 황금풀

# ── 월드 배율/비용 ──
const WORLD_HP_MULT := [1.0, 1.3, 1.69, 2.2, 2.86, 3.71, 4.83]
const WORLD_REWARD_MULT := [1.0, 1.3, 1.69, 2.2, 2.86, 3.71, 4.83]
const WORLD_UNLOCK_COST := [0, 24000, 60000, 105000, 180000, 420000, 840000]
const GOOMOK_WORLD_SCALE := [1.0, 3.5, 9.0, 15.0, 16.0, 33.0, 36.0]  # 거목 HP 전용 스케일

# ── 씨앗/정예 ──
const SEED_NEED := [3, 8, 12, 17, 21, 26, 30]  # 월드1~7 거목 소환 필요 씨앗(=정예 처치수)
const ELITE_HP_MULT := 2.0            # 정예 HP = 풀 평균 × 이 배수
const ELITE_DENSITY := 4.0e-6         # 정예 밀도(월드1 기준), 월드별 N비례 증가

# ── 세션 레벨(인런) XP 곡선 ──
const GRASS_XP := [1, 2, 3, 4, 5]     # 티어별 XP
const GOLD_XP := 6
const SESSION_LV_CAP := 10
const SLEVEL_TOTAL := 1300.0          # Lv10 도달 누적 XP
const SLEVEL_P := 2.7                 # 누적 곡선 지수

# ── 게임 레벨(계정 메타) ──
const GLEVEL_CAP := 15
const GLEVEL_XP_CURVE_P := 3.2
const GLEVEL_SESSION_XP := 5.0        # 세션 완료당
const GLEVEL_GOOMOK_K := 1.0          # 거목 XP = K × √(거목HP)

# ── 초월 ──
const MAX_TRANS := 3

# ── 월드 메타(이름/테마색) ──
const WORLD_NAMES := ["슬라임 늪", "들판", "기사의 성벽", "마법의 숲", "수정 호수", "고대 유적", "용의 봉우리"]
const WORLD_COLORS := [
	Color(0.13, 0.22, 0.15), Color(0.28, 0.22, 0.13), Color(0.20, 0.26, 0.30),
	Color(0.16, 0.13, 0.26), Color(0.13, 0.28, 0.30), Color(0.22, 0.24, 0.13),
	Color(0.26, 0.15, 0.13),
]

# ── 게임 레벨 총 XP(완주≈Lv15 목표) ──
const GLEVEL_TOTAL_XP := 4600.0

# ── 보석 게이트: 스킬 상위 티어(유저레벨) 해금 비용(보석 수) — balance_sim GEM_LOCK ──
const GEM_LOCK := {
	"attack_power": {4: 1, 6: 2, 8: 3}, "attack_speed": {4: 1, 5: 2, 6: 3}, "attack_range": {6: 1},
	"crit_chance": {4: 1}, "goomok_dmg": {5: 1}, "crit_damage": {5: 1},
	"grass_density": {5: 1, 7: 2}, "grass_quality": {5: 1, 7: 2}, "attack_count": {3: 1, 4: 2, 5: 3},
	"golden_chance": {5: 1}, "move_speed": {5: 1}, "session_time": {3: 1, 5: 2},
}

# ── 정예 밀도(월드별) ──
static func elite_density(world: int) -> float:
	return ELITE_DENSITY * (float(SEED_NEED[world]) / float(SEED_NEED[0]))
