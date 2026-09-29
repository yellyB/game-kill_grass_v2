extends RefCounted
class_name UIKit
## 뷰(View) 전용 UI 팩토리 — 버튼 스타일/코인 라벨/보석 아이콘 등 Control 노드 생성.
## ⚠️ 로직 매니저(GameManager 등)는 이 코드를 몰라야 한다(플랫폼별로 달라질 수 있는 순수 뷰).
## Phase 1.5: game_manager.gd에서 분리(코어↔뷰 디커플). 플랫폼별 스킨은 추후 이 레이어에서 분기.

const BUTTON_COLORS := {
	"main": Color(0.3, 0.75, 0.45),
	"muted": Color(0.45, 0.45, 0.5),
	"sub": Color(0.45, 0.62, 0.78),
}

const COIN_TEXTURE := preload("res://resources/images/coin.png")
const GEM_TEXTURE := preload("res://resources/images/gem.png")

# ── 공유 위젯 헬퍼 (React식 프리미티브) ──

# 스타일 패널(카드): 배경/테두리/코너 반경. 거의 모든 화면의 패널 공통.
static func make_card(bg: Color = Palette.PANEL_BG, border: Color = Palette.PANEL_BORDER,
		radius: int = 14, border_width: int = 2) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_width)
	sb.border_color = border
	card.add_theme_stylebox_override("panel", sb)
	return card

# 아웃라인 포함 라벨. 폰트크기/색만 주면 검정 아웃라인 자동.
static func make_label(text: String, font_size: int = 28, color: Color = Palette.TEXT,
		outline: int = 4) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	if outline > 0:
		lbl.add_theme_color_override("font_outline_color", Palette.OUTLINE)
		lbl.add_theme_constant_override("outline_size", outline)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

# ProgressBar 공통 스타일(채움/배경색). XP·충전·콤보·타이머 게이지 공용.
static func style_progress_bar(bar: ProgressBar, fill: Color, bg: Color = Color(0.2, 0.2, 0.25, 0.6),
		radius: int = 6) -> void:
	bar.show_percentage = false
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = bg
	bg_sb.set_corner_radius_all(radius)
	bar.add_theme_stylebox_override("background", bg_sb)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = fill
	fill_sb.set_corner_radius_all(radius)
	bar.add_theme_stylebox_override("fill", fill_sb)

# 코인 아이콘 + 금액 텍스트를 담은 HBoxContainer 생성
static func create_coin_label(amount_text: String, font_size: int = 30,
		font_color: Color = Color(1, 0.9, 0.3), outline_size: int = 0,
		center: bool = false) -> HBoxContainer:
	var icon_size = int(font_size * 0.85)
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(font_size * 0.2))
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if center:
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon = TextureRect.new()
	icon.texture = COIN_TEXTURE
	icon.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon)

	var label = Label.new()
	label.text = amount_text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if outline_size > 0:
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		label.add_theme_constant_override("outline_size", outline_size)
	hbox.add_child(label)

	return hbox

# 보석 아이콘 = gem.png 텍스처(코인과 동일한 그림 에셋 방식). 구 폴리곤 대체.
# tint: 이미지가 이미 마젠타로 채색돼 있어 무시(호환용 인자). 구매가능/불가 신호는 텍스트 색이 담당.
static func create_gem_icon(icon_size: int, _tint: Color = Color(0.9, 0.2, 0.4)) -> Control:
	var icon = TextureRect.new()
	icon.texture = GEM_TEXTURE
	icon.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 코인 아이콘과 동일하게 세로 중앙 고정 → 숫자와 정렬 맞춤.
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon

static func style_button(btn: Button, color_type: String = "main", btn_size: Vector2 = Vector2.ZERO) -> void:
	var main_color = BUTTON_COLORS.get(color_type, BUTTON_COLORS["main"])
	if btn_size != Vector2.ZERO:
		var font_size = int(btn_size.y * 35.0 / 75.0)
		btn.custom_minimum_size = btn_size
		btn.add_theme_font_size_override("font_size", font_size)
		if btn.icon:
			var aspect = float(btn.icon.get_width()) / float(btn.icon.get_height())
			btn.add_theme_constant_override("icon_max_width", int(font_size * aspect))
		else:
			btn.add_theme_constant_override("icon_max_width", font_size)
	var shadow_color = main_color.darkened(0.3)

	# Normal
	var style_n = StyleBoxFlat.new()
	style_n.bg_color = main_color
	style_n.corner_radius_top_left = 18
	style_n.corner_radius_top_right = 18
	style_n.corner_radius_bottom_left = 18
	style_n.corner_radius_bottom_right = 18
	style_n.border_width_bottom = 6
	style_n.border_color = shadow_color
	style_n.content_margin_left = 48
	style_n.content_margin_right = 48
	style_n.content_margin_top = 12
	style_n.content_margin_bottom = 14
	btn.add_theme_stylebox_override("normal", style_n)

	# Hover
	var style_h = style_n.duplicate()
	style_h.bg_color = main_color.lightened(0.1)
	btn.add_theme_stylebox_override("hover", style_h)

	# Pressed
	var style_p = StyleBoxFlat.new()
	style_p.bg_color = main_color.darkened(0.1)
	style_p.corner_radius_top_left = 18
	style_p.corner_radius_top_right = 18
	style_p.corner_radius_bottom_left = 18
	style_p.corner_radius_bottom_right = 18
	style_p.border_width_bottom = 2
	style_p.border_color = shadow_color
	style_p.content_margin_left = 48
	style_p.content_margin_right = 48
	style_p.content_margin_top = 16
	style_p.content_margin_bottom = 10
	btn.add_theme_stylebox_override("pressed", style_p)

	# Disabled
	var style_d = style_n.duplicate()
	style_d.bg_color = main_color.darkened(0.4)
	style_d.border_color = shadow_color.darkened(0.4)
	btn.add_theme_stylebox_override("disabled", style_d)

	# Focus (remove default outline)
	var style_f = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("focus", style_f)

	# Font colors
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.65, 0.65, 0.7))
