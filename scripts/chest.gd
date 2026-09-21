extends Node2D

const PowerupScene = preload("res://scenes/world/powerup.tscn")
const SFX_BREAK = preload("res://resources/sounds/effect/wood_box_break.wav")
var health: int = 1
var is_dead: bool = false

@onready var body: Polygon2D = $Body
@onready var lid: Polygon2D = $Lid
@onready var lock_icon: Polygon2D = $LockIcon

func _ready() -> void:
	add_to_group("field_objects")

func take_damage(_amount: int, _from_global_pos: Variant = null) -> void:
	if is_dead:
		return
	health -= 1
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	remove_from_group("field_objects")
	set_process(false)

	# Play break sound (on root so it persists after queue_free)
	if GameManager.sfx_enabled:
		var sfx = AudioStreamPlayer.new()
		sfx.stream = SFX_BREAK
		sfx.volume_db = -3.0
		get_tree().root.add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)

	# Open animation: expand + shake + fade
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(lid, "position:y", lid.position.y - 20, 0.15)
	await tween.finished

	# Shake + fade
	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(self, "modulate:a", 0.0, 0.35)

	var shake_tween = create_tween()
	for i in 5:
		var offset = Vector2(randf_range(-4, 4), randf_range(-4, 4))
		shake_tween.tween_property(self, "position", position + offset, 0.035)
		shake_tween.tween_property(self, "position", position, 0.035)

	await tween2.finished

	_drop_loot()
	queue_free()

func _drop_loot() -> void:
	var powerup = PowerupScene.instantiate()
	powerup.position = position
	get_parent().add_child(powerup)
