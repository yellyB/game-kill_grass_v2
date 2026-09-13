extends Area2D

@export var magnet_speed: float = 600.0
@export var pickup_delay: float = 0.3

var player: Node2D = null
var can_pickup: bool = false
var is_being_collected: bool = false
var is_collected: bool = false
var color_time: float = 0.0

@onready var visual: Node2D = $Visual

func _ready() -> void:
  player = get_tree().get_first_node_in_group("player")
  spawn_animation()
  await get_tree().create_timer(pickup_delay).timeout
  can_pickup = true

func _process(delta: float) -> void:
  # Rainbow shimmer for generic powerup
  color_time += delta * 2.0
  if visual:
    var r = (sin(color_time) + 1.0) / 2.0
    var g = (sin(color_time + TAU / 3.0) + 1.0) / 2.0
    var b = (sin(color_time + TAU * 2.0 / 3.0) + 1.0) / 2.0
    var shimmer = Color(0.5 + r * 0.5, 0.5 + g * 0.5, 0.5 + b * 0.5)
    for child in visual.get_children():
      if child is Polygon2D:
        child.color = shimmer

  if not can_pickup or not player:
    return

  var player_local_pos = get_parent().to_local(player.global_position)
  var distance_to_player = position.distance_to(player_local_pos)
  var magnet_range = GameManager.get_magnet_range()

  if distance_to_player < magnet_range or is_being_collected:
    is_being_collected = true
    var direction = (player_local_pos - position).normalized()
    var speed = magnet_speed * (1.0 + (magnet_range - min(distance_to_player, magnet_range)) / magnet_range)
    position += direction * speed * delta

    if distance_to_player < 30.0:
      collect()

  # Bobbing + rotation animation
  if visual:
    visual.position.y = sin(Time.get_ticks_msec() * 0.006) * 5.0
    visual.rotation += delta * 2.0

func spawn_animation() -> void:
  var pop_direction = Vector2(randf_range(-1, 1), randf_range(-1, -0.5)).normalized()
  var pop_distance = randf_range(30, 60)
  var peak_pos = position + pop_direction * pop_distance

  if visual:
    visual.scale = Vector2(0.3, 0.3)

  var tween = create_tween()
  tween.set_parallel(true)
  tween.tween_property(self, "position", peak_pos, 0.15).set_ease(Tween.EASE_OUT)
  if visual:
    tween.tween_property(visual, "scale", Vector2(1.2, 1.2), 0.1).set_ease(Tween.EASE_OUT)

  await tween.finished

  if visual:
    var tween2 = create_tween()
    tween2.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.1)

func collect() -> void:
  if is_collected:
    return
  is_collected = true

  # Show selection UI (pauses game)
  var selection = preload("res://scenes/ui/powerup_selection.tscn").instantiate()
  get_tree().root.add_child(selection)

  if visual:
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(visual, "scale", Vector2(2.0, 2.0), 0.15)
    tween.tween_property(visual, "modulate:a", 0.0, 0.15)
    await tween.finished

  queue_free()
