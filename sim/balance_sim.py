#!/usr/bin/env python3
"""
풀 좀 베겠습니다 v2 — 밸런싱 시뮬레이터 (틱 기반, 실제 플레이 근접)
================================================================
목적: 게임을 실행하지 않고 수치로 밸런스를 검증/튜닝. 나중에도 쉽게 재실행.

■ 실행법
    python3 sim/balance_sim.py session      # 단일 세션 수입(스킬 상태별)
    python3 sim/balance_sim.py pacing        # 월드1 페이싱(돈/거목 세션)
    python3 sim/balance_sim.py progression   # 월드1~7 완주 + 게임레벨
    python3 sim/balance_sim.py               # = progression

■ 모델 (실제 플레이 흉내)
    - 세션 수입 = **틱 시뮬**: 플레이어가 이동하며 범위 내 풀을 실제로 스윙 공격.
      풀이 밀도·이동에 따라 범위로 유입되고, 못 베면 뒤로 빠져나감(놓침) → 인카운터 vs DPS 자연 발생.
    - 거목 = 단일 보스라 DPS×시간 해석 판정(정확). 크릿·거목피해 반영.
    - 재생·황금풀·세션시간·월드 배율 반영.

■ 수치 출처: 원본(game-kill_grass @4cd58ca) 포팅 + v2 재조정.
  모든 튜닝값은 아래 CONFIG / SKILLS / COSTS 한곳에 모음 (여기만 고치면 됨).
"""
import argparse, math

# ═══════════════════════════════ CONFIG (튜닝은 여기) ═══════════════════════════════
SESSION_TIME   = 45.0     # 세션 길이(초, 세션시간 스킬 전)
TICK_DT        = 0.05     # 시뮬 틱(초)
GOOMOK_HP_BASE = 600.0    # 월드1 거목 HP (크릿·거목피해 DPS 반영 → 클리어 ~7세션)
GOOMOK_KILL_FRACTION = 0.55  # 세션 중 거목 전투에 쓰는 시간 비율
WORLD2_COST    = 100      # (표시용) 월드2 해금 비용

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
WORLD_UNLOCK_COST = [0, 100, 1000, 10000, 25000, 50000, 100000]
GOOMOK_WORLD_SCALE = WORLD_HP_MULT  # 거목 HP = BASE × 이 배율

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
    return max(1,c)

DPS_SKILLS    = ["attack_power","attack_speed","crit_chance","crit_damage","goomok_dmg"]
INCOME_SKILLS = ["grass_density","grass_quality","attack_count","golden_chance","attack_range","move_speed","session_time"]

# ═══════════════════════════════ 파생 스탯 ═══════════════════════════════
def eff_damage(st):
    d = s_attack_power(st.get("attack_power",0))
    cc = s_crit_chance(st.get("crit_chance",0)); cm = s_crit_mult(st.get("crit_damage",0))
    return d * (1 + cc*(cm-1))    # 크릿 기대 데미지
def goomok_dps(st):
    return eff_damage(st)/s_attack_speed(st.get("attack_speed",0)) * s_goomok_dmg(st.get("goomok_dmg",0))
def can_clear_goomok(st, goomok_hp):
    killt = s_session(st.get("session_time",0))*GOOMOK_KILL_FRACTION
    return goomok_dps(st)*killt >= goomok_hp

# ═══════════════════════════════ 세션 수입 (정상상태 해석 모델) ═══════════════════════════════
def simulate_session(st, world=0, want_xp=False):
    """세션 수확 수입(정상상태 근사). 실제 플레이 = min(풀 유입 속도, 처치 캐파).
    - 유입(encounter) = 공격원(반경 R)이 이동속도 v로 스와스를 훑음 = 2R·v·풀밀도D
    - 캐파(capacity) = 스윙당 cnt개에 dmg → 초당 처치 = cnt / (ceil(HP/dmg) × 스윙간격)
    - 실제 처치율 = min(유입, 캐파). (플레이어는 풀 있는 곳에 머물며 벤다고 가정)
    반환: (코인, 처치수[, 세션XP])."""
    hp_mult = WORLD_HP_MULT[world]; rw_mult = WORLD_REWARD_MULT[world]
    R   = s_attack_range(st.get("attack_range",0))
    v   = s_move(st.get("move_speed",0))
    iv  = s_attack_speed(st.get("attack_speed",0))
    cnt = s_attack_count(st.get("attack_count",0))
    dmg = eff_damage(st)
    dens = min(s_density(st.get("grass_density",0)), GRID_SIDE*GRID_SIDE)
    D   = dens / CHUNK_AREA
    dist = s_quality_dist(st.get("grass_quality",0))
    gc  = s_golden(st.get("golden_chance",0))
    T   = s_session(st.get("session_time",0))

    avg_hp  = (gc*GOLD[0] + (1-gc)*sum(dist[k]*GRASS[k][0] for k in range(5)))*hp_mult
    avg_val = (gc*GOLD[1] + (1-gc)*sum(dist[k]*GRASS[k][1] for k in range(5)))*rw_mult
    avg_xp  =  gc*GOLD_XP + (1-gc)*sum(dist[k]*GRASS_XP[k] for k in range(5))

    encounter = 2*R*v*D
    capacity  = cnt / (math.ceil(avg_hp/max(1e-9,dmg)) * iv)
    rate = min(encounter, capacity)          # 초당 처치 풀 수
    kills = rate*T
    coins = kills*avg_val
    if want_xp: return coins, kills, kills*avg_xp
    return coins, kills

def session_level(xp):
    lv=1; acc=xp
    for need in SESSION_LV_NEED:
        if acc>=need: acc-=need; lv+=1
        else: break
    return min(lv, SESSION_LV_CAP)

# ═══════════════════════════════ 플레이어 구매 전략 ═══════════════════════════════
# 실제 플레이 가정: 경제(수입)를 먼저 키워 돈을 빠르게 모으고(돈은 게이트 아님),
# 남는 돈으로 공격(DPS)에 점진 투자 → 거목은 강해지는 데 시간이 걸림(거목이 게이트).
PAYBACK_LIMIT = 3.0   # 수입 틱: 회수기간(세션) 이보다 짧으면 구매

def _income_rate(st): return simulate_session(st, world=0)[0]

def buy(st, money, goomok_hp):
    # 1) 수입 성장: ROI(Δ수입/비용) 좋은 income 틱을 payback 기준으로 구매
    while True:
        base=_income_rate(st); best=None
        for sk in INCOME_SKILLS:
            t=st.get(sk,0)
            if t>=MAXTICKS[sk]: continue
            c=tick_cost(sk,t)
            if c is None or c>money: continue
            st[sk]=t+1; d=_income_rate(st)-base; st[sk]=t   # 시험 계산
            pb=c/d if d>0 else 1e18
            if pb<PAYBACK_LIMIT and (best is None or pb<best[2]): best=(sk,c,pb)
        if best is None: break
        st[best[0]]=st.get(best[0],0)+1; money-=best[1]
    # 2) 남는 돈으로 DPS(공격) 점진 투자 — 최저가 순
    while True:
        d=None
        for sk in DPS_SKILLS:
            t=st.get(sk,0)
            if t>=MAXTICKS[sk]: continue
            c=tick_cost(sk,t)
            if c is None or c>money: continue
            if d is None or c<d[1]: d=(sk,c)
        if d is None: break
        st[d[0]]=st.get(d[0],0)+1; money-=d[1]
    return money

# ═══════════════════════════════ 시나리오 ═══════════════════════════════
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
    for hp in [280,320,350,380,450,600]:
        st={}; money=0; earned=0; mr=None; clear=None
        for s in range(1,41):
            coins,_=simulate_session(st); money+=coins; earned+=coins
            if mr is None and earned>=WORLD2_COST: mr=s
            money=buy(st, money, hp)
            if clear is None and can_clear_goomok(st,hp): clear=s
            if clear: break
        print(f"  {hp:5d}  |    {mr}      |    {clear}")

def scn_progression():
    print("── 월드1~7 완주 진행 ──")
    print(" 월드 | 세션 | 첫클리어 | 거목HP | 세션수입$ | AP | AS | 밀도 | 게임Lv")
    st={}; money=0; total=0; goomok_kills=0
    for w in range(7):
        ghp = GOOMOK_HP_BASE*GOOMOK_WORLD_SCALE[w]
        unlock = WORLD_UNLOCK_COST[w+1] if w+1<7 else 0
        ws=0; first=None; last_inc=0
        while ws<300:
            total+=1; ws+=1
            coins,_=simulate_session(st, world=w); money+=coins; last_inc=coins
            money=buy(st, money, ghp)
            if can_clear_goomok(st,ghp):
                if first is None: first=ws
                goomok_kills+=1
                if w==6 or money>=unlock:
                    if w<6: money-=unlock
                    break
        glv = game_level(goomok_kills)
        print(f"  {w+1}  | {ws:4d} |   {str(first):4s}  | {ghp:6.0f} | ${last_inc:8.0f} | {st.get('attack_power',0):2d} | {st.get('attack_speed',0):2d} | {st.get('grass_density',0):3d} |  {glv}")
    print(f"\n  완주 총 세션={total} | 거목 처치={goomok_kills} | 최종 게임레벨={game_level(goomok_kills)}")

def game_level(kills, cap=15):
    # 거목 처치 누적 → 레벨. ~6처치당 1레벨(메인7≈50처치→~9, +초월 그라인드로 15 도달)
    return min(cap, 1 + int(kills)//6)

if __name__=="__main__":
    ap=argparse.ArgumentParser(description="v2 밸런싱 시뮬")
    ap.add_argument("scenario", nargs="?", default="progression",
                    choices=["session","pacing","progression"])
    a=ap.parse_args()
    {"session":scn_session,"pacing":scn_pacing,"progression":scn_progression}[a.scenario]()
