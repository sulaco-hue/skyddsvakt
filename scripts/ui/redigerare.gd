class_name Redigerare
extends Control
## Textredigeraren i spelet: ändra dialoger, repliker och andra texter i
## datafilerna. Ändringar sparas bara på den här enheten (user://redigerat/)
## och används direkt när man provspelar. "Kopiera"/"Ladda ner" ger hela filen,
## färdig att klistra in på GitHub.

signal stang
signal provspela(sokvag: String)

const GITHUB := "https://github.com/sulaco-hue/skyddsvakt/edit/main/"
## Övriga filer (scenarierna läggs till från index.json).
const OVRIGA := [
	["res://data/kamratsnack.json", "Kamratsnack"],
	["res://data/radiobrus.json", "Radiotrafik (brus)"],
	["res://data/samband.json", "Samband med CQ"],
	["res://data/lagrum.json", "Lagrum och debriefing"],
	["res://data/lagstodskort.json", "Lagstödskort"],
]
## Nycklar som visas som en kort förklaring bredvid fältet.
const FORKLARING := {
	"replik": "motpartens replik",
	"du": "det du säger (visas som DU:)",
	"text": "texten",
	"nasta": "nästa dialogsteg",
	"handling": "bedöms i debriefingen",
	"stamning": "+/- stämning",
	"alternativ": "dina svarsalternativ",
	"atgarder": "svar på åtgärdsknapparna",
	"slut": "samtalet tar slut här",
}

## Senast öppnade fil (redigeraren öppnar den igen efter provspel).
static var senaste := ""

var _filer: Array = []
var _sokvag := ""
var _data: Dictionary = {}
var _spara_om := -1.0
var _dialog_ids: Array = []
var _handlingar: Array = []
## Sektionerna i formuläret: "dialog/start" -> {knapp, oppna: Callable}
var _sektioner: Dictionary = {}

var _valj: OptionButton
var _status: Label
var _scroll: ScrollContainer
var _innehall: VBoxContainer
var _json_ruta: VBoxContainer
var _json_text: TextEdit
var _json_fel: Label
var _lage_knapp: Button


func bygg(start := "") -> void:
	UiKit.helskarm(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := UiKit.ruta_farg(UiKit.BG, Vector2.ZERO)
	UiKit.helskarm(bg)
	add_child(bg)
	_handlingar = (Datafil.las_json(Spel.LAGRUM_SOKVAG).get("handlingar", {}) as Dictionary).keys()
	_handlingar.sort()
	for sc: Dictionary in Spel.scenarier():
		_filer.append([str(sc["sokvag"]), "Scenario: " + str(sc["namn"])])
	_filer.append_array(OVRIGA)

	var marg := MarginContainer.new()
	UiKit.helskarm(marg)
	var m := 8 if UiKit.kompakt else 16
	for sida in ["left", "right", "top", "bottom"]:
		marg.add_theme_constant_override("margin_" + sida, m)
	add_child(marg)
	var kol := UiKit.vbox(6)
	marg.add_child(kol)

	var topp := UiKit.hbox(10)
	topp.add_child(UiKit.titel("REDIGERA TEXTER", 18, UiKit.BARNSTEN))
	_valj = OptionButton.new()
	_valj.focus_mode = Control.FOCUS_NONE
	_valj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_valj.add_theme_font_size_override("font_size", _fs())
	for f: Array in _filer:
		_valj.add_item(str(f[1]))
	_valj.item_selected.connect(func(i: int) -> void: _oppna(str(_filer[i][0])))
	topp.add_child(_valj)
	var stang_k := UiKit.knapp("Stäng")
	stang_k.pressed.connect(_stang)
	topp.add_child(stang_k)
	kol.add_child(topp)

	var knappar := HFlowContainer.new()
	knappar.add_theme_constant_override("h_separation", 6)
	knappar.add_theme_constant_override("v_separation", 6)
	kol.add_child(knappar)
	var prov := UiKit.knapp("Provspela", true, UiKit.GRON)
	prov.pressed.connect(_provspela)
	knappar.add_child(prov)
	_lage_knapp = UiKit.knapp("Visa JSON")
	_lage_knapp.pressed.connect(_vaxla_lage)
	knappar.add_child(_lage_knapp)
	var kopiera := UiKit.knapp("Kopiera fil")
	kopiera.pressed.connect(_kopiera)
	knappar.add_child(kopiera)
	var ladda := UiKit.knapp("Ladda ner fil")
	ladda.pressed.connect(_ladda_ner)
	knappar.add_child(ladda)
	var gh := UiKit.knapp("Kopiera + öppna GitHub")
	gh.pressed.connect(_github)
	knappar.add_child(gh)
	var aterstall := UiKit.knapp("Återställ original")
	aterstall.pressed.connect(_aterstall)
	knappar.add_child(aterstall)

	_status = UiKit.etikett("", 18, UiKit.DAMPAD, true)
	kol.add_child(_status)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	kol.add_child(_scroll)
	_innehall = UiKit.vbox(4)
	_innehall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_innehall)

	_json_ruta = UiKit.vbox(6)
	_json_ruta.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_json_ruta.visible = false
	kol.add_child(_json_ruta)
	_json_text = TextEdit.new()
	_json_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_json_text.add_theme_font_size_override("font_size", 18)
	_stil_falt(_json_text)
	_json_text.text_changed.connect(func() -> void: _json_fel.text = "")
	_json_ruta.add_child(_json_text)
	var jrad := UiKit.hbox(10)
	var anvand := UiKit.knapp("Använd JSON-texten", true)
	anvand.pressed.connect(_anvand_json)
	jrad.add_child(anvand)
	_json_fel = UiKit.etikett("", 18, UiKit.ROSA, true)
	_json_fel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jrad.add_child(_json_fel)
	_json_ruta.add_child(jrad)

	var forsta := start if start != "" else senaste
	if forsta == "" or not _filer.any(func(f: Array) -> bool: return f[0] == forsta):
		forsta = str(_filer[0][0])
	_oppna(forsta)


func _process(delta: float) -> void:
	if _spara_om >= 0.0:
		_spara_om -= delta
		if _spara_om < 0.0:
			_spara()


# ------------------------------------------------------------ Filer --

func _oppna(sokvag: String) -> void:
	_spara_nu()
	_sokvag = sokvag
	senaste = sokvag
	for i in _filer.size():
		if str(_filer[i][0]) == sokvag:
			_valj.select(i)
	_data = Datafil.las_json(sokvag)
	_json_ruta.visible = false
	_scroll.visible = true
	_lage_knapp.text = "Visa JSON"
	_bygg_formular()
	_uppdatera_status()


func _andrat() -> void:
	_spara_om = 0.6
	_status.text = "Sparar…"


func _spara_nu() -> void:
	if _spara_om >= 0.0:
		_spara_om = -1.0
		_spara()


func _spara() -> void:
	if _sokvag == "":
		return
	Datafil.spara_redigering(_sokvag, Datafil.till_text(_data))
	_dialog_ids = (_data.get("dialog", {}) as Dictionary).keys() if _data.get("dialog") is Dictionary else []
	_uppdatera_status()


func _uppdatera_status() -> void:
	var fil := _sokvag.trim_prefix("res://")
	if not Datafil.har_redigering(_sokvag):
		_status.text = "%s · original (inga ändringar)" % fil
		_status.add_theme_color_override("font_color", UiKit.DAMPAD)
	elif Datafil.original_andrat(_sokvag):
		_status.text = "%s · REDIGERAD på den här enheten · OBS: originalet har ändrats sedan du redigerade – exportera dina ändringar eller återställ." % fil
		_status.add_theme_color_override("font_color", UiKit.ROSA)
	else:
		_status.text = "%s · REDIGERAD – sparad på den här enheten och används när du spelar här. Kopiera/ladda ner filen för att lägga in den på GitHub." % fil
		_status.add_theme_color_override("font_color", UiKit.BARNSTEN)


func _text() -> String:
	return Datafil.till_text(_data)


func _kopiera() -> void:
	_spara_nu()
	DisplayServer.clipboard_set(_text())
	_status.text = "Hela %s kopierad. På GitHub: öppna filen, Edit, markera allt, klistra in, Commit." % _sokvag.get_file()


func _ladda_ner() -> void:
	_spara_nu()
	var namn := _sokvag.get_file()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(_text().to_utf8_buffer(), namn, "application/json")
		_status.text = "%s nedladdad." % namn
		return
	DirAccess.make_dir_recursive_absolute("user://export")
	var f := FileAccess.open("user://export/" + namn, FileAccess.WRITE)
	if f == null:
		_status.text = "Kunde inte spara filen."
		return
	f.store_string(_text())
	f.close()
	var mapp := ProjectSettings.globalize_path("user://export")
	OS.shell_open(mapp)
	_status.text = "Sparad som %s/%s" % [mapp, namn]


func _github() -> void:
	_kopiera()
	OS.shell_open(GITHUB + _sokvag.trim_prefix("res://"))


func _aterstall() -> void:
	_spara_om = -1.0
	Datafil.ta_bort_redigering(_sokvag)
	_oppna(_sokvag)


func _provspela() -> void:
	_spara_nu()
	provspela.emit(_sokvag if _sokvag.begins_with("res://data/scenarier/") and _sokvag.get_file() != "index.json" else "")


func _stang() -> void:
	_spara_nu()
	stang.emit()


# ------------------------------------------------------------ JSON-läge --

func _vaxla_lage() -> void:
	if _json_ruta.visible:
		if not _anvand_json():
			return
		_json_ruta.visible = false
		_scroll.visible = true
		_lage_knapp.text = "Visa JSON"
	else:
		_spara_nu()
		_json_text.text = _text()
		_json_fel.text = ""
		_json_ruta.visible = true
		_scroll.visible = false
		_lage_knapp.text = "Visa formulär"


func _anvand_json() -> bool:
	var json := JSON.new()
	if json.parse(_json_text.text) != OK:
		_json_fel.text = "Fel på rad %d: %s" % [json.get_error_line(), json.get_error_message()]
		return false
	if typeof(json.data) != TYPE_DICTIONARY:
		_json_fel.text = "Filen måste vara ett JSON-objekt { … }"
		return false
	_data = json.data
	_spara()
	_bygg_formular()
	_json_fel.text = "Använd."
	return true


# ------------------------------------------------------------ Formulär --

func _bygg_formular() -> void:
	for c in _innehall.get_children():
		c.queue_free()
	_sektioner.clear()
	_dialog_ids = (_data.get("dialog", {}) as Dictionary).keys() if _data.get("dialog") is Dictionary else []
	# Dialogen först (det man oftast vill åt); filens ordning ändras inte.
	var nycklar := _data.keys()
	if nycklar.has("dialog"):
		nycklar.erase("dialog")
		nycklar.push_front("dialog")
	for k in nycklar:
		_lagg_falt(_innehall, _data, k, str(k))
	# Dialogen är det man oftast vill åt.
	if _sektioner.has("dialog"):
		(_sektioner["dialog"]["oppna"] as Callable).call(true)


## Ett fält: sektion för objekt/listor, annars ett redigerbart värde.
func _lagg_falt(box: VBoxContainer, behallare: Variant, nyckel: Variant, vag: String) -> void:
	var v: Variant = behallare[nyckel]
	if v is Dictionary or v is Array:
		_lagg_sektion(box, behallare, nyckel, vag)
		return
	var rad := UiKit.hbox(8)
	box.add_child(rad)
	var namn := ("#%d" % (int(nyckel) + 1)) if behallare is Array else str(nyckel)
	var etikett := UiKit.etikett(namn, 18, UiKit.GRON if not behallare is Array else UiKit.DAMPAD)
	etikett.custom_minimum_size = Vector2(110 if UiKit.kompakt else 150, 0)
	etikett.tooltip_text = str(FORKLARING.get(namn, ""))
	etikett.mouse_filter = Control.MOUSE_FILTER_PASS
	rad.add_child(etikett)
	match typeof(v):
		TYPE_BOOL:
			var c := CheckBox.new()
			c.button_pressed = v
			c.focus_mode = Control.FOCUS_NONE
			c.toggled.connect(func(p: bool) -> void:
				behallare[nyckel] = p
				_andrat())
			rad.add_child(c)
			rad.add_child(UiKit.fyllnad())
		TYPE_FLOAT, TYPE_INT:
			var le := LineEdit.new()
			le.text = Datafil.till_text(v).strip_edges()
			le.custom_minimum_size = Vector2(120, 0)
			le.add_theme_font_size_override("font_size", _fs())
			_stil_falt(le)
			le.text_changed.connect(func(t: String) -> void:
				if t.is_valid_float():
					behallare[nyckel] = t.to_float()
					_andrat())
			rad.add_child(le)
			rad.add_child(UiKit.fyllnad())
		TYPE_STRING:
			if str(nyckel) == "nasta" and not _dialog_ids.is_empty():
				_lagg_val(rad, behallare, nyckel, _dialog_ids, true)
			elif str(nyckel) == "handling" and not _handlingar.is_empty():
				_lagg_val(rad, behallare, nyckel, _handlingar, false)
			else:
				var te := TextEdit.new()
				te.text = v
				te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
				te.scroll_fit_content_height = true
				te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				te.add_theme_font_size_override("font_size", _fs())
				_stil_falt(te)
				te.text_changed.connect(func() -> void:
					behallare[nyckel] = te.text
					_andrat())
				rad.add_child(te)
		_:
			rad.add_child(UiKit.etikett(str(v), 18, UiKit.DAMPAD))
			rad.add_child(UiKit.fyllnad())
	if not is_same(behallare, _data):
		rad.add_child(_ta_bort_knapp(box, behallare, nyckel))


## Rullgardin för nasta (dialogstegen) och handling (lagrum.json).
func _lagg_val(rad: HBoxContainer, behallare: Variant, nyckel: Variant, val: Array, hopp: bool) -> void:
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.add_theme_font_size_override("font_size", _fs())
	var nu := str(behallare[nyckel])
	var lista := val.duplicate()
	if not lista.has(nu):
		lista.push_front(nu)
	for x in lista:
		ob.add_item(str(x) if str(x) != "" else "(inget)")
	ob.select(lista.find(nu))
	ob.item_selected.connect(func(i: int) -> void:
		behallare[nyckel] = str(lista[i])
		_andrat())
	rad.add_child(ob)
	if hopp:
		var g := UiKit.knapp("Gå till →")
		g.custom_minimum_size = Vector2(0, 36)
		g.pressed.connect(func() -> void: _hoppa(str(behallare[nyckel])))
		rad.add_child(g)


func _lagg_sektion(box: VBoxContainer, behallare: Variant, nyckel: Variant, vag: String) -> void:
	var v: Variant = behallare[nyckel]
	var rad := UiKit.hbox(6)
	box.add_child(rad)
	var knapp := Button.new()
	knapp.focus_mode = Control.FOCUS_NONE
	knapp.alignment = HORIZONTAL_ALIGNMENT_LEFT
	knapp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	knapp.clip_text = true
	knapp.add_theme_font_size_override("font_size", _fs())
	knapp.custom_minimum_size = Vector2(0, 38)
	rad.add_child(knapp)
	if not is_same(behallare, _data):
		rad.add_child(_ta_bort_knapp(box, behallare, nyckel))
	var indrag := MarginContainer.new()
	indrag.add_theme_constant_override("margin_left", 14 if UiKit.kompakt else 26)
	indrag.visible = false
	box.add_child(indrag)
	var barn := UiKit.vbox(4)
	indrag.add_child(barn)
	var namn := ("#%d" % (int(nyckel) + 1)) if behallare is Array else str(nyckel)
	var rubrik := func() -> String:
		return ("▾ " if indrag.visible else "▸ ") + namn + "   " + _forhandsvisning(behallare[nyckel])
	var bygg_barn := func() -> void:
		for c in barn.get_children():
			c.queue_free()
		var inne: Variant = behallare[nyckel]
		if inne is Dictionary:
			for k in inne:
				_lagg_falt(barn, inne, k, vag + "/" + str(k))
			_lagg_ny_nyckel(barn, inne, vag)
		else:
			for i in (inne as Array).size():
				_lagg_falt(barn, inne, i, vag + "/" + str(i))
			_lagg_nytt_element(barn, inne, vag)
	var oppna := func(oppen: bool) -> void:
		if oppen and barn.get_child_count() == 0:
			bygg_barn.call()
		indrag.visible = oppen
		knapp.text = rubrik.call()
	knapp.text = rubrik.call()
	# I ett dialogsteg visas svarsalternativen och åtgärdssvaren direkt.
	var delar := vag.split("/")
	if delar.size() >= 3 and delar[0] == "dialog" and delar[2] in ["alternativ", "atgarder"]:
		oppna.call(true)
	knapp.pressed.connect(func() -> void: oppna.call(not indrag.visible))
	barn.set_meta("bygg_om", bygg_barn)
	_sektioner[vag] = {"knapp": knapp, "oppna": oppna}


func _forhandsvisning(v: Variant) -> String:
	var t := ""
	if v is Dictionary:
		for k in ["replik", "text", "du", "namn", "etikett"]:
			if (v as Dictionary).has(k) and v[k] is String:
				t = str(v[k])
				break
		if t == "":
			t = "(%d fält)" % (v as Dictionary).size()
	elif v is Array:
		t = "(%d st)" % (v as Array).size()
		if (v as Array).size() > 0 and v[0] is String:
			t += "  " + str(v[0])
	t = t.replace("\n", " ")
	return t.left(80) + ("…" if t.length() > 80 else "")


func _ta_bort_knapp(box: VBoxContainer, behallare: Variant, nyckel: Variant) -> Button:
	var b := UiKit.knapp("✕")
	b.custom_minimum_size = Vector2(36, 36)
	b.tooltip_text = "Ta bort"
	b.add_theme_color_override("font_color", UiKit.ROSA)
	b.pressed.connect(func() -> void:
		if behallare is Array:
			(behallare as Array).remove_at(int(nyckel))
		else:
			(behallare as Dictionary).erase(nyckel)
		_andrat()
		_bygg_om(box))
	return b


## Bygger om innehållet i en sektion (efter att något lagts till eller tagits bort).
func _bygg_om(box: VBoxContainer) -> void:
	if box == _innehall:
		_bygg_formular()
	elif box.has_meta("bygg_om"):
		(box.get_meta("bygg_om") as Callable).call()


func _lagg_ny_nyckel(box: VBoxContainer, d: Dictionary, vag: String) -> void:
	var rad := UiKit.hbox(8)
	box.add_child(rad)
	var ar_dialog := vag == "dialog"
	var le := LineEdit.new()
	le.placeholder_text = "namn på nytt dialogsteg" if ar_dialog else "nytt fältnamn"
	le.custom_minimum_size = Vector2(240, 0)
	le.add_theme_font_size_override("font_size", 18)
	_stil_falt(le)
	rad.add_child(le)
	var k := UiKit.knapp("+ Nytt dialogsteg" if ar_dialog else "+ Nytt textfält")
	k.custom_minimum_size = Vector2(0, 36)
	k.pressed.connect(func() -> void:
		var namn := le.text.strip_edges()
		if namn == "" or d.has(namn):
			return
		d[namn] = {"replik": "– ", "alternativ": [{"text": "", "nasta": ""}]} if ar_dialog else ""
		_andrat()
		_dialog_ids = (_data.get("dialog", {}) as Dictionary).keys() if _data.get("dialog") is Dictionary else []
		_bygg_om(box))
	rad.add_child(k)


func _lagg_nytt_element(box: VBoxContainer, a: Array, _vag: String) -> void:
	var k := UiKit.knapp("+ Lägg till")
	k.custom_minimum_size = Vector2(0, 36)
	k.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	k.pressed.connect(func() -> void:
		# Ett nytt element av samma slag som det sista (tomma texter).
		a.append(_tom_kopia(a.back()) if not a.is_empty() else "")
		_andrat()
		_bygg_om(box))
	box.add_child(k)


func _tom_kopia(v: Variant) -> Variant:
	if v is String:
		return ""
	if v is Dictionary:
		var ut := {}
		for k in v:
			var x: Variant = v[k]
			if x is String:
				# Kopplingar och avsändare behålls, texter töms.
				ut[k] = x if str(k) in ["nasta", "handling", "fran", "vem"] else ""
			else:
				ut[k] = _tom_kopia(x)
		return ut
	if v is Array:
		return [] if (v as Array).is_empty() else [_tom_kopia(v[0])]
	return v


## Hoppa till ett dialogsteg: öppna det och rulla dit.
func _hoppa(id: String) -> void:
	if not _sektioner.has("dialog"):
		return
	(_sektioner["dialog"]["oppna"] as Callable).call(true)
	var vag := "dialog/" + id
	if not _sektioner.has(vag):
		return
	(_sektioner[vag]["oppna"] as Callable).call(true)
	var knapp: Button = _sektioner[vag]["knapp"]
	await get_tree().process_frame
	await get_tree().process_frame
	_scroll.scroll_vertical = int(knapp.global_position.y - _innehall.global_position.y) - 8
	var tw := knapp.create_tween()
	knapp.modulate = UiKit.BARNSTEN
	tw.tween_property(knapp, "modulate", Color.WHITE, 1.2)


func _fs() -> int:
	return 17 if UiKit.kompakt else 20


func _stil_falt(c: Control) -> void:
	c.add_theme_stylebox_override("normal", UiKit.ruta(UiKit.RUTA, UiKit.KANT, 2, 8, 4))
	c.add_theme_stylebox_override("focus", UiKit.ruta(UiKit.RUTA, UiKit.BARNSTEN, 2, 8, 4))
	c.add_theme_color_override("font_color", UiKit.TEXT)
