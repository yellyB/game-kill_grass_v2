#!/usr/bin/env python3
"""
v2 밸런싱 탐색 시뮬 v3 (월드1 페이싱 + 재조정 스킬 검증)
재조정: 이동 300→750, 세션 45→65초, 황금 0→5%. (수집범위=편의라 income 모델 제외)
확인: 돈~3세션 / 거목~7~8세션 유지? 황금 빌드가 과하진 않나?
원본(4cd58ca) 수치 포팅. 해석 모델(경향).
"""
import math
WORLD2_COST=100
GRASS=[(4,1),(18,5),(38,30),(75,80),(130,200)]  # (HP,value) tier0..4
GOLD=(80,100)  # 황금풀
CHUNK_AREA=400.0*400.0

COSTS={
 "attack_power":([(1,1),(15,4),(300,70),(4500,1125),(27000,4950),(81000,14850),(288000,52200),(900000,162000),(3060000,550800)],5),
 "attack_speed":([(15,2),(28,5),(200,28),(6500,980),(220000,33000),(800000,120000)],5),
 "attack_range":([(10,1),(25,2),(60,5),(800,60),(3000,230),(32000,2460),(140000,10780),(370000,28490)],5),
 "grass_density":([(1,1),(15,2),(85,12),(1000,120),(28000,3360),(196000,23520),(710000,85200),(2800000,336000)],5),
 "grass_quality":([(15,1),(20,1),(80,5),(480,38),(5000,400),(42000,3360),(275000,22000),(670000,53600)],8),
 "attack_count":([(20,5),(300,100),(8000,2000),(300000,75000),(2500000,625000)],3),
 # ── 재조정 스킬 (1차 비용, 시뮬 튜닝) ──
 "move_speed":([(30,5),(60,10),(300,40),(6000,900),(200000,30000)],6),      # 300→750
 "session_time":([(50,10),(200,40),(3000,500),(40000,6000),(400000,60000)],3), # 45→65초
 "golden_chance":([(20,2),(150,30),(1800,220),(21000,2500),(250000,30000)],2), # 0→5%
}
MAXLV={k:len(v[0]) for k,(v,s) in COSTS.items()}
SUBMAX={k:s for k,(v,s) in COSTS.items()}
def tick_cost(sk,t):
    tbl,sm=COSTS[sk]; lv=t//sm; sub=t%sm
    if lv>=len(tbl): return None
    b,p=tbl[lv]; return max(1,b+sub*p)
def tmax(sk): return MAXLV[sk]*SUBMAX[sk]

def wdmg(t):
    per=lambda l:1 if l<=3 else 2 if l<=5 else 3 if l<=7 else 4
    lv=t//5; sub=t%5; tot=sum(per(l)*5 for l in range(1,lv+1))+per(lv+1)*sub; return 1+tot
def iv(t): return max(0.1,0.7-t*0.02)
def rng(t): return 60.0+t*7.0
def cnt(t):
    lv=t//3; sub=t%3; c=1+sum((l+1)*3 for l in range(lv))
    if lv<5: c+=(lv+1)*sub
    return c
def dens(t):
    if t<=0: return 1
    v=0;r=t
    for lv in range(1,9):
        x=min(r,5); v+=x*lv; r-=x
        if r<=0: break
    return 1+v
def qdist(t):
    lv=t//8; sub=t%8; p=[0.0]*5
    if lv>=8: p[4]=1.0; return p
    base=min(lv//2,4); nxt=(sub/8*0.5) if lv%2==0 else (0.5+sub/8*0.5)
    p[base]+=1-nxt; p[min(base+1,4)]+=nxt; return p
def move(t): return 300.0+t*15.0          # 300→750 (30틱)
def session(t): return 45.0+t*(20.0/15.0) # 45→65 (15틱)
def golden(t): return t*0.005             # 0→5% (10틱)

def income(st, breakdown=False):
    dmg=wdmg(st.get("attack_power",0)); i=iv(st.get("attack_speed",0))
    R=rng(st.get("attack_range",0)); c=cnt(st.get("attack_count",0))
    dn=min(dens(st.get("grass_density",0)),225); D=dn/CHUNK_AREA
    gc=golden(st.get("golden_chance",0)); d=qdist(st.get("grass_quality",0))
    av=gc*GOLD[1]+(1-gc)*sum(d[k]*GRASS[k][1] for k in range(5))
    ah=gc*GOLD[0]+(1-gc)*sum(d[k]*GRASS[k][0] for k in range(5))
    v=move(st.get("move_speed",0)); T=session(st.get("session_time",0))
    enc=2*R*v*D; cap=c/(math.ceil(ah/max(1,dmg))*i)
    inc=min(enc,cap)*av*T
    if breakdown:
        gold_share=gc*GOLD[1]/max(av,0.01)
        return inc, dict(dn=dn,av=round(av,1),move=round(v),T=round(T),gc=round(gc*100,1),goldshare=round(gold_share*100))
    return inc

def goomok_dps(st): return wdmg(st.get("attack_power",0))/iv(st.get("attack_speed",0))

BUY=list(COSTS.keys())
def cheapest(st):
    b=None
    for sk in BUY:
        t=st.get(sk,0)
        if t>=tmax(sk): continue
        c=tick_cost(sk,t)
        if c is None: continue
        if b is None or c<b[1]: b=(sk,c)
    return b

def run(goomok_hp, verbose=False):
    st={}; money=0; mr=None; clear=None; earned=0
    for s in range(1,41):
        inc=income(st); money+=inc; earned+=inc
        if mr is None and earned>=WORLD2_COST: mr=s
        while True:
            ct=cheapest(st)
            if ct is None: break
            sk,c=ct
            if c>money: break
            st[sk]=st.get(sk,0)+1; money-=c
        dps=goomok_dps(st); killt=session(st.get("session_time",0))*0.55
        if clear is None and dps*killt>=goomok_hp: clear=s
        if verbose:
            _,bd=income(st,True)
            print(f"S{s:2d} inc${inc:7.0f} dps{dps:5.1f} dens{bd['dn']} av${bd['av']} move{bd['move']} T{bd['T']} 황금{bd['gc']}%(수입비중{bd['goldshare']}%)")
        if clear: break
    return mr,clear

if __name__=="__main__":
    print("무스킬 세션수입=${:.0f}".format(income({})))
    print("거목HP | 돈$100세션 | 거목클리어")
    for hp in [280,320,350,380]:
        mr,cl=run(hp); print(f"{hp:5d} |   {mr}      |   {cl}")
    print("\n=== 거목HP350 상세 (황금 수입비중 관찰) ===")
    run(350, verbose=True)
