extends RefCounted
class_name SkillTree
## 스킬 트리 컨테이너 컴포넌트(순수). groups/edges props를 받아 그룹별 그리드로 배치하고
## SkillNode(노드) + SkillLink(연결선)를 조립해 ScrollContainer로 반환.
## ★ 매니저/게임상태 안 읽음. 상태는 화면이 GameManager에서 읽어 props로 넘긴다.
##
## groups = [ { "name": String, "group_idx": int, "columns": int,
##             "nodes": [ SkillNode props dict, ... ] } ]   # 각 node props엔 skill_type 포함
## edges  = [ { "from": skill_type, "to": skill_type, "group_idx": int, "is_met": bool } ]
## on_select = Callable(btn, skill_type, target_level)

static func build(groups: Array, edges: Array, on_select: Callable, node_size: float = 150.0) -> ScrollContainer:
	var gap := 18.0
	var group_gap := 46.0
	var header_h := 40.0

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var canvas := Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(canvas)

	var centers := {}   # skill_type -> Vector2(center)
	var node_btns := {} # skill_type -> Button
	var y := 0.0
	var max_x := 0.0

	for g in groups:
		var columns: int = maxi(1, int(g.get("columns", 2)))
		var nodes: Array = g.get("nodes", [])
		var group_idx: int = int(g.get("group_idx", 0))

		# 그룹 헤더
		var header := UIKit.make_label(str(g.get("name", "")), 30, Palette.XP, 4)
		header.position = Vector2(0, y)
		canvas.add_child(header)
		y += header_h

		# 노드 그리드
		for i in nodes.size():
			var np: Dictionary = nodes[i]
			var col := i % columns
			var row := i / columns
			var px := col * (node_size + gap)
			var py := y + row * (node_size + gap)
			var btn := SkillNode.build(np, node_size, on_select)
			btn.position = Vector2(px, py)
			canvas.add_child(btn)
			var st: String = np.get("skill_type", "")
			centers[st] = Vector2(px + node_size / 2.0, py + node_size / 2.0)
			node_btns[st] = btn
			max_x = maxf(max_x, px + node_size)

		var rows := int(ceil(float(nodes.size()) / float(columns)))
		y += rows * (node_size + gap) + group_gap

	canvas.custom_minimum_size = Vector2(max_x, y)

	# 연결선 (노드 뒤에 깔리도록 맨 앞에 삽입 + z 낮춤)
	var line_idx := 0
	for e in edges:
		var from_c = centers.get(e.get("from", ""), null)
		var to_c = centers.get(e.get("to", ""), null)
		if from_c == null or to_c == null:
			continue
		var color := SkillLink.color_for(int(e.get("group_idx", 0)), bool(e.get("is_met", false)))
		# 엘보(세로→가로) 경로 — 부모 중심 → 자식 y로 꺾어 → 자식 중심
		var pts := PackedVector2Array([from_c, Vector2(from_c.x, to_c.y), to_c])
		var line := SkillLink.make(pts, color)
		line.z_index = 0
		canvas.add_child(line)
		canvas.move_child(line, line_idx)  # 노드보다 앞(=아래 레이어)에 배치
		line_idx += 1

	return scroll
