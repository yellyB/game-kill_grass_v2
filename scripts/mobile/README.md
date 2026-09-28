# scenes/mobile — 모바일 UI 세트 (미제작)

모바일 전용 UI 씬을 여기에 만든다. **PC 씬(scenes/pc/)을 공유하지 않는다.**

만들 것: `main_menu.tscn`, `main.tscn`(공유 `res://scenes/game/world.tscn` 인스턴스 + 모바일 HUD/오버레이 조립),
그리고 모바일 레이아웃의 `hud.tscn` 등.

만든 뒤 `autoload/ui_router.gd`의 `SETS`에 추가:
```gdscript
"mobile": {
    "main_menu": "res://scenes/mobile/main_menu.tscn",
    "game":      "res://scenes/mobile/main.tscn",
},
```
그러면 `PlatformService.uses_touch()`인 기기에서 자동으로 이 세트가 로드된다.
공유되는 것은 core/·매니저·`scenes/game/world.tscn`(게임플레이 월드)뿐 — UI는 완전 분리.
