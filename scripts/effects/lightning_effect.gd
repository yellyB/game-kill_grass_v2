extends Node2D

@export var bolt_count: int = 3
@export var bolt_radius: float = 18.0
@export var bolt_length: float = 28.0
@export var bolt_width: float = 0.5
@export var spawn_interval: float = 0.15
@export var bolt_color: Color = Color(1.0, 0.95, 0.3, 0.9)
@export var bolt_bright_color: Color = Color(1.0, 1.0, 0.8, 1.0)

var bolts: Array = []  # [{points, alpha, lifetime}]
var spawn_timer: float = 0.0

func _process(delta: float) -> void:
  # Spawn new bolts
  spawn_timer -= delta
  if spawn_timer <= 0:
    spawn_timer = spawn_interval + randf() * 0.1
    _spawn_bolts()

  # Update existing bolts
  var to_remove: Array = []
  for i in range(bolts.size()):
    bolts[i].lifetime -= delta
    bolts[i].alpha = bolts[i].lifetime / bolts[i].max_lifetime
    if bolts[i].lifetime <= 0:
      to_remove.append(i)

  for i in range(to_remove.size() - 1, -1, -1):
    bolts.remove_at(to_remove[i])

  queue_redraw()

func burst(intensity: int = 1) -> void:
  for i in intensity:
    _spawn_bolts()

func stop() -> void:
  set_process(false)
  bolts.clear()
  queue_redraw()

func _spawn_bolts() -> void:
  for i in bolt_count:
    var bolt = _create_bolt()
    bolts.append(bolt)

func _create_bolt() -> Dictionary:
  var angle = randf() * TAU
  var start = Vector2(cos(angle), sin(angle)) * bolt_radius
  var dir = Vector2(cos(angle), sin(angle))

  var points: PackedVector2Array = []
  points.append(start)

  var segments = randi_range(3, 6)
  var seg_len = bolt_length / segments
  var pos = start

  for i in segments:
    # Zigzag: alternate perpendicular offset
    var perp = Vector2(-dir.y, dir.x)
    var offset = perp * randf_range(-4.0, 4.0)
    pos += dir * seg_len + offset
    points.append(pos)

  var lifetime = randf_range(0.08, 0.15)
  return {
    "points": points,
    "alpha": 1.0,
    "lifetime": lifetime,
    "max_lifetime": lifetime
  }

func _draw() -> void:
  for bolt in bolts:
    var points: PackedVector2Array = bolt.points
    var alpha: float = bolt.alpha
    if points.size() < 2:
      continue

    # Bright core
    var core = bolt_bright_color
    core.a = alpha
    for i in range(points.size() - 1):
      draw_line(points[i], points[i + 1], core, bolt_width, true)

    # Yellow outer
    var outer = bolt_color
    outer.a = alpha * 0.8
    for i in range(points.size() - 1):
      draw_line(points[i], points[i + 1], outer, bolt_width + 0.8, true)
