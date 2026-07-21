# res://scripts/ui/MenuHeadingLabel.gd
@tool
extends RichTextLabel

@export var heading_text: String = "AUDIO":
	set(value):
		heading_text = value
		_refresh_heading()

@export var first_letter_size: int = 11:
	set(value):
		first_letter_size = max(1, value)
		_refresh_heading()

@export var rest_letter_size: int = 9:
	set(value):
		rest_letter_size = max(1, value)
		_refresh_heading()

@export var heading_font: FontFile = preload("res://data/res/LibreBaskerville-VariableFont_wght.ttf"):
	set(value):
		heading_font = value
		_bold_font = null
		_refresh_heading()

@export_range(0.0, 2.0, 0.05) var embolden: float = 0.75:
	set(value):
		embolden = value
		_bold_font = null
		_refresh_heading()

@export var heading_color: Color = Color.BLACK:
	set(value):
		heading_color = value
		_refresh_heading()

@export var auto_fit_width: bool = true:
	set(value):
		auto_fit_width = value
		_refresh_heading()

var _bold_font: FontVariation = null

func _ready() -> void:
	_refresh_heading()

func set_heading_text(value: String) -> void:
	heading_text = value

func _refresh_heading() -> void:
	if not is_inside_tree():
		return
	bbcode_enabled = true
	if heading_font:
		add_theme_font_override("normal_font", heading_font)
		add_theme_font_override("bold_font", _get_bold_font())
	text = _format_heading_text(heading_text)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fit_width_to_heading()

func _format_heading_text(value: String) -> String:
	var upper_text := value.to_upper()
	if upper_text == "":
		return ""
	var first_letter := upper_text.substr(0, 1)
	var rest_letters := upper_text.substr(1)
	var color_html := heading_color.to_html(false)
	return "[font_size=%d][color=#%s][b]%s[/b][/color][/font_size][font_size=%d][color=#%s][b]%s[/b][/color][/font_size]" % [
		first_letter_size,
		color_html,
		first_letter,
		rest_letter_size,
		color_html,
		rest_letters
	]

func _get_bold_font() -> FontVariation:
	if _bold_font == null:
		_bold_font = FontVariation.new()
		_bold_font.base_font = heading_font
		_bold_font.variation_embolden = embolden
	return _bold_font

func _fit_width_to_heading() -> void:
	if not auto_fit_width:
		return
	var target_width := ceilf(_get_heading_text_width(heading_text)) + 2.0
	if target_width <= 0.0:
		return
	var center_x := position.x + (size.x * 0.5)
	custom_minimum_size = Vector2(target_width, custom_minimum_size.y)
	size = Vector2(target_width, size.y)
	position = Vector2(center_x - (target_width * 0.5), position.y)
	update_minimum_size()

func _get_heading_text_width(value: String) -> float:
	if heading_font == null:
		return size.x
	var upper_text := value.to_upper()
	if upper_text == "":
		return 0.0
	var first_letter := upper_text.substr(0, 1)
	var rest_letters := upper_text.substr(1)
	var bold_font := _get_bold_font()
	var first_width := bold_font.get_string_size(first_letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, first_letter_size).x
	var rest_width := bold_font.get_string_size(rest_letters, HORIZONTAL_ALIGNMENT_LEFT, -1.0, rest_letter_size).x
	return first_width + rest_width
