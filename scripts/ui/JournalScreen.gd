# res://scripts/ui/JournalScreen.gd
extends Control

@export var notes_label: Label
@export var prev_button: BaseButton
@export var next_button: BaseButton
@export_range(1, 100, 1) var max_visible_lines := 21

var _pages: Array[String] = []
var _current_page := 0
var _notes: Array[Dictionary] = []
@onready var _next_audio: AudioStreamPlayer = _resolve_ui_audio_player(NodePath("JournalNextAudio"))
@onready var _prev_audio: AudioStreamPlayer = _resolve_ui_audio_player(NodePath("JournalPrevAudio"))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if notes_label:
		notes_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		notes_label.resized.connect(_on_notes_label_resized)
	if prev_button:
		prev_button.process_mode = Node.PROCESS_MODE_ALWAYS
		prev_button.pressed.connect(_on_prev_pressed)
	if next_button:
		next_button.process_mode = Node.PROCESS_MODE_ALWAYS
		next_button.pressed.connect(_on_next_pressed)
	InputRouter.ui_left_requested.connect(_on_ui_left_requested)
	InputRouter.ui_right_requested.connect(_on_ui_right_requested)
	_refresh_page()

func set_notes(notes: Array[Dictionary]) -> void:
	_notes = notes
	_pages = _build_pages(_notes)
	_current_page = clampi(_current_page, 0, max(_pages.size() - 1, 0))
	_refresh_page()

func _build_pages(notes: Array[Dictionary]) -> Array[String]:
	if notes.is_empty():
		return ["No notes yet."]

	var built_pages: Array[String] = []
	var current_lines: Array[String] = []
	for note in notes:
		var title: String = str(note.get("title", ""))
		var desc: String = str(note.get("description", ""))
		var entry_lines: Array[String] = []
		if title != "":
			entry_lines.append_array(_wrap_text_to_lines(title))
		if desc != "":
			entry_lines.append_array(_wrap_text_to_lines(desc))
		_append_entry_to_pages(entry_lines, current_lines, built_pages)

	if not current_lines.is_empty():
		built_pages.append("\n".join(current_lines))
	return built_pages

func _append_entry_to_pages(entry_lines: Array[String], current_lines: Array[String], built_pages: Array[String]) -> void:
	if entry_lines.is_empty():
		return
	var line_limit: int = max(max_visible_lines, 1)
	var entry_line_count: int = entry_lines.size()
	if entry_line_count <= line_limit:
		var spacing_lines := 1 if not current_lines.is_empty() else 0
		if not current_lines.is_empty() and current_lines.size() + spacing_lines + entry_line_count > line_limit:
			built_pages.append("\n".join(current_lines))
			current_lines.clear()
			spacing_lines = 0
		if spacing_lines > 0:
			current_lines.append("")
		current_lines.append_array(entry_lines)
		return

	for line in entry_lines:
		if current_lines.size() >= line_limit:
			built_pages.append("\n".join(current_lines))
			current_lines.clear()
		current_lines.append(line)

func _wrap_text_to_lines(text: String) -> Array[String]:
	var lines: Array[String] = []
	var paragraphs: PackedStringArray = text.split("\n", false)
	for paragraph in paragraphs:
		lines.append_array(_wrap_paragraph_to_lines(paragraph))
	return lines

func _wrap_paragraph_to_lines(paragraph: String) -> Array[String]:
	var max_width: float = _get_notes_text_width()
	if max_width <= 0.0:
		return [paragraph]

	var font: Font = _get_notes_font()
	var font_size: int = _get_notes_font_size()
	if font == null or font_size <= 0:
		return [paragraph]

	var words: PackedStringArray = paragraph.split(" ", false)
	if words.is_empty():
		return [""]

	var lines: Array[String] = []
	var current_line := ""
	for word in words:
		var candidate: String = word if current_line == "" else "%s %s" % [current_line, word]
		if _get_text_width(font, font_size, candidate) <= max_width:
			current_line = candidate
			continue
		if current_line != "":
			lines.append(current_line)
		current_line = word
	if current_line != "":
		lines.append(current_line)
	return lines

func _get_notes_text_width() -> float:
	if notes_label == null:
		return 0.0
	return notes_label.size.x

func _get_notes_font() -> Font:
	if notes_label == null:
		return null
	var settings: LabelSettings = notes_label.label_settings
	if settings != null and settings.font != null:
		return settings.font
	return notes_label.get_theme_font("font")

func _get_notes_font_size() -> int:
	if notes_label == null:
		return 0
	var settings: LabelSettings = notes_label.label_settings
	if settings != null and settings.font_size > 0:
		return settings.font_size
	return notes_label.get_theme_font_size("font_size")

func _get_text_width(font: Font, font_size: int, text: String) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x

func _refresh_page() -> void:
	if _pages.is_empty():
		_pages = ["No notes yet."]
		_current_page = 0
	if notes_label:
		notes_label.text = _pages[_current_page]
	if prev_button:
		prev_button.visible = _pages.size() > 1 and _current_page > 0
	if next_button:
		next_button.visible = _pages.size() > 1 and _current_page < _pages.size() - 1

func _on_prev_pressed() -> void:
	var previous_page: int = _current_page
	_current_page = maxi(_current_page - 1, 0)
	_refresh_page()
	if _current_page != previous_page:
		_play_ui_audio(_prev_audio)
	_mark_input_handled()

func _on_next_pressed() -> void:
	var previous_page: int = _current_page
	_current_page = mini(_current_page + 1, _pages.size() - 1)
	_refresh_page()
	if _current_page != previous_page:
		_play_ui_audio(_next_audio)
	_mark_input_handled()

func _on_ui_left_requested() -> void:
	if not visible:
		return
	if _current_page <= 0:
		return
	_on_prev_pressed()

func _on_ui_right_requested() -> void:
	if not visible:
		return
	if _current_page >= _pages.size() - 1:
		return
	_on_next_pressed()

func _on_notes_label_resized() -> void:
	if _notes.is_empty():
		return
	_pages = _build_pages(_notes)
	_current_page = clampi(_current_page, 0, max(_pages.size() - 1, 0))
	_refresh_page()

func _mark_input_handled() -> void:
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()

func _resolve_ui_audio_player(path: NodePath) -> AudioStreamPlayer:
	var node: Node = get_node_or_null(path)
	if node is AudioStreamPlayer:
		var player: AudioStreamPlayer = node as AudioStreamPlayer
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.bus = &"UI"
		player.volume_db = 0.0
		return player
	return null

func _play_ui_audio(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	player.stop()
	player.play()
