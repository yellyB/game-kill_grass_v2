extends Node2D

var particles: Array = []  # [{pos, alpha, lifetime, max_lifetime, radius, phase}]
var spawn_timer: float = 0.0
const SPAWN_INTERVAL: float = 0.3
const SPORE_COLORS: Array = [
  Color(0.3, 0.9, 0.4, 0.6),
  Color(0.2, 0.7, 0.5, 0.6),
]

func _process(delta: float) -> void:
  spawn_timer -= delta
  if spawn_timer <= 0:
    spawn_timer = SPAWN_INTERVAL + randf() * 0.15
    _spawn_particles(randi_range(1, 2))

  var to_remove: Array = []
  for i in range(particles.size()):
    var p = particles[i]
    p.lifetime -= delta
    var t = 1.0 - (p.lifetime / p.max_lifetime)
    p.alpha = sin(t * PI) * 0.6  # fade in then out
    # Float upward + sine wave wobble
    p.pos.y -= 12.0 * delta
    p.pos.x += sin(p.phase + t * TAU) * 15.0 * delta
    if p.lifetime <= 0:
      to_remove.append(i)

  for i in range(to_remove.size() - 1, -1, -1):
    particles.remove_at(to_remove[i])

  queue_redraw()

func burst(intensity: int = 1) -> void:
  _spawn_particles(intensity * 3)

func stop() -> void:
  set_process(false)
  particles.clear()
  queue_redraw()

func _spawn_particles(count: int) -> void:
  for i in count:
    var angle = randf() * TAU
    var dist = randf_range(12.0, 36.0)
    var pos = Vector2(cos(angle) * dist, sin(angle) * dist)
    var lifetime = randf_range(0.6, 1.0)
    particles.append({
      "pos": pos,
      "alpha": 0.0,
      "lifetime": lifetime,
      "max_lifetime": lifetime,
      "radius": randf_range(1.5, 3.0),
      "phase": randf() * TAU,
      "color_idx": randi() % SPORE_COLORS.size(),
    })

func _draw() -> void:
  for p in particles:
    var col = SPORE_COLORS[p.color_idx]
    # Glow (larger, dimmer)
    var glow = col
    glow.a = p.alpha * 0.3
    draw_circle(p.pos, p.radius * 2.5, glow)
    # Core
    col.a = p.alpha
    draw_circle(p.pos, p.radius, col)
