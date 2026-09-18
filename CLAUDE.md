# 풀죽이기 (Excuse Me, Mowing through) - Godot 4.3 Idle Game

> ⚠️ **v2 기준 필독**: 아래 서술은 **원본 모바일 게임** 기준이다. 현재 프로젝트는 PC(스팀) 리메이크 **v2**이며, 몬스터→식물(거목/정예), 분노→레벨업, 상자/열쇠→아이템 픽업/거목 클리어 등 **핵심 시스템이 바뀌었다**.
> **v2의 단일 기획서 = `docs/game-spec.md`** (게임 디자인+포팅+시뮬 아키텍처+로드맵). 파워업/아이템 목록은 `docs/powerups.md`, 밸런스 수치는 `sim/balance_sim.py`(→`core/`)가 소유. 원본 자료는 `docs/legacy/`.
> **아래 원본 설명은 이식 참조용**이며, v2 설계와 충돌 시 `game-spec.md`가 우선한다.

## 프로젝트 개요
풀을 베어서 돈을 모으는 방치형 모바일 게임. 플레이어가 이동하면 자동으로 범위 내 풀을 베고, 떨어진 코인을 수집하여 골드를 획득한다. 7개 월드를 해금하며 진행.

## 핵심 시스템

### 이동 방식
- 플레이어는 화면 중앙에 고정
- 월드(WorldRoot)가 플레이어 입력의 반대 방향으로 이동
- 배경은 플레이어를 따라다니며 무한하게 보임
- 입력: 키보드 (WASD/방향키), 터치 드래그 (모바일)

### 세션 시스템
- 세션 시간: 45초 (`main.gd` SESSION_TIME), 세션 시간 스킬로 최대 90초
- 화면 상단 중앙에 남은 시간 표시, 10초 이하 빨간색
- 세션 종료 시 BGM 페이드아웃 + 팡파레 효과음
- 터치하여 메인 메뉴로 복귀
- 게임 중 "처음으로" 버튼으로 메뉴 복귀 가능 (확인 다이얼로그)

### 월드 시스템
7개 월드, 각각 고유한 배경색/풀 색상/몬스터/BGM:
| 월드 | 이름 | 해금 비용 | 보스 몬스터 | 테마색 |
|------|------|-----------|-------------|--------|
| 1 | 슬라임 늪 | 무료 | 슬라임 | 어두운 초록 |
| 2 | 들판 | $100 | 멧돼지 | 따뜻한 갈색 |
| 3 | 기사의 성벽 | $1,000 | 잔디 기사 | 회청 |
| 4 | 마법의 숲 | $10,000 | 마도사 | 어두운 남보라 |
| 5 | 수정 호수 | $25,000 | 수정 사슴 | 투명한 시안 |
| 6 | 고대 유적 | $50,000 | 잔디 골렘 | 어두운 올리브 |
| 7 | 용의 봉우리 | $100,000 | 드래곤 | 어두운 적갈색 |

- 해금 조건: 코인 + 이전 월드 상자에서 획득한 열쇠
- 월드별 풀 색상: `WORLD_GRASS_TINTS` (메시 꼭짓점) × `WORLD_GRASS_COLORS` (인스턴스별)
- 월드별 배경색: `world_root.gd` `WORLD_BG_COLORS`

### 열쇠 & 상자 시스템
- 상자는 청크 진입 시 확률적 스폰 (상자 확률 스킬, 기본 0%)
- 상자는 "monsters" 그룹에 소속 → 플레이어 자동공격으로 파괴
- 상자 파괴 → 열쇠(또는 아이템) 드롭 → 플레이어에게 비행 → 수집
- 마지막 월드(7)의 보스 처치 시 "황금 왕관" 드롭 (엔딩 아이템)
- 이미 열쇠를 보유하면 상자 미출현

### 무한 맵 (청크 시스템)
- `grass_spawner.gd`: MultiMesh 기반 무한 풀 생성 (1 draw call)
- 풀 데이터는 Dictionary로 관리 (씬 인스턴스 없음)
- GPU 셰이더로 바람 흔들림 애니메이션 (`grass_sway.gdshader`)
- 청크 크기: 400x400, 렌더 거리: 3 청크
- 플레이어 주변 청크만 로드, 멀어지면 언로드
- 대칭 랜덤 오프셋으로 청크 경계 비가시화

### 풀 종류 (5종 + 황금풀)
| idx | 종류 | 체력 | 드롭 | 재생시간 | 색상 | 등장 확률 |
|-----|------|------|------|----------|------|-----------|
| 0 | 새싹 | 4 | $1 | 22초 | 밝은 초록 | 등급 레벨 의존 |
| 1 | 잔디 | 18 | $5 | 23초 | 청록색 | 등급 레벨 의존 |
| 2 | 여린풀 | 38 | $30 | 24초 | 어두운 청록 | 등급 레벨 의존 |
| 3 | 강한풀 | 75 | $80 | 25초 | 딥 블루 | 등급 레벨 의존 |
| 4 | 초강풀 | 130 | $200 | 26초 | 다크 블루 | 등급 레벨 의존 |
| 5 | 황금풀 | 80 | $100 | 25초 | 황금색 | 황금풀 확률 스킬 (기본 0%) |

### 코인 시스템
- 풀을 베면 해당 위치에 코인 생성 (WorldRoot 자식)
- 코인 색상: 브론즈($0~99), 실버($100~499), 골드($500~999), 다이아($1,000+)
- 고액 코인(브론즈 $50+, 실버 $300+, 골드 $750+)은 피라미드형 3개 쌓인 비주얼
- 자석 범위 내 접근 시 자동 끌려옴 (기본 범위 50, 스킬로 최대 260)
- 수집 시 플로팅 텍스트 표시 (배치 합산)

### 무기 시스템
10단계 무기 (공격력 스킬 레벨에 연동, 상세: `docs/weapons.md`):
1. 나뭇가지 - 기본, $0, 공격력 1
2. 녹슨 식칼 - $90, 공격력 2
3. 피자 커터 - $450, 공격력 3
4. 전기 파리채 - $1,200, 공격력 4
5. 뜨거운 다리미 - $2,600, 공격력 5
6. 매우 화난 고양이 - $6,000, 공격력 7
7. 체인소 - $13,000, 공격력 9
8. 마법 지팡이 - $29,000, 공격력 10
9. 날개달린 선풍기 - $60,000, 공격력 11
10. 위성 레이저 제초기 - $120,000, 공격력 12

### 업그레이드 시스템 (상세: `docs/skill-tree.md`)
- 스킬 트리 기반 업그레이드: 무기/수확/탐험 3개 그룹, 16개 스킬
- 스킬별 개별 비용 테이블 (틱 단위)
- 특정 스킬 레벨은 보석으로 해금 필요 (총 41개 보석)
- 보석 해금 UI: dim 오버레이 + 보석 아이콘, "해금하기" 버튼
- 공격 속도: 최대 Lv.6, 틱당 -0.02초 (0.70초→0.10초)

### 몬스터 시스템 (분노 보스)
- 분노 게이지를 채워 월드별 보스 소환 (`monster_spawner.gd`)
- 보스별 고유 스프라이트 (5프레임 애니메이션), 체력, 이동속도
- 플레이어 추격 AI
- 피격 시 빨간 플래시 + 슬래시 효과음, 사망 시 확대->흔들림->페이드 + 사망 효과음
- 사망 시 파워업 드롭 가능 (30% 확률), 초월 보스는 보석 드롭
- 상세: `docs/monsters.md`

### 사운드 시스템
**효과음** (`resources/sounds/effect/`):
| 파일 | 트리거 | 적용 위치 |
|------|--------|-----------|
| grass_swoosh.wav | 풀 공격 | player.gd |
| pick_coin.wav | 코인 수집 | player.gd |
| monster_slash.wav | 몬스터 피격 | monster.gd |
| monster_death.wav | 몬스터 사망 | monster.gd |
| wood_box_break.wav | 상자 파괴 | chest.gd |
| pick_key.wav | 아이템/열쇠 수집 | dropped_item.gd |
| button_click.wav | 일반 버튼 클릭 | GameManager (공용) |
| confirm_button_click.wav | 확인/구매 버튼 | GameManager (공용) |
| upgrade_success.wav | 업그레이드/무기 강화 성공 | GameManager (공용) |
| unlock_world.wav | 월드 해금 | GameManager (공용) |
| end_session_fanfare.wav | 세션 종료 결과 화면 | main.gd |

**배경음** (`resources/sounds/`):
| 파일 | 재생 위치 |
|------|-----------|
| bgm_main.wav | 메인 메뉴 (루프) |
| bgm_world_1~4.wav | 월드별 BGM (1초 딜레이 후 루프, 세션 종료 시 페이드아웃) |

- 공용 SFX는 `GameManager`에 AudioStreamPlayer로 관리
- queue_free되는 노드의 효과음은 root에 부착하여 재생 보장

### HUD 알림
- 열쇠 획득 시 화면 우측 상단(돈 아래)에 시안색 알림
- 1.5초 표시 후 0.5초간 페이드아웃

### 보석 시스템
- 초월 보스 처치 시 보석 드롭 (초월 레벨만큼)
- 각 월드+초월 레벨당 1회만 보석 드롭 (중복 불가, `collected_gem_levels`로 추적)
- 보석으로 특정 스킬 레벨 해금 (`SKILL_GEM_COSTS`)
- 보유 보석은 코인과 함께 HUD/메뉴에 표시 (`money_display.gd`)

### 세션 종료 화면
- 수집/보너스 내역 표시 후 합계 표시
- 보석 획득 시 보석 행 추가
- 순차 fade-in 애니메이션

### 디버그 기능
메인 메뉴 하단에 디버그 버튼 (debug build only):
- 초기화: 모든 데이터 리셋
- +$100000: 돈 추가
- +보석10: 보석 10개 추가
- 월드 전체해금: 모든 월드 해금

## 파일 구조

```
autoload/
  game_manager.gd    - 돈, 스킬 트리, 열쇠, 보석, SFX 관리
  weapon_manager.gd  - 무기 데이터 및 구매
  save_manager.gd    - 저장/불러오기
  session_manager.gd - 세션 관리 (시작/종료/메뉴 복귀)

scripts/
  main.gd            - 게임 세션 관리, 타이머, BGM, 세션 종료
  main_menu.gd       - 메인 메뉴 UI, 월드 선택, 초월, 메뉴 BGM
  player.gd          - 플레이어 이동, 자동 공격, 무기 비주얼, SFX
  grass_spawner.gd   - MultiMesh 기반 청크 풀 생성/관리, 월드별 풀 색상
  coin.gd            - 코인 수집, 자석 효과, 색상/스택 비주얼
  money_display.gd   - 코인/보석 보유량 표시 (메뉴/강화 화면)
  floating_text.gd   - 금액 표시 UI
  world_root.gd      - 월드 이동, 배경 처리, 월드별 배경색
  hud.gd             - HUD 표시 + 열쇠 획득 알림
  upgrade_panel.gd   - 업그레이드 패널 UI (스킬 트리)
  weapon_shop.gd     - 무기 상점 UI
  monster.gd         - 몬스터 동작, AI, 사망
  monster_spawner.gd - 몬스터/상자 스폰 (월드별 분노 보스)
  dropped_item.gd    - 드롭 아이템 (포물선 비행, 열쇠/보석 수집)
  chest.gd           - 상자 (파괴 시 열쇠 드롭)
  effects/lightning_effect.gd      - 슬라임 번개 이펙트
  effects/dust_cloud_effect.gd     - 멧돼지 먼지구름 이펙트
  effects/spark_effect.gd          - 잔디 기사 금속 스파크 이펙트
  effects/spore_effect.gd          - 마도사 포자 이펙트
  effects/crystal_shimmer_effect.gd - 수정 사슴 반짝임 이펙트
  effects/rock_debris_effect.gd    - 잔디 골렘 바위 파편 이펙트
  effects/fire_wisp_effect.gd      - 드래곤 화염 이펙트
  info_panel.gd      - 정보 패널 UI
  pause_menu.gd      - 일시정지 메뉴
  game_camera.gd     - 카메라

scenes/
  core/main.tscn       - 메인 게임 씬
  core/player.tscn     - 플레이어 씬
  core/game_camera.tscn - 카메라 씬
  world/world_root.tscn     - 월드 루트
  world/grass_spawner.tscn  - 풀 스포너
  world/coin.tscn           - 코인
  world/monster.tscn        - 몬스터
  world/dropped_item.tscn   - 드롭 아이템
  world/chest.tscn          - 상자
  effects/lightning_effect.tscn      - 번개 이펙트 씬
  effects/dust_cloud_effect.tscn     - 먼지구름 이펙트 씬
  effects/spark_effect.tscn          - 금속 스파크 이펙트 씬
  effects/spore_effect.tscn          - 포자 이펙트 씬
  effects/crystal_shimmer_effect.tscn - 수정 반짝임 이펙트 씬
  effects/rock_debris_effect.tscn    - 바위 파편 이펙트 씬
  effects/fire_wisp_effect.tscn      - 화염 이펙트 씬
  ui/main_menu.tscn         - 메인 메뉴
  ui/hud.tscn               - HUD
  ui/upgrade_panel.tscn     - 업그레이드 패널
  ui/weapon_shop.tscn       - 무기 상점
  ui/info_panel.tscn        - 정보 패널
  ui/pause_menu.tscn        - 일시정지 메뉴
  ui/floating_text.tscn     - 플로팅 텍스트
  ui/money_display.tscn     - 코인/보석 표시

resources/
  grass_data.gd                    - 풀 데이터 리소스 클래스
  shaders/grass_sway.gdshader      - 풀 흔들림 GPU 셰이더
  shaders/electric_glow.gdshader   - 전기 글로우 셰이더
  sounds/                          - 배경음 + 효과음
  images/weapon/                   - 무기 이미지 (1~10단계)
  images/monster/                  - 몬스터 스프라이트 (7종, 각 5프레임)

docs/
  game-design.md       - 게임 기획서 (디자인 철학 + 전체 시스템)
  dev-plan.md          - MVP 단계별 개발 계획
  monsters.md          - 몬스터 종류/스탯/행동/VFX
  weapons.md           - 무기 상세 정보 + 이미지 프롬프트
  skill-tree.md        - 스킬 트리 & 업그레이드 정보
  items.md             - 파워업 아이템 + 재료/제작 시스템
  image-prompts.md     - 스프라이트 시트 이미지 생성 프롬프트
```

## Git 브랜치 & 릴리즈 규칙

- **dev**: 개발 브랜치. 모든 기능 개발과 커밋은 반드시 여기서만 수행
- **main**: 프로덕션 브랜치. dev를 머지하는 것만 허용, 직접 커밋 금지
- 머지 시 annotated 태그 추가: `git tag -a "v{버전코드}-{버전이름}" -m "{버전코드} ({버전이름})"`
  - 예: `git tag -a "v12-1.0.1" -m "12 (1.0.1)"`
  - 버전코드: Google Play Console의 versionCode (정수)
  - 버전이름: Google Play Console의 versionName (x.y.z)
- **머지 요청 시 절차**:
  1. 최신 태그(이전 버전)를 찾아 알려주기
  2. 이전 태그 이후 변경된 커밋 목록을 확인하고, 유저 대상 릴리즈 노트를 구체적으로 정리하여 보여주기
  3. 버전코드/버전이름을 질문한 뒤 머지 + 태그 + 푸시 수행
  4. `export_presets.cfg`의 `version/code`와 `version/name`도 함께 업데이트

## 커밋 메시지 규칙

- **언어**: 한글
- **제목**: 한 줄, 변경 대상 + 변경 내용 요약
  - 변경이 여러 개면 쉼표 또는 `+`로 나열
  - 접두어 패턴: `{대상} {동작}: {세부 내용}`
  - 동작 예시: 추가, 수정, 개선, 제거, 교체, 상향, 최적화
- **본문** (선택): 변경이 복잡할 때만 작성, `- ` 불릿으로 주요 변경 나열
- **예시**:
  - `모바일 터치 드래그 입력 안 되는 버그 수정: UI Control mouse_filter IGNORE 설정`
  - `설정 팝업 기능 추가: 배경음/효과음/진동 토글 + 게임 데이터 초기화`
  - `미사용 _drop_penalty_coins, _spawn_scatter_coin 함수 제거`
  - `공격 범위/수집 범위 틱당 증가량 +5 → +7로 상향`

## 좌표계 주의사항

WorldRoot가 이동하므로 좌표 변환 필요:
```gdscript
# 코인에서 플레이어 위치 계산 시
var player_local_pos = get_parent().to_local(player.global_position)

# 공격 범위 계산 시 (grass_spawner 로컬 좌표)
var local_attack_center = attack_center - grass_spawner.global_position
```

## 세이브 데이터
- 위치: `~/Library/Application Support/Godot/app_userdata/풀죽이기/savegame.json`
- 저장 항목: money, upgrades, selected_world, unlocked_worlds, owned_keys, has_potion, world_strength_levels, owned_gems, unlocked_gem_skills, collected_gem_levels, has_ever_transcended

## 알려진 이슈 및 해결책

1. **코인이 플레이어 따라 움직임** -> 코인을 WorldRoot 자식으로 추가
2. **플로팅 텍스트 값이 안 바뀜** -> add_child() 후에 setup() 호출
3. **무기 스케일 누적** -> 애니메이션에서 고정 스케일 값 사용
4. **풀 렌더링 성능** -> MultiMesh + GPU 셰이더로 해결 (씬 인스턴스 제거)
5. **Tween "Target object freed" 경고** -> `queue_free()` 대신 `remove_child()` + `queue_free()` 사용
6. **queue_free 후 사운드 재생** -> AudioStreamPlayer를 root에 부착, finished 시 queue_free
