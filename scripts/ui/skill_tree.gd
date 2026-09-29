extends Control
class_name SkillTree
## 스킬 트리 컨테이너 컴포넌트(순수). 자기 크기에 맞춰 그룹을 세로로 쌓고, 각 그룹은
## 루트(좌) → 오른쪽으로 뻗는 가로 트리로 배치(원본 upgrade_panel 레이아웃 이식).
## 노드=SkillNode, 연결선=SkillLink. ★ 매니저 안 읽음: groups/edges props를 화면이 공급.
##
## setup(groups, edges, on_select)
##   groups = [ {name, group_idx, columns, nodes:[SkillNode props...(skill_type 포함, 순서=루트먼저)]} ]
##   edges  = [ {from, to, group_idx, is_met} ]
##   on_select = Callable(btn, skill_type, target_level)

const NODE_MARGIN := 6.0
const NODE_INNER_PAD := 12.0
const GROUP_GAP := 34.0
const GROUP_HEADER_H := 65.0

var _groups: Array = []
var _edges: Array = []
var _on_select: Callable

func setup(groups: Array, edges: Array, on_select: Callable) -> void:
	_groups = groups
	_edges = edges
	_on_select = on_select
	clip_contents = true
	_relayout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_relayout()

func _relayout() -> void:
	if _groups.is_empty() or size.x <= 0 or size.y <= 0:
		return
	for c in get_children():
		c.queue_free()

	var row_gap := NODE_MARGIN + NODE_INNER_PAD * 2.0
	var group_count := _groups.size()
	var first_columns: int = int(_groups[0].get("columns", 2))

	# 노드 크기: 가로/세로 모두 맞게(스크롤 없이 한 화면)
	var max_col_count := 0
	for g in _groups:
		var cols: int = maxi(1, int(g.get("columns", 2)))
		var rc := int(ceil((g.get("nodes", []).size() - 1) / float(cols)))
		max_col_count = maxi(max_col_count, rc)
	var max_total_cols := 1 + max_col_count
	var tree_area_width := size.x - GROUP_HEADER_H
	var node_size_h := (tree_area_width - (max_total_cols - 1) * row_gap) / float(max_total_cols)
	var avail_v := size.y - (group_count - 1) * GROUP_GAP
	var group_width_max := avail_v / float(group_count)
	var node_size_v := (group_width_max - NODE_MARGIN * (first_columns + 1)) / float(first_columns) - NODE_INNER_PAD
	var node_size := minf(node_size_h, node_size_v) * 0.92
	node_size = maxf(node_size, 40.0)
	var group_width := (node_size + NODE_INNER_PAD) * first_columns + NODE_MARGIN * (first_columns + 1)
	var max_tree_width := max_total_cols * node_size + (max_total_cols - 1) * row_gap
	var base_x_shared := GROUP_HEADER_H + (tree_area_width - max_tree_width) / 2.0

	var centers := {}       # skill_type -> Vector2
	var row_counts := {}    # skill_type -> int
	var parent_of := _build_parent_map()

	var acc_y := 0.0
	for gi in range(group_count):
		var group: Dictionary = _groups[gi]
		var nodes: Array = group.get("nodes", [])
		var columns: int = maxi(1, int(group.get("columns", 2)))
		var group_idx: int = int(group.get("group_idx", gi))
		var group_y := acc_y

		# 그룹 헤더(좌측, 세로 중앙)
		var header := UIKit.make_label(str(group.get("name", "")), 32, Palette.XP, 4)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		header.position = Vector2(base_x_shared - GROUP_HEADER_H - 40, group_y)
		header.size = Vector2(GROUP_HEADER_H, group_width)
		add_child(header)

		if nodes.is_empty():
			acc_y += group_width + GROUP_GAP
			continue

		# 루트(좌, 세로 중앙)
		var root_props: Dictionary = nodes[0]
		var root_type: String = root_props.get("skill_type", "")
		var root_y := group_y + (group_width - node_size) / 2.0
		_place_node(root_props, Vector2(base_x_shared, root_y), node_size, centers)
		row_counts[root_type] = 1

		# 나머지: 오른쪽으로 뻗는 컬럼(컬럼당 columns행)
		var remaining: Array = nodes.slice(1)
		var col_count := int(ceil(remaining.size() / float(columns)))
		for c in range(col_count):
			var in_col: int = mini(columns, remaining.size() - c * columns)
			for r in range(in_col):
				var idx := c * columns + r
				var np: Dictionary = remaining[idx]
				var st: String = np.get("skill_type", "")
				var ny: float
				if in_col == 1:
					var sp: String = parent_of.get(st, "")
					if sp != "" and centers.has(sp):
						ny = centers[sp].y - node_size / 2.0
					else:
						ny = group_y + (group_width - node_size) / 2.0
				else:
					ny = group_y + NODE_MARGIN + r * (node_size + NODE_MARGIN + NODE_INNER_PAD * 2.0)
				var nx := base_x_shared + (c + 1) * (node_size + row_gap)
				_place_node(np, Vector2(nx, ny), node_size, centers)
				row_counts[st] = in_col

		acc_y += group_width + GROUP_GAP

	_draw_edges(centers, row_counts, node_size)

func _place_node(props: Dictionary, pos: Vector2, node_size: float, centers: Dictionary) -> void:
	var btn := SkillNode.build(props, node_size, _on_select)
	btn.position = pos
	btn.z_index = 2
	add_child(btn)
	centers[props.get("skill_type", "")] = pos + Vector2(node_size / 2.0, node_size / 2.0)

# 자식→부모(단일) 맵: edges에서 to가 한 번만 나오는 경우
func _build_parent_map() -> Dictionary:
	var incoming := {}
	for e in _edges:
		var to: String = e.get("to", "")
		incoming[to] = incoming.get(to, [])
		incoming[to].append(e.get("from", ""))
	var single := {}
	for to in incoming:
		if incoming[to].size() == 1:
			single[to] = incoming[to][0]
	return single

func _draw_edges(centers: Dictionary, row_counts: Dictionary, node_size: float) -> void:
	for e in _edges:
		var pt: String = e.get("from", "")
		var ct: String = e.get("to", "")
		if not centers.has(pt) or not centers.has(ct):
			continue
		var fc: Vector2 = centers[pt]
		var tc: Vector2 = centers[ct]
		var color := SkillLink.color_for(int(e.get("group_idx", 0)), bool(e.get("is_met", false)))
		var dy := tc.y - fc.y
		var pts: PackedVector2Array
		if abs(dy) < 2.0:
			pts = PackedVector2Array([Vector2(fc.x + node_size / 2.0, fc.y), Vector2(tc.x - node_size / 2.0, tc.y)])
		elif int(row_counts.get(pt, 1)) == 1:
			var s := Vector2(fc.x, fc.y + (node_size / 2.0 if dy > 0 else -node_size / 2.0))
			pts = PackedVector2Array([s, Vector2(s.x, tc.y), Vector2(tc.x - node_size / 2.0, tc.y)])
		else:
			var end := Vector2(tc.x, tc.y + (-node_size / 2.0 if dy > 0 else node_size / 2.0))
			pts = PackedVector2Array([Vector2(fc.x + node_size / 2.0, fc.y), Vector2(tc.x, fc.y), end])
		var line := SkillLink.make(pts, color)
		add_child(line)  # z_index=1 < 노드(2) → 노드 아래
