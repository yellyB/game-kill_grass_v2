extends PanelContainer
class_name CurrencyChip
## 자원 칩 = "붕어빵 틀". 테두리 박스 + 아이콘 + 숫자. 코인/보석/정수 무엇이 될지는 쓸 때 주입.
## ★ 순수 표시 컴포넌트 — 게임 상태(GameManager) 안 읽음. 값은 set_value()로 외부가 넣어준다.
## 아이콘/색은 인자(붕어빵 속). 아웃라인/nudge/패널 스타일은 틀이 고정으로 담당.

# 숫자가 아이콘보다 아래로 내려가 보이는 폰트 메트릭 보정(위로 px).
const NUM_NUDGE := 5

var _label: Label = null

# 틀 찍어내기: 아이콘·숫자색만 주면 완성된 칩 반환.
static func make(icon: Texture2D, value_color: Color, icon_size: int = 36, font_size: int = 38) -> CurrencyChip:
	var chip := CurrencyChip.new()
	chip._build(icon, value_color, icon_size, font_size)
	return chip

func _build(icon: Texture2D, value_color: Color, icon_size: int, font_size: int) -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_END
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_style()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	var ic := TextureRect.new()
	ic.texture = icon
	ic.custom_minimum_size = Vector2(icon_size, icon_size)
	ic.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)

	_label = Label.new()
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", value_color)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 4)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)
	_nudge_up(_label)

func set_value(text: String) -> void:
	if is_instance_valid(_label):
		_label.text = text

# 구매 시 박스 아래로 떠오르는 -비용 피드백(팝 + 상승 + 페이드).
func show_cost_floating(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 34)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.position = Vector2(0, size.y)
	lbl.size = Vector2(size.x, 40)
	add_child(lbl)
	lbl.scale = Vector2(0.5, 0.5)
	lbl.pivot_offset = Vector2(lbl.size.x, lbl.size.y / 2.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "position:y", size.y + 30, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.4)
	tween.chain().tween_callback(lbl.queue_free)

# ── 틀 내부 고정 스타일 ──
func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.16, 0.22, 0.9)
	style.set_border_width_all(2)
	style.border_color = Color(0.65, 0.7, 0.8, 0.6)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0.6, 0.7, 0.9, 0.25)
	style.shadow_size = 4
	add_theme_stylebox_override("panel", style)

# 라벨을 HBox 안에서 위로 NUM_NUDGE px 올림(숫자가 아래로 처져 보이는 폰트 메트릭 보정).
func _nudge_up(lbl: Label) -> void:
	var row := lbl.get_parent()
	var idx := lbl.get_index()
	row.remove_child(lbl)
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_top", -NUM_NUDGE)
	mc.add_theme_constant_override("margin_bottom", NUM_NUDGE)
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mc.add_child(lbl)
	row.add_child(mc)
	row.move_child(mc, idx)
