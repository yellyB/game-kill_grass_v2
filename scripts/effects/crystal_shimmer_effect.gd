extends Node2D

var particles: Array = []  # [{pos, alpha, lifetime, max_lifetime, size, color_idx}]
var spawn_timer: float = 0.0
const SPAWN_INTERVAL: float = 0.18
const PRISM_COLORS: Array = [
  Color(0.3, 0.9, 1.0),   # cyan
  Color(0.5, 0.8, 1.0),   # sky
  Color(0.7, 0.5, 1.0),   # purple
  Color(0.4, 1.0, 0.8),   # mint
]

func _process(delta: float) -> void:
  spawn_timer -= delta
  if spawn_timer <= 0:
    spawn_timer = SPAWN_INTERVAL + randf() * 0.08
    _spawn_particles(randi_range(1, 2))

  var to_remove: Array = []
  for i in range(particles.size()):
    var p = particles[i]
    p.lifetime -= delta
    # Alpha: sin curve (fade in then out)
    var t = p.lifetime / p.max_lifetime
    p.alpha = sin(t * PI)
    if p.lifetime <= 0:
      to_remove.append(i)

  for i in range(to_remove.size() - 1, -1, -1):
    particles.remove_at(to_remove[i])

  queue_redraw()

func burst(intensity: int = 1) -> void:
  _spawn_particles(intensity * 5)

func stop() -> void:
  set_process(false)
  particles.clear()
  queue_redraw()

func _spawn_particles(count: int) -> void:
  for i in count:
    var angle = randf() * TAU
    var dist = randf_range(16.0, 40.0)
    var pos = Vector2(cos(angle) * dist, sin(angle) * dist)
    var lifetime = randf_range(0.15, 0.3)
    particles.append({
      "pos": pos,
      "alpha": 1.0,
      "lifetime": lifetime,
      "max_lifetime": lifetime,
      "size": randf_range(2.0, 4.0),
      "color_idx": randi() % PRISM_COLORS.size(),
    })

func _draw() -> void:
  for p in particles:
    var col = PRISM_COLORS[p.color_idx]
    col.a = p.alpha

    # Twinkle: cross lines + center dot
    var s = p.size
    draw_line(p.pos + Vector2(-s, 0), p.pos + Vector2(s, 0), col, 0.7, true)
    draw_line(p.pos + Vector2(0, -s), p.pos + Vector2(0, s), col, 0.7, true)
    draw_circle(p.pos, 1.0, col)
