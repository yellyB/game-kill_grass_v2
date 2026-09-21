extends Node2D
## 자연물 컨테이너(그루터기/씨앗주머니 등). 부수면 즉발 아이템 1개 드롭 → 슬롯.
## elite와 동일 충돌 구조(layer 8 hittable). 낮은 HP로 몇 대에 파괴.

const DROPPED_ITEM = preload("res://scenes/world/dropped_item.tscn")

var max_hp: float = 6.0
var hp: float = 6.0
var _dead: bool = false
var _base_scale: Vector2 = Vector2.ONE

@onready var visual: Node2D = $Visual

func setup(p_hp: float) -> void:
	max_hp = maxf(1.0, p_hp)
	hp = max_hp

func _ready() -> void:
	_build_visual()
	visual.scale = Vector2.ZERO
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(visual, "scale", _base_scale, 0.22)

func _build_visual() -> void:
	# 나무 그루터기: 갈색 몸통 + 윗면 나이테
	var body = Polygon2D.new()
	body.color = Color(0.42, 0.29, 0.16)
	body.polygon = PackedVector2Array([
		Vector2(-22, 20), Vector2(22, 20), Vector2(18, -10), Vector2(-18, -10)
	])
	visual.add_child(body)
	var top = Polygon2D.new()
	top.color = Color(0.6, 0.45, 0.28)
	var pts: PackedVector2Array = []
	for i in 14:
		var a = TAU / 14.0 * i
		pts.append(Vector2(cos(a) * 20.0, sin(a) * 8.0 - 10.0))
	top.polygon = pts
	visual.add_child(top)
	var ring = Polygon2D.new()
	ring.color = Color(0.5, 0.36, 0.22)
	var rpts: PackedVector2Array = []
	for i in 14:
		var a = TAU / 14.0 * i
		rpts.append(Vector2(cos(a) * 10.0, sin(a) * 4.0 - 10.0))
	ring.polygon = rpts
	visual.add_child(ring)

func take_damage(dmg: int, _from_pos: Vector2) -> void:
	if _dead:
		return
	hp -= float(dmg)
	visual.modulate = Color(1.8, 1.8, 1.8)
	var tw = create_tween()
	tw.tween_property(visual, "modulate", Color(1, 1, 1), 0.1)
	var punch = create_tween()
	punch.tween_property(visual, "scale", _base_scale * 1.12, 0.04)
	punch.tween_property(visual, "scale", _base_scale, 0.08)
	if hp <= 0.0:
		_die()

func _die() -> void:
	if _dead:
		return
	_dead = true
	var player = get_tree().get_first_node_in_group("player")
	# 컨테이너 = 열매(아이템 재화) 공급. 소량 드롭 → 상점에서 아이템 구매.
	var drop = DROPPED_ITEM.instantiate()
	drop.setup_token(randi_range(2, 4), player)
	get_parent().add_child(drop)
	drop.global_position = global_position
	var tw = create_tween()
	tw.tween_property(visual, "scale", Vector2.ZERO, 0.15)
	tw.parallel().tween_property(visual, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)
