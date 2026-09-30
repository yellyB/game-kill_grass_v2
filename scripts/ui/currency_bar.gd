extends VBoxContainer
class_name CurrencyBar
## 상단 자원 표시 바 = "접시". CurrencyChip(붕어빵 틀)로 찍어낸 코인/보석 칩을 세로로 담는다.
## 스마트 컨테이너: GameManager를 구독해 칩에 값 주입(노드 free 시 연결 자동 해제).
## money_display 인터페이스 호환: update_display / show_cost_floating / show_gem_cost_floating.
## 정수 등 새 자원은 CurrencyChip.make(아이콘, 색)으로 칩 하나 더 추가하면 끝.

var _coin: CurrencyChip = null
var _gem: CurrencyChip = null
var _crown: TextureRect = null

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_coin = CurrencyChip.make(Icons.COIN, Color(1, 0.9, 0.3))
	add_child(_coin)
	_gem = CurrencyChip.make(Icons.GEM, Color(0.95, 0.3, 0.5))
	add_child(_gem)
	if GameManager.has_potion:
		_add_crown()

	GameManager.money_changed.connect(_on_money_changed)
	update_display()

func _on_money_changed(_amount: int) -> void:
	update_display()

func _add_crown() -> void:
	_crown = TextureRect.new()
	_crown.texture = preload("res://resources/images/icon/crown.png")
	_crown.custom_minimum_size = Vector2(48, 48)
	_crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_crown.size_flags_horizontal = Control.SIZE_SHRINK_END
	_crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crown)

# ── money_display 호환 인터페이스 ──
func update_display() -> void:
	if is_instance_valid(_coin):
		_coin.set_value(GameManager.format_number(GameManager.money))
	if is_instance_valid(_gem):
		_gem.set_value(GameManager.format_number(GameManager.owned_gems))
	# 칩 너비 동기화: 넓은 쪽에 맞춤(코인/보석 박스 폭 정렬)
	await get_tree().process_frame
	_sync_chip_widths()

func _sync_chip_widths() -> void:
	if not is_instance_valid(_coin) or not is_instance_valid(_gem):
		return
	_coin.custom_minimum_size.x = 0
	_gem.custom_minimum_size.x = 0
	var max_w: float = maxf(_coin.get_combined_minimum_size().x, _gem.get_combined_minimum_size().x)
	_coin.custom_minimum_size.x = max_w
	_gem.custom_minimum_size.x = max_w

func show_cost_floating(amount: int) -> void:
	if is_instance_valid(_coin):
		_coin.show_cost_floating("-%s" % GameManager.format_number(amount), Color(1, 0.35, 0.3))

func show_gem_cost_floating(amount: int) -> void:
	if is_instance_valid(_gem):
		_gem.show_cost_floating("-%s" % GameManager.format_number(amount), Color(0.95, 0.3, 0.5))
