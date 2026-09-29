extends RefCounted
class_name SkillNode
## 스킬 트리 노드 위젯 — 공유 컴포넌트(React식). 화면(허브/레거시 패널)은 배치만 하고
## 노드 자체는 이걸로 만든다. 색=Palette, 보석아이콘=UIKit, 데이터=GameManager.
## build()가 스타일된 Button을 반환. 클릭 시 on_pressed.call(btn, skill_type, target_level).
## ★ 인자 5개(+데이터는 매니저에서 읽음)로 공유 기준 충족.

const NODE_CORNER_RADIUS := 8
const LOCK_ICON := preload("res://resources/images/icon/lock.png")
const SKILL_ICONS := {
	"attack_power": preload("res://resources/images/skill/attack_power.png"),
	"attack_speed": preload("res://resources/images/skill/attack_speed.png"),
	"crit_chance": preload("res://resources/images/skill/crit_chance.png"),
	"crit_damage": preload("res://resources/images/skill/crit_damage.png"),
	"monster_damage": preload("res://resources/images/skill/monster_damage.png"),
	"attack_range": preload("res://resources/images/skill/attack_range.png"),
	"attack_count": preload("res://resources/images/skill/attack_count.png"),
	"move_speed": preload("res://resources/images/skill/move_speed.png"),
	"magnet_range": preload("res://resources/images/skill/magnet_range.png"),
	"grass_density": preload("res://resources/images/skill/grass_density.png"),
	"grass_quality": preload("res://resources/images/skill/grass_quality.png"),
	"combo_duration": preload("res://resources/images/skill/chest_chance.png"),
	"elite_chance": preload("res://resources/images/skill/elite_chance.png"),
	"fury_rate": preload("res://resources/images/skill/fury_rate.png"),
	"golden_chance": preload("res://resources/images/skill/golden_chance.png"),
	"golden_reward": preload("res://resources/images/skill/golden_reward.png"),
	"session_time": preload("res://resources/images/skill/session_time.png"),
}

# skill_type: 스킬 id / state: completed|in_progress|purchasable|gem_locked|locked
# node_size: 정사각 한 변 / group_idx: 0=무기 1=수집 2=수확 / on_pressed: Callable(btn, skill_type, level)
static func build(skill_type: String, state: String, node_size: float, group_idx: int, on_pressed: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(node_size, node_size)
	btn.clip_text = true

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(NODE_CORNER_RADIUS)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4

	var current_level: int = GameManager.get_upgrade_level(skill_type)
	var chain: Dictionary = GameManager.get_skill_def(skill_type)
	var max_level: int = chain.max_level
	var sub_level: int = GameManager.get_upgrade_sub_level(skill_type)
	var sub_max: int = GameManager.get_skill_sub_max(skill_type)
	var next_level := current_level + 1

	var gc: Dictionary = Palette.GROUP_NODE_COLORS[group_idx]
	var is_sub_complete := sub_level > 0 and sub_level >= sub_max
	var is_blocked := not GameManager.check_skill_prereqs(skill_type, next_level).met
	var is_dim := is_sub_complete or is_blocked
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
		icon_rect.texture = SKILL_ICONS.get(skill_type, null)
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
		lock_rect.texture = LOCK_ICON
		lock_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock_rect.offset_left = c - lock_size / 2.0
		lock_rect.offset_top = c - lock_size / 2.0
		lock_rect.offset_right = c + lock_size / 2.0
		lock_rect.offset_bottom = c + lock_size / 2.0
		lock_rect.modulate = Color(0.45, 0.45, 0.5)
		lock_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lock_rect)
		var prereq := GameManager.check_skill_prereqs(skill_type, next_level)
		for req in prereq.missing:
			if req.type == "_total":
				var rl := UIKit.make_label("스킬 필요(%d/%d)" % [req.current, req.level], 20, Color(0.6, 0.55, 0.55), 4)
				rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				rl.anchor_right = 1.0
				rl.offset_top = c + lock_size / 2.0
				rl.offset_left = -10
				rl.offset_right = 10
				btn.add_child(rl)
				break

	var label_color := Color(0.5, 0.5, 0.55) if not is_active else Color.WHITE

	if is_locked:
		return btn

	# 이름(상단)
	var name_label := UIKit.make_label(chain.name, 20, label_color, 5)
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	name_label.add_theme_constant_override("shadow_offset_x", 2)
	name_label.add_theme_constant_override("shadow_offset_y", 2)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	name_label.offset_top = 2
	btn.add_child(name_label)

	# 하단 바 — 레벨/진행
	var bar_h := 34.0
	var bar := ColorRect.new()
	bar.color = Color(0.25, 0.2, 0.05, 0.8) if state == "completed" else Color(0, 0, 0, 0.4)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -bar_h
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

	# 테두리 오버레이(바 위에 그려 테두리 항상 보이게)
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

	return btn
