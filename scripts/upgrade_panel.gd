extends Control
## 강화 패널 — 스킬 강화(코인) + 보석 게이트 해금 + 무기 구매. 코드 주도 UI.
const Skills = preload("res://core/skills.gd")

var _list: VBoxContainer
var _header: Label
var _weapon_row: HBoxContainer

const SKILL_NAMES := {
	"attack_power": "공격력", "attack_speed": "공격 속도", "attack_range": "공격 범위",
	"attack_count": "공격 개수", "crit_chance": "치명 확률", "crit_damage": "치명 피해",
	"grass_density": "풀 밀도", "grass_quality": "풀 등급", "magnet_range": "수집 범위",
	"golden_chance": "황금풀 확률", "move_speed": "이동 속도", "session_time": "세션 시간",
	"goomok_dmg": "거목 피해", "level_gauge": "레벨 게이지",
}
# core에 있는 스킬만 노출(정예확률/게이지 등 미모델 스킬은 후속)
const SHOWN := ["attack_power", "attack_speed", "attack_range", "attack_count",
	"crit_chance", "crit_damage", "grass_density", "grass_quality",
	"golden_chance", "move_speed", "session_time", "goomok_dmg"]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.1, 0.09, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	root.offset_left = 40; root.offset_top = 20; root.offset_right = -40; root.offset_bottom = -20
	add_child(root)

	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 34)
	root.add_child(_header)

	# 무기
	_weapon_row = HBoxContainer.new()
	_weapon_row.add_theme_constant_override("separation", 16)
	root.add_child(_weapon_row)

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	sc.add_child(_list)

	var close := Button.new()
	close.text = "닫기"
	close.custom_minimum_size = Vector2(200, 70)
	close.pressed.connect(func(): queue_free())
	root.add_child(close)

	GameManager.money_changed.connect(func(_m): _refresh())
	GameManager.gems_changed.connect(func(_g): _refresh())
	WeaponManager.weapon_changed.connect(func(_l): _refresh())
	_refresh()

func _refresh() -> void:
	_header.text = "강화    $%s    보석 %d" % [GameManager.format_number(GameManager.money), GameManager.owned_gems]
	# 무기 행
	for c in _weapon_row.get_children(): c.queue_free()
	var wlab := Label.new()
	wlab.add_theme_font_size_override("font_size", 24)
	wlab.text = "무기: %s" % WeaponManager.get_current().name
	_weapon_row.add_child(wlab)
	if WeaponManager.has_next():
		var wbtn := Button.new()
		wbtn.text = "→ %s  $%s (Lv%d)" % [WeaponManager.WEAPONS[WeaponManager.current_weapon_level + 1].name,
			GameManager.format_number(WeaponManager.next_price()), WeaponManager.next_skill_req()]
		wbtn.disabled = not WeaponManager.can_buy()
		wbtn.pressed.connect(func(): if WeaponManager.buy_next(): SaveManager.save_game(); _refresh())
		_weapon_row.add_child(wbtn)
	# 스킬 목록
	for c in _list.get_children(): c.queue_free()
	for sk in SHOWN:
		_list.add_child(_skill_row(sk))

func _skill_row(sk: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var t := GameManager.ticks(sk)
	var sm: int = Skills.COSTS[sk][1]
	var lv := t / sm
	var name_lab := Label.new()
	name_lab.custom_minimum_size = Vector2(340, 0)
	name_lab.add_theme_font_size_override("font_size", 22)
	name_lab.text = "%s  Lv.%d (t%d/%d)" % [SKILL_NAMES.get(sk, sk), lv, t, Skills.max_ticks(sk)]
	row.add_child(name_lab)

	if t >= Skills.max_ticks(sk):
		var m := Label.new(); m.text = "MAX"; m.add_theme_font_size_override("font_size", 22)
		row.add_child(m)
	elif GameManager.skill_tier_locked(sk, t):
		var gcost := GameManager.gem_unlock_cost(sk, t)
		var gb := Button.new()
		gb.text = "보석 %d로 해금" % gcost
		gb.disabled = GameManager.owned_gems < gcost
		gb.pressed.connect(func(): if GameManager.unlock_skill_tier(sk, t): SaveManager.save_game(); _refresh())
		row.add_child(gb)
	else:
		var cost := Skills.tick_cost(sk, t)
		var b := Button.new()
		b.text = "강화  $%s" % GameManager.format_number(cost)
		b.disabled = GameManager.money < cost
		b.pressed.connect(func(): if GameManager.buy_skill_tick(sk): SaveManager.save_game(); _refresh())
		row.add_child(b)
	return row
