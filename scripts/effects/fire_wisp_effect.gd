extends Node2D

var particles: Array = []  # [{pos, vel, lifetime, max_lifetime}]
var spawn_timer: float = 0.0
const SPAWN_INTERVAL: float = 0.15
const COLOR_CORE: Color = Color(1.0, 0.9, 0.3)
const COLOR_MID: Color = Color(1.0, 0.5, 0.1)
const COLOR_OUTER: Color = Color(0.8, 0.2, 0.05)

func _process(delta: float) -> void:
  spawn_timer -= delta
  if spawn_timer <= 0:
    spawn_timer = SPAWN_INTERVAL + randf() * 0.08
    _spawn_particles(randi_range(1, 2))

  var to_remove: Array = []
  for i in range(particles.size()):
    var p = particles[i]
    p.lifetime -= delta
    # Float upward + horizontal noise
    p.pos.y -= 25.0 * delta
    p.pos.x += sin(p.phase + (1.0 - p.lifetime / p.max_lifetime) * TAU) * 20.0 * delta
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
    var dist = randf_range(14.0, 36.0)
    var pos = Vector2(cos(angle) * dist, sin(angle) * dist)
    var lifetime = randf_range(0.3, 0.6)
    particles.append({
      "pos": pos,
      "lifetime": lifetime,
      "max_lifetime": lifetime,
      "phase": randf() * TAU,
    })

func _draw() -> void:
  for p in particles:
    var t = 1.0 - (p.lifetime / p.max_lifetime)  # 0 → 1
    var alpha = 1.0 - t  # fade out

    # 3-layer circles: outer → mid → core
    var outer = COLOR_OUTER.lerp(Color(0.4, 0.1, 0.02), t)
    outer.a = alpha * 0.4
    draw_circle(p.pos, 4.0 * (1.0 - t * 0.5), outer)

    var mid = COLOR_MID.lerp(COLOR_OUTER, t)
    mid.a = alpha * 0.7
    draw_circle(p.pos, 2.5 * (1.0 - t * 0.3), mid)

    var core = COLOR_CORE.lerp(COLOR_MID, t)
    core.a = alpha
    draw_circle(p.pos, 1.2, core)
