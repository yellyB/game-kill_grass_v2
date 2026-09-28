extends RefCounted
## 콤보(정수) 배율 — 누적 수렴형 순수 계산. 게임/시뮬 공유(결정적, Node 의존 0).
## 세션 중 연속 처치(풀+정예, 거목 제외)로 콤보가 쌓이고, 처치당 점수 배율은
## 콤보가 커질수록 COMBO_MAX_MULT로 수렴(saturate)한다. 누적점수는 세션끝 정수로 환산.
const Balance = preload("res://core/balance_data.gd")

# 현재 콤보 수에서의 처치당 점수 배율. combo→∞ 이면 COMBO_MAX_MULT 로 수렴.
static func multiplier(combo: int) -> float:
	if combo <= 0:
		return 1.0
	var cap := Balance.COMBO_MAX_MULT - 1.0
	return 1.0 + cap * float(combo) / (float(combo) + Balance.COMBO_HALF_K)

# 이번 1처치가 누적점수에 더하는 양(= 처치 시점 콤보의 배율).
static func score_gain(combo: int) -> float:
	return multiplier(combo)

# 세션 누적점수 → 정수 개수.
static func tokens_from_score(score: float) -> int:
	return int(floor(score / Balance.COMBO_TOKEN_DIV))
