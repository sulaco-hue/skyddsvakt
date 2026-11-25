class_name UiKit
extends RefCounted
## Gemensamt utseende (pixelstil) och byggstenar för gränssnittet.

## Beredskapsnivån visas inte tills vidare (HUD och briefing). Sätt true för att visa den igen.
const VISA_BEREDSKAP := false
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

## Kompakt läge för pekskärmar (mobil/surfplatta): större text, mindre ytor.
static var kompakt := false

static var _brod: Font
static var _rubrik: Font
static var _rubrik_spatierad: Font


static func brodfont() -> Font:
	if _brod == null:
		_brod = load("res://assets/fonts/VT323-Regular.ttf")
		_lagg_fallback(_brod)
	return _brod


## Kyrilliska tecken (t.ex. ryska repliker) finns inte i pixeltypsnitten;
## Pixelify Sans tar dem (webbversionen har inga systemtypsnitt att falla tillbaka på).
static func _lagg_fallback(f: Font) -> void:
	var fb: Font = load("res://assets/fonts/PixelifySans.ttf")
	if fb and not f.fallbacks.has(fb):
		var lista := f.fallbacks.duplicate()
		lista.append(fb)
		f.fallbacks = lista


## Sant om texten innehåller kyrilliska tecken.
static func ar_kyrillisk(text: String) -> bool:
	for i in text.length():
		var k := text.unicode_at(i)
		if k >= 0x0400 and k <= 0x04FF:
			return true
	return false


## Kyrillisk text sätts helt i Pixelify Sans (så att hela repliken har samma
## typsnitt). Pixelify saknar versalerna О och П; de ersätts med de likadana
## latinska O och grekiska Π.
static func kyrillisk_etikett(l: Label) -> void:
	l.text = l.text.replace("О", "O").replace("П", "Π")
	l.add_theme_font_override("font", load("res://assets/fonts/PixelifySans.ttf"))


static func rubrikfont(spatierad := false) -> Font:
	if _rubrik == null:
		var bas: Font = load("res://assets/fonts/Jersey15-Regular.ttf")
		_lagg_fallback(bas)
		_rubrik = bas
		var fv := FontVariation.new()
		fv.base_font = bas
		fv.spacing_glyph = 1
		_rubrik_spatierad = fv
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


## Rubrikfonten (Jersey 15) är mindre än brödtexten vid samma punktstorlek.
const RUBRIK_SKALA := 1.35


static func rubrik(text: String, storlek := 15, farg := GRON) -> Label:
	var l := etikett(text, roundi(storlek * RUBRIK_SKALA), farg)
	l.add_theme_font_override("font", rubrikfont(true))
	return l


static func titel(text: String, storlek := 26, farg := TEXT) -> Label:
	var l := etikett(text, roundi(storlek * RUBRIK_SKALA), farg)
	l.add_theme_font_override("font", rubrikfont(false))
	return l


static func knapp(text: String, primar := false, farg := BARNSTEN) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	if primar:
		b.add_theme_font_override("font", rubrikfont(false))
		b.add_theme_font_size_override("font_size", roundi(15 * RUBRIK_SKALA))
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
	# PASS: händelsen går vidare till en omgivande ScrollContainer, så att man
	# kan dra/scrolla på pekskärm även när fingret startar på en ruta.
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.mouse_entered.connect(func() -> void: p.add_theme_stylebox_override("panel", hov))
	p.mouse_exited.connect(func() -> void: p.add_theme_stylebox_override("panel", p.get_meta("normal")))
	return p


## Låter tryck-dra gå igenom paneler till en omgivande ScrollContainer
## (PanelContainer stoppar annars händelsen, så att man inte kan scrolla
## på pekskärm när fingret startar på t.ex. en textruta).
static func slapp_igenom(rot: Node) -> void:
	for c in rot.get_children():
		if c is PanelContainer and (c as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		slapp_igenom(c)


## Ett "tryck": knappen släpps på rutan utan att fingret/musen dragits iväg
## (så att scrollning inte räknas som ett val).
static func ar_tryck(event: InputEvent, c: Control) -> bool:
	var m := event as InputEventMouseButton
	if m == null or m.button_index != MOUSE_BUTTON_LEFT:
		return false
	if m.pressed:
		c.set_meta("tryck_start", m.global_position)
		return false
	if not c.has_meta("tryck_start"):
		return false
	var start: Vector2 = c.get_meta("tryck_start")
	c.remove_meta("tryck_start")
	return start.distance_to(m.global_position) < 14.0 and c.get_global_rect().has_point(m.global_position)


static func ar_klick(event: InputEvent) -> bool:
	var mus := event as InputEventMouseButton
	return mus != null and mus.pressed and mus.button_index == MOUSE_BUTTON_LEFT


static func helskarm(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0


## Ljudknapp (musik av/på) – samma som i HUD:en, för menyerna.
static func ljudknapp() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(52, 52)
	b.focus_mode = Control.FOCUS_NONE
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.tooltip_text = "Musik av/på [M]"
	b.add_theme_stylebox_override("normal", ruta(PANEL, KANT, 3, 10, 10))
	var pa := preload("res://assets/gfx/hogtalare_pa.png")
	var av := preload("res://assets/gfx/hogtalare_av.png")
	b.icon = pa if Musik.ar_pa() else av
	b.pressed.connect(func() -> void: Musik.vaxla())
	Musik.andrad.connect(func(p: bool) -> void:
		if is_instance_valid(b):
			b.icon = pa if p else av)
	return b
