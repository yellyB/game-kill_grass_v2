extends Node2D

const SFX_PICK_KEY = preload("res://resources/sounds/effect/pick_key.wav")
const SFX_PICK_ITEM = preload("res://resources/sounds/effect/pick_item.wav")

var item_id: String = ""
var item_texture: Texture2D = null
var target: Node2D = null  # Player to fly toward

var is_key: bool = false
var key_world_index: int = -1
var ends_session: bool = false

@onready var sprite: Sprite2D = $Sprite2D

# Arc flight state
var is_flying: bool = false
var fly_time: float = 0.0
var fly_duration: float = 0.45
var start_pos: Vector2 = Vector2.ZERO
var control_point: Vector2 = Vector2.ZERO

func setup_key(p_world_index: int, p_target: Node2D) -> void:
	is_key = true
	key_world_index = p_world_index
	target = p_target

var use_potion_visual: bool = false
var is_gem: bool = false
var gem_world: int = -1
var gem_strength: int = 0

func setup_potion(p_item_id: String, p_target: Node2D) -> void:
	item_id = p_item_id
	use_potion_visual = true
	target = p_target

func setup_gem(p_target: Node2D, p_world: int = -1, p_strength: int = 0) -> void:
	is_gem = true
	target = p_target
	gem_world = p_world
	gem_strength = p_strength

func _ready() -> void:
	if is_key:
		_build_key_visual()
	elif is_gem:
		_build_gem_visual()
	elif use_potion_visual:
		_build_potion_visual()
	elif sprite and item_texture:
		sprite.texture = item_texture
	_animate()

func _process(delta: float) -> void:
	if not is_flying:
		return

	fly_time += delta
	var t = clampf(fly_time / fly_duration, 0.0, 1.0)

	if not is_instance_valid(target):
		_collect()
		return

	# Ease-in (cubic) for "whoosh" acceleration toward player
	var eased_t = t * t * t
	var end_pos = target.global_position

	# Quadratic bezier: B(t) = (1-t)²·P0 + 2(1-t)t·P1 + t²·P2
	var inv_t = 1.0 - eased_t
	global_position = inv_t * inv_t * start_pos + 2 * inv_t * eased_t * control_point + eased_t * eased_t * end_pos

	# Scale: start big, shrink toward end
	var s = lerpf(1.8, 0.3, t * t)
	scale = Vector2(s, s)

	# Fade near end
	if t > 0.65:
		modulate.a = lerpf(1.0, 0.5, (t - 0.65) / 0.35)

	if t >= 1.0:
		is_flying = false
		_collect()

func _animate() -> void:
	scale = Vector2.ZERO

	# Pop out big with bounce
	var pop_tween = create_tween()
	pop_tween.set_ease(Tween.EASE_OUT)
	pop_tween.set_trans(Tween.TRANS_BACK)
	pop_tween.tween_property(self, "scale", Vector2(2.4, 2.4), 0.2)
	pop_tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.1)
	await pop_tween.finished

	# Brief pause
	await get_tree().create_timer(0.2).timeout

	if not is_instance_valid(target):
		_collect()
		return

	# Calculate bezier arc
	start_pos = global_position
	var end_pos = target.global_position
	var mid = (start_pos + end_pos) * 0.5
	var direction = end_pos - start_pos
	var perpendicular = Vector2(-direction.y, direction.x).normalized()

	# Arc height: goes upward, with slight random side offset
	var dist = start_pos.distance_to(end_pos)
	var arc_height = maxf(80.0, dist * 0.5)
	var side_offset = randf_range(-25, 25)
	control_point = mid + Vector2(0, -arc_height) + perpendicular * side_offset

	fly_time = 0.0
	is_flying = true

func _build_potion_visual() -> void:
	if sprite:
		sprite.visible = false
	# 왕관 밴드 (금색)
	var band = Polygon2D.new()
	band.color = Color(0.85, 0.65, 0.1)
	band.polygon = PackedVector2Array([
		Vector2(-12, 0), Vector2(12, 0), Vector2(12, 8), Vector2(-12, 8)
	])
	add_child(band)
	# 왕관 꼭지 3개 (밝은 금색)
	var crown = Polygon2D.new()
	crown.color = Color(1.0, 0.85, 0.2)
	crown.polygon = PackedVector2Array([
		Vector2(-12, 0), Vector2(-8, -10), Vector2(-4, 0),
		Vector2(0, -14), Vector2(4, 0),
		Vector2(8, -10), Vector2(12, 0)
	])
	add_child(crown)
	# 중앙 보석 (빨간색)
	var gem = Polygon2D.new()
	gem.color = Color(0.9, 0.15, 0.15)
	gem.polygon = PackedVector2Array([
		Vector2(0, -8), Vector2(3, -5), Vector2(0, -2), Vector2(-3, -5)
	])
	add_child(gem)

func _build_gem_visual() -> void:
	if sprite:
		sprite.visible = false
	# 세로로 길쭉한 육각형 보석 (위아래 뾰족)
	var body = Polygon2D.new()
	body.color = Color(0.9, 0.2, 0.4)
	body.polygon = PackedVector2Array([
		Vector2(0, -14),   # 위 꼭짓점
		Vector2(10, -5),   # 우상
		Vector2(10, 5),    # 우하
		Vector2(0, 14),    # 아래 꼭짓점
		Vector2(-10, 5),   # 좌하
		Vector2(-10, -5),  # 좌상
	])
	add_child(body)
	# 밝은 면 (왼쪽 위 반사광)
	var highlight = Polygon2D.new()
	highlight.color = Color(1.0, 0.5, 0.6, 0.5)
	highlight.polygon = PackedVector2Array([
		Vector2(0, -14),
		Vector2(10, -5),
		Vector2(0, 0),
		Vector2(-10, -5),
	])
	add_child(highlight)

func _build_key_visual() -> void:
	# Hide the default sprite
	if sprite:
		sprite.visible = false
	# Key shape: circle head + rectangle shaft
	var head = Polygon2D.new()
	head.color = Color(0.3, 1.0, 1.0)
	head.polygon = PackedVector2Array([
		Vector2(-8, -14), Vector2(8, -14), Vector2(8, -2), Vector2(-8, -2)
	])
	add_child(head)
	var shaft = Polygon2D.new()
	shaft.color = Color(0.2, 0.8, 0.8)
	shaft.polygon = PackedVector2Array([
		Vector2(-3, -2), Vector2(3, -2), Vector2(3, 14), Vector2(-3, 14)
	])
	add_child(shaft)
	# Teeth
	var tooth = Polygon2D.new()
	tooth.color = Color(0.2, 0.8, 0.8)
	tooth.polygon = PackedVector2Array([
		Vector2(3, 8), Vector2(8, 8), Vector2(8, 12), Vector2(3, 12)
	])
	add_child(tooth)

func _collect() -> void:
	# Play pickup sound (on root so it persists after queue_free)
	if GameManager.sfx_enabled:
		var sfx = AudioStreamPlayer.new()
		sfx.stream = SFX_PICK_KEY if is_key else SFX_PICK_ITEM
		sfx.volume_db = -3.0
		get_tree().root.add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)

	if is_key:
		GameManager.add_key(key_world_index)
	elif is_gem:
		GameManager.add_gem()
		if gem_world >= 0:
			GameManager.mark_gems_collected(gem_world, gem_strength)
		SaveManager.save_game()
	elif use_potion_visual:
		GameManager.has_potion = true
		GameManager.session_crown_acquired = true
		SaveManager.save_game()

	if ends_session:
		GameManager.session_key_acquired = key_world_index
		GameManager.boss_key_collected.emit(key_world_index)
	queue_free()
