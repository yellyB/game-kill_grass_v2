#!/usr/bin/env python3
"""
풀 좀 베겠습니다 v2 — 밸런싱 시뮬레이터 (틱 기반, 실제 플레이 근접)
================================================================
목적: 게임을 실행하지 않고 수치로 밸런스를 검증/튜닝. 나중에도 쉽게 재실행.

■ 실행법
    python3 sim/balance_sim.py session      # 단일 세션 수입(스킬 상태별)
    python3 sim/balance_sim.py pacing        # 월드1 페이싱(돈/거목 세션)
    python3 sim/balance_sim.py progression   # 월드1~7 완주 + 게임레벨
    python3 sim/balance_sim.py powerups      # 파워업 인런 모델(코인/거목 배율)
    python3 sim/balance_sim.py goomok        # 거목/씨앗 진단(등장 시점·격파 소요)
    python3 sim/balance_sim.py runes         # 룬(키스톤) 효과 축별 비교
    python3 sim/balance_sim.py glevel        # 게임 레벨 XP 곡선(레벨별 도달 세션·진행률)
    python3 sim/balance_sim.py full          # 풀 이코노미(월드+초월+보석+스킬) = 기본
    python3 sim/balance_sim.py               # = full

■ 모델 (실제 플레이 흉내)
    - 세션 수입 = **틱 시뮬**: 플레이어가 이동하며 범위 내 풀을 실제로 스윙 공격.
      풀이 밀도·이동에 따라 범위로 유입되고, 못 베면 뒤로 빠져나감(놓침) → 인카운터 vs DPS 자연 발생.
    - 거목 = 단일 보스라 DPS×시간 해석 판정(정확). 크릿·거목피해 반영.
    - 재생·황금풀·세션시간·월드 배율 반영.

■ 수치 출처: 원본(game-kill_grass @4cd58ca) 포팅 + v2 재조정.
  모든 튜닝값은 아래 CONFIG / SKILLS / COSTS 한곳에 모음 (여기만 고치면 됨).

■ 밸런스 원칙 (필수): **상한(cap/clamp)을 절대 넣지 않는다.**
  어떤 값이 과도하게 커져 상한이 필요해 보이면, 그 원인이 되는 수치를 더 낮게 조정해
  상한이 필요 없게 만든다. (예: 파워업 코인배율이 튀면 파워업 개별 효과나 코인비용을
  조정하지, min()으로 잘라내지 않는다.) 상한은 문제를 가릴 뿐 밸런스가 아니다.
  ※ 예외: 게임 진행 규칙(세션 레벨/초월/게임 레벨 상한)과 자연 한계(크릿 100% 등)는 상한이 아니라 설계 규칙.
"""
import argparse, math, zlib

# ═══════════════════════════════ CONFIG (튜닝은 여기) ═══════════════════════════════
SESSION_TIME   = 45.0     # 세션 길이(초, 세션시간 스킬 전)
TICK_DT        = 0.05     # 시뮬 틱(초)
GOOMOK_HP_BASE = 900.0    # 월드1 거목 HP (크릿·거목피해+인런 파워업 DPS 반영 → 클리어 ~7세션)
GOOMOK_KILL_FRACTION = 0.55  # 세션 중 거목 전투에 쓰는 시간 비율
WORLD2_COST    = 100      # (표시용) 월드2 해금 비용
POWERUP_COIN_MAX_BONUS = 0.4  # (구 근사, USE_POWERUPS=False일 때만) 세션Lv 10에서 +40%
SPEND_FRAC = 0.6              # 매 세션 보유금의 이 비율은 스킬 재투자, 나머지는 진행(해금/초월) 저축

# ── 파워업(인런) 모델 ──
USE_POWERUPS   = True    # True=33종 파워업 드래프트+스탯 수정자 모델, False=구 coin_mult 근사
PU_SEEDS       = 10      # 파워업 코인 배율 = 이 횟수만큼 랜덤 드래프트 평균 (상한 없음 — 밸런스는 코인비용으로)
POWERUP_GOOMOK_MULT = 1.5  # 거목전 인런 파워업+슬롯아이템의 DPS 기여(결정적 근사, 튜닝값)
COIN_COST_MULT = 2.0     # 코인 비용 배수(스킬틱·해금·초월). 파워업(상한없음)+씨앗게이트 반영 → 월드해금 39/초월 52/스킬맥스 56 (목표 40/54/58)

# ── 룬(키스톤) 모델 ── 세션당 1개 장착, 게임레벨로 점진 해금. 조건부는 실효(평균)값으로 근사.
#  맹공=파밍 공격력↑(거목엔 X), 축재=코인↑(플랫), 벌목꾼=거목DPS↑(파밍 X),
#  파종=씨앗수집↑(거목 조기등장), 만개=획득XP↑(파워업 더↑, 플랫)
ACTIVE_RUNE = None   # 시뮬 장착 룬: None/onslaught/avarice/woodcutter/sowing/bloom/windfury
# 맹공=파밍 공격력 / 축재=코인 / 벌목꾼=거목DPS / 파종=씨앗수집 (단순 배율)
# 만개=레벨업 XP+25% & 세션 최대레벨+2 (구조적 — _apply_pu/_phased_session에서 직접 처리, RUNE_VAL 미사용)
# 질풍(windfury)=치명 적중마다 공속 누적 → 실효 공속보너스 = 치명확률 비례(아래 _rune_atkspd)
RUNE_VAL = {"onslaught":0.15, "avarice":0.15, "woodcutter":0.30, "sowing":0.40}
WINDFURY_MAX = 0.15       # 질풍 실효 최대 공속 보너스(치명 램프 유지 시) — 다른 룬 수준(~+15%)
WINDFURY_CRIT_REF = 0.5   # 이 치명확률에서 최대치 도달(그 이하는 비례 축소)
def _rune(name): return (1.0+RUNE_VAL[name]) if ACTIVE_RUNE==name else 1.0
def _rune_atkspd(st):   # 질풍: 실효 공속 보너스(치명확률 비례 — 크리 자주 나야 램프 유지)
    if ACTIVE_RUNE!="windfury": return 0.0
    return WINDFURY_MAX*min(1.0, s_crit_chance(st.get("crit_chance",0))/WINDFURY_CRIT_REF)

CHUNK          = 400.0
CHUNK_AREA     = CHUNK*CHUNK
GRID_SIDE      = 15       # 청크당 15x15=225 셀 (밀도 상한)
DENSITY_COST_MULT = 1.0   # 밀도 비용 배수 (1=원본. 올리면 페이싱 깨짐 — 시뮬 결론)

# 풀 티어: (HP, 코인값, 재생초)
GRASS = [
    (4,   1,   22.0),  # 새싹
    (18,  5,   23.0),  # 잔디
    (38,  30,  24.0),  # 여린풀
    (75,  80,  25.0),  # 강한풀
    (130, 200, 26.0),  # 초강풀
]
GOLD = (80, 100, 25.0)   # 황금풀

# 월드 배율 (풀 HP·보상), 해금 비용 (원본)
WORLD_HP_MULT     = [1.0, 1.3, 1.69, 2.2, 2.86, 3.71, 4.83]
WORLD_REWARD_MULT = [1.0, 1.3, 1.69, 2.2, 2.86, 3.71, 4.83]
WORLD_UNLOCK_COST = [0, 24000, 60000, 105000, 180000, 420000, 840000]  # 시뮬 정렬: 월드해금~40/초월~54/스킬맥스~58
# 거목 HP = BASE × 이 배율. 플레이어 DPS가 월드 배율(4.83×)보다 훨씬 빨리 커서(≈80×)
# 풀 HP 배율을 그대로 쓰면 후반 거목이 시시함 → 거목 전용 가파른 스케일(격파 소요 ~10초 목표로 역산)
GOOMOK_WORLD_SCALE = [1.0, 3.5, 9.0, 15.0, 16.0, 33.0, 36.0]  # 격파소요 월드1~22초/월드2~7~10초 목표 역산(시뮬 수렴)

# 거목 소환 씨앗: 월드별 필요 개수(3→30, 선형 보간) + 필드 수집 모델
SEED_NEED = [3, 8, 12, 17, 21, 26, 30]   # 월드1~7 거목 소환 필요 씨앗 수 (사용자: 3→30)
SEED_DENSITY = 4.5e-6   # 필드 씨앗 밀도(개/area). 수집/초 = 2×자석범위×이동속도×밀도 (코인 자석 로직 재사용)
                        # N이 10배(3→30) 느는 걸 자석(8배)+이동(2.5배) 동반 성장으로 상쇄

# 세션 레벨(인런) XP 곡선: 벤 풀 티어 XP + 레벨업 필요치 (cap 10)
GRASS_XP        = [1, 2, 3, 4, 5]   # 티어별 XP
GOLD_XP         = 6
SESSION_LV_CAP  = 10
SESSION_LV_NEED = [2,4,6,8,10,12,14,16,18]  # Lv1→2 ... Lv9→10

# ═══════════════════════════════ 스킬 수치 (SKILLS) ═══════════════════════════════
# 재조정값(v2): 수집 400 / 이동 750 / 세션 65초 / 황금 5%. 나머지 원본.
def s_attack_speed(t): return max(0.1, 0.7 - t*0.02)      # 공격 간격 0.70→0.10
def s_attack_range(t): return 60.0 + t*7.0                # 60→340
def s_attack_count(t):
    lv=t//3; sub=t%3; c=1 + sum((l+1)*3 for l in range(lv))
    if lv<5: c += (lv+1)*sub
    return c                                              # 1→46
def s_density(t):
    if t<=0: return 1
    v=0; r=t
    for lv in range(1,9):
        x=min(r,5); v+=x*lv; r-=x
        if r<=0: break
    return 1+v                                            # 1→181
def s_attack_power(t):                                    # 데미지 1→~
    per=lambda l: 1 if l<=3 else 2 if l<=5 else 3 if l<=7 else 4
    lv=t//5; sub=t%5
    return 1 + sum(per(l)*5 for l in range(1,lv+1)) + per(lv+1)*sub
def s_crit_chance(t): return min(1.0, t*0.05)            # 0→100%
def s_crit_mult(t):   return 1.2 + t*0.10                # 1.2→3.7
def s_goomok_dmg(t):  return 1.0 + t*0.10                # 거목피해 100→450% (구 monster_damage)
def s_move(t):        return 300.0 + t*15.0              # 300→750 (재조정)
def s_session(t):     return SESSION_TIME + t*(20.0/15.0)# 45→65 (재조정)
def s_golden(t):      return t*0.005                     # 0→5% (재조정)
def s_magnet(t):      return 50.0 + t*(350.0/30.0)       # 50→400 (재조정, income엔 미반영)
def s_quality_dist(t):                                   # 등급 분포 [P0..P4]
    lv=t//8; sub=t%8; p=[0.0]*5
    if lv>=8: p[4]=1.0; return p
    base=min(lv//2,4); nxt=(sub/8*0.5) if lv%2==0 else (0.5+sub/8*0.5)
    p[base]+=1-nxt; p[min(base+1,4)]+=nxt; return p

# ═══════════════════════════════ 스킬 비용 (COSTS) ═══════════════════════════════
# [level] = (base, per_sub), 그리고 sub_max. 원본 포팅 + 재조정 스킬 1차값.
COSTS = {
 "attack_power":([(1,1),(15,4),(300,70),(4500,1125),(27000,4950),(81000,14850),(288000,52200),(900000,162000),(3060000,550800)],5),
 "attack_speed":([(15,2),(28,5),(200,28),(6500,980),(220000,33000),(800000,120000)],5),
 "attack_range":([(10,1),(25,2),(60,5),(800,60),(3000,230),(32000,2460),(140000,10780),(370000,28490)],5),
 "attack_count":([(20,5),(300,100),(8000,2000),(300000,75000),(2500000,625000)],3),
 "grass_density":([(1,1),(15,2),(85,12),(1000,120),(28000,3360),(196000,23520),(710000,85200),(2800000,336000)],5),
 "grass_quality":([(15,1),(20,1),(80,5),(480,38),(5000,400),(42000,3360),(275000,22000),(670000,53600)],8),
 "crit_chance":([(20,2),(150,12),(2400,320),(23000,2300)],5),
 "crit_damage":([(50,5),(1000,80),(6000,500),(60000,5000),(580000,46400)],5),
 "goomok_dmg":([(50,6),(120,10),(500,50),(12000,1200),(45000,4500),(100000,10000),(260000,26000)],5),
 "move_speed":([(30,5),(60,10),(300,40),(6000,900),(200000,30000)],6),
 "session_time":([(50,10),(200,40),(3000,500),(40000,6000),(400000,60000)],3),
 "golden_chance":([(20,2),(150,30),(1800,220),(21000,2500),(250000,30000)],2),
}
MAXTICKS = {k:len(tbl)*sm for k,(tbl,sm) in COSTS.items()}
def tick_cost(sk,t):
    tbl,sm=COSTS[sk]; lv=t//sm; sub=t%sm
    if lv>=len(tbl): return None
    b,p=tbl[lv]; c=b+sub*p
    if sk=="grass_density": c=int(c*DENSITY_COST_MULT)
    return max(1,int(c*COIN_COST_MULT))

DPS_SKILLS    = ["attack_power","attack_speed","crit_chance","crit_damage","goomok_dmg"]
INCOME_SKILLS = ["grass_density","grass_quality","attack_count","golden_chance","attack_range","move_speed","session_time"]

# ═══════════════════════════════ 파생 스탯 ═══════════════════════════════
def eff_damage(st):
    d = s_attack_power(st.get("attack_power",0))
    cc = s_crit_chance(st.get("crit_chance",0)); cm = s_crit_mult(st.get("crit_damage",0))
    return d * (1 + cc*(cm-1))    # 크릿 기대 데미지
def goomok_dps(st):   # 거목 DPS (벌목꾼=거목피해, 질풍=공속. 맹공은 거목엔 X)
    return eff_damage(st)/s_attack_speed(st.get("attack_speed",0))*(1+_rune_atkspd(st)) * s_goomok_dmg(st.get("goomok_dmg",0)) * _rune("woodcutter")
def seed_rate(st):   # 초당 씨앗 수집 = 2×자석범위×이동속도×밀도 (파종 룬 반영)
    v=s_move(st.get("move_speed",0))
    magnet_eff=50.0+max(0.0,(v-300.0))/450.0*350.0  # 자석 50→400, 이동과 동반 성장(탐험 스킬 프록시)
    return 2*magnet_eff*v*SEED_DENSITY*_rune("sowing")
def goomok_summon_time(st, world):   # 씨앗 N개 모을 때까지(초) = 거목 등장 시점
    r=seed_rate(st); return SEED_NEED[world]/r if r>0 else 1e9
def can_clear_goomok(st, goomok_hp, world=0):
    T = s_session(st.get("session_time",0))
    window = T - goomok_summon_time(st, world)   # 거목 등장 후 남는 전투 시간
    if window <= 0: return False
    dps = goomok_dps(st) * (POWERUP_GOOMOK_MULT if USE_POWERUPS else 1.0)  # 인런 파워업+슬롯아이템 기여
    return dps*window >= goomok_hp

# ═══════════════════════════════ 세션 수입 (정상상태 해석 모델) ═══════════════════════════════
def _analytic_rate(st, world, trans):
    """정상상태 처치율/평균값 (파워업 미적용, 기본 스킬만). 반환 (rate, avg_val, avg_xp, T)."""
    hp_mult = WORLD_HP_MULT[world]*(1+0.4*trans); rw_mult = WORLD_REWARD_MULT[world]*(1+0.5*trans)
    R=s_attack_range(st.get("attack_range",0)); v=s_move(st.get("move_speed",0))
    iv=s_attack_speed(st.get("attack_speed",0))/(1+_rune_atkspd(st)); cnt=s_attack_count(st.get("attack_count",0))
    dmg=eff_damage(st)*_rune("onslaught"); dens=min(s_density(st.get("grass_density",0)),GRID_SIDE*GRID_SIDE); D=dens/CHUNK_AREA
    dist=s_quality_dist(st.get("grass_quality",0)); gc=s_golden(st.get("golden_chance",0)); T=s_session(st.get("session_time",0))
    avg_hp =(gc*GOLD[0]+(1-gc)*sum(dist[k]*GRASS[k][0] for k in range(5)))*hp_mult
    avg_val=(gc*GOLD[1]+(1-gc)*sum(dist[k]*GRASS[k][1] for k in range(5)))*rw_mult*_rune("avarice")
    avg_xp = gc*GOLD_XP+(1-gc)*sum(dist[k]*GRASS_XP[k] for k in range(5))
    rate=min(2*R*v*D, cnt/(math.ceil(avg_hp/max(1e-9,dmg))*iv))
    return rate, avg_val, avg_xp, T

def simulate_session(st, world=0, trans=0, want_xp=False):
    """세션 수확 수입. 기본 정상상태 수입 × 인런 파워업 코인 배율(파워업 드래프트 모델).
    - trans(초월): 풀 HP ×(1+0.4L), 보상 ×(1+0.5L).
    반환: (코인, 처치수[, 세션XP])."""
    rate, avg_val, avg_xp, T = _analytic_rate(st, world, trans)
    kills = rate*T; xp = kills*avg_xp
    if USE_POWERUPS:
        coin_mult, _ = powerup_factors(st, world, trans)
    else:
        coin_mult = 1.0 + POWERUP_COIN_MAX_BONUS*(session_level(xp)/SESSION_LV_CAP)
    coins = kills*avg_val*coin_mult
    if want_xp: return coins, kills, xp
    return coins, kills

def session_level(xp):
    lv=1; acc=xp
    for need in SESSION_LV_NEED:
        if acc>=need: acc-=need; lv+=1
        else: break
    return min(lv, SESSION_LV_CAP)

# ═══════════════════════════════ 파워업 (인런 드래프트 + 스탯 수정자) ═══════════════════════════════
import random as _random
# powerups.md §4의 33종 파워업(지속). type: (weight, max_stacks, effect)
#  effect 키: dmg/iv/R/v/val/D = 스택당 승수 | vadd/cc/cm/gc = 스택당 가산 | xp/cap = 승수
#            hp = 유효체력 승수(1회) | overkill/reaper/snowball/compound/level_burst = 플래그
#            goomok = 거목 DPS 승수(수입 무효) | income_dud = 수입 영향 없음(=거목/메타 전용)
#            reroll/extra_choice/luck = 드래프트 개선(수입 marginal엔 미반영 → 보수적)
PU = {
 "sharp_blade":     (20,5,{"dmg":1.15}),
 "pu_attack_speed": (20,5,{"iv":1/1.12}),
 "pu_attack_range": (20,5,{"R":1.15}),
 "timber":          (10,5,{"goomok":1.30,"income_dud":True}),
 "chain_reaction":  ( 4,1,{"cap":1.30}),
 "pu_crit_chance":  (10,5,{"cc":0.08}),
 "pu_crit_damage":  (10,5,{"cm":0.40}),
 "critical_reaper": (10,1,{"reaper":True}),
 "execute":         ( 4,1,{"hp":0.80}),
 "coin_value":      (20,5,{"val":1.15}),
 "pu_magnet_range": (20,5,{"income_dud":True}),
 "regrow_speed":    (20,5,{"D":1.10}),
 "coin_leech":      (20,5,{"vadd":1.0}),
 "combo_harvest":   ( 4,1,{"val":1.25}),
 "interest":        (10,5,{"val":1.10}),
 "overkill":        ( 4,1,{"overkill":True}),
 "pu_golden_chance":(10,5,{"gc":0.02}),
 "golden_luck":     (10,1,{"income_dud":True}),
 "midas":           ( 4,1,{"val":1.05}),
 "pu_move_speed":   (20,5,{"v":1.12}),
 "momentum":        (10,1,{"dmg":1.25}),
 "stun_resist":     (20,5,{"income_dud":True}),
 "thorns":          ( 4,1,{"income_dud":True}),
 "finale":          ( 4,1,{"val":1.08,"cap":1.03}),
 "cursed_scythe":   ( 4,1,{"val":1.50,"xp":0.60}),
 "level_burst":     (10,1,{"level_burst":True}),
 "seed_blessing":   (10,1,{"val":1.05,"cap":1.03}),
 "xp_gain":         (20,5,{"xp":1.20}),
 "reroll":          (10,3,{"reroll":1,"income_dud":True}),
 "extra_choice":    ( 4,1,{"extra_choice":1,"income_dud":True}),
 "luck":            ( 4,1,{"luck":1,"income_dud":True}),
 "snowball":        ( 4,1,{"snowball":0.02}),
 "compound":        ( 1,1,{"compound":0.03}),
}

def _apply_pu(st, pu, kills, level, world, trans, dist):
    """현재 파워업 보유(pu)로 수정된 (처치율, 처치당 코인, 처치당 XP)."""
    hp_mult=WORLD_HP_MULT[world]*(1+0.4*trans); rw_mult=WORLD_REWARD_MULT[world]*(1+0.5*trans)
    dmg_m=iv_m=R_m=v_m=val_m=D_m=hp_m=xp_m=cap_m=1.0; vadd=cc_add=cm_add=gc_add=0.0
    allm=1.0; overkill=reaper=False
    for ty,n in pu.items():
        e=PU[ty][2]
        if "dmg" in e: dmg_m*=e["dmg"]**n
        if "iv"  in e: iv_m *=e["iv"]**n
        if "R"   in e: R_m  *=e["R"]**n
        if "v"   in e: v_m  *=e["v"]**n
        if "val" in e: val_m*=e["val"]**n
        if "D"   in e: D_m  *=e["D"]**n
        if "cap" in e: cap_m*=e["cap"]**n
        if "xp"  in e: xp_m *=e["xp"]**n
        if "vadd"in e: vadd +=e["vadd"]*n
        if "cc"  in e: cc_add+=e["cc"]*n
        if "cm"  in e: cm_add+=e["cm"]*n
        if "gc"  in e: gc_add+=e["gc"]*n
        if "hp"  in e: hp_m *=e["hp"]
        if "overkill" in e: overkill=True
        if "reaper"   in e: reaper=True
        if "snowball" in e: dmg_m*=(1+e["snowball"]*(kills/100.0))
        if "compound" in e: allm*=(1+e["compound"]*(level-1))
    dmg_m*=allm; R_m*=allm; v_m*=allm; val_m*=allm
    base_dmg=s_attack_power(st.get("attack_power",0))*dmg_m*_rune("onslaught")
    cc=min(1.0,s_crit_chance(st.get("crit_chance",0))+cc_add); cm=s_crit_mult(st.get("crit_damage",0))+cm_add
    dmg=base_dmg*(1+cc*(cm-1))
    R=s_attack_range(st.get("attack_range",0))*R_m; v=s_move(st.get("move_speed",0))*v_m
    iv=s_attack_speed(st.get("attack_speed",0))*iv_m/(1+_rune_atkspd(st)); cnt=s_attack_count(st.get("attack_count",0))
    dens=min(s_density(st.get("grass_density",0)),GRID_SIDE*GRID_SIDE); D=dens/CHUNK_AREA*D_m
    gc=min(1.0,s_golden(st.get("golden_chance",0))+gc_add)
    avg_hp =(gc*GOLD[0]+(1-gc)*sum(dist[k]*GRASS[k][0] for k in range(5)))*hp_mult*hp_m
    avg_val=(gc*GOLD[1]+(1-gc)*sum(dist[k]*GRASS[k][1] for k in range(5)))*rw_mult
    avg_xp =(gc*GOLD_XP+(1-gc)*sum(dist[k]*GRASS_XP[k] for k in range(5)))*xp_m*(1.25 if ACTIVE_RUNE=="bloom" else 1.0)
    if reaper: cap_m*=(1+cc*0.3)
    rate=min(2*R*v*D, cnt/(math.ceil(avg_hp/max(1e-9,dmg))*iv)*cap_m)
    val=(avg_val*val_m+vadd)*_rune("avarice")
    if overkill:   # 초과데미지 비례 코인. 하드상한 대신 자연 수렴(→+100% 점근, 새싹 폭발 방지)
        r=max(0.0, dmg/max(1e-9,avg_hp)-1.0); val*=(1 + r/(r+1.0))
    return rate, val, avg_xp

def _draft_pick(st, pu, rng, marginal):
    avail=[t for t in PU if pu.get(t,0)<PU[t][1]]
    if not avail: return None
    has_luck=pu.get("luck",0)>0; n=4 if pu.get("extra_choice",0)>0 else 3; rr=pu.get("reroll",0)
    def draw():
        pool=avail[:]; wts=[PU[t][0]*(3.0 if (has_luck and PU[t][0]<=4) else 1.0) for t in pool]; out=[]
        for _ in range(min(n,len(pool))):
            tot=sum(wts); r=rng.random()*tot; acc=0.0
            for i,w in enumerate(wts):
                acc+=w
                if r<=acc: out.append(pool.pop(i)); wts.pop(i); break
        return out
    offered=draw()
    for _ in range(rr):
        alt=draw()
        if alt and max((marginal(t) for t in alt),default=-1)>max((marginal(t) for t in offered),default=-1):
            offered=alt
    return max(offered, key=lambda t:(marginal(t), PU[t][0])) if offered else None

def _phased_session(st, world, trans, seed):
    """세션을 레벨업 구간으로 나눠 시뮬(파워업 누적 램프 반영). 반환 코인."""
    rng=_random.Random(seed); dist=s_quality_dist(st.get("grass_quality",0))
    T=s_session(st.get("session_time",0)); pu={}; t=0.0; level=1; coins=0.0; kills=0.0
    lvcap=SESSION_LV_CAP + (2 if ACTIVE_RUNE=="bloom" else 0)  # 만개: 세션 최대 레벨 +2
    def need(lv): return 2*lv   # Lv→Lv+1 필요 XP (SESSION_LV_NEED와 동일, 상한 확장용 일반식)
    def marginal(ty):
        r0,v0,_=_apply_pu(st,pu,kills,level,world,trans,dist); base=r0*v0
        p2=dict(pu); p2[ty]=p2.get(ty,0)+1
        r1,v1,_=_apply_pu(st,p2,kills,level,world,trans,dist); return r1*v1-base
    while t<T-1e-9:
        rate,val,xpk=_apply_pu(st,pu,kills,level,world,trans,dist)
        if level<lvcap:
            xps=rate*xpk; dt_lv=need(level)/xps if xps>0 else 1e9
        else: dt_lv=1e9
        dt=min(dt_lv, T-t); coins+=rate*val*dt; kills+=rate*dt; t+=dt
        if t<T-1e-9 and level<lvcap:
            level+=1
            pick=_draft_pick(st,pu,rng,marginal)
            if pick: pu[pick]=pu.get(pick,0)+1
            if pu.get("level_burst",0):
                _,v2,_=_apply_pu(st,pu,kills,level,world,trans,dist)
                R=s_attack_range(st.get("attack_range",0)); dens=min(s_density(st.get("grass_density",0)),GRID_SIDE*GRID_SIDE)
                ak=(dens/CHUNK_AREA)*math.pi*(2*R)**2; coins+=ak*v2; kills+=ak
    return coins

_pu_cache={}
def powerup_factors(st, world, trans):
    """(코인 배율, 거목 DPS 배율). 코인 배율 = PU_SEEDS회 랜덤 드래프트 평균 / 기본수입."""
    if not USE_POWERUPS: return (1.0,1.0)
    key=(tuple(sorted(st.items())), world, trans)
    r=_pu_cache.get(key)
    if r is not None: return r
    rate,avg_val,_,T=_analytic_rate(st,world,trans); base=rate*avg_val*T
    if base<=0: _pu_cache[key]=(1.0,POWERUP_GOOMOK_MULT); return _pu_cache[key]
    kseed=zlib.crc32(repr(key).encode())   # 결정적 시드(문자열 해시 랜덤화 회피 → 재현성)
    tot=0.0
    for s in range(PU_SEEDS):
        tot+=_phased_session(st,world,trans,(kseed^(s*2654435761))&0x7fffffff)
    cm=(tot/PU_SEEDS)/base   # 상한 없음(밸런스는 수치로 조정)
    res=(cm, POWERUP_GOOMOK_MULT); _pu_cache[key]=res; return res

# ═══════════════════════════════ 플레이어 구매 전략 ═══════════════════════════════
# 실제 플레이 가정: 경제(수입)를 먼저 키워 돈을 빠르게 모으고(돈은 게이트 아님),
# 남는 돈으로 공격(DPS)에 점진 투자 → 거목은 강해지는 데 시간이 걸림(거목이 게이트).
PAYBACK_LIMIT = 3.0   # 수입 틱: 회수기간(세션) 이보다 짧으면 구매

def _income_rate(st):   # ROI 판단용 기본 수입(파워업 제외 → 빠름)
    rate, avg_val, _, T = _analytic_rate(st, 0, 0); return rate*avg_val*T

def buy(st, money, goomok_hp, world=0, reserve=0):
    """실제 방치형: 번 돈을 (reserve 남기고) 전부 재투자.
    우선순위: 거목 못 잡으면 DPS → 그다음 수입 ROI 최고 틱 → 남으면 아무거나(코인 소진)."""
    while True:
        avail = money - reserve
        if avail <= 0: break
        pick=None
        # 거목 못 잡으면 DPS 최저가
        if not can_clear_goomok(st, goomok_hp, world):
            for sk in DPS_SKILLS:
                t=st.get(sk,0)
                if t>=MAXTICKS[sk]: continue
                c=tick_cost(sk,t)
                if c is None or c>avail: continue
                if pick is None or c<pick[1]: pick=(sk,c)
        # 수입 ROI 최고 틱
        if pick is None:
            base=_income_rate(st); bestpb=None
            for sk in INCOME_SKILLS:
                t=st.get(sk,0)
                if t>=MAXTICKS[sk]: continue
                c=tick_cost(sk,t)
                if c is None or c>avail: continue
                st[sk]=t+1; d=_income_rate(st)-base; st[sk]=t
                pb=c/d if d>0 else 1e18
                if bestpb is None or pb<bestpb[2]: bestpb=(sk,c,pb)
            if bestpb and bestpb[2]<1e17: pick=(bestpb[0],bestpb[1])
        # 그래도 없으면 아무 스킬이나 최저가(코인 소진 = 남은 비싼 티어 채움)
        if pick is None:
            for sk in COSTS:
                t=st.get(sk,0)
                if t>=MAXTICKS[sk]: continue
                c=tick_cost(sk,t)
                if c is None or c>avail: continue
                if pick is None or c<pick[1]: pick=(sk,c)
        if pick is None: break
        st[pick[0]]=st.get(pick[0],0)+1; money-=pick[1]
    return money

# ═══════════════════════════════ 시나리오 ═══════════════════════════════
def first_clear_data():
    """풀 이코노미를 돌려 각 월드 첫 클리어(초월0) 시점의 (세션#, 스킬상태 스냅샷) 반환."""
    st={}; money=0; gems=0; gem_unlocked=set(); unlocked={0}; trans=[0]*7; cleared=set(); sessions=0
    fc={}
    while sessions<5000 and len(fc)<7:
        sessions+=1
        w=max(unlocked,key=lambda x:simulate_session(st,x,trans[x])[0])
        money+=simulate_session(st,w,trans[w])[0]
        budget=money*SPEND_FRAC; left,gems=buy_full(st,budget,gems,gem_unlocked,goomok_hp_at(w,trans[w]),w); money-=(budget-left)
        for w2 in list(unlocked):
            L=trans[w2]
            if (w2,L) not in cleared and can_clear_at(st,w2,L): cleared.add((w2,L)); gems+=gem_drop(w2,L)
        for w2 in list(unlocked):
            if w2 not in fc and can_clear_at(st,w2,0): fc[w2]=(sessions,dict(st))
        nw=max(unlocked)+1
        if nw<7 and can_clear_at(st,nw,0) and money>=unlock_cost(nw): money-=unlock_cost(nw); unlocked.add(nw)
        if len(unlocked)>=5:
            cand=[(trans_cost(w2,trans[w2]),w2) for w2 in unlocked if trans[w2]<MAX_TRANS and can_clear_at(st,w2,trans[w2]+1)]
            cand=[c for c in cand if c[0]<=money]
            if cand: c,w2=min(cand); money-=c; trans[w2]+=1
    return fc

def scn_goomok():
    print("── 거목/씨앗 진단 (각 월드 첫 클리어 시점의 상태 기준) ──")
    print(f"  씨앗 필요수(월드1~7) = {SEED_NEED} | 씨앗수집/s = 2×자석×이동×밀도")
    print("  월드 첫클리어 | 이속 | 씨앗/s | 거목등장 | 세션 | 전투창 | 거목HP | DPS | 격파소요 | 판정")
    fc=first_clear_data()
    for w in range(7):
        if w not in fc: print(f"  {w+1}  | 미클리어"); continue
        sess,sst=fc[w]; v=s_move(sst.get("move_speed",0)); r=seed_rate(sst); T=s_session(sst.get("session_time",0))
        summon=goomok_summon_time(sst,w); win=T-summon; hp=goomok_hp_at(w,0)
        dps=goomok_dps(sst)*POWERUP_GOOMOK_MULT; ttk=hp/dps if dps>0 else 9999
        ok="OK" if (win>0 and ttk<=win) else "부족"
        print(f"  {w+1} S{sess:<3d}| {v:4.0f} | {r:5.2f} | {summon:5.1f}s | {T:4.0f} | {win:5.1f}s | {hp:6.0f} | {dps:5.0f} | {ttk:5.1f}s | {ok}")
    print("  ※ 거목등장=씨앗 N개 수집까지 걸린 초 / 전투창=세션-등장 / 격파소요=거목HP/DPS")

def scn_powerups():
    print(f"── 파워업 인런 모델 (드래프트 {PU_SEEDS}회 평균) ──")
    print("  스킬상태별 코인 배율(파워업 有/無) + 대표 드래프트 결과")
    states=[("무스킬",{}),
            ("초반(밀도5)",{"grass_density":5}),
            ("중반(밀도15+공10+등급16)",{"grass_density":15,"attack_power":10,"grass_quality":16}),
            ("후반(밀도30+공20+등급40+속5)",{"grass_density":30,"attack_power":20,"grass_quality":40,"attack_speed":5,"attack_range":10})]
    for label,st in states:
        cm,gm=powerup_factors(st,0,0)
        base=_income_rate(st)
        print(f"  {label:30s} 기본수입 ${base:9.0f} | 코인배율 x{cm:.2f} → ${base*cm:9.0f} | 거목DPS x{gm:.2f}")
    # 대표 세션 1회의 최종 드래프트 로드아웃 예시
    print("\n  예시 로드아웃(후반 상태, seed 0):")
    st={"grass_density":30,"attack_power":20,"grass_quality":40,"attack_speed":5,"attack_range":10}
    rng=_random.Random(0); dist=s_quality_dist(st.get("grass_quality",0)); pu={}; t=0.0; level=1; kills=0.0
    T=s_session(0)
    def marg(ty):
        r0,v0,_=_apply_pu(st,pu,kills,level,0,0,dist); p2=dict(pu); p2[ty]=p2.get(ty,0)+1
        r1,v1,_=_apply_pu(st,p2,kills,level,0,0,dist); return r1*v1-r0*v0
    while t<T-1e-9:
        rate,val,xpk=_apply_pu(st,pu,kills,level,0,0,dist)
        xps=rate*xpk; dt_lv=SESSION_LV_NEED[level-1]/xps if (level<SESSION_LV_CAP and xps>0) else 1e9
        dt=min(dt_lv,T-t); kills+=rate*dt; t+=dt
        if t<T-1e-9 and level<SESSION_LV_CAP:
            level+=1; pick=_draft_pick(st,pu,rng,marg)
            if pick: pu[pick]=pu.get(pick,0)+1
    print(f"    세션Lv{level} | {dict(sorted(pu.items(), key=lambda x:-x[1]))}")

def scn_session():
    print("── 단일 세션 수입 (월드1) ──")
    for label, st in [("무스킬",{}), ("밀도5",{"grass_density":5}),
                      ("밀도10+공격5",{"grass_density":10,"attack_power":5}),
                      ("밀도20+등급16+공격10",{"grass_density":20,"grass_quality":16,"attack_power":10})]:
        coins,kills,xp = simulate_session(st, want_xp=True)
        print(f"  {label:22s} 코인 ${coins:8.0f} | 처치 {int(kills):5d} | 세션Lv {session_level(xp)}")

def scn_pacing():
    print("── 월드1 페이싱 (거목 HP별) ──")
    print("  거목HP | 돈$100세션 | 거목클리어세션")
    for hp in [600,750,900,1050,1200]:
        st={}; money=0; earned=0; mr=None; clear=None
        for s in range(1,41):
            coins,_=simulate_session(st); money+=coins; earned+=coins
            if mr is None and earned>=WORLD2_COST: mr=s
            money=buy(st, money, hp, 0)
            if clear is None and can_clear_goomok(st,hp,0): clear=s
            if clear: break
        print(f"  {hp:5d}  |    {mr}      |    {clear}")

TOTAL_TICKS = sum(MAXTICKS.values())
def skill_max_pct(st): return 100.0*sum(min(st.get(k,0),MAXTICKS[k]) for k in COSTS)/TOTAL_TICKS

def scn_progression(target=7):
    """각 월드 목표 세션 수(target)로 강제 진행 → 필요한 해금비용 역산 + 스킬맥스 추적."""
    print(f"── 월드1~7 진행 (각 월드 {target}세션 목표) ──")
    print(" 월드 | 첫클리어 | 거목HP | 세션수입$ | 권장해금비용$ | 스킬맥스% | 게임Lv")
    st={}; money=0; total=0; kills=0; unlock_rec=[0]; skillmax_done=None
    for w in range(7):
        ghp = GOOMOK_HP_BASE*GOOMOK_WORLD_SCALE[w]
        first=None; last_inc=0
        for s in range(target):
            total+=1
            last_inc=simulate_session(st, world=w)[0]; money+=last_inc
            money=buy(st, money, ghp, w)
            if can_clear_goomok(st,ghp,w):
                if first is None: first=s+1
                kills+=1
            if skillmax_done is None and skill_max_pct(st)>=99.9: skillmax_done=total
        unlock_rec.append(round(money))   # 이 세션들 후 보유금 = 다음 월드 권장 해금비용
        money=0                            # 해금에 지불
        print(f"  {w+1}  |   {str(first):4s}  | {ghp:6.0f} | ${last_inc:9.0f} | ${unlock_rec[-1]:11d} |  {skill_max_pct(st):5.1f}  |  {game_level(kills)}")
    print(f"\n  완주 총 세션={total} | 거목 처치={kills} | 게임레벨={game_level(kills)}")
    print(f"  전 월드 해금 완료 = {total}세션 | 스킬 전체 맥스 = {skillmax_done or '>완주'}세션")
    print(f"  권장 해금비용 곡선(월드2~7) = {unlock_rec[1:]}")

def game_level(kills, cap=15):
    # 거목(첫클리어) 누적 → 레벨. 완주=전 초월 첫클리어 28회 ≈ Lv15 (2회당 1레벨)
    return min(cap, 1 + int(kills)//2)

# ── 게임 레벨 XP 곡선 ── 세션 완료(기본) + 거목 처치(더 큼). 누적 임계로 레벨(Lv8≈진행 40%)
GLEVEL_CAP = 15
GLEVEL_XP_CURVE_P = 2.5    # 임계 곡선 지수(>1=초반 빠르게/후반 완만). Lv8≈진행 40%에 맞춤
GLEVEL_SESSION_XP = 10.0   # 세션 완료당 기본 XP
GLEVEL_GOOMOK_XP  = 40.0   # 거목 처치당 XP(세션보다 큼)
def goomok_xp(w, L): return GLEVEL_GOOMOK_XP   # 거목 처치 XP(균등 — 곡선 매끄럽게)
def glevel_threshold(total_xp, lv):  # Lv 도달 누적 XP 임계(Lv15=total)
    return total_xp*((lv-1)/(GLEVEL_CAP-1))**GLEVEL_XP_CURVE_P
def glevel_from_xp(cum_xp, total_xp):
    lv=1
    for L in range(2,GLEVEL_CAP+1):
        if cum_xp>=glevel_threshold(total_xp,L): lv=L
        else: break
    return lv

# ═══════════════════════════════ 초월 + 보석 경제 ═══════════════════════════════
MAX_TRANS = 3
def goomok_hp_at(w, L): return GOOMOK_HP_BASE*GOOMOK_WORLD_SCALE[w]*(1+0.4*L)
def can_clear_at(st, w, L): return can_clear_goomok(st, goomok_hp_at(w,L), w)
def unlock_cost(w): return int(WORLD_UNLOCK_COST[w]*COIN_COST_MULT)  # 해금 비용(코인배수 반영)
def trans_cost(w, L):  # 초월 L→L+1 비용 (사용자: ~월드4~5 해금 비용 수준)
    base = WORLD_UNLOCK_COST[min(w+2,6)]
    return int(max(500, base)*(1+L)*COIN_COST_MULT)
def gem_drop(w, L): return max(1, L)   # (w,L) 첫 클리어 보석(초월 레벨만큼, 최소1)

# 보석으로 잠긴 스킬 상위 티어 (유저레벨: 보석수) — 원본 SKILL_GEM_COSTS(모델된 스킬만)
GEM_LOCK = {
 "attack_power":{4:1,6:2,8:3}, "attack_speed":{4:1,5:2,6:3}, "attack_range":{6:1},
 "crit_chance":{4:1}, "goomok_dmg":{5:1}, "crit_damage":{5:1},
 "grass_density":{5:1,7:2}, "grass_quality":{5:1,7:2}, "attack_count":{3:1,4:2,5:3},
 "golden_chance":{5:1}, "move_speed":{5:1}, "session_time":{3:1,5:2},
}
GEMS_NEEDED = sum(sum(v.values()) for v in GEM_LOCK.values())

def next_tier_locked(sk, ticks, gem_unlocked):
    ulv = ticks//COSTS[sk][1] + 1   # 다음 틱의 유저 레벨(1-base)
    cost = GEM_LOCK.get(sk,{}).get(ulv,0)
    return cost>0 and (sk,ulv) not in gem_unlocked

def buy_full(st, money, gems, gem_unlocked, goomok_hp, world=0):
    """번 돈/보석을 재투자. 보석으로 막힌 상위 티어는 보석으로 개방 후 코인 구매."""
    # 1) 막고 있는 티어를 보석으로 개방(가능한 것부터)
    changed=True
    while changed:
        changed=False
        for sk in list(COSTS):
            t=st.get(sk,0)
            if t>=MAXTICKS[sk]: continue
            ulv=t//COSTS[sk][1]+1; cost=GEM_LOCK.get(sk,{}).get(ulv,0)
            if cost>0 and (sk,ulv) not in gem_unlocked and gems>=cost:
                gem_unlocked.add((sk,ulv)); gems-=cost; changed=True
    # 2) 코인으로 스킬 구매(거목 못 잡으면 DPS 우선, 그 후 수입 ROI, 티어락 스킵)
    def buyable(sk):
        t=st.get(sk,0)
        if t>=MAXTICKS[sk]: return None
        if next_tier_locked(sk,t,gem_unlocked): return None
        c=tick_cost(sk,t)
        return c if (c is not None and c<=money) else None
    while True:
        pick=None
        if not can_clear_goomok(st, goomok_hp, world):
            for sk in DPS_SKILLS:
                c=buyable(sk)
                if c and (pick is None or c<pick[1]): pick=(sk,c)
        if pick is None:
            base=_income_rate(st); bestpb=None
            for sk in INCOME_SKILLS:
                c=buyable(sk)
                if c is None: continue
                t=st.get(sk,0); st[sk]=t+1; d=_income_rate(st)-base; st[sk]=t
                pb=c/d if d>0 else 1e18
                if bestpb is None or pb<bestpb[2]: bestpb=(sk,c,pb)
            if bestpb and bestpb[2]<1e17: pick=(bestpb[0],bestpb[1])
        if pick is None:  # 남은 코인 아무 스킬(비싼 티어 채움)
            for sk in COSTS:
                c=buyable(sk)
                if c and (pick is None or c<pick[1]): pick=(sk,c)
        if pick is None: break
        st[pick[0]]=st.get(pick[0],0)+1; money-=pick[1]
    return money, gems

def skills_maxed(st): return all(st.get(sk,0)>=MAXTICKS[sk] for sk in COSTS)

def buy_save(st, money, gems, gem_unlocked, goomok_hp, world=0, pb_limit=3.0):
    """저축형: 보석 티어 개방 + 거목 잡을 DPS + 회수기간 좋은(payback<pb) 수입 투자만. 나머지 저축."""
    changed=True
    while changed:
        changed=False
        for sk in list(COSTS):
            t=st.get(sk,0)
            if t>=MAXTICKS[sk]: continue
            ulv=t//COSTS[sk][1]+1; cost=GEM_LOCK.get(sk,{}).get(ulv,0)
            if cost>0 and (sk,ulv) not in gem_unlocked and gems>=cost:
                gem_unlocked.add((sk,ulv)); gems-=cost; changed=True
    def buyable(sk):
        t=st.get(sk,0)
        if t>=MAXTICKS[sk] or next_tier_locked(sk,t,gem_unlocked): return None
        c=tick_cost(sk,t); return c if (c is not None and c<=money) else None
    while not can_clear_goomok(st, goomok_hp, world):   # 거목 잡을 만큼 DPS
        pick=None
        for sk in DPS_SKILLS:
            c=buyable(sk)
            if c and (pick is None or c<pick[1]): pick=(sk,c)
        if pick is None: break
        st[pick[0]]=st.get(pick[0],0)+1; money-=pick[1]
    while True:   # 회수기간 좋은 수입 투자만
        base=_income_rate(st); best=None
        for sk in INCOME_SKILLS:
            c=buyable(sk)
            if c is None: continue
            t=st.get(sk,0); st[sk]=t+1; d=_income_rate(st)-base; st[sk]=t
            pb=c/d if d>0 else 1e18
            if pb<pb_limit and (best is None or pb<best[2]): best=(sk,c,pb)
        if best is None: break
        st[best[0]]=st.get(best[0],0)+1; money-=best[1]
    return money, gems

def scn_tune(target=7):
    print(f"── 해금비용 역산 (각 월드 {target}세션 목표, 저축형 플레이어) ──")
    st={}; money=0; gems=0; gem_unlocked=set(); cleared=set(); total=0; kills=0; unlock_rec=[0]
    for w in range(7):
        for s in range(target):
            total+=1
            money+=simulate_session(st, w, 0)[0]
            money,gems=buy_save(st,money,gems,gem_unlocked, goomok_hp_at(w,0), w)
            if (w,0) not in cleared and can_clear_at(st,w,0):
                cleared.add((w,0)); gems+=gem_drop(w,0); kills+=1
        unlock_rec.append(round(money))   # 7세션 후 저축액 = 권장 해금비용
        inc=simulate_session(st,w,0)[0]
        print(f"  월드{w+1}→{w+2}: 권장해금 ${unlock_rec[-1]:>11,} | 세션수입 ${inc:>9,.0f} | 스킬맥스 {skill_max_pct(st):4.0f}% | 보석 {gems}")
        money=0
    print(f"\n  권장 해금비용(월드2~7) = {unlock_rec[1:]}")
    print(f"  → 월드 전체 해금 ≈ {total}세션 (각 {target}세션) | 최종 스킬맥스 {skill_max_pct(st):.0f}%")

def run_full(timeline=None):
    """풀 이코노미 루프 실행 → (world_done, trans_done, skill_done, sessions, cleared수) 반환.
    timeline 리스트 전달 시 거목 첫클리어를 (세션, 월드, 초월)로 기록."""
    st={}; money=0; gems=0; gem_unlocked=set()
    unlocked={0}; trans=[0]*7; cleared=set()
    sessions=0; world_done=None; skill_done=None; trans_done=None
    while sessions<5000:
        sessions+=1
        w=max(unlocked, key=lambda x: simulate_session(st,x,trans[x])[0])
        money+=simulate_session(st,w,trans[w])[0]
        budget=money*SPEND_FRAC
        left,gems=buy_full(st,budget,gems,gem_unlocked, goomok_hp_at(w,trans[w]), w)
        money-=(budget-left)
        for w2 in list(unlocked):
            L=trans[w2]
            if (w2,L) not in cleared and can_clear_at(st,w2,L):
                cleared.add((w2,L)); gems+=gem_drop(w2,L)
                if timeline is not None: timeline.append((sessions,w2,L))
        nw=max(unlocked)+1
        if nw<7 and can_clear_at(st,nw,0) and money>=unlock_cost(nw):
            money-=unlock_cost(nw); unlocked.add(nw)
        if len(unlocked)>=5:
            cand=[(trans_cost(w2,trans[w2]),w2) for w2 in unlocked
                  if trans[w2]<MAX_TRANS and can_clear_at(st,w2,trans[w2]+1)]
            cand=[c for c in cand if c[0]<=money]
            if cand:
                c,w2=min(cand); money-=c; trans[w2]+=1
        if world_done is None and len(unlocked)==7: world_done=sessions
        if trans_done is None and all(t==MAX_TRANS for t in trans): trans_done=sessions
        if skill_done is None and skills_maxed(st): skill_done=sessions
        if world_done and trans_done and skill_done: break
    return world_done, trans_done, skill_done, sessions, len(cleared)

def _glevel_timeline(tl, total):
    """세션별 누적 게임레벨 XP → 각 레벨 도달 세션. (세션당 기본XP + 거목 처치XP)"""
    clears_at={}
    for (s,w,L) in tl: clears_at.setdefault(s,[]).append((w,L))
    total_xp=total*GLEVEL_SESSION_XP + sum(goomok_xp(w,L) for _,w,L in tl)
    cum=0.0; lv_sess={}
    for s in range(1,total+1):
        cum+=GLEVEL_SESSION_XP
        for (w,L) in clears_at.get(s,[]): cum+=goomok_xp(w,L)
        lv=glevel_from_xp(cum,total_xp)
        if lv not in lv_sess: lv_sess[lv]=s
    return lv_sess, total_xp

def scn_glevel():
    print(f"── 게임 레벨 XP 곡선 (세션 {GLEVEL_SESSION_XP:.0f}XP + 거목 {GLEVEL_GOOMOK_XP:.0f}XP, 곡선지수 p={GLEVEL_XP_CURVE_P}) ──")
    tl=[]; wd,td,sd,total,_=run_full(tl)
    lv_sess,total_xp=_glevel_timeline(tl,total)
    print(f"  총 세션 {total} | 거목 첫클리어 {len(tl)}회 | 총 XP {total_xp:.0f}")
    print("  레벨 | 도달세션 | 진행률% | XP임계")
    for L in range(1,GLEVEL_CAP+1):
        s=lv_sess.get(L)
        if s is None: print(f"   {L:2d}  |  (스킵)"); continue
        thr=glevel_threshold(total_xp,L) if L>1 else 0
        mark=" ← 목표 40%" if L==8 else ""
        print(f"   {L:2d}  |   {s:3d}   |  {100*s/total:4.0f}%  | {thr:7.0f}{mark}")

def scn_runes():
    global ACTIVE_RUNE
    print("── 룬(키스톤) 효과 (축별 깨끗한 지표) ──")
    print(f"  값: {RUNE_VAL}")
    print("  ※ full 총세션은 그리디-초월 부작용으로 노이즈 큼 → world1 게이트 + 세션수입으로 비교")
    print("  룬     | world1첫클 | 중반수입 | Δ | 후반수입 | Δ")
    mid={"grass_density":15,"attack_power":10,"grass_quality":16,"crit_chance":6}
    late={"grass_density":30,"attack_power":20,"grass_quality":40,"attack_speed":5,"attack_range":10,"crit_chance":10}
    b_w1=b_im=b_il=None
    for rune in [None,"onslaught","avarice","woodcutter","sowing","bloom","windfury"]:
        ACTIVE_RUNE=rune; _pu_cache.clear()
        fc=first_clear_data(); w1=fc[0][0] if 0 in fc else 0
        im=simulate_session(mid,0,0)[0]; il=simulate_session(late,0,0)[0]
        if rune is None: b_w1,b_im,b_il=w1,im,il
        label={None:"무룬","onslaught":"맹공","avarice":"축재","woodcutter":"벌목꾼","sowing":"파종","bloom":"만개","windfury":"질풍"}[rune]
        dm=f"+{(im/b_im-1)*100:.0f}%" if rune else ""; dl=f"+{(il/b_il-1)*100:.0f}%" if rune else ""
        gate=f"(-{b_w1-w1})" if rune else ""
        print(f"  {label:6s} | {w1}세션 {gate:5s} | ${im:6.0f} | {dm:4s} | ${il:7.0f} | {dl}")
    ACTIVE_RUNE=None; _pu_cache.clear()
    print("  → 맹공=후반 파밍↑ / 축재=전구간 코인↑ / 벌목꾼·파종=world1 게이트↓ / 만개=파워업 빌드로 수입↑")

def scn_full(verbose=False):
    print(f"── 풀 이코노미 (월드+초월+보석+스킬, 숫자 세션루프) ──  [스킬 맥스 필요 보석={GEMS_NEEDED}]")
    st={}; money=0; gems=0; gem_unlocked=set()
    unlocked={0}; trans=[0]*7; cleared=set()
    sessions=0; world_done=None; skill_done=None; trans_done=None
    while sessions<5000:
        sessions+=1
        # 1) 가장 돈 되는 해금 월드(현재 초월 상태) 선택해서 플레이
        w=max(unlocked, key=lambda x: simulate_session(st,x,trans[x])[0])
        money+=simulate_session(st,w,trans[w])[0]
        # 2) 재투자: 보유금의 SPEND_FRAC만 스킬에, 나머지는 진행(해금/초월) 저축
        budget=money*SPEND_FRAC
        left,gems=buy_full(st,budget,gems,gem_unlocked, goomok_hp_at(w,trans[w]), w)
        money-=(budget-left)
        # 3) 거목 첫 클리어(각 월드 현재 초월) → 보석
        for w2 in list(unlocked):
            L=trans[w2]
            if (w2,L) not in cleared and can_clear_at(st,w2,L):
                cleared.add((w2,L)); gems+=gem_drop(w2,L)
        # 4) 다음 월드 해금(거목 클리어 + 코인)
        nw=max(unlocked)+1
        if nw<7 and can_clear_at(st,nw,0) and money>=unlock_cost(nw):
            money-=unlock_cost(nw); unlocked.add(nw)
        # 5) 초월(월드 5 도달 시 개방 — 해금된 월드만, 감당되고 클리어 가능하면 최저가 순)
        if len(unlocked)>=5:
            cand=[(trans_cost(w2,trans[w2]),w2) for w2 in unlocked
                  if trans[w2]<MAX_TRANS and can_clear_at(st,w2,trans[w2]+1)]
            cand=[c for c in cand if c[0]<=money]
            if cand:
                c,w2=min(cand); money-=c; trans[w2]+=1
        # 마일스톤
        if world_done is None and len(unlocked)==7: world_done=sessions
        if trans_done is None and all(t==MAX_TRANS for t in trans): trans_done=sessions
        if skill_done is None and skills_maxed(st): skill_done=sessions
        if world_done and trans_done and skill_done: break
        if verbose and sessions%10==0:
            print(f"  S{sessions}: 월드{len(unlocked)} 초월{trans} 보석{gems} 스킬맥스{skill_max_pct(st):.0f}% 돈${money:.0f}")
    print(f"  전 월드 해금 = {world_done}세션")
    print(f"  전 초월(Lv{MAX_TRANS}) 완료 = {trans_done}세션")
    print(f"  전 스킬 맥스 = {skill_done}세션 (스킬맥스율 {skill_max_pct(st):.0f}%)")
    print(f"  총 {sessions}세션 | 보석 획득총량≈{gems+sum(GEM_LOCK[s][l] for (s,l) in gem_unlocked)} | 게임레벨 {game_level(len(cleared))}")

if __name__=="__main__":
    ap=argparse.ArgumentParser(description="v2 밸런싱 시뮬")
    ap.add_argument("scenario", nargs="?", default="full",
                    choices=["session","pacing","progression","full","tune","powerups","goomok","runes","glevel"])
    a=ap.parse_args()
    {"session":scn_session,"pacing":scn_pacing,"progression":scn_progression,
     "full":scn_full,"tune":scn_tune,"powerups":scn_powerups,"goomok":scn_goomok,"runes":scn_runes,"glevel":scn_glevel}[a.scenario]()
