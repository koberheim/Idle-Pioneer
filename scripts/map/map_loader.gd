## Parses a hand-authored ASCII map into a MapGrid (task M2 - see
## docs/GODOT_PLAN.md Phase 5.2). MVP maps are hand-authored, not procedural
## (Phase 7) - this is the authoring path for that.
##
## Terrain legend, matching MapGrid.TERRAIN_GLYPH exactly:
##   .  deep water    ~  shallow water    +  coast    #  land
##
## Two input styles are both accepted, so this can parse either a human-authored
## map file (space-separated, one glyph per cell - easy to keep aligned in an
## editor) or the output of MapGrid.to_ascii() directly (compact, no spaces - see
## its own doc for why round-tripping through it needs this):
##   ". . . ~ ~ + # # #"   (whitespace-separated tokens)
##   ".+T"                 (one character per cell, no separator)
##
## SCOPE NOTE: this parses terrain only. Deposits are authored directly on
## RegionDef (task D3), not embedded in the ASCII map - a region already carries
## its own `deposit_id`, so there is no need for a second, ambiguous encoding of
## the same fact here (a single letter can't uniquely represent an arbitrary
## StringName id like &"timber" vs &"tin" anyway). MapGrid.deposits stays at its
## all-empty default for every hand-authored MVP map; only a later procedural
## generator (Phase 8+) would need to populate it programmatically.
class_name MapLoader

const GLYPH_TO_TERRAIN: Dictionary = {
	".": MapGrid.Terrain.DEEP_WATER,
	"~": MapGrid.Terrain.SHALLOW_WATER,
	"+": MapGrid.Terrain.COAST,
	"#": MapGrid.Terrain.LAND,
}


## Returns null and push_errors a specific reason on any malformed input -
## never a silently wrong map.
static func from_ascii(text: String) -> MapGrid:
	var lines: Array[String] = _split_into_rows(text)
	if lines.is_empty():
		push_error("MapLoader.from_ascii: input has no rows")
		return null

	var rows: Array[Array] = []
	var expected_width: int = -1

	for row_index: int in range(lines.size()):
		var tokens: Array = _tokenize_row(lines[row_index])

		if expected_width == -1:
			expected_width = tokens.size()
		elif tokens.size() != expected_width:
			push_error(
				"MapLoader.from_ascii: row %d has %d cells, expected %d (ragged map)" % [
					row_index, tokens.size(), expected_width
				]
			)
			return null

		var terrain_row: Array[MapGrid.Terrain] = []
		for col_index: int in range(tokens.size()):
			var token: String = tokens[col_index]
			if not GLYPH_TO_TERRAIN.has(token):
				push_error(
					"MapLoader.from_ascii: unknown glyph '%s' at row %d, col %d" % [
						token, row_index, col_index
					]
				)
				return null
			terrain_row.append(GLYPH_TO_TERRAIN[token] as MapGrid.Terrain)

		rows.append(terrain_row)

	var height: int = rows.size()
	var width: int = expected_width
	var grid: MapGrid = MapGrid.create(width, height)

	for y: int in range(height):
		for x: int in range(width):
			grid.set_terrain(Vector2i(x, y), rows[y][x])

	return grid


## Reads `path` (a res:// or user:// path) as text and parses it the same way
## as from_ascii(). Returns null (with a push_error already emitted) if the
## file can't be opened.
static func from_file(path: String) -> MapGrid:
	if not FileAccess.file_exists(path):
		push_error("MapLoader.from_file: no file at '%s'" % path)
		return null

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error(
			"MapLoader.from_file: failed to open '%s' (%s)" % [
				path, error_string(FileAccess.get_open_error())
			]
		)
		return null

	var text: String = file.get_as_text()
	file.close()
	return from_ascii(text)


## Splits raw text into non-empty, whitespace-trimmed rows. Tolerates the
## leading/trailing blank lines a triple-quoted GDScript string literal produces,
## and CRLF line endings (files in this repo are checked out with CRLF).
static func _split_into_rows(text: String) -> Array[String]:
	var normalized: String = text.replace("\r\n", "\n").dedent()
	var out: Array[String] = []
	for raw_line: String in normalized.split("\n"):
		var line: String = raw_line.strip_edges()
		if not line.is_empty():
			out.append(line)
	return out


## Whitespace-separated if the row contains any whitespace; otherwise one
## character per cell (see the class doc for why both are supported).
static func _tokenize_row(row: String) -> Array:
	if row.contains(" ") or row.contains("\t"):
		var regex := RegEx.new()
		regex.compile("\\S+")
		var tokens: Array = []
		for m: RegExMatch in regex.search_all(row):
			tokens.append(m.get_string())
		return tokens

	var chars: Array = []
	for i: int in range(row.length()):
		chars.append(row[i])
	return chars
