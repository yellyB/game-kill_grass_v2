# 아키텍처 — 한 코어, 여러 플랫폼

> 목표: **하나의 로직으로 모바일/스팀(및 향후 플랫폼) 화면을 모두 개발**한다.
> 전략 B = 플랫폼별 UI 씬 세트를 따로 두되, 로직/입력은 공유한다.

## 레이어 & 폴더 (UI 완전 격리)

**공유(플랫폼 무관)** — 이것만 여러 플랫폼이 함께 쓴다:
```
core/                 순수 정적 SSOT (Node 무관). balance/economy/progression/skills/combo/stat_block
autoload/*.gd         로직 매니저(싱글턴). 상태 소유 + signal 방출. Control 노드 생성 금지.
                      GameManager/WeaponManager/ActiveManager/SessionManager/PlatformService/UIRouter/SaveManager
scenes/game/          게임플레이 월드(공유): world.tscn(+player/grass/field/coin/elite/great_tree/dropped_item/camera/floating_text)
scripts/game/         위 월드 스크립트 + powerup_data.gd(파워업 콘텐츠)
scripts/ui/ui_kit.gd  공유 UI 프리미티브 툴킷(버튼/코인라벨/보석아이콘)
scripts/boot.gd       부팅 로더
```

**플랫폼별 UI(격리)** — 서로 공유하지 않는다:
```
scenes/pc/    scripts/pc/     PC UI 세트: main·main_menu·hud·upgrade_panel·money_display·confirm_dialog·powerup_selection·settings_popup
scenes/mobile/ scripts/mobile/ 모바일 UI 세트(별도 제작 예정 — 지금은 비어있음)
```

부팅 → `boot.gd` → `UIRouter.goto("main_menu")` → 플랫폼에 맞는 세트 로드.
PC `main.tscn`은 공유 `scenes/game/world.tscn`을 인스턴스 + PC HUD/오버레이 조립. 모바일도 같은 world를 재사용.

## 계약 (지켜야 할 규칙)

1. **매니저는 뷰를 모른다.** 매니저/core는 `Label`·`Button`·`StyleBoxFlat` 등 Control 노드를 만들지 않는다. UI 생성은 `UIKit`(뷰) 또는 씬에서.
2. **뷰는 상태를 갖지 않는다.** 게임 상태(돈/레벨/콤보/정수/세션시간/액티브충전 등)는 매니저가 소유. 뷰는 signal로 받고 getter로 읽는다.
3. **뷰 → 코어는 메서드 호출로만.** 뷰가 매니저 변수를 직접 대입하지 않는다(예: `SessionManager.add_time()` O / `main.session_time = x` X).
4. **코어 → 뷰는 signal로만.** 매니저가 특정 뷰 노드를 직접 참조/호출하지 않는다.
5. **입력은 PlatformService 경유**(Phase 2). 뷰가 `KEY_*`/터치를 직접 분기하지 않는다.
6. **밸런스 수치는 core/ 소유.** 게임과 Python 시뮬이 동일 레이어 공유(캡 금지 원칙: `game-spec.md`).

## 현재 상태 (Phase 1.5 완료 시점)

| 항목 | 상태 |
|------|------|
| core/ SSOT (balance/economy/progression/skills/combo) | ✅ 공유 |
| 매니저 signal 방출 (GameManager/ActiveManager/SessionManager/…) | ✅ |
| UI 팩토리 분리 (GameManager → UIKit) | ✅ Phase 1.5 |
| 세션 클록 분리 (main.gd → SessionManager) | ✅ Phase 1.5 |
| 입력/진동/종료 추상화 (PlatformService) | ✅ Phase 2 |
| 플랫폼별 UI 씬 세트 로더 (UIRouter) | ✅ Phase 3 |
| 밸런스 시뮬 (콤보→정수→액티브 페이싱) | ✅ Phase 4 |
| 모바일 터치 백엔드 + Android 익스포트 | ✅ Phase 5 |
| **UI 완전 격리 (game/ 공유 vs pc/·mobile/ 분리)** | ✅ (PC 씬 공유 제거) |
| 모바일 전용 UI 세트(scenes/mobile/) 제작 | ⏳ 별도 작업(디바이스 반복) |

## PlatformService (Phase 2)

`autoload/platform_service.gd` — 플랫폼 차이를 감추는 서비스.
- `is_mobile()`, `platform_name()`, `input_backend()`/`uses_touch()` (KEYBOARD_MOUSE | TOUCH)
- `vibrate(ms)` — 설정 + 모바일일 때만 (데스크톱 자동 무시)
- `request_quit()` — 앱 종료(모든 `get_tree().quit()`는 이걸 경유)

**입력 규약**: 불연속 게임 액션은 Godot InputMap 액션으로(이식성). 이동=`move_*`, 액티브=`active_slot_1/2`.
모바일은 HUD 버튼이 같은 `ActiveManager.fire_slot()`을 호출 → 물리 키코드 하드코딩 없음.
플랫폼 능력 차이(터치 여부/진동/종료)만 PlatformService가 담당.

## UIRouter (Phase 3) — 플랫폼별 UI 세트 로더

`autoload/ui_router.gd` + `scenes/boot.tscn`(run/main_scene).
- 부팅 → `boot.gd` → `UIRouter.goto("main_menu")` → 플랫폼 세트의 메뉴 진입.
- `SETS`: 논리 이름(`main_menu`/`game`) → 플랫폼별 씬 경로. 현재 `pc`만. `current_set()`이 `PlatformService.uses_touch()`로 분기(모바일 세트 없으면 pc fallback).
- 모든 씬 전환은 `UIRouter.goto(logical)` 경유(직접 `change_scene_to_file` 금지).
- **새 플랫폼 추가**: `SETS`에 세트 1개 + 씬 파일만 추가 → 코드 변경 없음.

## 모바일 (Phase 5)

- **터치 입력**: 이동=드래그(`player.gd`, 백엔드 무관 동작). 액티브=HUD 온스크린 버튼(`_setup_touch_active_buttons`, `PlatformService.uses_touch()`일 때만). 키보드 1/2와 동일하게 `ActiveManager.fire_slot()` 호출.
- **UI 세트**: `UIRouter.SETS["mobile"]` 존재(현재 가로 UI 공유). 전용 세로 레이아웃이 필요하면 이 경로만 mobile 전용 씬으로 교체 → 로직/입력/밸런스 무변경.
- **방향**: `window/handheld/orientation="landscape"` (v2는 가로 설계).
- **익스포트**: `export_presets.cfg` Android 프리셋(arm64, `com.yelly.pooljukigi`, etc2/astc). iOS는 preset 추가 필요.
- **남은 것**: 모바일 전용 세로 레이아웃은 디바이스 위 비주얼 반복이 필요(헤드리스 검증 불가) → 별도 작업.

## UI 패리티 점검 (PC↔모바일 누락 방지)

UI를 플랫폼별로 분리했으므로, 화면 요소를 한쪽에만 넣고 빠뜨리기 쉽다. 이를 막는 단일 매니페스트 + 점검기:

- **매니페스트**: `docs/ui_features.json` — 모든 UI 요소를 `{scope, screen, pc, mobile, desc}`로 선언. **단일 출처 겸 체크리스트.**
  - `scope`: `both`(양쪽 필수) / `pc_only` / `mobile_only`
- **점검**: `python3 sim/ui_parity.py` → 표 출력, `both`인데 한쪽 누락이면 종료코드 1.
- **규칙 (습관화)**: 화면에 요소를 **추가/삭제하면 매니페스트 한 줄**을 갱신하고 점검을 돌린다.
  - 예) 모바일에 콤보 미터 구현 → `hud_combo_meter`의 `mobile: true`. 아직 안 했으면 `false` → 점검이 "누락!"으로 잡아줌.
- 이렇게 하면 "어떤 요소가 어디에 있고 없는지"를 명령 하나로 확인 → 빠뜨림 방지.

## 아직 남은 커플링 (알려진 것)

- 오디오(SFX/BGM)는 매니저·씬에 혼재 → 뷰/프레젠테이션 관심사, 우선순위 낮음(추후 정리 후보).
