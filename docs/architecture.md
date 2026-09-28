# 아키텍처 — 한 코어, 여러 플랫폼

> 목표: **하나의 로직으로 모바일/스팀(및 향후 플랫폼) 화면을 모두 개발**한다.
> 전략 B = 플랫폼별 UI 씬 세트를 따로 두되, 로직/입력은 공유한다.

## 레이어

```
core/            순수 정적 SSOT (Node 무관). balance/economy/progression/skills/combo/stat_block
   ↓ preload
autoload/*_manager.gd   로직 매니저(싱글턴). 상태 소유 + signal 방출. Control 노드 생성 금지.
   ↓ signal 구독 / 메서드 호출
scripts/ (뷰)    씬 컨트롤러. 순수 뷰: 표시·연출·입력 수신. 상태는 매니저에만.
   ├ scripts/ui/ui_kit.gd   뷰 전용 UI 팩토리(버튼/코인라벨/보석아이콘). 플랫폼 스킨 분기 지점.
   └ (Phase 2) PlatformService  입력/진동/뒤로가기 추상화
(Phase 3) 플랫폼 UI 로더   부팅 시 플랫폼에 맞는 UI 씬 세트 선택
```

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
| 입력 추상화 (PlatformService) | ⏳ Phase 2 |
| 플랫폼별 UI 씬 세트 + 로더 | ⏳ Phase 3 |
| 모바일 세로 UI + 터치 백엔드 + 익스포트 | ⏳ Phase 5 |

## 아직 남은 커플링 (알려진 것)

- `player.gd`가 `KEY_1/2`·`InputEventScreenTouch`를 직접 처리 → Phase 2에서 PlatformService로.
- UI 씬은 현재 PC(가로) 1벌뿐 → Phase 3에서 플랫폼별 세트로.
- 오디오(SFX/BGM)는 매니저·씬에 혼재 → 뷰/프레젠테이션 관심사, 우선순위 낮음(추후 정리 후보).
