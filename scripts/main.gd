extends Node2D
## M0 게임 세션 — 이동(월드 스크롤)→자동 베기→코인→세션 종료 최소 루프.
## 코드 주도 구성(물리 바디 없이 거리 기반). 밸런스는 GameManager→core/.

const GrassSpawnerScript = preload("res://scripts/grass_spawner.gd")

var world_root: Node2D
var grass: Node2D            # GrassSpawner
var player_visual: Node2D
var cam: Camera2D
var time_label: Label
var money_label: Label
var end_label: Label

var _coins: Array = []       # [{node, value}]
var _attack_accum := 0.0
var _remaining := 45.0
var _ended := false

func _ready() -> void:
	_remaining = GameManager.get_session_time()

	world_root = Node2D.new()
	world_root.name = "WorldRoot"
	add_child(world_root)

	grass = GrassSpawnerScript.new()
	grass.name = "GrassSpawner"
	world_root.add_child(grass)

	# 플레이어(화면 중앙 고정 비주얼)
	player_visual = Node2D.new()
	player_visual.name = "Player"
	add_child(player_visual)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-12,-16), Vector2(12,-16), Vector2(12,16), Vector2(-12,16)])
	body.color = Color(0.95, 0.9, 0.85)
	player_visual.add_child(body)

	cam = Camera2D.new()
	cam.position = Vector2.ZERO
	add_child(cam)
	cam.make_current()

	_build_hud()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	time_label = Label.new()
	time_label.position = Vector2(20, 16)
	time_label.add_theme_font_size_override("font_size", 40)
	layer.add_child(time_label)
	money_label = Label.new()
	money_label.position = Vector2(20, 64)
	money_label.add_theme_font_size_override("font_size", 28)
	layer.add_child(money_label)
	end_label = Label.new()
	end_label.position = Vector2(0, 480)
	end_label.size = Vector2(1920, 120)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.add_theme_font_size_override("font_size", 56)
	end_label.visible = false
	layer.add_child(end_label)

func _process(delta: float) -> void:
	if _ended:
		return
	# 이동 = 월드 스크롤(플레이어 반대 방향)
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := GameManager.get_base_move_speed()
	world_root.position -= dir * speed * delta

	var player_in_world := -world_root.position   # 플레이어의 grass 좌표

	grass.update_field(player_in_world, delta)

	# 자동 공격
	_attack_accum += delta
	var interval := GameManager.get_attack_interval()
	while _attack_accum >= interval:
		_attack_accum -= interval
		var hits: Array = grass.attack_around(
			player_in_world, GameManager.get_attack_range(),
			GameManager.get_attack_count(), GameManager.get_eff_damage())
		for h in hits:
			_spawn_coin(h.pos, h.value)

	_update_coins(delta, player_in_world)

	# 세션 타이머
	_remaining -= delta
	time_label.text = "%0.1f" % maxf(0.0, _remaining)
	money_label.text = "$" + GameManager.format_number(GameManager.session_money)
	if _remaining <= 0.0:
		_end_session()

func _spawn_coin(world_pos: Vector2, value: int) -> void:
	var n := Polygon2D.new()
	n.polygon = PackedVector2Array([Vector2(0,-7), Vector2(7,0), Vector2(0,7), Vector2(-7,0)])
	n.color = _coin_color(value)
	n.position = world_pos
	world_root.add_child(n)
	_coins.append({"node": n, "value": value})

func _coin_color(v: int) -> Color:
	if v >= 1000: return Color(0.6, 0.9, 1.0)   # 다이아
	elif v >= 500: return Color(1.0, 0.9, 0.3)  # 골드
	elif v >= 100: return Color(0.85, 0.85, 0.9) # 실버
	return Color(0.8, 0.55, 0.3)                 # 브론즈

func _update_coins(delta: float, player_in_world: Vector2) -> void:
	var magnet := GameManager.get_magnet_range()
	var i := _coins.size() - 1
	while i >= 0:
		var c: Dictionary = _coins[i]
		var node: Node2D = c.node
		var to_player := player_in_world - node.position
		var d := to_player.length()
		if d < magnet:
			node.position += to_player.normalized() * 900.0 * delta
			if d < 24.0:
				GameManager.add_session_money(c.value)
				node.queue_free()
				_coins.remove_at(i)
		i -= 1

func _end_session() -> void:
	_ended = true
	SessionManager.end_session(true)   # 정산+저장
	end_label.text = "세션 종료  ($%s)\n아무 키나 눌러 계속" % GameManager.format_number(GameManager.money)
	end_label.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if _ended and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
