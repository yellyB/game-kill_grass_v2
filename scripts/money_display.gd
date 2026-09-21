extends VBoxContainer

@onready var coin_panel: PanelContainer = $CoinPanel
@onready var coin_row: HBoxContainer = $CoinPanel/CoinRow
@onready var coin_icon: TextureRect = $CoinPanel/CoinRow/CoinIcon
@onready var money_label: Label = $CoinPanel/CoinRow/MoneyLabel

var gem_panel: PanelContainer = null
var gem_row: HBoxContainer = null
var gem_label: Label = null
var crown_icon: Control = null

func _ready() -> void:
  GameManager.money_changed.connect(_on_money_changed)
  _style_panel(coin_panel)
  # HUD(플레이 중)에서는 보석 패널 숨김
  var in_hud = get_tree().current_scene and get_tree().current_scene.scene_file_path == "res://scenes/core/main.tscn"
  if not in_hud:
    _create_gem_row()
    if GameManager.has_potion:
      _create_crown_row()
  update_display()

func _on_money_changed(_amount: int) -> void:
  update_display()

func _style_panel(panel: PanelContainer) -> void:
  var style = StyleBoxFlat.new()
  style.bg_color = Color(0.16, 0.16, 0.22, 0.9)
  style.border_width_top = 2
  style.border_width_bottom = 2
  style.border_width_left = 2
  style.border_width_right = 2
  style.border_color = Color(0.65, 0.7, 0.8, 0.6)
  style.corner_radius_top_left = 12
  style.corner_radius_top_right = 12
  style.corner_radius_bottom_left = 12
  style.corner_radius_bottom_right = 12
  style.content_margin_left = 20
  style.content_margin_right = 20
  style.content_margin_top = 8
  style.content_margin_bottom = 8
  style.shadow_color = Color(0.6, 0.7, 0.9, 0.25)
  style.shadow_size = 4
  panel.add_theme_stylebox_override("panel", style)

func _create_gem_row() -> void:
  gem_panel = PanelContainer.new()
  gem_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
  gem_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
  _style_panel(gem_panel)
  add_child(gem_panel)

  gem_row = HBoxContainer.new()
  gem_row.add_theme_constant_override("separation", 16)
  gem_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
  gem_panel.add_child(gem_row)

  var gem_icon = GameManager._create_gem_display_icon(36)
  gem_row.add_child(gem_icon)

  gem_label = Label.new()
  gem_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  gem_label.add_theme_font_size_override("font_size", 38)
  gem_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.5))
  gem_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  gem_label.add_theme_constant_override("outline_size", 4)
  gem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  gem_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  gem_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  gem_row.add_child(gem_label)

func _create_crown_row() -> void:
  crown_icon = TextureRect.new()
  crown_icon.texture = preload("res://resources/images/icon/crown.png")
  crown_icon.custom_minimum_size = Vector2(48, 48)
  crown_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  crown_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  crown_icon.size_flags_horizontal = Control.SIZE_SHRINK_END
  crown_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
  add_child(crown_icon)

func update_display() -> void:
  money_label.text = GameManager.format_number(GameManager.money)
  if gem_label:
    gem_label.text = GameManager.format_number(GameManager.owned_gems)
  # 두 패널 너비 동기화: 더 넓은 쪽에 맞춤
  await get_tree().process_frame
  _sync_panel_widths()

func _sync_panel_widths() -> void:
  if not gem_panel or not is_instance_valid(gem_panel):
    return
  # 리셋하여 자연 크기 측정
  coin_panel.custom_minimum_size.x = 0
  gem_panel.custom_minimum_size.x = 0
  var coin_w = coin_panel.get_combined_minimum_size().x
  var gem_w = gem_panel.get_combined_minimum_size().x
  var max_w = maxf(coin_w, gem_w)
  coin_panel.custom_minimum_size.x = max_w
  gem_panel.custom_minimum_size.x = max_w

func show_cost_floating(amount: int) -> void:
  var lbl = Label.new()
  lbl.text = "-%s" % GameManager.format_number(amount)
  lbl.add_theme_font_size_override("font_size", 34)
  lbl.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
  lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  lbl.add_theme_constant_override("outline_size", 4)
  lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
  # 코인 패널 아래에 배치
  lbl.position = Vector2(0, coin_panel.size.y)
  lbl.size = Vector2(coin_panel.size.x, 40)
  coin_panel.add_child(lbl)
  # 팝 + 위로 떠오르며 페이드아웃
  lbl.scale = Vector2(0.5, 0.5)
  lbl.pivot_offset = Vector2(lbl.size.x, lbl.size.y / 2.0)
  var tween = create_tween()
  tween.set_parallel(true)
  tween.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
  tween.tween_property(lbl, "position:y", coin_panel.size.y + 30, 0.8).set_ease(Tween.EASE_OUT)
  tween.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.4)
  tween.chain().tween_callback(lbl.queue_free)

func show_gem_cost_floating(amount: int) -> void:
  if not gem_panel or not is_instance_valid(gem_panel):
    return
  var lbl = Label.new()
  lbl.text = "-%s" % GameManager.format_number(amount)
  lbl.add_theme_font_size_override("font_size", 34)
  lbl.add_theme_color_override("font_color", Color(0.95, 0.3, 0.5))
  lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  lbl.add_theme_constant_override("outline_size", 4)
  lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
  lbl.position = Vector2(0, gem_panel.size.y)
  lbl.size = Vector2(gem_panel.size.x, 40)
  gem_panel.add_child(lbl)
  lbl.scale = Vector2(0.5, 0.5)
  lbl.pivot_offset = Vector2(lbl.size.x, lbl.size.y / 2.0)
  var tween = create_tween()
  tween.set_parallel(true)
  tween.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
  tween.tween_property(lbl, "position:y", gem_panel.size.y + 30, 0.8).set_ease(Tween.EASE_OUT)
  tween.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.4)
  tween.chain().tween_callback(lbl.queue_free)
