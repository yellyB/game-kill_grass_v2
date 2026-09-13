#!/usr/bin/env python3
"""
World 1 해금까지 걸리는 시간 시뮬레이션
- 최적 강화 루트를 찾아 총 소요 시간 계산
- 가정: 세션 60초 + 세션 간 강화 시간 1분
"""

import math
import random

random.seed(42)

# ── Constants ──

SESSION_TIME = 60.0
BETWEEN_SESSION_TIME = 60  # seconds (1 min for upgrades)
WORLD_1_COST = 5000

# Player
PLAYER_SPEED = 300.0  # px/s
ATTACK_RADIUS = 80.0
ATTACK_COOLDOWN = 0.38  # seconds
ATTACK_CENTER_OFFSET = 40.0  # px ahead of player

# Grass
CHUNK_SIZE = 400.0
BASE_DROP_CHANCE = 0.2

# Grass types
GRASS_TYPES = [
    {"name": "기본풀", "hp": 4, "value": 1, "regen": 22.0},
    {"name": "강한풀", "hp": 12, "value": 5, "regen": 23.0},
    {"name": "완전 센풀", "hp": 24, "value": 30, "regen": 24.0},
    {"name": "황금풀", "hp": 160, "value": 300, "regen": 25.0},
]

# Weapons
WEAPONS = [
    {"name": "나뭇가지", "price": 0, "damage": 1},
    {"name": "녹슨 식칼", "price": 100, "damage": 2},
    {"name": "피자 커터", "price": 350, "damage": 3},
    {"name": "전기 파리채", "price": 900, "damage": 4},
    {"name": "뜨거운 다리미", "price": 2000, "damage": 5},
    {"name": "매우 화난 고양이", "price": 4500, "damage": 7},
]

WEAPON_SKILL_REQS = [0, 0, 2, 5, 9, 14, 20, 27, 35, 42]

SKILL_DEFS = {
    "grass_density": {"max": 10},
    "grass_quality": {"max": 10},
    "grass_regen": {"max": 3},
    "grass_reward": {"max": 10},
    "monster_knockback": {"max": 3},
    "grass_drop": {"max": 5},
    "golden_chance": {"max": 5},
}

SKILL_PREREQS = {
    "grass_regen:1": [("grass_density", 2)],
    "grass_regen:2": [("grass_density", 5)],
    "grass_regen:3": [("grass_density", 8)],
    "grass_reward:1": [("grass_quality", 2)],
    "monster_knockback:1": [("grass_reward", 2)],
    "golden_chance:1": [("grass_density", 3)],
    "golden_chance:2": [("grass_density", 5)],
    "golden_chance:3": [("grass_density", 7)],
    "golden_chance:4": [("grass_density", 9)],
    "grass_drop:1": [("grass_reward", 2)],
    "grass_drop:2": [("grass_reward", 4)],
    "grass_drop:3": [("grass_reward", 6)],
    "grass_drop:4": [("grass_reward", 8)],
}


# ── Game Mechanics ──

def get_cell_size(density_level):
    return 40.0 * 2.5 / (1.0 + density_level * 0.525)

def get_grass_type_weights(quality_level):
    if quality_level >= 8:
        normal_w = 0.0
    else:
        normal_w = ((8.0 - quality_level) / 8.0) ** 1.8
    if quality_level <= 2:
        strong_w = 0.0
    else:
        strong_w = ((quality_level - 2.0) / 8.0) ** 1.8
    tough_w = max(0.0, 1.0 - normal_w - strong_w)
    return normal_w, tough_w, strong_w

def get_golden_chance(golden_level):
    if golden_level == 0:
        return 0.0002
    return 0.002 * golden_level

def get_drop_chance(drop_level):
    return BASE_DROP_CHANCE + drop_level * 0.06

def get_reward_multiplier(reward_level):
    return 1.0 + reward_level * 0.3

def get_regen_reduction(regen_level):
    return regen_level * 5.0

def get_upgrade_cost(current_level, upgrade_type):
    base = int(100 * (1.8 ** current_level))
    if upgrade_type in ["golden_chance", "grass_drop"]:
        mult = 5.0 + current_level * 16.2
        return int(base * mult)
    if upgrade_type in ["grass_density", "grass_reward"] and current_level > 0:
        mult = 1.0 + current_level * 0.3
        return int(base * mult)
    if upgrade_type == "grass_quality" and current_level > 0:
        mult = 1.0 + current_level * 0.15
        return int(base * mult)
    if upgrade_type in ["grass_regen", "monster_knockback"] and current_level > 0:
        mult = 1.0 + current_level * 7.0
        return int(base * mult)
    return base

def can_unlock_skill(skill_type, target_level, levels):
    key = f"{skill_type}:{target_level}"
    if key not in SKILL_PREREQS:
        return True
    for req_type, req_level in SKILL_PREREQS[key]:
        if levels.get(req_type, 0) < req_level:
            return False
    return True

def get_total_skill_level(levels):
    return sum(levels.values())


# ── Session Simulation (grid-based, small area with back-and-forth) ──

def simulate_session(weapon_level, levels, num_trials=3):
    """
    Simulate a 60-second session.
    Player walks back and forth in a small area, repeatedly hitting grass.
    """
    damage = WEAPONS[weapon_level]["damage"]
    density_level = levels.get("grass_density", 0)
    quality_level = levels.get("grass_quality", 0)
    regen_level = levels.get("grass_regen", 0)
    reward_level = levels.get("grass_reward", 0)
    drop_level = levels.get("grass_drop", 0)
    golden_level = levels.get("golden_chance", 0)

    cell_size = get_cell_size(density_level)
    drop_chance = get_drop_chance(drop_level)
    reward_mult = get_reward_multiplier(reward_level)
    golden_chance = get_golden_chance(golden_level)
    normal_w, tough_w, strong_w = get_grass_type_weights(quality_level)

    total_earnings = 0

    for trial in range(num_trials):
        rng = random.Random(trial * 7 + 13)

        # Create grass in a rectangular area
        # Player walks back and forth along Y axis, advancing in X periodically
        field_w = 1200.0
        field_h = 800.0

        cells_x = int(field_w / cell_size)
        cells_y = int(field_h / cell_size)

        # Generate grass
        grass = []
        for gx in range(cells_x):
            for gy in range(cells_y):
                roll = rng.random()
                if roll < golden_chance:
                    type_idx = 3
                else:
                    roll2 = rng.random()
                    if roll2 < normal_w:
                        type_idx = 0
                    elif roll2 < normal_w + tough_w:
                        type_idx = 1
                    else:
                        type_idx = 2

                gt = GRASS_TYPES[type_idx]
                wx = gx * cell_size + cell_size * 0.5 + rng.uniform(-cell_size * 0.4, cell_size * 0.4)
                wy = gy * cell_size + cell_size * 0.5 + rng.uniform(-cell_size * 0.4, cell_size * 0.4)

                regen_time = max(5.0, gt["regen"] - get_regen_reduction(regen_level))
                grass.append({
                    "type": type_idx,
                    "hp": gt["hp"],
                    "max_hp": gt["hp"],
                    "value": gt["value"],
                    "cut": False,
                    "regen_timer": 0.0,
                    "regen_time": regen_time,
                    "x": wx,
                    "y": wy,
                })

        # Player starts at center-left
        px = 100.0
        py = field_h / 2.0
        dir_y = 1.0  # Moving down

        # Strip width = 2 * attack_radius (attack circle diameter)
        strip_width = ATTACK_RADIUS * 2.0

        time = 0.0
        dt = ATTACK_COOLDOWN
        earnings = 0

        while time < SESSION_TIME:
            # Move player
            move_dist = PLAYER_SPEED * dt
            py += dir_y * move_dist

            # Bounce at field edges (stay in field, walk back and forth)
            if py >= field_h - 50:
                dir_y = -1.0
                px += strip_width * 0.7  # advance to next strip (some overlap)
            elif py <= 50:
                dir_y = 1.0
                px += strip_width * 0.7

            # If we've gone beyond the field width, wrap back
            if px >= field_w - 50:
                px = 100.0

            # Attack center (offset ahead of player in movement direction)
            attack_cx = px
            attack_cy = py + dir_y * ATTACK_CENTER_OFFSET

            # Attack all grass in range
            r2 = ATTACK_RADIUS * ATTACK_RADIUS
            for g in grass:
                if g["cut"]:
                    continue
                dx = g["x"] - attack_cx
                dy = g["y"] - attack_cy
                if dx * dx + dy * dy <= r2:
                    g["hp"] -= damage
                    if g["hp"] <= 0:
                        g["cut"] = True
                        g["regen_timer"] = 0.0
                        # Drop check
                        is_golden = (g["type"] == 3)
                        if is_golden or rng.random() < drop_chance:
                            coin_value = max(1, int(round(g["value"] * reward_mult)))
                            earnings += coin_value

            # Process regen for cut grass
            for g in grass:
                if g["cut"]:
                    g["regen_timer"] += dt
                    if g["regen_timer"] >= g["regen_time"]:
                        # Regenerate with new type
                        roll = rng.random()
                        if roll < golden_chance:
                            type_idx = 3
                        else:
                            roll2 = rng.random()
                            if roll2 < normal_w:
                                type_idx = 0
                            elif roll2 < normal_w + tough_w:
                                type_idx = 1
                            else:
                                type_idx = 2
                        gt = GRASS_TYPES[type_idx]
                        g["type"] = type_idx
                        g["hp"] = gt["hp"]
                        g["max_hp"] = gt["hp"]
                        g["value"] = gt["value"]
                        g["cut"] = False
                        g["regen_timer"] = 0.0
                        g["regen_time"] = max(5.0, gt["regen"] - get_regen_reduction(regen_level))

            time += dt

        total_earnings += earnings

    return total_earnings / num_trials


# ── Optimizer ──

def get_available_upgrades(levels):
    available = []
    for skill_type, skill_def in SKILL_DEFS.items():
        current = levels.get(skill_type, 0)
        if current >= skill_def["max"]:
            continue
        next_level = current + 1
        if not can_unlock_skill(skill_type, next_level, levels):
            continue
        cost = get_upgrade_cost(current, skill_type)
        available.append({
            "type": skill_type,
            "level": next_level,
            "cost": cost,
        })
    return available

def get_available_weapons(weapon_level, levels):
    if weapon_level + 1 >= len(WEAPONS):
        return None
    next_weapon = WEAPONS[weapon_level + 1]
    required_skill = WEAPON_SKILL_REQS[weapon_level + 1] if weapon_level + 1 < len(WEAPON_SKILL_REQS) else 999
    total_skill = get_total_skill_level(levels)
    if total_skill >= required_skill:
        return {
            "weapon_level": weapon_level + 1,
            "cost": next_weapon["price"],
            "name": next_weapon["name"],
        }
    return None


def simulate_optimal_path():
    """
    Simulate the optimal path to unlock World 1.
    Greedy: at each step, buy the upgrade with best ROI.
    """
    levels = {k: 0 for k in SKILL_DEFS}
    weapon_level = 0
    total_money = 0
    session_count = 0
    total_time_seconds = 0
    history = []

    print("=" * 70)
    print("월드 1 해금 시뮬레이션 (최적 강화 루트)")
    print("=" * 70)
    print(f"목표: ${WORLD_1_COST:,} + 열쇠")
    print(f"세션 시간: {SESSION_TIME}초, 세션 간 시간: {BETWEEN_SESSION_TIME}초")
    print()

    # Cache current earnings to avoid re-simulation
    current_session_earnings = None

    max_sessions = 200  # Safety limit

    while total_money < WORLD_1_COST and session_count < max_sessions:
        # Simulate a session
        if current_session_earnings is None:
            current_session_earnings = simulate_session(weapon_level, levels, num_trials=5)

        earnings = int(current_session_earnings)
        if earnings <= 0:
            earnings = 1  # Minimum $1 per session (there's always some income)

        total_money += earnings
        session_count += 1
        total_time_seconds += SESSION_TIME + BETWEEN_SESSION_TIME

        weapon_name = WEAPONS[weapon_level]["name"]
        skill_total = get_total_skill_level(levels)
        print(f"세션 {session_count:3d} | 수입: ${earnings:>6,} | 누적: ${total_money:>8,} | "
              f"무기: {weapon_name} (dmg:{WEAPONS[weapon_level]['damage']}) | 스킬합: {skill_total}")

        if total_money >= WORLD_1_COST:
            break

        # Decide what to buy
        bought_something = True
        while bought_something:
            bought_something = False
            best_option = None
            best_roi = -1

            # Current baseline earnings
            baseline = current_session_earnings

            # Check skill upgrades
            for upgrade in get_available_upgrades(levels):
                if upgrade["cost"] > total_money:
                    continue
                test_levels = dict(levels)
                test_levels[upgrade["type"]] = upgrade["level"]
                new_earnings = simulate_session(weapon_level, test_levels, num_trials=3)
                extra = new_earnings - baseline
                if extra > 0 and upgrade["cost"] > 0:
                    # ROI = sessions to pay back
                    payback_sessions = upgrade["cost"] / extra
                    roi = extra / upgrade["cost"]
                elif extra > 0:
                    roi = 999
                else:
                    roi = -1

                if roi > best_roi:
                    best_roi = roi
                    best_option = {"action": "skill", "data": upgrade, "new_earnings": new_earnings}

            # Check weapon upgrade
            weapon_opt = get_available_weapons(weapon_level, levels)
            if weapon_opt and weapon_opt["cost"] <= total_money:
                new_earnings = simulate_session(weapon_opt["weapon_level"], levels, num_trials=3)
                extra = new_earnings - baseline
                if extra > 0 and weapon_opt["cost"] > 0:
                    roi = extra / weapon_opt["cost"]
                elif extra > 0:
                    roi = 999
                else:
                    roi = -1

                if roi > best_roi:
                    best_roi = roi
                    best_option = {"action": "weapon", "data": weapon_opt, "new_earnings": new_earnings}

            # Only buy if ROI is good enough (payback within ~10 sessions)
            # or if we have lots of money
            if best_option and best_roi > 0:
                if best_option["action"] == "skill":
                    upgrade = best_option["data"]
                    total_money -= upgrade["cost"]
                    levels[upgrade["type"]] = upgrade["level"]
                    current_session_earnings = best_option["new_earnings"]
                    print(f"  → 강화: {upgrade['type']} Lv.{upgrade['level']} "
                          f"(${upgrade['cost']:,}) | 잔액: ${total_money:,}")
                    bought_something = True
                    history.append(f"스킬 {upgrade['type']} Lv.{upgrade['level']} (${upgrade['cost']:,})")

                elif best_option["action"] == "weapon":
                    wp = best_option["data"]
                    total_money -= wp["cost"]
                    weapon_level = wp["weapon_level"]
                    current_session_earnings = best_option["new_earnings"]
                    print(f"  → 무기: {wp['name']} Lv.{weapon_level} "
                          f"(${wp['cost']:,}) | 잔액: ${total_money:,}")
                    bought_something = True
                    history.append(f"무기 {wp['name']} (${wp['cost']:,})")

    # Summary
    total_minutes = total_time_seconds / 60
    play_minutes = session_count * SESSION_TIME / 60
    upgrade_minutes = session_count * BETWEEN_SESSION_TIME / 60

    print()
    print("=" * 70)
    print("결과 요약")
    print("=" * 70)
    print(f"총 세션 수: {session_count}")
    print(f"총 소요 시간: {total_minutes:.0f}분 ({total_minutes/60:.1f}시간)")
    print(f"  - 플레이 시간: {play_minutes:.0f}분")
    print(f"  - 강화 시간: {upgrade_minutes:.0f}분")
    print(f"최종 보유 금액: ${total_money:,}")
    print(f"최종 무기: {WEAPONS[weapon_level]['name']} (Lv.{weapon_level}, dmg:{WEAPONS[weapon_level]['damage']})")
    active_skills = {k: v for k, v in levels.items() if v > 0}
    print(f"최종 스킬: {active_skills}")
    print()
    print("강화 순서:")
    for i, h in enumerate(history, 1):
        print(f"  {i}. {h}")

    if session_count >= max_sessions:
        print(f"\n⚠ 안전 제한 ({max_sessions} 세션)에 도달하여 시뮬레이션이 중단되었습니다.")

    return {
        "sessions": session_count,
        "total_time_minutes": total_minutes,
    }


def test_earnings():
    """Quick check: earnings at various configs"""
    print("=" * 70)
    print("세션별 예상 수입 테스트")
    print("=" * 70)

    configs = [
        ("초기 상태 (Lv0, 밀도0)", 0, {}),
        ("무기 Lv1 (dmg 2)", 1, {}),
        ("무기 Lv1 + 밀도1", 1, {"grass_density": 1}),
        ("무기 Lv2 (dmg 3) + 밀도2", 2, {"grass_density": 2}),
        ("무기 Lv3 (dmg 4) + 밀도3", 3, {"grass_density": 3, "grass_quality": 2}),
        ("무기 Lv3 + 밀도5 + 보상2", 3, {"grass_density": 5, "grass_quality": 2, "grass_reward": 2}),
    ]

    for label, wlv, skill_overrides in configs:
        full_levels = {k: 0 for k in SKILL_DEFS}
        full_levels.update(skill_overrides)
        earn = simulate_session(wlv, full_levels, num_trials=3)
        print(f"  {label:40s} → ${earn:>7,.0f}/세션")

    print()


if __name__ == "__main__":
    test_earnings()
    result = simulate_optimal_path()
