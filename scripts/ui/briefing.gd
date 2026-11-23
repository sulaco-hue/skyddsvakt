class_name Briefing
extends Control
## Omvärldsläge och briefing före passet.

signal starta


func bygg(scenario: Dictionary) -> void:
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

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	marg.add_child(scroll)
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
	bv.add_child(UiKit.etikett("Påverkar vad som är troligt – inte vad lagen tillåter.", 20, UiKit.LJUS, true))
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
	info.add_child(UiKit.rubrik("STYRNING", 13, UiKit.DAMPAD))
	var styr := "Klicka för att gå – grinden öppnas när du närmar dig. Klicka på en person för kontakt, på kamraten för ”tyst nu”. Q observera · R samband · N anteckna · T tyst nu · I instruktion · M musik av/på · F3 debugrad."
	if UiKit.kompakt:
		styr = "Tryck där du vill gå – grinden öppnas när du närmar dig. Tryck på en person för kontakt, på kamraten för ”tyst nu”. DBG visar debugraden."
	info.add_child(UiKit.etikett(styr, 20, UiKit.LJUS, true))
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
	var lag := UiKit.panel(UiKit.KANT, UiKit.RUTA)
	lag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lv := UiKit.vbox(6)
	lag.add_child(lv)
	lv.add_child(UiKit.rubrik("LAGSTÖD I FOKUS", 13))
	var flode := HFlowContainer.new()
	flode.add_theme_constant_override("h_separation", 6)
	flode.add_theme_constant_override("v_separation", 6)
	flode.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for t in b.get("lagstod_fokus", []):
		var chip := UiKit.panel(UiKit.KANT2, Color(0, 0, 0, 0), 8, 2)
		chip.add_child(UiKit.etikett(str(t), 19))
		flode.add_child(chip)
	lv.add_child(flode)
	grid.add_child(lag)

	hoger.add_child(UiKit.fyllnad())
	var knappar := UiKit.hbox(12)
	knappar.add_child(UiKit.etikett("Lagstödet i detta utkast är inte juridiskt granskat.", 20, UiKit.DAMPAD))
	knappar.add_child(UiKit.fyllnad())
	var start := UiKit.knapp("STARTA PASS", true, UiKit.GRON)
	start.custom_minimum_size = Vector2(200, 52)
	start.pressed.connect(func() -> void: starta.emit())
	knappar.add_child(start)
	hoger.add_child(knappar)


func _unhandled_input(event: InputEvent) -> void:
	var tangent := event as InputEventKey
	if visible and tangent != null and tangent.pressed and not tangent.echo:
		if tangent.keycode == KEY_ENTER or tangent.keycode == KEY_SPACE:
			starta.emit()
			get_viewport().set_input_as_handled()
