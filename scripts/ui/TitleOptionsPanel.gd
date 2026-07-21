@tool
extends PanelContainer
class_name TitleOptionsPanel

@export_group("Main Panel")
@export var panel_background_color: Color = Color(0.75331914, 0.8409651, 0.9177723, 0.8235294):
	set(value):
		panel_background_color = value
		_apply_panel_style_if_ready()
@export var panel_border_color: Color = Color.WHITE:
	set(value):
		panel_border_color = value
		_apply_panel_style_if_ready()
@export_range(0, 16, 1) var panel_border_width: int = 3:
	set(value):
		panel_border_width = value
		_apply_panel_style_if_ready()
@export_range(0, 32, 1) var panel_corner_radius: int = 10:
	set(value):
		panel_corner_radius = value
		_apply_panel_style_if_ready()

@export_group("Options")
@export var option_background_color: Color = Color(1.0, 0.96, 0.84, 0.9)
@export var option_selection_color: Color = Color(0.9843137, 0.7921569, 0.5176471, 0.8235294)
@export var option_border_color: Color = Color(0.0, 0.0, 0.0, 0.45)
@export_range(320, 900, 1) var option_row_width: float = 520.0:
	set(value):
		option_row_width = value
		_apply_options_list_style_if_ready()

@export_group("Scroll Bar")
@export var scroll_bar_color: Color = Color(0.9843137, 0.7921569, 0.5176471, 0.95):
	set(value):
		scroll_bar_color = value
		_apply_scroll_style_if_ready()
@export var scroll_bar_background_color: Color = Color(0.0, 0.0, 0.0, 0.25):
	set(value):
		scroll_bar_background_color = value
		_apply_scroll_style_if_ready()
@export_range(0, 64, 1) var scroll_bar_left_margin: int = 22:
	set(value):
		scroll_bar_left_margin = value
		_apply_scroll_style_if_ready()
@export_range(2, 32, 1) var scroll_bar_width: int = 12:
	set(value):
		scroll_bar_width = value
		_apply_scroll_style_if_ready()

var _configured_options_list: VBoxContainer = null
var _configured_scroll: ScrollContainer = null

func _ready() -> void:
	apply_panel_style()
	_apply_options_list_style_if_ready()
	_apply_scroll_style_if_ready()

func apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = panel_background_color
	style.border_color = panel_border_color
	style.set_border_width_all(panel_border_width)
	style.set_corner_radius_all(panel_corner_radius)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 22.0
	style.content_margin_bottom = 22.0
	add_theme_stylebox_override("panel", style)

func apply_options_list_style(options_list: VBoxContainer) -> void:
	_configured_options_list = options_list
	_apply_options_list_style_if_ready()

func apply_scroll_style(scroll: ScrollContainer) -> void:
	_configured_scroll = scroll
	_apply_scroll_style_if_ready()

func make_option_row_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = option_selection_color if selected else option_background_color
	style.border_color = option_border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style

func _apply_panel_style_if_ready() -> void:
	if is_inside_tree():
		apply_panel_style()

func _apply_options_list_style_if_ready() -> void:
	if _configured_options_list == null or not is_instance_valid(_configured_options_list):
		return
	_configured_options_list.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_configured_options_list.custom_minimum_size.x = option_row_width

func _apply_scroll_style_if_ready() -> void:
	if _configured_scroll == null or not is_instance_valid(_configured_scroll):
		return
	_configured_scroll.add_theme_constant_override("h_separation", scroll_bar_left_margin)
	var scroll_bar: VScrollBar = _configured_scroll.get_v_scroll_bar()
	if scroll_bar == null:
		return
	scroll_bar.custom_minimum_size.x = scroll_bar_width
	scroll_bar.add_theme_stylebox_override("scroll", _make_scroll_style(scroll_bar_background_color))
	scroll_bar.add_theme_stylebox_override("scroll_focus", _make_scroll_style(scroll_bar_background_color))
	scroll_bar.add_theme_stylebox_override("grabber", _make_scroll_style(scroll_bar_color))
	scroll_bar.add_theme_stylebox_override("grabber_highlight", _make_scroll_style(scroll_bar_color.lightened(0.12)))
	scroll_bar.add_theme_stylebox_override("grabber_pressed", _make_scroll_style(scroll_bar_color.darkened(0.12)))

func _make_scroll_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	var corner_radius: int = maxi(1, int(round(float(scroll_bar_width) * 0.5)))
	style.set_corner_radius_all(corner_radius)
	return style
