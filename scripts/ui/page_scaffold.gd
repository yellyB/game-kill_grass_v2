extends RefCounted
class_name PageScaffold
## 공통 페이지 레이아웃 스캐폴드 — 배경 + 상단바(뒤로·제목·게임레벨) + 콘텐츠 영역.
## 허브/월드선택 등 전체화면 페이지가 공통으로 사용. 통화(코인/보석) 표시는 페이지가
## 상단바 영역(우상단)에 자기 것을 배치(플랫폼별 위젯이라 스캐폴드가 강제하지 않음).
## ★ 순수: game_level은 인자로 받음(매니저 안 읽음). 색/위젯=Palette/UIKit.

const TOP_BAR_H := 170.0   # 상단바 높이(콘텐츠는 이 아래부터 → 우상단 자원표시와 겹치지 않음)

# page에 bg+상단바를 깔고, 그 아래 콘텐츠 Control을 반환한다.
static func setup(page: Control, title: String, game_level: int, on_back: Callable) -> Control:
	var bg := ColorRect.new()
	bg.color = Palette.BG_DARK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(bg)
	page.move_child(bg, 0)

	var back := Button.new()
	back.text = "◀ 뒤로"
	back.position = Vector2(30, 34)
	back.pressed.connect(on_back)
	UIKit.style_button(back, "muted", Vector2(190, 64))
	page.add_child(back)

	var title_lbl := UIKit.make_label(title, 42, Palette.TEXT, 4)
	title_lbl.position = Vector2(250, 40)
	page.add_child(title_lbl)

	var lvl := UIKit.make_label("게임 레벨 Lv.%d" % game_level, 28, Palette.XP, 3)
	lvl.position = Vector2(250, 100)
	page.add_child(lvl)

	# 콘텐츠 영역(상단바 아래 전체)
	var content := Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_top = TOP_BAR_H
	content.offset_left = 30.0
	content.offset_right = -30.0
	content.offset_bottom = -30.0
	page.add_child(content)
	return content
