extends RefCounted
class_name SkillNode
## 스킬 트리 노드 위젯 — 순수 공유 컴포넌트(React presentational).
## ★ 매니저/게임상태를 읽지 않는다. 모든 상태는 props(Dictionary)로 받고, 아이콘=Icons·색=Palette·보석=UIKit.
## 클릭 시 on_pressed.call(btn, skill_type, target_level). 데이터 페칭은 화면(컨테이너) 책임.
##
## props = {
##   "skill_type": String,   # 아이콘 조회 + 콜백 식별용(매니저 조회엔 안 씀)
##   "name": String,
##   "state": String,        # completed | in_progress | purchasable | gem_locked | locked
##   "group_idx": int,       # 0무기 1수집 2수확
##   "current_level": int, "next_level": int, "max_level": int,
##   "sub_level": int, "sub_max": int,
##   "is_dim": bool,               # in_progress인데 서브만점/선행미충족 → 흐리게
##   "prereq_missing": Array,      # locked용 [{type,current,level}] (없으면 [])
##   "required_total": int,        # locked 하단 "스킬 N 필요"
## }

const NODE_CORNER_RADIUS := 8

static func build(props: Dictionary, node_size: float, on_pressed: Callable) -> Button:
	var skill_type: String = props.get("skill_type", "")
	var state: String = props.get("state", "locked")
	var group_idx: int = props.get("group_idx", 0)
	var current_level: int = props.get("current_level", 0)
	var next_level: int = props.get("next_level", current_level + 1)
	var max_level: int = props.get("max_level", 0)
	var sub_level: int = props.get("sub_level", 0)
	var sub_max: int = props.get("sub_max", 1)
	var is_dim: bool = props.get("is_dim", false)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(node_size, node_size)
	btn.clip_text = true

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(NODE_CORNER_RADIUS)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4

	var gc: Dictionary = Palette.GROUP_NODE_COLORS[clampi(group_idx, 0, Palette.GROUP_NODE_COLORS.size() - 1)]
	match state:
		"completed":
			style.bg_color = gc.completed
			style.set_border_width_all(3)
			style.border_color = Color(1, 0.85, 0.3)
			btn.pressed.connect(on_pressed.bind(btn, skill_type, max_level))
		"in_progress":
			style.set_border_width_all(2)
			if is_dim:
				style.bg_color = gc.purchasable
				style.border_color = gc.purchasable_border
			else:
				style.bg_color = gc.in_progress
				style.border_color = gc.in_progress_border
			btn.pressed.connect(on_pressed.bind(btn, skill_type, next_level))
		"purchasable":
			style.bg_color = gc.in_progress
			style.set_border_width_all(2)
			style.border_color = gc.in_progress_border
			btn.pressed.connect(on_pressed.bind(btn, skill_type, next_level))
		"gem_locked":
			style.bg_color = gc.purchasable
			style.set_border_width_all(2)
			style.border_color = gc.purchasable_border
			btn.pressed.connect(on_pressed.bind(btn, skill_type, next_level))
		"locked":
			style.bg_color = gc.locked
			style.set_border_width_all(2)
			style.border_color = gc.locked_border
			btn.disabled = true

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("disabled", style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.set_meta("base_style", style)
	btn.set_meta("skill_type", skill_type)

	var is_locked := state == "locked"
	var is_active := state == "completed" or state == "purchasable" or (state == "in_progress" and not is_dim)

	# 스킬 아이콘(중앙) — locked 제외
	if not is_locked:
		var icon_rect := TextureRect.new()
		icon_rect.texture = Icons.skill(skill_type)
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_rect.offset_left = 2
		icon_rect.offset_top = 2
		icon_rect.offset_right = -2
		icon_rect.offset_bottom = -2
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not is_active:
			icon_rect.modulate = Color(0.5, 0.5, 0.5)
		btn.add_child(icon_rect)

	# 보석 잠금 오버레이 + 보석 아이콘
	if state == "gem_locked":
		var overlay := ColorRect.new()
		overlay.color = Color(0, 0, 0, 0.35)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(overlay)
		var gem_size := int(node_size * 0.4)
		var inner := node_size - 4 * 2
		var c := 4 + inner / 2.0
		var gem_ctrl := UIKit.create_gem_icon(gem_size)
		gem_ctrl.position = Vector2(c - gem_size / 2.0, c - gem_size / 2.0)
		gem_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(gem_ctrl)

	# 잠금 아이콘 + 필요 개수 (locked)
	if is_locked:
		var lock_size := node_size * 0.75
		var inner := node_size - 4 * 2
		var c := 4 + inner / 2.0
		var lock_rect := TextureRect.new()
		lock_rect.texture = Icons.LOCK
		lock_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock_rect.offset_left = c - lock_size / 2.0
		lock_rect.offset_top = c - lock_size / 2.0
		lock_rect.offset_right = c + lock_size / 2.0
		lock_rect.offset_bottom = c + lock_size / 2.0
		lock_rect.modulate = Color(0.45, 0.45, 0.5)
		lock_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lock_rect)
		for req in props.get("prereq_missing", []):
			if req.get("type", "") == "_total":
				var rl := UIKit.make_label("스킬 필요(%d/%d)" % [req.get("current", 0), req.get("level", 0)], 20, Color(0.6, 0.55, 0.55), 4)
				rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				rl.anchor_right = 1.0
				rl.offset_top = c + lock_size / 2.0
				rl.offset_left = -10
				rl.offset_right = 10
				btn.add_child(rl)
				break

	var label_color := Color(0.5, 0.5, 0.55) if not is_active else Color.WHITE

	# locked면 하단 바에 "스킬 N 필요"만 표시하고 종료
	if is_locked:
		var bar_l := ColorRect.new()
		bar_l.color = Color(0, 0, 0, 0.4)
		bar_l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		bar_l.offset_top = -34.0
		bar_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bar_l)
		var req_total: int = props.get("required_total", 0)
		var rl := UIKit.make_label("스킬 %d 필요" % req_total if req_total > 0 else "잠김", 14, Color(0.55, 0.5, 0.5), 3)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bar_l.add_child(rl)
		_add_border_overlay(btn, style)
		return btn

	# 이름(상단)
	var name_label := UIKit.make_label(props.get("name", ""), 20, label_color, 5)
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	name_label.add_theme_constant_override("shadow_offset_x", 2)
	name_label.add_theme_constant_override("shadow_offset_y", 2)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	name_label.offset_top = 2
	btn.add_child(name_label)

	# 하단 바
	var bar := ColorRect.new()
	bar.color = Color(0.25, 0.2, 0.05, 0.8) if state == "completed" else Color(0, 0, 0, 0.4)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -34.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(bar)

	# 레벨(좌)
	var level_label := UIKit.make_label("Lv.%d" % (current_level if state == "completed" else current_level + 1), 20, label_color, 4)
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	level_label.offset_left = 6
	bar.add_child(level_label)

	# 서브레벨/MAX(우)
	var sub_label := Label.new()
	if state == "completed":
		sub_label.text = "✦ MAX"
		sub_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	elif sub_level > 0:
		sub_label.text = "%d/%d" % [sub_level, sub_max]
		sub_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	else:
		sub_label.text = "0/%d" % sub_max
		sub_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	sub_label.add_theme_font_size_override("font_size", 20)
	sub_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	sub_label.add_theme_constant_override("outline_size", 3)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub_label.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	sub_label.offset_left = -80
	sub_label.offset_right = -6
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(sub_label)

	_add_border_overlay(btn, style)
	return btn

# 테두리 오버레이(바 위에 그려 테두리 항상 보이게)
static func _add_border_overlay(btn: Button, style: StyleBoxFlat) -> void:
	var border_overlay := Panel.new()
	var bo := StyleBoxFlat.new()
	bo.bg_color = Color(0, 0, 0, 0)
	bo.set_corner_radius_all(NODE_CORNER_RADIUS)
	bo.border_width_top = style.border_width_top
	bo.border_width_bottom = style.border_width_bottom
	bo.border_width_left = style.border_width_left
	bo.border_width_right = style.border_width_right
	bo.border_color = style.border_color
	border_overlay.add_theme_stylebox_override("panel", bo)
	border_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(border_overlay)
