extends RefCounted
class_name WorldCard
## 월드 카드 컴포넌트("붕어빵 틀"). 리스트 = 이 카드들의 모음.
## ★ 순수 표시 컴포넌트 — 게임 상태(GameManager) 안 읽음. 데이터는 props로 주입, 상호작용은 콜백 위임.
## 디자인 시스템만 참조(Icons/UIKit/Palette). CurrencyChip·SkillNode와 동일 패턴.
##
## props = {
##   name:String, monster:String,
##   unlocked:bool, selected:bool, cleared:bool,
##   strength:int, is_max:bool, hp_bonus_pct:int, reward_bonus_pct:int,
## }
## on_select  : 카드 클릭 시 (사운드/선택 처리는 호출측이)
## on_transcend : 초월 버튼 클릭 시 (사운드/다이얼로그는 호출측이)

static func build(props: Dictionary, on_select: Callable, on_transcend: Callable) -> PanelContainer:
	var unlocked: bool = props.get("unlocked", false)
	var selected: bool = props.get("selected", false)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 143)
	var st := StyleBoxFlat.new()
	if selected:
		st.bg_color = Color(0.12, 0.24, 0.2) if unlocked else Color(0.15, 0.15, 0.22)
		st.border_color = Color(0.35, 0.85, 0.62) if unlocked else Color(0.45, 0.45, 0.7)
		st.set_border_width_all(3)
	else:
		st.bg_color = Color(0.1, 0.17, 0.15) if unlocked else Color(0.09, 0.1, 0.14)
		st.border_color = Color(0.25, 0.55, 0.42) if unlocked else Color(0.22, 0.26, 0.35)
		st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	st.content_margin_left = 26
	st.content_margin_right = 26
	st.content_margin_top = 18
	st.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", st)

	if not unlocked:
		var lock_c := CenterContainer.new()
		lock_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lock := TextureRect.new()
		lock.texture = Icons.LOCK
		lock.custom_minimum_size = Vector2(108, 108)
		lock.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.modulate = Color(0.4, 0.4, 0.5)
		lock_c.add_child(lock)
		card.add_child(lock_c)
	else:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(hbox)

		hbox.add_child(UIKit.make_label("O", 43, Color(0.3, 0.8, 0.55), 0))

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info.add_theme_constant_override("separation", 8)
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(info)
		info.add_child(UIKit.make_label(props.get("name", ""), 38, Color(1, 0.95, 0.8), 2))
		info.add_child(UIKit.make_label(props.get("monster", ""), 26, Color(0.62, 0.7, 0.66), 0))

		if props.get("cleared", false):
			var strength: int = props.get("strength", 0)
			var str_hbox := HBoxContainer.new()
			str_hbox.add_theme_constant_override("separation", 10)
			str_hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hbox.add_child(str_hbox)
			var str_info := VBoxContainer.new()
			str_info.add_theme_constant_override("separation", 1)
			str_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			str_hbox.add_child(str_info)
			if strength > 0:
				str_info.add_child(UIKit.make_label("초월 Lv.%d" % strength, 28, Color(1.0, 0.8, 0.3), 2))
				str_info.add_child(UIKit.make_label("체력+%d%%" % int(props.get("hp_bonus_pct", 0)), 23, Color(0.7, 0.65, 0.4), 0))
				str_info.add_child(UIKit.make_label("보상+%d%%" % int(props.get("reward_bonus_pct", 0)), 23, Color(0.7, 0.65, 0.4), 0))
			var str_btn := Button.new()
			str_btn.add_theme_font_size_override("font_size", 36)
			str_btn.custom_minimum_size = Vector2(150, 108)
			if props.get("is_max", false):
				str_btn.text = "MAX"
				str_btn.disabled = true
				UIKit.style_button(str_btn, "muted")
			else:
				str_btn.text = "초월"
				UIKit.style_button(str_btn, "main")
				str_btn.pressed.connect(on_transcend)
			str_hbox.add_child(str_btn)

	# 카드 클릭 오버레이(선택)
	var pick := Button.new()
	pick.flat = true
	pick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pick.focus_mode = Control.FOCUS_NONE
	pick.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	pick.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pick.pressed.connect(on_select)
	card.add_child(pick)
	card.move_child(pick, 0)
	return card
