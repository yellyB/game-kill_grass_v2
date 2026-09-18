# core/ — 밸런스 로직 SSOT (순수 로직 레이어)

> 게임과 시뮬이 **공유하는 단일 진실 원천**. Godot Node/렌더/입력 의존 **0** (순수 정적 함수·데이터).
> 참조 방식: `const X = preload("res://core/xxx.gd")` (헤드리스 캐시 무관하게 확실).

## 레이어
| 파일 | 역할 | 파이썬 대응 |
|---|---|---|
| `balance_data.gd` | 모든 밸런스 상수·테이블(CONFIG/GRASS/WORLD/SEED/곡선) | `balance_sim.py` CONFIG |
| `skills.gd` | 스킬 효과 공식 + 비용 테이블(COSTS) | `s_*` / `COSTS` / `tick_cost` |
| `economy.gd` | 유효데미지·정상상태 수입·거목 DPS·씨앗 수집·거목 클리어 판정 | `eff_damage`/`_analytic_rate`/`goomok_*`/`seed_rate` |
| `progression.gd` | 세션 레벨·게임 레벨 XP·해금/초월 비용 | `session_level`/`glevel_*`/`unlock_cost`/`trans_cost` |

## 패리티 (수치 freeze 근거)
`sim/run_sim.gd`(헤드리스) 덤프 = `balance_sim.py` 덤프 **바이트 단위 완전 일치** 확인 완료:
```
godot --headless --path . --script res://sim/run_sim.gd -- skills|economy|progression
```
→ 결정적 공식·수치는 core/가 파이썬과 동일. **이 수치로 freeze.**

## 스코프 경계 (중요)
- **결정적 밸런스 공식** = core/ (게임 런타임이 실제 사용: 데미지/수입/비용/씨앗/거목/레벨 곡선).
- **확률적 밸런싱 시뮬**(파워업 드래프트 평균, 55세션 풀 이코노미 루프) = **`sim/balance_sim.py`에 Python으로 존치**(설계 문서 dev-plan 0-7 "검증 도구로 보존").
  - 이유: (1) Python MT난수 ↔ GDScript RNG는 알고리즘이 달라 **확률 파트 바이트 파리티 불가**(기댓값만 유사). (2) **게임 런타임은 풀 이코노미 루프를 돌리지 않음** — 실제 파워업은 인게임에서 실시간 적용(→ M2에서 StatBlock으로 core에 얹음). 밸런싱 예측은 설계 도구(Python)로 충분.
- 즉 core/ = "게임이 매 순간 쓰는 수식", balance_sim.py = "그 위에서 진행을 예측하는 설계 도구". 둘의 **결정적 접점은 위 패리티로 검증**됨.

## 다음(M2)에서 core/에 추가될 것
- `stat_block.gd` — 스킬 base + **인런 파워업/룬 수정자**를 얹은 실효 스탯 벡터(게임 실시간 적용). 파워업 50종 효과를 수정자로.
- `data/powerups.gd`·`runes.gd`·`game_level.gd` — 데이터 테이블(현재 balance_sim.py `PU`/`RUNE_VAL`에 있음 → 이식).
