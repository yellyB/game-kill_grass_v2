extends Node2D

@onready var amount_label: Label = $AmountLabel

var float_speed: float = 80.0
var fade_duration: float = 1.0
var spread_offset: Vector2 = Vector2.ZERO

# Batch mode state
var is_batch_mode: bool = false

func _ready() -> void:
	if not is_batch_mode:
		animate()

func _process(delta: float) -> void:
	if is_batch_mode:
		return
	# Float upward
	position.y -= float_speed * delta
	position += spread_offset * delta

# Legacy single-coin setup
func setup(amount: int) -> void:
	if amount_label:
		amount_label.text = "+%s" % GameManager.format_number(amount)
		apply_color(amount)

func animate() -> void:
	scale = Vector2(0.5, 0.5)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1).set_ease(Tween.EASE_OUT)

	await tween.finished

	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	tween2.tween_property(self, "modulate:a", 0.0, fade_duration).set_delay(0.3)

	await tween2.finished
	queue_free()

# --- Batch mode methods ---

func start_batch(amount: int) -> void:
	is_batch_mode = true
	if amount_label:
		amount_label.text = "+%s" % GameManager.format_number(amount)
		apply_color(amount)
	# Pop in
	scale = Vector2(0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)

func update_batch(total: int) -> void:
	if amount_label:
		amount_label.text = "+%s" % GameManager.format_number(total)
		apply_color(total)
	bump_animation()

func finish_batch() -> void:
	is_batch_mode = false
	# Float up and fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 60.0, 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	await tween.finished
	queue_free()

func bump_animation() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.05).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08).set_ease(Tween.EASE_IN)

func setup_penalty(amount: int) -> void:
	if amount_label:
		amount_label.text = "-%s" % GameManager.format_number(amount)
		amount_label.modulate = Color(1, 0.3, 0.3)

func apply_color(amount: int) -> void:
	if not amount_label:
		return
	if amount >= 50:
		amount_label.modulate = Color(1, 0.6, 0.1)  # Orange
	elif amount >= 10:
		amount_label.modulate = Color(1, 0.85, 0.0)  # Gold
	elif amount >= 5:
		amount_label.modulate = Color(0.75, 0.75, 0.85)  # Silver
	else:
		amount_label.modulate = Color(1, 0.9, 0.3)  # Bronze/default

