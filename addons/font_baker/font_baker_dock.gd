@tool
extends VBoxContainer

var _src_path: String = ""
var _dst_path: String = ""
var _custom_text_path: String = ""
var _src_dialog: EditorFileDialog
var _dst_dialog: EditorFileDialog
var _custom_text_dialog: EditorFileDialog

# Charset checkbox keys matching Charsets constants
const CHARSET_KEYS := [
	"ASCII",
	"LATIN_EXTENDED",
	"HIRAGANA",
	"KATAKANA",
	"CJK_SYMBOLS",
	"FULLWIDTH",
	"CJK_UNIFIED",
	"CJK_UNIFIED_EXT_A",
	"JIS_LEVEL1",
	"JIS_LEVEL2",
]

# Node names for checkboxes (must match .tscn)
const CHECKBOX_NAMES := [
	"ChkAscii",
	"ChkLatinExt",
	"ChkHiragana",
	"ChkKatakana",
	"ChkCjkSymbols",
	"ChkFullwidth",
	"ChkCjkUnified",
	"ChkCjkExtA",
	"ChkJis1",
	"ChkJis2",
]


func _ready() -> void:
	# Source font dialog
	_src_dialog = EditorFileDialog.new()
	_src_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_src_dialog.add_filter("*.ttf, *.otf ; Font Files")
	_src_dialog.title = "Select Source Font"
	_src_dialog.file_selected.connect(_on_src_selected)
	add_child(_src_dialog)

	# Destination dialog
	_dst_dialog = EditorFileDialog.new()
	_dst_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_dst_dialog.add_filter("*.tres ; Godot Resource")
	_dst_dialog.title = "Select Output Path"
	_dst_dialog.file_selected.connect(_on_dst_selected)
	add_child(_dst_dialog)

	# Custom text file dialog
	_custom_text_dialog = EditorFileDialog.new()
	_custom_text_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_custom_text_dialog.add_filter("*.txt ; Text Files")
	_custom_text_dialog.title = "Select Custom Text File"
	_custom_text_dialog.file_selected.connect(_on_custom_text_selected)
	add_child(_custom_text_dialog)

	# Connect buttons
	%SrcButton.pressed.connect(func(): _src_dialog.popup_centered_ratio(0.6))
	%DstButton.pressed.connect(func(): _dst_dialog.popup_centered_ratio(0.6))
	%CustomTextButton.pressed.connect(func(): _custom_text_dialog.popup_centered_ratio(0.6))
	%BakeButton.pressed.connect(_on_bake_pressed)

	# Connect checkboxes for status update
	for cb_name in CHECKBOX_NAMES:
		var cb: CheckBox = %CharsetContainer.get_node(cb_name)
		cb.toggled.connect(func(_v): _update_status())

	_update_status()


func _on_src_selected(path: String) -> void:
	_src_path = path
	%SrcPath.text = path.get_file()
	_update_status()


func _on_dst_selected(path: String) -> void:
	_dst_path = path
	%DstPath.text = path.get_file()


func _on_custom_text_selected(path: String) -> void:
	_custom_text_path = path
	%CustomTextPath.text = path.get_file()
	_update_status()


func _update_status() -> void:
	var total := _estimate_char_count()
	%StatusLabel.text = "Bake target: approx. %d characters" % total


func _estimate_char_count() -> int:
	var total := 0
	for i in CHARSET_KEYS.size():
		var cb_name: String = CHECKBOX_NAMES[i]
		var cb: CheckBox = %CharsetContainer.get_node(cb_name)
		if not cb.button_pressed:
			continue
		var key: String = CHARSET_KEYS[i]
		total += Charsets.estimate_count(key)

	if not _custom_text_path.is_empty():
		var chars := FontBakerCore.extract_chars_from_file(_custom_text_path)
		total += chars.size()
	return total


func _on_bake_pressed() -> void:
	if _src_path.is_empty():
		%ResultLabel.text = "Error: No source font selected."
		return
	if _dst_path.is_empty():
		%ResultLabel.text = "Error: No output path selected."
		return

	%BakeButton.disabled = true
	%ResultLabel.text = ""

	# Gather ranges and points
	var ranges: Array = []
	var points := PackedInt32Array()

	for i in CHARSET_KEYS.size():
		var cb: CheckBox = %CharsetContainer.get_node(CHECKBOX_NAMES[i])
		if not cb.button_pressed:
			continue
		var key: String = CHARSET_KEYS[i]
		var data: Dictionary = Charsets.get_charset(key)
		if data.has("ranges"):
			ranges.append_array(data["ranges"])
		if data.has("points"):
			var pts: PackedInt32Array = data["points"]
			points.append_array(pts)

	# Custom text file
	if not _custom_text_path.is_empty():
		var custom_chars := FontBakerCore.extract_chars_from_file(_custom_text_path)
		points.append_array(custom_chars)

	if ranges.is_empty() and points.is_empty():
		%ResultLabel.text = "Error: No characters selected."
		%BakeButton.disabled = false
		return

	# Build options
	var options := FontBakerCore.BakeOptions.new()
	options.msdf_pixel_range = int(%PixelRangeSpin.value)
	options.msdf_size = int(%MsdfSizeSpin.value)

	# Bake
	var baker := FontBakerCore.new()
	baker.progress_updated.connect(func(msg): %StatusLabel.text = msg)

	var result := baker.bake(_src_path, ranges, points, options)
	if result == null:
		%ResultLabel.text = "Bake failed. Check Output log."
		%BakeButton.disabled = false
		return

	# Save
	var err := ResourceSaver.save(result, _dst_path)
	if err != OK:
		%ResultLabel.text = "Save failed: error %d" % err
	else:
		var file_size := FileAccess.get_file_as_bytes(_dst_path).size()
		var size_str: String
		if file_size > 1048576:
			size_str = "%.1f MB" % (file_size / 1048576.0)
		else:
			size_str = "%.1f KB" % (file_size / 1024.0)
		%ResultLabel.text = "Bake succeeded!\nSaved to: %s\nFile size: %s" % [_dst_path.get_file(), size_str]

	%BakeButton.disabled = false
