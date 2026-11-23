class_name Briefing
extends Control
## Omvärldsläge och briefing före passet.

signal starta


func bygg(scenario: Dictionary) -> void:
	if UiKit.kompakt:
		_bygg_kompakt(scenario)
		return
	UiKit.helskarm(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := UiKit.ruta_farg(UiKit.BG, Vector2.ZERO)
	UiKit.helskarm(bg)
	add_child(bg)

	var marg := MarginContainer.new()
	UiKit.helskarm(marg)
	for s in ["margin_left", "margin_right"]:
		marg.add_theme_constant_override(s, 32)
	for s in ["margin_top", "margin_bottom"]:
		marg.add_theme_constant_override(s, 28)
	marg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(marg)

	var yttre := UiKit.vbox(12)
	marg.add_child(yttre)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	yttre.add_child(scroll)
	var rad := UiKit.hbox(24)
	rad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(rad)

	# --- Omvärldsläge
	var vanster := UiKit.vbox(12)
	vanster.custom_minimum_size = Vector2(300 if UiKit.kompakt else 400, 0)
	rad.add_child(vanster)
	vanster.add_child(UiKit.titel("Omvärldsläge"))

	var bered := UiKit.panel(UiKit.BARNSTEN, UiKit.KNAPP)
	var bv := UiKit.vbox(2)
	bered.add_child(bv)
	bv.add_child(UiKit.rubrik("BEREDSKAPSNIVÅ", 13, UiKit.DAMPAD))
	bv.add_child(UiKit.titel(str(scenario.get("beredskap", "")), 22, UiKit.BARNSTEN))
	vanster.add_child(bered)

	vanster.add_child(UiKit.rubrik("SENASTE DYGNET", 13, UiKit.DAMPAD))
	for n in scenario.get("omvarldslage", []):
		var p := UiKit.panel(UiKit.KANT, UiKit.RUTA)
		var pv := UiKit.vbox(0)
		p.add_child(pv)
		pv.add_child(UiKit.etikett("%s · %s" % [n.get("tid", ""), n.get("kalla", "")], 18, UiKit.GRON))
		pv.add_child(UiKit.etikett(str(n.get("text", "")), 22, UiKit.TEXT, true))
		vanster.add_child(p)

	# --- Briefing
	var hoger := UiKit.vbox(14)
	hoger.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rad.add_child(hoger)
	var topp := UiKit.hbox(12)
	topp.add_child(UiKit.titel("Briefing · " + str(scenario.get("pass", ""))))
	topp.add_child(UiKit.fyllnad())
	topp.add_child(UiKit.etikett("%s · %s" % [scenario.get("passtid", ""), scenario.get("objekt", "")], 22, UiKit.DAMPAD))
	hoger.add_child(topp)

	var b: Dictionary = scenario.get("briefing", {})
	var kartrad := UiKit.hbox(16)
	hoger.add_child(kartrad)
	var kartram := UiKit.panel(UiKit.KANT2, UiKit.BG, 0, 0)
	var karta := TextureRect.new()
	var bild := "res://assets/gfx/objektskarta_%s.png" % Spel.objekttyp
	karta.texture = load(bild if ResourceLoader.exists(bild) else "res://assets/gfx/objektskarta.png")
	karta.custom_minimum_size = Vector2(336, 189) if UiKit.kompakt else Vector2(480, 270)
	karta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	karta.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	karta.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # kartan visas i 75 % storlek
	kartram.add_child(karta)
	kartrad.add_child(kartram)
	var info := UiKit.vbox(6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.rubrik("OBJEKTET", 13, UiKit.DAMPAD))
	info.add_child(UiKit.etikett(str(b.get("objektinfo", "")), 22, UiKit.LJUS, true))
	info.add_child(UiKit.rubrik("SAMBAND", 13, UiKit.DAMPAD))
	info.add_child(UiKit.etikett(str(b.get("samband", "")), 20, UiKit.LJUS, true))
	kartrad.add_child(info)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hoger.add_child(grid)
	var upp := UiKit.panel(UiKit.KANT, UiKit.RUTA)
	upp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var uv := UiKit.vbox(6)
	upp.add_child(uv)
	uv.add_child(UiKit.rubrik("BEVAKNINGSINSTRUKTION", 13))
	uv.add_child(UiKit.etikett(str(b.get("uppdrag", "")), 22, UiKit.TEXT, true))
	grid.add_child(upp)

	var knappar := UiKit.hbox(12)
	knappar.add_child(UiKit.etikett("Lagstödet i detta utkast är inte juridiskt granskat.", 20, UiKit.DAMPAD))
	knappar.add_child(UiKit.fyllnad())
	var start := UiKit.knapp("STARTA PASS", true, UiKit.GRON)
	start.custom_minimum_size = Vector2(200, 52)
	start.pressed.connect(func() -> void: starta.emit())
	knappar.add_child(start)
	yttre.add_child(knappar)


func _unhandled_input(event: InputEvent) -> void:
	var tangent := event as InputEventKey
	if visible and tangent != null and tangent.pressed and not tangent.echo:
		if tangent.keycode == KEY_ENTER or tangent.keycode == KEY_SPACE:
			starta.emit()
			get_viewport().set_input_as_handled()


# ------------------------------------------------------------ Mobil --
# På liten skärm visas en del i taget under flikar: UPPDRAG, OBJEKTET och
# OMVÄRLD. Passets namn och STARTA PASS ligger alltid synliga längst ner.

var _flikar: Array[Button] = []
var _sidor: Array[Control] = []


func _bygg_kompakt(scenario: Dictionary) -> void:
	UiKit.helskarm(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := UiKit.ruta_farg(UiKit.BG, Vector2.ZERO)
	UiKit.helskarm(bg)
	add_child(bg)
	var marg := MarginContainer.new()
	UiKit.helskarm(marg)
	for s in ["margin_left", "margin_right"]:
		marg.add_theme_constant_override(s, 16)
	for s in ["margin_top", "margin_bottom"]:
		marg.add_theme_constant_override(s, 8)
	marg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(marg)
	var yttre := UiKit.vbox(8)
	marg.add_child(yttre)

	var flikrad := UiKit.hbox(8)
	yttre.add_child(flikrad)
	var b: Dictionary = scenario.get("briefing", {})
	var sidor := [
		["UPPDRAG", _sida_uppdrag(scenario, b)],
		["OBJEKTET", _sida_objekt(b)],
		["OMVÄRLD", _sida_omvarld(scenario)],
	]
	for i in sidor.size():
		var f := UiKit.knapp(str(sidor[i][0]))
		f.toggle_mode = true
		f.custom_minimum_size = Vector2(130, 40)
		f.pressed.connect(_visa_sida.bind(i))
		flikrad.add_child(f)
		_flikar.append(f)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var innehall: Control = sidor[i][1]
		innehall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(innehall)
		yttre.add_child(scroll)
		_sidor.append(scroll)
	_visa_sida(0)

	var nere := UiKit.hbox(12)
	var namn := UiKit.titel("Briefing · " + str(scenario.get("pass", "")), 22)
	namn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nere.add_child(namn)
	nere.add_child(UiKit.fyllnad())
	var start := UiKit.knapp("STARTA PASS", true, UiKit.GRON)
	start.custom_minimum_size = Vector2(180, 46)
	start.pressed.connect(func() -> void: starta.emit())
	nere.add_child(start)
	yttre.add_child(nere)


func _visa_sida(i: int) -> void:
	for j in _sidor.size():
		_sidor[j].visible = j == i
		_flikar[j].button_pressed = j == i


func _sida_uppdrag(scenario: Dictionary, b: Dictionary) -> Control:
	var v := UiKit.vbox(10)
	v.add_child(UiKit.etikett("%s · %s · %s" % [scenario.get("passtid", ""), scenario.get("objekt", ""),
		scenario.get("vader", "")], 20, UiKit.DAMPAD, true))
	var upp := UiKit.panel(UiKit.KANT, UiKit.RUTA)
	var uv := UiKit.vbox(4)
	upp.add_child(uv)
	uv.add_child(UiKit.rubrik("BEVAKNINGSINSTRUKTION", 13))
	uv.add_child(UiKit.etikett(str(b.get("uppdrag", "")), 22, UiKit.TEXT, true))
	v.add_child(upp)
	v.add_child(UiKit.rubrik("SAMBAND", 13, UiKit.DAMPAD))
	v.add_child(UiKit.etikett(str(b.get("samband", "")), 22, UiKit.LJUS, true))
	var rad := UiKit.hbox(8)
	rad.add_child(UiKit.rubrik("BEREDSKAPSNIVÅ", 13, UiKit.DAMPAD))
	var niva := UiKit.rubrik(str(scenario.get("beredskap", "")), 13, UiKit.BARNSTEN)
	rad.add_child(niva)
	v.add_child(rad)
	return v


func _sida_objekt(b: Dictionary) -> Control:
	var h := UiKit.hbox(14)
	var karta := TextureRect.new()
	var bild := "res://assets/gfx/objektskarta_%s.png" % Spel.objekttyp
	karta.texture = load(bild if ResourceLoader.exists(bild) else "res://assets/gfx/objektskarta.png")
	karta.custom_minimum_size = Vector2(400, 225)
	karta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	karta.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	karta.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	h.add_child(karta)
	var info := UiKit.vbox(8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.etikett(str(b.get("objektinfo", "")), 20, UiKit.LJUS, true))
	h.add_child(info)
	return h


func _sida_omvarld(scenario: Dictionary) -> Control:
	var v := UiKit.vbox(8)
	for n in scenario.get("omvarldslage", []):
		var p := UiKit.panel(UiKit.KANT, UiKit.RUTA, 12, 6)
		var pv := UiKit.vbox(0)
		p.add_child(pv)
		pv.add_child(UiKit.etikett("%s · %s" % [n.get("tid", ""), n.get("kalla", "")], 18, UiKit.GRON))
		pv.add_child(UiKit.etikett(str(n.get("text", "")), 21, UiKit.TEXT, true))
		v.add_child(p)
	return v

