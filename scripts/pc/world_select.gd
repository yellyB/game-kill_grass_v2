extends Control
## 월드 선택 (전체화면 페이지). 좌=룬(이번 판) / 우=월드 카드+초월 / 하단=시작.
## ★ PC 전용 뷰. 데이터는 GameManager에서 읽음(화면=컨테이너). 색=Palette, 위젯=UIKit.

const WORLD_DATA := [
	{"name": "슬라임 늪", "monster": "슬라임"},
	{"name": "들판", "monster": "멧돼지"},
	{"name": "기사의 성벽", "monster": "잔디 기사"},
	{"name": "마법의 숲", "monster": "마도사"},
	{"name": "수정 호수", "monster": "수정 사슴"},
	{"name": "고대 유적", "monster": "잔디 골렘"},
	{"name": "용의 봉우리", "monster": "드래곤"},
]

var _selected: int = 0
var _cards_box: VBoxContainer = null
var _rune_box: VBoxContainer = null

func _ready() -> void:
	_selected = GameManager.selected_world
	var bg := ColorRect.new()
	bg.color = Palette.BG_DARK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)

	_build_top_bar()
	_build_left_rune()
	_build_right_worlds()
	_build_start()

func _build_top_bar() -> void:
	var back := Button.new()
	back.text = "◀ 허브"
	back.position = Vector2(30, 30)
	back.add_theme_font_size_override("font_size", 28)
	back.pressed.connect(func(): GameManager.play_button_click(); UIRouter.goto("hub"))
	UIKit.style_button(back, "muted", Vector2(200, 64))
	add_child(back)

	var lvl := UIKit.make_label("게임 레벨 Lv.%d" % GameManager.get_game_level(), 34, Palette.XP, 4)
	lvl.position = Vector2(260, 36)
	add_child(lvl)

# ── 좌 ~35%: 룬 ──
func _build_left_rune() -> void:
	var panel := UIKit.make_card(Color(0.10, 0.13, 0.16))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_right = 0.34
	panel.offset_left = 30.0
	panel.offset_top = 120.0
	panel.offset_right = -10.0
	panel.offset_bottom = -140.0
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	vb.add_child(UIKit.make_label("🔮 룬 (세션당 1개)", 32, Color(0.7, 0.85, 0.6), 4))
	if GameManager.get_game_level() < 8:
		vb.add_child(UIKit.make_label("게임 레벨 8부터 개방", 24, Palette.TEXT_DIM, 3))
		return
	_rune_box = VBoxContainer.new()
	_rune_box.add_theme_constant_override("separation", 10)
	vb.add_child(_rune_box)
	_refresh_rune()

func _refresh_rune() -> void:
	if _rune_box == null:
		return
	for c in _rune_box.get_children():
		c.queue_free()
	for r in GameManager.RUNE_DEFS:
		var unlocked: bool = GameManager.is_rune_unlocked(r.type)
		var active: bool = GameManager.active_rune == r.type
		var b := Button.new()
		b.text = "%s — %s" % [r.name, r.desc]
		b.add_theme_font_size_override("font_size", 22)
		b.disabled = not unlocked
		UIKit.style_button(b, "main" if active else "muted", Vector2(0, 64))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if unlocked:
			b.pressed.connect(func():
				GameManager.play_button_click()
				GameManager.set_active_rune("" if GameManager.active_rune == r.type else r.type)
				_refresh_rune())
		_rune_box.add_child(b)

# ── 우 ~65%: 월드 카드 (세로) ──
func _build_right_worlds() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.anchor_left = 0.36
	scroll.offset_left = 10.0
	scroll.offset_top = 120.0
	scroll.offset_right = -30.0
	scroll.offset_bottom = -140.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_cards_box = VBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 16)
	_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cards_box)
	_rebuild_cards()

func _rebuild_cards() -> void:
	if _cards_box == null:
		return
	for c in _cards_box.get_children():
		c.queue_free()
	for i in WORLD_DATA.size():
		_cards_box.add_child(_make_world_card(i))

func _make_world_card(index: int) -> PanelContainer:
	# 원본 _create_world_card 디자인 이식(높이 143, O/X, 이름38/몬스터26, 초월Lv+보너스, 초월버튼 150×108)
	var wd: Dictionary = WORLD_DATA[index]
	var unlocked: bool = index in GameManager.unlocked_worlds
	var selected: bool = index == _selected

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

		var icon := UIKit.make_label("O", 43, Color(0.3, 0.8, 0.55), 0)
		hbox.add_child(icon)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info.add_theme_constant_override("separation", 8)
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(info)
		info.add_child(UIKit.make_label(wd.name, 38, Color(1, 0.95, 0.8), 2))
		info.add_child(UIKit.make_label(wd.monster, 26, Color(0.62, 0.7, 0.66), 0))

		var strength: int = GameManager.get_world_strength_level(index)
		if GameManager.is_world_cleared(index):
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
				str_info.add_child(UIKit.make_label("체력+%d%%" % int(strength * 40), 23, Color(0.7, 0.65, 0.4), 0))
				str_info.add_child(UIKit.make_label("보상+%d%%" % int(strength * 50), 23, Color(0.7, 0.65, 0.4), 0))
			var str_btn := Button.new()
			str_btn.add_theme_font_size_override("font_size", 36)
			str_btn.custom_minimum_size = Vector2(150, 108)
			if strength >= GameManager.MAX_STRENGTH_LEVEL:
				str_btn.text = "MAX"
				str_btn.disabled = true
				UIKit.style_button(str_btn, "muted")
			else:
				str_btn.text = "초월"
				UIKit.style_button(str_btn, "main")
				str_btn.pressed.connect(func():
					if GameManager.strengthen_world(index):
						GameManager.play_skill_upgrade_sound()
						_rebuild_cards()
					else:
						GameManager.play_button_click())
			str_hbox.add_child(str_btn)

	# 카드 클릭 오버레이(선택)
	var pick := Button.new()
	pick.flat = true
	pick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pick.focus_mode = Control.FOCUS_NONE
	pick.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	pick.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pick.pressed.connect(func():
		GameManager.play_button_click()
		_selected = index
		_rebuild_cards()
		_refresh_start())
	card.add_child(pick)
	card.move_child(pick, 0)
	return card

# ── 하단: 시작 ──
func _build_start() -> void:
	var btn := Button.new()
	btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	btn.offset_left = -440.0
	btn.offset_top = -110.0
	btn.offset_right = -20.0
	btn.offset_bottom = -20.0
	btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	btn.add_theme_font_size_override("font_size", 40)
	_start_btn = btn
	btn.pressed.connect(_on_start)
	add_child(btn)
	_refresh_start()

var _start_btn: Button = null

func _refresh_start() -> void:
	if _start_btn == null:
		return
	var unlocked: bool = _selected in GameManager.unlocked_worlds
	if unlocked:
		_start_btn.text = "시작 ▶"
		UIKit.style_button(_start_btn, "main", Vector2(420, 90))
	else:
		_start_btn.text = "해금 ▶"
		UIKit.style_button(_start_btn, "sub", Vector2(420, 90))

func _on_start() -> void:
	var unlocked: bool = _selected in GameManager.unlocked_worlds
	if unlocked:
		GameManager.play_confirm_click()
		GameManager.selected_world = _selected
		SaveManager.save_game()
		UIRouter.goto("game")
	else:
		# 해금 시도(다음 순번 월드 + 이전 월드 클리어 + 코인 충분 시)
		var cost: int = GameManager.WORLD_UNLOCK_COSTS[_selected]
		var is_next: bool = _selected == GameManager.unlocked_worlds.max() + 1
		var prev_ok: bool = GameManager.is_world_cleared(_selected - 1) if _selected > 0 else true
		if is_next and prev_ok and GameManager.money >= cost:
			GameManager.money -= cost
			GameManager.money_changed.emit(GameManager.money)
			GameManager.unlocked_worlds.append(_selected)
			SaveManager.save_game()
			GameManager.play_unlock_sound()
			_rebuild_cards()
			_refresh_start()
		else:
			GameManager.play_button_click()
