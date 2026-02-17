class_name FontBakerCore
extends RefCounted

signal progress_updated(message: String)

## Options for baking.
class BakeOptions:
	var msdf_pixel_range: int = 14
	var msdf_size: int = 48


## Bake MSDF glyph atlas from a font file.
## [param src_font_path]: Path to the source TTF/OTF font file.
## [param char_ranges]: Array of [start, end] pairs (inclusive).
## [param char_points]: PackedInt32Array of individual code points.
## [param options]: BakeOptions instance.
## Returns the baked FontFile, or null on failure.
func bake(src_font_path: String, char_ranges: Array, char_points: PackedInt32Array, options: BakeOptions = null) -> FontFile:
	if options == null:
		options = BakeOptions.new()

	# 1. Load source font
	progress_updated.emit("Loading font...")
	var font_data := FileAccess.get_file_as_bytes(src_font_path)
	if font_data.is_empty():
		push_error("FontBaker: Failed to read font file: " + src_font_path)
		return null

	var src := FontFile.new()
	src.data = font_data
	src.multichannel_signed_distance_field = true
	src.msdf_pixel_range = options.msdf_pixel_range
	src.msdf_size = options.msdf_size

	# 2. Render specified character ranges
	var size := Vector2i(options.msdf_size * 64, 0)
	var ts := TextServerManager.get_primary_interface()
	var src_rids := src.get_rids()
	if src_rids.is_empty():
		push_error("FontBaker: Failed to get font RID")
		return null
	var src_rid: RID = src_rids[0]

	var total_chars := 0
	for r in char_ranges:
		if r is Array and r.size() >= 2:
			var range_start: int = r[0]
			var range_end: int = r[1]
			total_chars += range_end - range_start + 1
			progress_updated.emit("Rendering range U+%04X - U+%04X (%d chars)..." % [range_start, range_end, range_end - range_start + 1])
			ts.font_render_range(src_rid, size, range_start, range_end)

	if not char_points.is_empty():
		total_chars += char_points.size()
		progress_updated.emit("Rendering %d individual glyphs..." % char_points.size())
		for cp in char_points:
			var glyph_idx := ts.font_get_glyph_index(src_rid, size.x, cp, 0)
			if glyph_idx != 0:
				ts.font_render_glyph(src_rid, size, glyph_idx)

	progress_updated.emit("Rendered %d characters total." % total_chars)

	# 3. Build destination FontFile (no font data)
	var dst := FontFile.new()
	dst.multichannel_signed_distance_field = true
	dst.msdf_pixel_range = options.msdf_pixel_range
	dst.msdf_size = options.msdf_size

	# 4. Copy textures
	var tex_count := src.get_texture_count(0, size)
	progress_updated.emit("Copying %d textures..." % tex_count)
	for i in tex_count:
		dst.set_texture_image(0, size, i, src.get_texture_image(0, size, i))
		dst.set_texture_offsets(0, size, i, src.get_texture_offsets(0, size, i))

	# 5. Remap glyphs (FreeType glyph index -> Unicode code point)
	var glyph_list := src.get_glyph_list(0, size)
	var copied_count := 0
	progress_updated.emit("Remapping %d glyphs..." % glyph_list.size())

	for glyph_idx in glyph_list:
		var char_code := ts.font_get_char_from_glyph_index(src_rid, size.x, glyph_idx)
		if char_code == 0:
			continue

		dst.set_glyph_advance(0, size.x, char_code,
			src.get_glyph_advance(0, size.x, glyph_idx))
		dst.set_glyph_offset(0, size, char_code,
			src.get_glyph_offset(0, size, glyph_idx))
		dst.set_glyph_size(0, size, char_code,
			src.get_glyph_size(0, size, glyph_idx))
		dst.set_glyph_uv_rect(0, size, char_code,
			src.get_glyph_uv_rect(0, size, glyph_idx))
		dst.set_glyph_texture_idx(0, size, char_code,
			src.get_glyph_texture_idx(0, size, glyph_idx))
		copied_count += 1

	# 6. Copy font metrics
	dst.set_cache_ascent(0, size.x, src.get_cache_ascent(0, size.x))
	dst.set_cache_descent(0, size.x, src.get_cache_descent(0, size.x))

	progress_updated.emit("Bake complete: %d glyphs, %d textures." % [copied_count, tex_count])
	return dst


## Extract unique characters from a text file.
## Returns a PackedInt32Array of unique Unicode code points.
static func extract_chars_from_file(path: String) -> PackedInt32Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("FontBaker: Failed to open text file: " + path)
		return PackedInt32Array()

	var text := file.get_as_text()
	var char_set := {}
	for i in text.length():
		var cp := text.unicode_at(i)
		if cp > 0x20:  # Skip control characters and space
			char_set[cp] = true

	var result := PackedInt32Array()
	result.resize(char_set.size())
	var idx := 0
	for cp in char_set:
		result[idx] = cp
		idx += 1
	result.sort()
	return result
