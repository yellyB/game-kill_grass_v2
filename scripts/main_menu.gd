extends Control
## 메인 메뉴 — 시작·강화·월드 선택·초월 + 코인/보석/레벨 표시. (설정 팝업은 M1.5)
const UpgradePanelScript = preload("res://scripts/upgrade_panel.gd")
const Balance = preload("res://core/balance_data.gd")
const Progression = preload("res://core/progression.gd")

var top_label: Label
var overlay: Control

func _ready() -> void:
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 20)
	add_child(center)

	var title := Label.new()
	title.text = "풀죽이기"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	center.add_child(title)

	top_label = Label.new()
	top_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_label.add_theme_font_size_override("font_size", 30)
	center.add_child(top_label)

	center.add_child(_menu_btn("시작", _on_start))
	center.add_child(_menu_btn("월드 선택", _open_world_select))
	center.add_child(_menu_btn("강화", _open_upgrade))
	center.add_child(_menu_btn("설정", _open_settings))
	_refresh()

func _open_settings() -> void:
	add_child(preload("res://scripts/settings_popup.gd").new())

func _menu_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 90)
	b.add_theme_font_size_override("font_size", 36)
	b.pressed.connect(cb)
	return b

func _refresh() -> void:
	top_label.text = "$%s   보석 %d   Lv.%d   [%s]" % [
		GameManager.format_number(GameManager.money), GameManager.owned_gems,
		GameManager.get_game_level(), Balance.WORLD_NAMES[GameManager.selected_world]]

func _on_start() -> void:
	SessionManager.start_session(GameManager.selected_world)

func _open_upgrade() -> void:
	var p := UpgradePanelScript.new()
	add_child(p)
	p.tree_exited.connect(_refresh)

func _open_world_select() -> void:
	if overlay: overlay.queue_free()
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.add_theme_constant_override("separation", 10)
	overlay.add_child(box)
	var hdr := Label.new(); hdr.text = "월드 선택"; hdr.add_theme_font_size_override("font_size", 40)
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hdr)
	for w in range(7):
		box.add_child(_world_row(w))
	var close := Button.new(); close.text = "닫기"; close.custom_minimum_size = Vector2(200, 60)
	close.pressed.connect(func(): overlay.queue_free(); overlay = null)
	box.add_child(close)

func _world_row(w: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var unlocked := GameManager.is_world_unlocked(w)
	var tr := GameManager.get_world_trans(w)
	var cleared := GameManager.collected_gem_levels.has("%d:0" % w)
	var mark := ("✓" if cleared else "")
	var lab := Label.new()
	lab.custom_minimum_size = Vector2(360, 0)
	lab.add_theme_font_size_override("font_size", 26)
	lab.text = "%d. %s  %s%s" % [w + 1, Balance.WORLD_NAMES[w], ("초월%d " % tr if tr > 0 else ""), mark]
	row.add_child(lab)
	if unlocked:
		var sel := Button.new(); sel.text = "선택"
		sel.pressed.connect(func(): GameManager.selected_world = w; SaveManager.save_game(); _refresh(); overlay.queue_free(); overlay = null)
		row.add_child(sel)
		# 초월
		if GameManager.get_world_trans(w) < Balance.MAX_TRANS:
			var tb := Button.new()
			tb.text = "초월 $%s" % GameManager.format_number(Progression.trans_cost(w, tr))
			tb.disabled = not GameManager.can_transcend(w)
			tb.pressed.connect(func(): if GameManager.do_transcend(w): SaveManager.save_game(); overlay.queue_free(); overlay = null; _open_world_select())
			row.add_child(tb)
	else:
		var nw: int = int(GameManager.unlocked_worlds.max()) + 1
		if w == nw:
			var ub := Button.new()
			ub.text = "해금 $%s" % GameManager.format_number(Progression.unlock_cost(w))
			ub.disabled = not GameManager.can_unlock_next()
			ub.pressed.connect(func(): if GameManager.unlock_next_world(): SaveManager.save_game(); overlay.queue_free(); overlay = null; _open_world_select())
			row.add_child(ub)
		else:
			var lk := Label.new(); lk.text = "🔒"; row.add_child(lk)
	return row

func _unhandled_input(event: InputEvent) -> void:
	if overlay:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		_on_start()
