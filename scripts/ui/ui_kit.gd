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

static func create_gem_icon(icon_size: int, tint: Color = Color(0.9, 0.2, 0.4)) -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(icon_size, icon_size)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 컨테이너(HBox 등)에서 세로로 늘어나면 폴리곤이 위쪽(0~size)에 그려져 아이콘이 위로 뜬다.
	# 코인 아이콘(SHRINK_CENTER)과 동일하게 세로 중앙 고정 → 숫자와 정렬 맞춤.
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cx = icon_size * 0.5
	var cy = icon_size * 0.5
	var sx = icon_size * 0.38
	var sy = icon_size * 0.5
	var body = Polygon2D.new()
	body.color = tint
	body.polygon = PackedVector2Array([
		Vector2(cx, cy - sy), Vector2(cx + sx, cy - sy * 0.35),
		Vector2(cx + sx, cy + sy * 0.35), Vector2(cx, cy + sy),
		Vector2(cx - sx, cy + sy * 0.35), Vector2(cx - sx, cy - sy * 0.35),
	])
	container.add_child(body)
	var hl = Polygon2D.new()
	hl.color = Color(tint.r + 0.1, tint.g + 0.3, tint.b + 0.2, 0.5)
	hl.polygon = PackedVector2Array([
		Vector2(cx, cy - sy), Vector2(cx + sx, cy - sy * 0.35),
		Vector2(cx, cy), Vector2(cx - sx, cy - sy * 0.35),
	])
	container.add_child(hl)
	return container

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
