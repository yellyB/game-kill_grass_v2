extends RefCounted
class_name PageScaffold
## 공통 페이지 레이아웃 스캐폴드 — 배경 + 상단바(뒤로·제목·게임레벨) + 콘텐츠 영역.
## 허브/월드선택 등 전체화면 페이지가 공통으로 사용. 통화(코인/보석) 표시는 페이지가
## 상단바 영역(우상단)에 자기 것을 배치(플랫폼별 위젯이라 스캐폴드가 강제하지 않음).
## ★ 순수: game_level은 인자로 받음(매니저 안 읽음). 색/위젯=Palette/UIKit.

const TOP_BAR_H := 170.0   # 상단바 높이(콘텐츠는 이 아래부터 → 우상단 자원표시와 겹치지 않음)
const PAD := 30.0          # 페이지 공통 패딩

# 상단바(뒤로·제목·게임레벨·자원표시)만 page에 추가. bg/콘텐츠는 추가 안 함.
# 허브(자체 bg·콘텐츠 보유)처럼 상단바만 공유하고 싶은 페이지가 사용. 반환=자원표시 노드.
static func build_top_bar(page: Control, title: String, game_level: int, on_back: Callable) -> CurrencyBar:
	var back := Button.new()
	back.text = "◀ 뒤로"
	back.position = Vector2(PAD, 34.0)
	back.pressed.connect(on_back)
	UIKit.style_button(back, "muted", Vector2(190, 64))
	page.add_child(back)

	if title != "":
		var title_lbl := UIKit.make_label(title, 42, Palette.TEXT, 4)
		title_lbl.position = Vector2(250, 40)
		page.add_child(title_lbl)

	var lvl := UIKit.make_label("게임 레벨 Lv.%d" % game_level, 28, Palette.XP, 3)
	lvl.position = Vector2(250, 104)
	page.add_child(lvl)

	# 자원표시(코인/보석) — 우상단 공통(원본 money_display와 동일한 우측 고정 박스)
	var cur := CurrencyBar.new()
	cur.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	cur.offset_left = -420.0
	cur.offset_top = 24.0
	cur.offset_right = -PAD
	cur.offset_bottom = 170.0
	cur.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	page.add_child(cur)
	return cur

# bg + 상단바 + 콘텐츠 영역(공통 패딩)까지 깔고 콘텐츠 Control 반환. (신규 전체화면 페이지용)
static func setup(page: Control, title: String, game_level: int, on_back: Callable) -> Control:
	var bg := ColorRect.new()
	bg.color = Palette.BG_DARK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(bg)
	page.move_child(bg, 0)

	build_top_bar(page, title, game_level, on_back)

	var content := Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_top = TOP_BAR_H
	content.offset_left = PAD
	content.offset_right = -PAD
	content.offset_bottom = -PAD
	page.add_child(content)
	return content
