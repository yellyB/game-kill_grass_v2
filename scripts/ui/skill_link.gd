extends RefCounted
class_name SkillLink
## 스킬 노드 연결선 — 공유 컴포넌트(선 스타일/색). 공유 컴포넌트.
## ⚠️ 경로(어디서 꺾어 어디로) 계산은 각 화면의 레이아웃에 종속되므로 공유하지 않음(화면이 점 배열을 만든다).
##    여기선 "점 배열 → 스타일된 Line2D"와 "그룹/충족여부 → 색"만 공유. (인자 과다 회피)

# 그룹(0무기 1수집 2수확) + 충족여부 → 연결선 색 (Palette 토큰)
static func color_for(group_idx: int, is_met: bool) -> Color:
	var arr := Palette.GROUP_LINE_MET if is_met else Palette.GROUP_LINE_UNMET
	return arr[clampi(group_idx, 0, arr.size() - 1)]

# 점 배열 → 공통 스타일 Line2D
static func make(points: PackedVector2Array, color: Color, width: float = 4.5) -> Line2D:
	var line := Line2D.new()
	line.z_index = 1
	line.width = width
	line.antialiased = true
	line.default_color = color
	line.points = points
	return line
