extends Node2D
## 정예 식물 (씨앗 공급원). HP = 풀 평균 ×2. 처치 시 씨앗 1개 드롭.
## 플레이어 AttackArea(mask 2)가 자식 Area2D(layer 2)를 감지 → take_damage 호출.

signal died(elite)

const DROPPED_ITEM = preload("res://scenes/world/dropped_item.tscn")

var max_hp: float = 20.0
var hp: float = 20.0
var _dead: bool = false
var _base_scale: Vector2 = Vector2.ONE

@onready var visual: Node2D = $Visual

func setup(p_hp: float) -> void:
	max_hp = maxf(1.0, p_hp)
	hp = max_hp

func _ready() -> void:
	_build_visual()
	# 팝업 등장 연출
	visual.scale = Vector2.ZERO
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(visual, "scale", _base_scale, 0.25)

func _build_visual() -> void:
	# 어두운 줄기 + 가시 잎(정예 표식: 붉은기 도는 위협적 식물)
	var stem = Polygon2D.new()
	stem.color = Color(0.25, 0.35, 0.2)
	stem.polygon = PackedVector2Array([
		Vector2(-5, 30), Vector2(5, 30), Vector2(3, -6), Vector2(-3, -6)
	])
	visual.add_child(stem)
	var leaf_color = Color(0.7, 0.25, 0.3)
	for i in 5:
		var a = -PI * 0.5 + (i - 2) * 0.5
		var leaf = Polygon2D.new()
		leaf.color = leaf_color
		var tip = Vector2(cos(a), sin(a)) * 34.0
		var perp = Vector2(-sin(a), cos(a)) * 9.0
		leaf.polygon = PackedVector2Array([Vector2(0, -4), tip + perp, tip, tip - perp])
		visual.add_child(leaf)
	# 중앙 열매(밝은 붉은색)
	var core = Polygon2D.new()
	core.color = Color(0.95, 0.35, 0.3)
	var pts: PackedVector2Array = []
	for j in 10:
		var ang = TAU / 10.0 * j
		pts.append(Vector2(cos(ang), sin(ang)) * 10.0)
	core.polygon = pts
	core.position = Vector2(0, -4)
	visual.add_child(core)

func take_damage(dmg: int, _from_pos: Vector2) -> void:
	if _dead:
		return
	hp -= float(dmg)
	# 피격 플래시
	visual.modulate = Color(2, 2, 2)
	var tw = create_tween()
	tw.tween_property(visual, "modulate", Color(1, 1, 1), 0.12)
	# 살짝 흔들림
	var punch = create_tween()
	punch.tween_property(visual, "scale", _base_scale * 1.15, 0.04)
	punch.tween_property(visual, "scale", _base_scale, 0.08)
	if hp <= 0.0:
		_die()

func _die() -> void:
	if _dead:
		return
	_dead = true
	died.emit(self)
	# 씨앗 드롭 → 플레이어에게 비행
	var player = get_tree().get_first_node_in_group("player")
	var seed_item = DROPPED_ITEM.instantiate()
	seed_item.setup_seed(player)
	get_parent().add_child(seed_item)
	seed_item.global_position = global_position
	# 사망 연출 후 제거
	var tw = create_tween()
	tw.tween_property(visual, "scale", Vector2.ZERO, 0.15)
	tw.parallel().tween_property(visual, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)
