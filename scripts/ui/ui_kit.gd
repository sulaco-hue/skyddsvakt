class_name UiKit
extends RefCounted
## Gemensamt utseende (pixelstil) och byggstenar för gränssnittet.

const BG := Color("121822")
const PANEL := Color(0.047, 0.067, 0.094, 0.93)
const RUTA := Color("1A232D")
const KNAPP := Color("1D2833")
const KNAPP_HOVER := Color("24313E")
const KANT := Color("2C3A48")
const KANT2 := Color("3B4C5D")
const TEXT := Color("E6EBE0")
const DAMPAD := Color("A9B6AE")
const LJUS := Color("C8D2CA")
const GRON := Color("8DBF5A")
const BARNSTEN := Color("F2B134")
const ROSA := Color("F07C8C")
const MORK := Color("121822")

const UTFALL := {
	"ok": {"etikett": "LAGSTÖD", "farg": GRON, "tecken": "+"},
	"warn": {"etikett": "DISKUTABELT", "farg": BARNSTEN, "tecken": "!"},
	"bad": {"etikett": "SAKNAR LAGSTÖD", "farg": ROSA, "tecken": "x"},
}

static var _brod: Font
static var _rubrik: Font
static var _rubrik_spatierad: Font


static func brodfont() -> Font:
	if _brod == null:
		_brod = load("res://assets/fonts/VT323-Regular.ttf")
	return _brod


static func rubrikfont(spatierad := false) -> Font:
	if _rubrik == null:
		var bas: Font = load("res://assets/fonts/PixelifySans.ttf")
		var fv := FontVariation.new()
		fv.base_font = bas
		fv.variation_embolden = 0.5
		_rubrik = fv
		var fv2 := FontVariation.new()
		fv2.base_font = bas
		fv2.variation_embolden = 0.5
		fv2.spacing_glyph = 2
		_rubrik_spatierad = fv2
	return _rubrik_spatierad if spatierad else _rubrik


static func skapa_tema() -> Theme:
	var t := Theme.new()
	t.default_font = brodfont()
	t.default_font_size = 22
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", ruta(PANEL, KANT))
	t.set_stylebox("normal", "Button", ruta(KNAPP, KANT2, 3, 14, 6))
	t.set_stylebox("hover", "Button", ruta(KNAPP_HOVER, BARNSTEN, 3, 14, 6))
	t.set_stylebox("pressed", "Button", ruta(KANT, BARNSTEN, 3, 14, 6))
	t.set_stylebox("disabled", "Button", ruta(Color("161D25"), KANT, 3, 14, 6))
	var fokus := ruta(Color(0, 0, 0, 0), BARNSTEN, 3, 14, 6)
	fokus.draw_center = false
	t.set_stylebox("focus", "Button", fokus)
	for f in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(f, "Button", TEXT)
	t.set_color("font_disabled_color", "Button", DAMPAD)
	t.set_font_size("font_size", "Button", 22)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	return t


static func ruta(bg: Color, kant: Color, bredd := 3, mx := 16, my := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = kant
	s.set_border_width_all(bredd)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	s.anti_aliasing = false
	return s


static func panel(kant := KANT, bg := PANEL, mx := 16, my := 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ruta(bg, kant, 3, mx, my))
	return p


static func etikett(text: String, storlek := 22, farg := TEXT, radbryt := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", storlek)
	l.add_theme_color_override("font_color", farg)
	if radbryt:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func rubrik(text: String, storlek := 15, farg := GRON) -> Label:
	var l := etikett(text, storlek, farg)
	l.add_theme_font_override("font", rubrikfont(true))
	return l


static func titel(text: String, storlek := 26, farg := TEXT) -> Label:
	var l := etikett(text, storlek, farg)
	l.add_theme_font_override("font", rubrikfont(false))
	return l


static func knapp(text: String, primar := false, farg := BARNSTEN) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	if primar:
		b.add_theme_font_override("font", rubrikfont(false))
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_stylebox_override("normal", ruta(farg, farg.darkened(0.35), 3, 18, 6))
		b.add_theme_stylebox_override("hover", ruta(farg.lightened(0.15), farg.darkened(0.35), 3, 18, 6))
		b.add_theme_stylebox_override("pressed", ruta(farg.darkened(0.15), farg.darkened(0.35), 3, 18, 6))
		for f in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(f, MORK)
	return b


static func vbox(mellanrum := 8) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", mellanrum)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func hbox(mellanrum := 8) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", mellanrum)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func fyllnad() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func ruta_farg(farg: Color, storlek: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = farg
	r.custom_minimum_size = storlek
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Liten ikon för utfall: färgad ruta med tecken (+ ! x) så att den går att
## skilja ut även utan färgseende.
static func utfallsikon(utfall: String, storlek := 22) -> PanelContainer:
	var info: Dictionary = UTFALL.get(utfall, UTFALL["warn"])
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ruta(info["farg"], info["farg"], 0, 0, 0))
	p.custom_minimum_size = Vector2(storlek, storlek)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := rubrik(str(info["tecken"]), int(storlek * 0.7), MORK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## Klickbar ruta (används för svarsalternativ och tidslinjerader där
## texten ska kunna radbrytas).
static func klickruta(kant := KANT2, bg := KNAPP, hover_kant := BARNSTEN) -> PanelContainer:
	var p := PanelContainer.new()
	var normal := ruta(bg, kant, 3, 16, 10)
	var hov := ruta(KNAPP_HOVER, hover_kant, 3, 16, 10)
	p.add_theme_stylebox_override("panel", normal)
	p.set_meta("normal", normal)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.mouse_entered.connect(func() -> void: p.add_theme_stylebox_override("panel", hov))
	p.mouse_exited.connect(func() -> void: p.add_theme_stylebox_override("panel", p.get_meta("normal")))
	return p


static func ar_klick(event: InputEvent) -> bool:
	var mus := event as InputEventMouseButton
	return mus != null and mus.pressed and mus.button_index == MOUSE_BUTTON_LEFT


static func helskarm(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
