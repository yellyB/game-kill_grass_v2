extends SceneTree
## 헤드리스 시뮬 러너 — core/ 공식 호출. balance_sim.py와 패리티 검증용.
## 실행: godot --headless --script res://sim/run_sim.gd -- <scenario>
## 시나리오: skills(공식 덤프, 파이썬 대조) | (추후 session/full 추가)
const Skills = preload("res://core/skills.gd")
const Balance = preload("res://core/balance_data.gd")
const Economy = preload("res://core/economy.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scenario := "skills"
	if args.size() > 0:
		scenario = args[0]
	match scenario:
		"skills":
			_scn_skills()
		"economy":
			_scn_economy()
		_:
			print("unknown scenario: ", scenario)
	quit()

func _scn_economy() -> void:
	print("# economy dump (core/economy.gd)")
	var states := [
		{},
		{"grass_density": 5},
		{"grass_density": 15, "attack_power": 10, "grass_quality": 16, "crit_chance": 6},
		{"grass_density": 30, "attack_power": 20, "grass_quality": 40, "attack_speed": 5, "attack_range": 10, "attack_count": 6, "crit_chance": 10},
	]
	var wt := [[0, 0], [0, 0], [3, 0], [6, 3]]
	for i in range(states.size()):
		var st: Dictionary = states[i]
		var w: int = wt[i][0]
		var tr: int = wt[i][1]
		var ar: Dictionary = Economy.analytic_rate(st, w, tr)
		var base_income: float = ar["rate"] * ar["avg_val"] * ar["T"]
		var sr := Economy.seed_rate(st, w, tr)
		var summon := Economy.goomok_summon_time(st, w, tr)
		var ghp := Economy.goomok_hp_at(w, tr)
		var gdps := Economy.goomok_dps(st)
		print("s%d w%d tr%d | rate=%.5f val=%.3f xp=%.4f T=%.3f income=%.2f | seed/s=%.4f summon=%.2f | ghp=%.1f gdps=%.2f effdmg=%.3f" % [
			i, w, tr, ar["rate"], ar["avg_val"], ar["avg_xp"], ar["T"], base_income, sr, summon, ghp, gdps, Economy.eff_damage(st)])

func _scn_skills() -> void:
	# 파이썬과 동일 포맷으로 스킬 공식 값 덤프 → diff로 패리티 확인
	print("# skill formula dump (core/skills.gd)")
	var ticks := [0, 1, 3, 5, 8, 10, 16, 25, 40]
	for t in ticks:
		var line := "t=%d" % t
		line += " aspd=%.3f" % Skills.attack_speed(t)
		line += " arange=%.1f" % Skills.attack_range(t)
		line += " acount=%d" % Skills.attack_count(t)
		line += " dens=%d" % Skills.density(t)
		line += " apow=%d" % Skills.attack_power(t)
		line += " cc=%.3f" % Skills.crit_chance(t)
		line += " cm=%.3f" % Skills.crit_mult(t)
		line += " gdmg=%.3f" % Skills.goomok_dmg(t)
		line += " move=%.1f" % Skills.move(t)
		line += " sess=%.3f" % Skills.session(t)
		line += " gold=%.4f" % Skills.golden(t)
		line += " magnet=%.2f" % Skills.magnet(t)
		var d: Array = Skills.quality_dist(t)
		line += " qdist=[%.3f,%.3f,%.3f,%.3f,%.3f]" % [d[0], d[1], d[2], d[3], d[4]]
		print(line)
	print("# tick_cost dump")
	for sk in ["attack_power", "grass_density", "attack_count", "golden_chance"]:
		var costs := []
		for t in range(0, mini(Skills.max_ticks(sk), 12)):
			costs.append(Skills.tick_cost(sk, t))
		print("%s: %s" % [sk, str(costs)])
