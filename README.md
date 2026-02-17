# Font Baker

Godot 4 editor plugin that bakes MSDF glyph atlases from TTF/OTF fonts.

The baked `.tres` resource contains only the glyph cache (textures + metrics), allowing text rendering **without distributing the original font file**. This is useful for CJK fonts with restrictive licenses that prohibit embedding.

## How It Works

1. Load a TTF/OTF font and enable MSDF rendering
2. Render the selected character ranges into glyph atlas textures
3. Remap glyph indices from FreeType IDs to Unicode code points
4. Save as a FontFile resource (`.tres`) with cache data only, no font binary

Godot's TextServer already supports "no font data" mode where glyphs are looked up directly from cache, so the baked resource works as a drop-in replacement.

## Installation

Copy the `addons/font_baker/` directory into your Godot project's `addons/` folder, then enable the plugin in **Project > Project Settings > Plugins**.

## Usage

1. Open the **Font Baker** dock panel (bottom-left by default)
2. Select a source TTF/OTF font
3. Choose an output path for the `.tres` file
4. Adjust MSDF settings if needed (Pixel Range, MSDF Size)
5. Select character sets to include
6. Optionally load a text file to extract used characters
7. Click **Bake**

## Character Set Presets

| Preset | Range | Count |
|--------|-------|-------|
| ASCII | U+0020-007E | 95 |
| Latin Extended | U+00A0-024F | 432 |
| Hiragana | U+3040-309F | 96 |
| Katakana | U+30A0-30FF, U+FF65-FF9F | 155 |
| CJK Symbols | U+3000-303F | 64 |
| Fullwidth Alphanumeric | U+FF01-FF60 | 96 |
| CJK Unified Ideographs | U+4E00-9FFF | 20,992 |
| CJK Unified Ext. A | U+3400-4DBF | 6,592 |
| JIS Level 1 | 2,965 kanji | 2,965 |
| JIS Level 2 | 3,390 kanji | 3,390 |

JIS Level 1/2 code points are sourced from the [Unicode Consortium JIS X 0208 mapping](https://www.unicode.org/Public/MAPPINGS/OBSOLETE/EASTASIA/JIS/JIS0208.TXT).

## Limitations

- No HarfBuzz shaping (ligatures, contextual alternation) in baked output. CJK text is unaffected since it uses 1:1 character-to-glyph mapping.
- Ideographic Variation Sequences (IVS) are not supported without FreeType.
- The baked font works at any display size thanks to MSDF, but cannot be re-rasterized at a different MSDF source size.

## License

MIT
