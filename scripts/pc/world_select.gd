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

func _ready() -> void:
	_selected = GameManager.selected_world
	_build_popup()

# ── 월드 선택: 시작화면의 원본 팝업과 동일한 룩(중앙 패널 780폭) ──
func _build_popup() -> void:
	# 배경(어둡게)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.07, 0.08, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 자원표시(우상단) — 해금 비용 참고용
	var cur := CurrencyBar.new()
	cur.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	cur.offset_left = -420.0
	cur.offset_top = 24.0
	cur.offset_right = -30.0
	cur.offset_bottom = 170.0
	cur.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(cur)

	# 중앙 팝업 패널 (원본 _open_world_select와 동일: 폭 780)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 0)   # 폭 고정, 높이는 내용에 맞춤(룬 빠진 만큼 자동)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.09, 0.12, 0.12)
	ps.set_corner_radius_all(20)
	ps.set_border_width_all(3)
	ps.border_color = Color(0.25, 0.47, 0.4)
	ps.content_margin_left = 30
	ps.content_margin_right = 30
	ps.content_margin_top = 44
	ps.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	panel.add_child(vbox)

	# 헤더
	var header := Label.new()
	header.text = "월드 선택"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 50)
	header.add_theme_color_override("font_color", Color.WHITE)
	header.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	header.add_theme_constant_override("outline_size", 3)
	vbox.add_child(header)

	# 구분선
	var sep_m := MarginContainer.new()
	sep_m.add_theme_constant_override("margin_top", 16)
	sep_m.add_theme_constant_override("margin_bottom", 16)
	vbox.add_child(sep_m)
	var sep := ColorRect.new()
	sep.color = Color(0.24, 0.24, 0.32)
	sep.custom_minimum_size = Vector2(0, 2)
	sep_m.add_child(sep)

	# 월드 카드
	_cards_box = VBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 20)
	vbox.add_child(_cards_box)
	_rebuild_cards()

	# 여백
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	# 시작/해금 버튼 (중앙)
	var action_center := CenterContainer.new()
	action_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(action_center)
	_start_btn = Button.new()
	_start_btn.custom_minimum_size = Vector2(420, 90)
	_start_btn.add_theme_font_size_override("font_size", 38)
	_start_btn.pressed.connect(_on_start)
	action_center.add_child(_start_btn)
	_refresh_start()

	# 닫기 → 허브
	var close_center := CenterContainer.new()
	close_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(close_center)
	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.custom_minimum_size = Vector2(420, 90)
	close_btn.add_theme_font_size_override("font_size", 38)
	close_btn.pressed.connect(func(): GameManager.play_button_click(); UIRouter.goto("hub"))
	UIKit.style_button(close_btn, "muted")
	close_center.add_child(close_btn)

func _rebuild_cards() -> void:
	if _cards_box == null:
		return
	for c in _cards_box.get_children():
		c.queue_free()
	for i in WORLD_DATA.size():
		_cards_box.add_child(_make_world_card(i))

func _make_world_card(index: int) -> PanelContainer:
	# 컨테이너 역할: GameManager에서 상태 읽어 props 조립 → 공유 WorldCard 컴포넌트로 렌더
	var wd: Dictionary = WORLD_DATA[index]
	var strength: int = GameManager.get_world_strength_level(index)
	var props := {
		"name": wd.name,
		"monster": wd.monster,
		"unlocked": index in GameManager.unlocked_worlds,
		"selected": index == _selected,
		"cleared": GameManager.is_world_cleared(index),
		"strength": strength,
		"is_max": strength >= GameManager.MAX_STRENGTH_LEVEL,
		"hp_bonus_pct": GameManager.get_strength_hp_bonus_pct(strength),
		"reward_bonus_pct": GameManager.get_strength_reward_bonus_pct(strength),
	}
	return WorldCard.build(props,
		func():
			GameManager.play_button_click()
			_selected = index
			_rebuild_cards()
			_refresh_start(),
		func():
			GameManager.play_button_click()
			_show_strengthen_dialog(index))

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

# ── 초월 확인 다이얼로그 (원본 main_menu._show_strengthen_dialog 이식) ──
var _strengthen_dialog: Control = null

func _show_strengthen_dialog(world: int) -> void:
	if _strengthen_dialog:
		_strengthen_dialog.queue_free()

	var level: int = GameManager.get_world_strength_level(world)
	var cost: int = GameManager.get_strengthen_cost(world)
	var needs_gems: bool = level > 0 and not GameManager.has_collected_gems(world, level)
	var can_afford: bool = GameManager.money >= cost and not needs_gems

	var cur_hp: float = GameManager.get_strength_hp_mult(world, level)
	var cur_rw: float = GameManager.get_strength_reward_mult(world, level)
	var next_hp: float = GameManager.get_strength_hp_mult(world, level + 1)
	var next_rw: float = GameManager.get_strength_reward_mult(world, level + 1)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	root.add_child(overlay)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.2, 0.98)
	panel_style.set_corner_radius_all(15)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -300
	panel.offset_top = -185
	panel.offset_right = 300
	panel.offset_bottom = 185
	panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 28
	vbox.offset_top = 24
	vbox.offset_right = -28
	vbox.offset_bottom = -24
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "초월 Lv.%d → Lv.%d" % [level, level + 1]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 3)
	vbox.add_child(title)

	var cost_row := HBoxContainer.new()
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 8)
	var cost_label := Label.new()
	cost_label.text = "비용  "
	cost_label.add_theme_font_size_override("font_size", 28)
	cost_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	cost_row.add_child(cost_label)
	var cost_color := Color(1, 0.9, 0.3) if can_afford else Color(0.8, 0.3, 0.3)
	cost_row.add_child(UIKit.create_coin_label(GameManager.format_number(cost), 28, cost_color))
	vbox.add_child(cost_row)

	var sep := ColorRect.new()
	sep.color = Color(0.24, 0.24, 0.32)
	sep.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(sep)

	var effects_vbox := VBoxContainer.new()
	effects_vbox.add_theme_constant_override("separation", 6)
	var hp_rt := RichTextLabel.new()
	hp_rt.bbcode_enabled = true
	hp_rt.fit_content = true
	hp_rt.scroll_active = false
	hp_rt.text = "[center]풀 체력   x%.1f → [color=#ff6655]x%.1f[/color][/center]" % [cur_hp, next_hp]
	hp_rt.add_theme_font_size_override("normal_font_size", 25)
	hp_rt.add_theme_color_override("default_color", Color(0.85, 0.85, 0.9))
	effects_vbox.add_child(hp_rt)
	var rw_rt := RichTextLabel.new()
	rw_rt.bbcode_enabled = true
	rw_rt.fit_content = true
	rw_rt.scroll_active = false
	rw_rt.text = "[center]풀 보상   x%.1f → [color=#ff6655]x%.1f[/color][/center]" % [cur_rw, next_rw]
	rw_rt.add_theme_font_size_override("normal_font_size", 25)
	rw_rt.add_theme_color_override("default_color", Color(0.85, 0.85, 0.9))
	effects_vbox.add_child(rw_rt)
	vbox.add_child(effects_vbox)

	if needs_gems:
		var warn := Label.new()
		warn.text = "초월 Lv.%d 보석을 먼저 획득하세요" % level
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warn.add_theme_font_size_override("font_size", 22)
		warn.add_theme_color_override("font_color", Color(0.95, 0.3, 0.5))
		vbox.add_child(warn)
	elif GameManager.money < cost:
		var warn := Label.new()
		warn.text = "돈이 부족합니다"
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warn.add_theme_font_size_override("font_size", 22)
		warn.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
		vbox.add_child(warn)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 20)
	var cancel_btn := Button.new()
	cancel_btn.text = "취소"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.custom_minimum_size = Vector2(0, 80)
	cancel_btn.add_theme_font_size_override("font_size", 28)
	UIKit.style_button(cancel_btn, "muted")
	cancel_btn.pressed.connect(_on_strengthen_cancelled)
	btn_row.add_child(cancel_btn)
	var confirm_btn := Button.new()
	confirm_btn.text = "초월하기"
	confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_btn.custom_minimum_size = Vector2(0, 80)
	confirm_btn.add_theme_font_size_override("font_size", 28)
	confirm_btn.disabled = not can_afford
	UIKit.style_button(confirm_btn, "main" if can_afford else "muted")
	confirm_btn.pressed.connect(_on_strengthen_confirmed.bind(world))
	btn_row.add_child(confirm_btn)
	vbox.add_child(btn_row)

	_strengthen_dialog = root
	add_child(root)

func _on_strengthen_confirmed(world: int) -> void:
	if _strengthen_dialog:
		_strengthen_dialog.queue_free()
		_strengthen_dialog = null
	if GameManager.strengthen_world(world):
		GameManager.play_skill_upgrade_sound()
		_rebuild_cards()
		_refresh_start()

func _on_strengthen_cancelled() -> void:
	GameManager.play_button_click()
	if _strengthen_dialog:
		_strengthen_dialog.queue_free()
		_strengthen_dialog = null
