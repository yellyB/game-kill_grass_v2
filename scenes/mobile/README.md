# scenes/mobile — 모바일 UI 세트 (세로)

PC(`scenes/pc/`) 구성을 복제해 만든 **독립** 모바일 UI 세트. PC 씬을 공유하지 않는다.
공유되는 것은 core/·매니저·`scenes/game/world.tscn`(게임플레이 월드)·`scripts/ui/ui_kit.gd`·`PowerupData`뿐.

- 씬: main·main_menu·hud·upgrade_panel·money_display·confirm_dialog·powerup_selection
- 스크립트: `scripts/mobile/`의 같은 이름들
- 방향: `project.godot` `window/handheld/orientation="portrait"`
- 라우팅: `PlatformService.uses_touch()` 기기 → `UIRouter.SETS["mobile"]` 자동 로드

## 데스크톱에서 미리보기
```
Godot --path . res://scenes/boot.tscn --mobile-ui
```
(에디터의 Run 인자에 `--mobile-ui` 넣어도 됨) → 터치 백엔드 + 모바일 세트로 실행.

## TODO (세로 레이아웃 폴리시)
현재는 PC(가로 1920×1080 기준) 좌표를 그대로 복제한 상태라, 세로 화면에선 배치가 어긋난다.
세로에 맞게 각 씬/스크립트의 앵커·좌표를 조정 필요(디바이스/프리뷰로 반복).
