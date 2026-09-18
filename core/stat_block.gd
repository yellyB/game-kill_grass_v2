extends RefCounted
## StatBlock — 기본 스킬 + 인런 파워업/룬 수정자 → 실효 스탯(런타임).
## main.gd가 매 공격/프레임에 호출. balance_sim _apply_pu의 런타임판.
const Skills = preload("res://core/skills.gd")
const Economy = preload("res://core/economy.gd")
const Balance = preload("res://core/balance_data.gd")
const PowerupData = preload("res://core/data/powerups.gd")

## skills_st={스킬:틱}, pu={파워업type:스택}, rune="", kills/level=현재 세션 상태
## world/trans=배율. 반환: 실효 스탯 Dictionary.
static func effective(skills_st: Dictionary, pu: Dictionary, rune: String, kills: float, level: int, world: int, trans: int) -> Dictionary:
	var dmg_m := 1.0
	var iv_m := 1.0
	var R_m := 1.0
	var v_m := 1.0
	var val_m := 1.0
	var D_m := 1.0
	var magnet_m := 1.0
	var cap_m := 1.0
	var xp_m := 1.0
	var goomok_m := 1.0
	var cc_add := 0.0
	var cm_add := 0.0
	var gc_add := 0.0
	var allm := 1.0
	for t in pu:
		var n: int = pu[t]
		var e: Dictionary = PowerupData.by_type(t).get("effect", {})
		if e.has("dmg"): dmg_m *= pow(e["dmg"], n)
		if e.has("iv"): iv_m *= pow(e["iv"], n)
		if e.has("R"): R_m *= pow(e["R"], n)
		if e.has("v"): v_m *= pow(e["v"], n)
		if e.has("val"): val_m *= pow(e["val"], n)
		if e.has("D"): D_m *= pow(e["D"], n)
		if e.has("regrow"): D_m *= pow(e["regrow"], n)
		if e.has("magnet"): magnet_m *= pow(e["magnet"], n)
		if e.has("cap"): cap_m *= pow(e["cap"], n)
		if e.has("xp"): xp_m *= pow(e["xp"], n)
		if e.has("goomok"): goomok_m *= pow(e["goomok"], n)
		if e.has("cc"): cc_add += e["cc"] * n
		if e.has("cm"): cm_add += e["cm"] * n
		if e.has("gc"): gc_add += e["gc"] * n
		if e.has("snowball"): dmg_m *= (1.0 + e["snowball"] * (kills / 100.0))
		if e.has("compound"): allm *= (1.0 + e["compound"] * (level - 1))
		if e.has("reaper"): cap_m *= (1.0 + Skills.crit_chance(int(skills_st.get("crit_chance", 0))) * 0.3)
	# 룬
	var onslaught := _rune(rune, "onslaught")
	var avarice := _rune(rune, "avarice")
	var woodcutter := _rune(rune, "woodcutter")
	dmg_m *= allm; R_m *= allm; v_m *= allm; val_m *= allm
	# 기본 스킬값
	var base_dmg := float(Skills.attack_power(int(skills_st.get("attack_power", 0)))) * dmg_m * onslaught
	var cc: float = minf(1.0, Skills.crit_chance(int(skills_st.get("crit_chance", 0))) + cc_add)
	var cm := Skills.crit_mult(int(skills_st.get("crit_damage", 0))) + cm_add
	var eff_dmg := base_dmg * (1.0 + cc * (cm - 1.0))
	var iv := Skills.attack_speed(int(skills_st.get("attack_speed", 0))) * iv_m / (1.0 + _windfury(skills_st, rune))
	var rng := Skills.attack_range(int(skills_st.get("attack_range", 0))) * R_m
	var mv := Skills.move(int(skills_st.get("move_speed", 0))) * v_m
	var magnet := Skills.magnet(int(skills_st.get("magnet_range", 0))) * magnet_m
	var goomok_dmg := Skills.goomok_dmg(int(skills_st.get("goomok_dmg", 0))) * goomok_m * woodcutter
	return {
		"eff_damage": eff_dmg,
		"attack_interval": maxf(0.02, iv),
		"attack_range": rng,
		"attack_count": Skills.attack_count(int(skills_st.get("attack_count", 0))),
		"move_speed": mv,
		"magnet_range": magnet,
		"coin_mult": val_m * avarice,
		"cap_mult": cap_m,
		"goomok_dmg_mult": goomok_dmg,
		"gc_add": gc_add,
		"crit_chance": cc,
	}

static func _rune(active: String, name: String) -> float:
	if active == name and Balance.RUNE_VAL.has(name):
		return 1.0 + float(Balance.RUNE_VAL[name])
	return 1.0

static func _windfury(skills_st: Dictionary, active: String) -> float:
	if active != "windfury":
		return 0.0
	var cc := Skills.crit_chance(int(skills_st.get("crit_chance", 0)))
	return Balance.WINDFURY_MAX * minf(1.0, cc / Balance.WINDFURY_CRIT_REF)
