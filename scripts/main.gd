extends Node2D
## M2 게임 세션 — 이동/베기/코인 + 정예·씨앗·거목 + 레벨업 3택 + 게임레벨.
## 밸런스는 core/(StatBlock/Economy). 파워업 실시간 적용.

const GrassSpawnerScript = preload("res://scripts/grass_spawner.gd")
const StatBlock = preload("res://core/stat_block.gd")
const Balance = preload("res://core/balance_data.gd")
const Skills = preload("res://core/skills.gd")
const PowerupData = preload("res://core/data/powerups.gd")

enum { PLAYING, LEVELUP, ENDED }

var world_root: Node2D
var grass: Node2D
var player_visual: Node2D
var cam: Camera2D
var time_label: Label
var money_label: Label
var info_label: Label
var end_label: Label
var levelup_layer: CanvasLayer

var _coins: Array = []
var _elites: Array = []          # [{node, hp}]
var _goomok: Dictionary = {}     # {node, hp, maxhp} or empty
var _seeds := 0
var _world := 0
var _trans := 0
var _pu: Dictionary = {}         # 파워업 type→stacks
var _rune := ""
var _kills := 0.0
var _attack_accum := 0.0
var _elite_accum := 0.0
var _remaining := 45.0
var _state := PLAYING
var _rng := RandomNumberGenerator.new()
var _eff: Dictionary = {}
var _stun_timer := 0.0
var _goomok_pattern_accum := 0.0

func _ready() -> void:
	_rng.randomize()
	_world = GameManager.selected_world
	_trans = GameManager.get_world_trans(_world)
	_rune = GameManager.equipped_rune
	GameManager.session_lv_cap = 10 + (2 if _rune == "bloom" else 0)
	_remaining = GameManager.get_session_time()

	world_root = Node2D.new(); world_root.name = "WorldRoot"; add_child(world_root)
	var bg := ColorRect.new()
	bg.color = Balance.WORLD_COLORS[_world]
	bg.size = Vector2(4000, 4000); bg.position = Vector2(-2000, -2000)
	bg.z_index = -100
	add_child(bg)
	grass = GrassSpawnerScript.new(); grass.name = "GrassSpawner"; world_root.add_child(grass)

	player_visual = Node2D.new(); add_child(player_visual)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-12,-16), Vector2(12,-16), Vector2(12,16), Vector2(-12,16)])
	body.color = Color(0.95, 0.9, 0.85)
	player_visual.add_child(body)

	cam = Camera2D.new(); add_child(cam); cam.make_current()
	_build_hud()
	GameManager.level_up.connect(_on_level_up)

func _build_hud() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	time_label = _mk_label(layer, Vector2(20,16), 40)
	money_label = _mk_label(layer, Vector2(20,64), 28)
	info_label = _mk_label(layer, Vector2(20,104), 24)
	end_label = _mk_label(layer, Vector2(0,460), 56)
	end_label.size = Vector2(1920,200); end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.visible = false
	levelup_layer = CanvasLayer.new(); levelup_layer.layer = 5; add_child(levelup_layer); levelup_layer.visible = false

func _mk_label(parent: Node, pos: Vector2, size: int) -> Label:
	var l := Label.new(); l.position = pos; l.add_theme_font_size_override("font_size", size)
	parent.add_child(l); return l

func _process(delta: float) -> void:
	if _state == ENDED or _state == LEVELUP:
		return
	_eff = StatBlock.effective(GameManager.upgrade_levels, _pu, _rune, _kills, GameManager.session_level, _world, _trans)

	# 스턴 중이면 이동 불가
	if _stun_timer > 0.0:
		_stun_timer -= delta
	else:
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		world_root.position -= dir * _eff.move_speed * delta

	var pw := -world_root.position
	grass.update_field(pw, delta)

	# 자동 공격(풀 + 정예 + 거목)
	_attack_accum += delta
	var interval: float = _eff.attack_interval
	while _attack_accum >= interval:
		_attack_accum -= interval
		_do_attack(pw)

	_maybe_spawn_elites(pw, delta)
	_update_coins(delta, pw)
	if not _goomok.is_empty():
		_update_goomok(delta, pw)

	_remaining -= delta
	_update_hud()
	if _remaining <= 0.0:
		_end_session(false)

func _do_attack(pw: Vector2) -> void:
	var rng: float = _eff.attack_range
	var cnt: int = _eff.attack_count
	var dmg: float = _eff.eff_damage
	# 풀
	var hits: Array = grass.attack_around(pw, rng, cnt, dmg, _eff.cap_mult)
	for h in hits:
		_kills += 1.0
		var val := int(h.value * _eff.coin_mult)
		_spawn_coin(h.pos, val)
		GameManager.add_level_xp(_grass_xp(h.tier))
	# 정예(씨앗)
	for e in _elites:
		var en: Node2D = e.node
		if en.position.distance_to(pw) <= rng:
			e.hp -= dmg
	_reap_elites()
	# 거목
	if not _goomok.is_empty():
		var gn: Node2D = _goomok.node
		if gn.position.distance_to(pw) <= rng + 60.0:
			_goomok.hp -= dmg * _eff.goomok_dmg_mult * Balance.POWERUP_GOOMOK_MULT

func _grass_xp(tier: int) -> float:
	return float(Balance.GOLD_XP) if tier == 5 else float(Balance.GRASS_XP[tier])

func _maybe_spawn_elites(pw: Vector2, delta: float) -> void:
	if not _goomok.is_empty():
		return
	# 정예 밀도(월드별)에 비례해 주기적으로 스폰(플레이어 주변)
	_elite_accum += delta
	var rate: float = Balance.elite_density(_world) * 2.0 * float(_eff.attack_range) * float(_eff.move_speed)  # 대략 조우율
	var spawn_interval: float = (1.0 / maxf(0.05, rate)) if rate > 0.0 else 999.0
	if _elite_accum >= spawn_interval and _elites.size() < 6:
		_elite_accum = 0.0
		_spawn_elite(pw)

func _spawn_elite(pw: Vector2) -> void:
	var ang := _rng.randf() * TAU
	var dist := _rng.randf_range(200.0, 500.0)
	var pos := pw + Vector2(cos(ang), sin(ang)) * dist
	var n := Polygon2D.new()
	n.polygon = PackedVector2Array([Vector2(-16,-22), Vector2(16,-22), Vector2(20,20), Vector2(-20,20)])
	n.color = Color(0.4, 0.7, 0.3)
	n.position = pos
	world_root.add_child(n)
	var avg_hp := _avg_grass_hp()
	_elites.append({"node": n, "hp": Balance.ELITE_HP_MULT * avg_hp})

func _avg_grass_hp() -> float:
	var dist: Array = GameManager.get_quality_dist()
	var gc: float = GameManager.get_golden_chance() + float(_eff.get("gc_add", 0.0))
	var s := 0.0
	for k in range(5):
		s += float(dist[k]) * float(Balance.GRASS[k][0])
	return (gc * float(Balance.GOLD[0]) + (1.0 - gc) * s) * GameManager.get_world_hp_mult(_world)

func _reap_elites() -> void:
	var i := _elites.size() - 1
	while i >= 0:
		if _elites[i].hp <= 0.0:
			var en: Node2D = _elites[i].node
			en.queue_free()
			_elites.remove_at(i)
			_seeds += 1
			if _seeds >= Balance.SEED_NEED[_world] and _goomok.is_empty():
				_spawn_goomok()
		i -= 1

func _spawn_goomok() -> void:
	var pw := -world_root.position
	var pos := pw + Vector2(0, -350)
	var n := Polygon2D.new()
	n.polygon = PackedVector2Array([Vector2(-60,-90), Vector2(60,-90), Vector2(80,70), Vector2(-80,70)])
	n.color = Balance.WORLD_COLORS[_world].lightened(0.4)
	n.position = pos
	world_root.add_child(n)
	var hp := Balance.GOOMOK_HP_BASE * float(Balance.GOOMOK_WORLD_SCALE[_world]) * (1.0 + 0.4 * _trans)
	_goomok = {"node": n, "hp": hp, "maxhp": hp}

func _update_goomok(delta: float, pw: Vector2) -> void:
	# 공격 패턴(회전 덩굴 간이): 주기적으로 플레이어가 거목 근접+각도면 스턴
	_goomok_pattern_accum += delta
	var gn: Node2D = _goomok.node
	if gn.position.distance_to(pw) < 140.0 and _goomok_pattern_accum > 3.0:
		_goomok_pattern_accum = 0.0
		var base_stun := 0.6
		var resist := 0.0
		if _pu.has("stun_resist"):
			resist = minf(0.75, 0.25 * _pu["stun_resist"])
		_stun_timer = base_stun * (1.0 - resist)
	if _goomok.hp <= 0.0:
		gn.queue_free()
		_goomok = {}
		GameManager.on_goomok_cleared(_world)
		_try_unlock_world()
		_end_session(true)

func _try_unlock_world() -> void:
	# 거목 클리어 자격 + 코인 충분 시 다음 월드 해금
	if GameManager.can_unlock_next():
		GameManager.unlock_next_world()

func _spawn_coin(world_pos: Vector2, value: int) -> void:
	var n := Polygon2D.new()
	n.polygon = PackedVector2Array([Vector2(0,-7), Vector2(7,0), Vector2(0,7), Vector2(-7,0)])
	n.color = _coin_color(value)
	n.position = world_pos
	world_root.add_child(n)
	_coins.append({"node": n, "value": value})

func _coin_color(v: int) -> Color:
	if v >= 1000: return Color(0.6,0.9,1.0)
	elif v >= 500: return Color(1.0,0.9,0.3)
	elif v >= 100: return Color(0.85,0.85,0.9)
	return Color(0.8,0.55,0.3)

func _update_coins(delta: float, pw: Vector2) -> void:
	var magnet: float = _eff.magnet_range
	var i := _coins.size() - 1
	while i >= 0:
		var c: Dictionary = _coins[i]
		var node: Node2D = c.node
		var to_p := pw - node.position
		var d := to_p.length()
		if d < magnet:
			node.position += to_p.normalized() * 900.0 * delta
			if d < 24.0:
				GameManager.add_session_money(c.value)
				node.queue_free(); _coins.remove_at(i)
		i -= 1

func _update_hud() -> void:
	time_label.text = "%0.1f" % maxf(0.0, _remaining)
	money_label.text = "$" + GameManager.format_number(GameManager.session_money)
	var goomok_txt := ""
	if not _goomok.is_empty():
		goomok_txt = "  거목 %d%%" % int(100.0 * _goomok.hp / _goomok.maxhp)
	info_label.text = "Lv.%d  씨앗 %d/%d%s" % [GameManager.session_level, _seeds, Balance.SEED_NEED[_world], goomok_txt]

# ── 레벨업 3택 ──
func _on_level_up(_new_level: int) -> void:
	if _state == ENDED:
		return
	_open_levelup()

func _open_levelup() -> void:
	_state = LEVELUP   # 게임플레이만 정지(_process 조기 반환), 트리는 안 멈춤(버튼 입력 유지)
	for c in levelup_layer.get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0,0,0,0.6); dim.size = Vector2(1920,1080)
	levelup_layer.add_child(dim)
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.add_theme_constant_override("separation", 40)
	levelup_layer.add_child(box)
	var choices := _draft_choices()
	for t in choices:
		var d := PowerupData.by_type(t)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(360, 240)
		btn.text = "%s\n[%s]" % [d.name, d.rarity]
		btn.add_theme_font_size_override("font_size", 32)
		btn.pressed.connect(_pick_powerup.bind(t))
		box.add_child(btn)
	levelup_layer.visible = true

func _draft_choices() -> Array:
	var pool := PowerupData.powerups().filter(func(t):
		var d := PowerupData.by_type(t)
		return _pu.get(t, 0) < d.max_stacks)
	var picks := []
	var n: int = 4 if _pu.has("extra_choice") else 3
	var has_luck := _pu.has("luck")
	for _i in range(mini(n, pool.size())):
		var wsum := 0.0
		for t in pool:
			var w: float = PowerupData.by_type(t).weight
			if has_luck and w <= 4: w *= 3.0
			wsum += w
		var r := _rng.randf() * wsum
		var acc := 0.0
		var chosen = pool[0]
		for t in pool:
			var w: float = PowerupData.by_type(t).weight
			if has_luck and w <= 4: w *= 3.0
			acc += w
			if r <= acc:
				chosen = t; break
		picks.append(chosen)
		pool.erase(chosen)
	return picks

func _pick_powerup(t: String) -> void:
	_pu[t] = _pu.get(t, 0) + 1
	levelup_layer.visible = false
	for c in levelup_layer.get_children():
		c.queue_free()
	_state = PLAYING

func _end_session(victory: bool) -> void:
	if _state == ENDED:
		return
	_state = ENDED
	SessionManager.end_session(true)
	var head := "월드 클리어!" if victory else "세션 종료"
	end_label.text = "%s\n$%s  (보석 %d)\n아무 키나 눌러 계속" % [head, GameManager.format_number(GameManager.money), GameManager.owned_gems]
	end_label.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if _state == ENDED:
		if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		return
	if _state == PLAYING and event.is_action_pressed("ui_cancel"):
		SessionManager.quit_to_menu()
