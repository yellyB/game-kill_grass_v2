extends Node2D
## 필드 스포너 (구 monster_spawner 대체). 정예 식물을 플레이어 주변에 산재 스폰.
## 씨앗 N개 도달(GameManager.goomok_ready) → 정예 정리 후 거목 소환.
## WorldRoot 자식으로 배치 → 스폰물이 월드 스크롤을 따라 이동.

const ELITE = preload("res://scenes/world/elite_plant.tscn")
const GOOMOK = preload("res://scenes/world/great_tree.tscn")
const CONTAINER = preload("res://scenes/world/item_container.tscn")

var player: Node2D
var _elites: Array = []
var _containers: Array = []
var _goomok: Node = null
var _spawn_cooldown: float = 0.0
var _container_cooldown: float = 4.0
var target_elites: int = 3

const SPAWN_MIN_R: float = 420.0   # 공격범위 밖·화면 언저리
const SPAWN_MAX_R: float = 820.0

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	GameManager.goomok_ready.connect(_on_goomok_ready)
	# 월드별 정예 밀도 = 씨앗 N에 비례(더 위험한 월드 = 정예 더 많음)
	target_elites = clampi(2 + GameManager.selected_world, 2, 6)

func _process(delta: float) -> void:
	if _goomok != null:
		return
	if GameManager.goomok_ready_state:
		return
	_elites = _elites.filter(func(e): return is_instance_valid(e))
	_spawn_cooldown -= delta
	if _elites.size() < target_elites and _spawn_cooldown <= 0.0:
		_spawn_elite()
		_spawn_cooldown = 0.7
	# 아이템 컨테이너: 항상 1개 유지, 파괴 후 재등장(컨테이너 확률 스킬로 빈도↑)
	_containers = _containers.filter(func(c): return is_instance_valid(c))
	_container_cooldown -= delta
	if _containers.size() < 1 and _container_cooldown <= 0.0:
		_spawn_container()
		_container_cooldown = 6.0 * (1.0 - clampf(GameManager.get_chest_spawn_chance() * 4.0, 0.0, 0.5))

func _spawn_elite() -> void:
	if not is_instance_valid(player):
		return
	var e = ELITE.instantiate()
	e.setup(GameManager.get_elite_hp())
	e.died.connect(_on_elite_died)
	add_child(e)
	var ang = randf() * TAU
	var r = randf_range(SPAWN_MIN_R, SPAWN_MAX_R)
	e.global_position = player.global_position + Vector2(cos(ang), sin(ang)) * r
	_elites.append(e)

func _spawn_container() -> void:
	if not is_instance_valid(player):
		return
	var c = CONTAINER.instantiate()
	c.setup(GameManager.get_current_avg_grass_hp())
	add_child(c)
	var ang = randf() * TAU
	var r = randf_range(SPAWN_MIN_R, SPAWN_MAX_R)
	c.global_position = player.global_position + Vector2(cos(ang), sin(ang)) * r
	_containers.append(c)

func _on_elite_died(_e) -> void:
	# 씨앗 드롭은 정예가 자체 처리. 재스폰은 _process가 담당.
	pass

func _on_goomok_ready() -> void:
	for e in _elites:
		if is_instance_valid(e):
			e.queue_free()
	_elites.clear()
	_spawn_goomok()

func _spawn_goomok() -> void:
	if not is_instance_valid(player):
		return
	_goomok = GOOMOK.instantiate()
	_goomok.setup(GameManager.get_goomok_hp())
	add_child(_goomok)
	var ang = randf() * TAU
	_goomok.global_position = player.global_position + Vector2(cos(ang), sin(ang)) * 520.0
