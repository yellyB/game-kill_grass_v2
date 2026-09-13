extends Camera2D

@export var shake_decay: float = 2.5
@export var max_shake_offset: float = 20.0
@export var shake_interval: float = 0.033  # ~30fps (60fps의 절반)

var shake_intensity: float = 0.0
var original_offset: Vector2 = Vector2.ZERO
var shake_timer: float = 0.0

func _ready() -> void:
  original_offset = offset

func _process(delta: float) -> void:
  if shake_intensity > 0:
    shake_intensity = max(shake_intensity - shake_decay * delta, 0)
    shake_timer += delta
    if shake_timer >= shake_interval:
      shake_timer = 0.0
      offset = original_offset + Vector2(
        randf_range(-1, 1) * shake_intensity * max_shake_offset,
        0
      )
  else:
    offset = original_offset
    shake_timer = 0.0

func shake(intensity: float = 1.0) -> void:
  shake_intensity = clamp(intensity, 0, 1)
