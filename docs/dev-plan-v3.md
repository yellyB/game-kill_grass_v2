# 통합 개발 계획 v3 (콤보·액티브 재편 + 플랫폼 구조) — 간단판

> 목적: PC(스팀) 먼저 완성, 나중에 **화면(UI)만 얹어 모바일 출시** 가능한 구조 유지.
> 대원칙: **core/·로직은 공유(플랫폼 무관), UI는 뷰(signal 구독만), 입력은 PlatformService 경유.**
> 실제 구현은 별도 에이전트가 이 순서로. (설계 세부는 game-spec / 콤보 기획 참조)

## 순서

### Phase 1 — 기능 재편 (로직: 매니저/core, UI는 표시만)
- **콤보 시스템**: 기존 `combo_count` 승격 → core에 배율 공식, game_manager에 누적점수+**세션 끝 열매 정산**, signal. (처치 기준·정예 포함·거목 제외, 창 2.5초, 누적·수렴형)
- **열매 재편**: **컨테이너 제거**, 열매 = **콤보 + 거목**. 이번 세션에 만든 **상점(아이템 구매)/열매-구매/17아이템(item:true) 되돌리기**.
- **14 즉발 아이템 → 파워업 3택 복귀**(`item:false`). 애매 3종(그로스/즉시레벨/뿌리뽑기)은 보류.
- **chest_chance → "콤보 지속"(콤보 창 연장) 스킬**로 교체.
- **액티브 1/2/3**: 자동 충전 게이지 + 발동, 게임레벨 슬롯 해금. 메테오·소용돌이 구현(슬롯3 보류). **열매 강화(액티브당 2수치=충전+효과)**.

### Phase 2 — 입력 추상화
- **PlatformService 오토로드**: 추상 입력(`get_move_dir()`, `use_slot(n)`, pause/back) + vibrate/저장 창구. 지금은 **키보드 구현**, 터치는 나중.
- player/UI는 PlatformService 경유로만 입력 수신.

### Phase 3 — UILayout 반응형 마이그레이션 (뷰)
- `UILayout.*`로 리터럴 수치 추출 + 화면별 `_apply_layout()` + `form_factor_changed` 시그널 + F9 토글(가로↔세로 대조).
- 화면당: 치환 → 재배치 함수 → 헤드리스 로드 검증 + PC 육안 동일 → 커밋.
- 대상: main_menu / hud / powerup_selection / main / upgrade_panel.
- ⚠️ **Phase 1 이후에 진행**(같은 뷰 스크립트 이중작업 방지).

### Phase 4 — 밸런싱
- `balance_sim` 재조정: 콤보·열매·파워업 복귀·액티브 반영 → 목표치 재확인.

### Phase 5 — 모바일 (나중, 별도)
- 세로 UI 실수치 채우기 + PlatformService 터치 이동 구현 + 모바일 export preset. core/로직/매니저 재사용.

## 검증
- 각 단계 `godot --headless` 로드/파싱 확인(절대경로 바이너리 `/Applications/Godot.app/Contents/MacOS/Godot`).
- UI는 F9로 landscape 기존과 동일 대조(portrait 미완성 깨짐은 정상).
