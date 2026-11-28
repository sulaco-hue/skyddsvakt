commit: 00de083e3f9696663d754975ac0de80a209d9d28
resultat: success
godot: 4.7.2-stable
tid: 2026-11-28 13:13 UTC

--- test.log (sista 200 rader) ---
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

=== Halt, militär skyddsvakt!: automatisk kontroll ===
ok   res://scripts/main.gd
ok   res://scripts/core/datafil.gd
ok   res://scripts/core/demonstration.gd
ok   res://scripts/core/musik.gd
ok   res://scripts/core/radiotrafik.gd
ok   res://scripts/core/regelmotor.gd
ok   res://scripts/core/slagsmal.gd
ok   res://scripts/core/spel.gd
ok   res://scripts/ui/briefing.gd
ok   res://scripts/ui/debriefing.gd
ok   res://scripts/ui/hud.gd
ok   res://scripts/ui/kontakt.gd
ok   res://scripts/ui/redigerare.gd
ok   res://scripts/ui/scenarioval.gd
ok   res://scripts/ui/titelskarm.gd
ok   res://scripts/ui/ui_kit.gd
ok   res://scripts/ui/vrid_overlay.gd
ok   res://scripts/varld/aktor.gd
ok   res://scripts/varld/dronare.gd
ok   res://scripts/varld/kamratsnack.gd
ok   res://scripts/varld/varld.gd
ok   data och dialogkopplingar: fotografen.json
ok   data och dialogkopplingar: dronaren.json
ok   data och dialogkopplingar: hantverkaren.json
ok   data och dialogkopplingar: yxmannen.json
ok   data och dialogkopplingar: zombies.json
ok   data och dialogkopplingar: slagsmalet.json
ok   data och dialogkopplingar: demonstrationen.json
--- Textredigeraren ---
ok   alla 13 datafiler sparas tillbaka tecken för tecken lika
ok   redigering på enheten används
ok   redigeraren öppnade alla filer
--- Scenario: Fotografen ---
ok   fotografen framme vid (27, 16)
ok   debug visar spåret: Avvisa (LAGSTÖD → (svarar))
ok   skyddsvisitation: (SAKNAR LAGSTÖD → (svarar)) utan frihetsberövande, (LAGSTÖD → (svarar)) efter gripande
ok   lägestext efter kontakt
ok   begara_identitet bedömd 'ok'
ok   tillfalligt_omhanderta bedömd 'warn'
ok   foljdkrav_anmalan_polis bedömd 'bad'
ok   logg sparad
--- Scenario: Drönaren (med pilot) ---
ok   drönaren cirklar över objektet (med_pilot)
ok   be_landa bedömd 'ok'
ok   dokumentera bedömd 'ok'
ok   slutkrav_rapportera_vaktchef bedömd 'bad'
--- Scenario: Drönaren (utan pilot) ---
ok   drönaren cirklar över objektet (utan_pilot)
ok   drönaren nedskjuten och kraschad
ok   lägesrapport och polisbegäran säger att drönaren är nedskjuten
ok   vald_mot_farkost bedömd 'warn'
--- Scenario: Drönaren (dold pilot, kontakt) ---
ok   drönaren cirklar över objektet (dold_pilot)
ok   lägesrapport: drönaren har landat, piloten har lämnat sannolikt oriktiga uppgifter, drönare och minneskort tagna i beslag
ok   be_landa bedömd 'ok'
ok   begara_identitet bedömd 'ok'
ok   be_om_legitimation bedömd 'ok'
ok   beslag bedömd 'ok'
ok   avvisa bedömd 'ok'
--- Scenario: Drönaren (dold pilot, ingen kontakt) ---
ok   drönaren cirklar över objektet (dold_pilot)
ok   piloten tog ner drönaren och gick; lägesrapport: pilot i skogskanten norr om staketet har tagit ner drönaren och gått norrut
--- Missad händelse ---
ok   fotografen gav sig av utan kontakt
ok   Norra grinden rapporterar bilen som åker
ok   missad_1 bedömd 'bad'
--- Scenario: Hantverkaren (arlig) ---
ok   hantverkaren vid bommen (32, 24)
ok   begara_identitet bedömd 'ok'
ok   neka_tilltrade bedömd 'ok'
ok   dokumentera bedömd 'ok'
--- Scenario: Hantverkaren (arlig) ---
ok   hantverkaren vid bommen (32, 24)
ok   avvisa bedömd 'bad'
--- Scenario: Hantverkaren (arlig) ---
ok   hantverkaren vid bommen (32, 24)
ok   slappa_in bedömd 'bad'
--- Scenario: Hantverkaren (oriktig) ---
ok   hantverkaren vid bommen (32, 24)
ok   be_om_legitimation bedömd 'ok'
ok   avvisa bedömd 'ok'
--- Scenario: Hantverkaren (oriktig) ---
ok   hantverkaren vid bommen (32, 24)
ok   avvisa bedömd 'ok'
--- Scenario: Hantverkaren (rekognosering) ---
ok   hantverkaren vid bommen (32, 24)
ok   undersoka_fordon bedömd 'ok'
ok   beslag bedömd 'ok'
ok   gripa bedömd 'ok'
ok   skyddsvisitera bedömd 'ok'
--- Scenario: Hantverkaren (rekognosering) ---
ok   hantverkaren vid bommen (32, 24)
ok   gripa bedömd 'bad'
--- Scenario: Yxmannen (ger_upp) ---
ok   kamraten upptäcker yxmannen, knappar: halt, varningsskott, verkanseld (avstånd 18)
ok   yxmannen gav upp efter halt-order
ok   halt_order bedömd 'ok'
ok   envarsgripande bedömd 'ok'
ok   anmala_polis bedömd 'ok'
ok   slutkrav_rapportera_vaktchef bedömd 'bad'
--- Scenario: Yxmannen (skarp) ---
ok   kamraten upptäcker yxmannen, knappar: halt, varningsskott, verkanseld (avstånd 17)
ok   verkanseld: mannen ligger, knappen Första hjälpen visas
ok   halt_order bedömd 'ok'
ok   varningsskott bedömd 'ok'
ok   verkanseld bedömd 'ok'
ok   larma_sjukvard bedömd 'ok'
ok   foljdkrav_skjutning_rapporterad bedömd 'bad'
--- Scenario: Slagsmålet (stannar) ---
ok   slagsmålet upptäckt, knappar: halt, varningsskott, verkanseld
ok   bråkaren efter halt + varningsskott: flyr (offret: staende)
ok   lägesrapport: en man lindrigt skadad efter slagsmål vid stugan längs vägen öster om grinden, varningsskott avlossat
ok   halt_order bedömd 'ok'
ok   varningsskott bedömd 'bad'
--- Scenario: Slagsmålet (lamnar) ---
ok   slagsmålet upptäckt, knappar: halt, varningsskott, verkanseld
ok   slagskämparna står intill varandra nere vid vägen
ok   lamnade_posten bedömd 'warn'
ok   forsta_hjalpen bedömd 'ok'
--- Scenario: Slagsmålet (smygare) ---
ok   slagsmålet upptäckt, knappar: halt, varningsskott, verkanseld
ok   lägesrapport: två män slåss vid stugan längs vägen öster om grinden, verkanseld avgiven mot mörkklädd man vid norra staketet, han är skadad · ambulans: , en man med skottskada vid norra staketet
ok   verkanseld bedömd 'bad'
--- Scenario: Slagsmålet (smygare_flykt) ---
ok   slagsmålet upptäckt, knappar: halt, varningsskott, verkanseld
ok   smygaren tappade skylten; lägesrapport: slagsmål vid stugan längs vägen öster om grinden, varningsskott avlossat, mörkklädd man skruvade ner skyddsobjektsskylten vid norra staketet men tappade den när han flydde norrut
ok   varningsskott bedömd 'bad'
--- Scenario: Demokratiska rättigheter? (dialog) ---
ok   demonstrationen upptäckt, knappar: halt, handgemang, varningsskott, verkanseld
ok   avslutat samtal: personen lyssnar inte längre
ok   en demonstrant reste sig och tryckte på igen
ok   QRF:en på plats bakom grinden
ok   polisen kom, demonstranterna gick; lägesrapport: några har tagit sig in och sitter innanför staketet och polis på plats, demonstranterna lämnar
ok   neka_tilltrade bedömd 'ok'
ok   anmala_polis bedömd 'ok'
ok   rapportera_vaktchef bedömd 'ok'
ok   begar_forstarkning bedömd 'ok'
--- Scenario: Demokratiska rättigheter? (vald) ---
ok   demonstrationen upptäckt, knappar: halt, handgemang, varningsskott, verkanseld
ok   demonstranter trycker på mot stridsparet i grinden
ok   en demonstrant bars ut
ok   halt_rop bedömd 'ok'
ok   varningsskott bedömd 'bad'
ok   avlagsna bedömd 'ok'
ok   ingen_forstarkning bedömd 'bad'
ok   handgemang bedömd 'ok'
--- Lämna posten (fotografen) ---
ok   lamnade_posten bedömd 'warn'
--- Scenario: Yxmannen (skarp) ---
ok   kamraten upptäcker yxmannen, knappar: halt, varningsskott, verkanseld (avstånd 18)
ok   verkanseld bedömd 'bad'
--- Scenario: Yxmannen (skarp) ---
ok   kamraten upptäcker yxmannen, knappar: halt, varningsskott, verkanseld (avstånd 18)
ok   angrepp_nadde_fram bedömd 'bad'
ok   larma_sjukvard bedömd 'ok'
--- Scenario: Zombieapokalypsen (skjuter) ---
ok   zombierna upptäckta, knappar: halt, varningsskott, verkanseld
ok   alla tolv nere (1 omladdningar)
ok   första hjälpen erbjuds (och avböjs)
ok   verkanseld bedömd 'ok'
ok   halt_order bedömd 'ok'
ok   varningsskott bedömd 'ok'
ok   forsta_hjalpen bedömd 'ok'
--- Scenario: Zombieapokalypsen (gör inget) ---
ok   zombierna upptäckta, knappar: halt, varningsskott, verkanseld
ok   zombie_0 knuffades omkull och reste sig igen
ok   angrepp_nadde_fram bedömd 'bad'
--- Scenario: Zombieapokalypsen (dödsfall) ---
ok   kamraten uppäten efter tredje angreppet
ok   GAME OVER: direkt till debriefingen
ok   kamrat_dod bedömd 'bad'
ok   spelaren_dod bedömd 'bad'
--- Skyddsobjekt ---
ok   byggnad (Förråd Granåsen) blockerar 12 rutor
ok   lastbil (Helikoptern Granåsen) blockerar 4 rutor
ok   vapenforrad (Vapenförråd Granåsen) blockerar 12 rutor
ok   radiomast (Radiostation Granåsen) blockerar 2 rutor
--- Kompakt läge (pekskärm) ---
--- Scenario: Fotografen ---
ok   fotografen framme vid (27, 16)
ok   debug visar spåret: Avvisa (LAGSTÖD → (svarar))
ok   skyddsvisitation: (SAKNAR LAGSTÖD → (svarar)) utan frihetsberövande, (LAGSTÖD → (svarar)) efter gripande
ok   lägestext efter kontakt
ok   begara_identitet bedömd 'ok'
ok   tillfalligt_omhanderta bedömd 'warn'
ok   foljdkrav_anmalan_polis bedömd 'bad'
ok   logg sparad
=== RESULTAT: OK ===
WARNING: 4 ObjectDB instances were leaked at exit (run with `--verbose` for details).
   at: cleanup (core/object/object.cpp:2536)
ERROR: 2 resources still in use at exit (run with --verbose for details).
   at: clear (core/io/resource.cpp:822)

--- export.log (sista 80 rader) ---
[  76% ] [90m[1msavepack[22m | Storing File: res://.godot/imported/yxman_utan_1.png-5daf2ac0b30e371cb7e052b0f0ba79a4.ctex[39m[0m
[  76% ] [90m[1msavepack[22m | Storing File: res://assets/gfx/yxman_utan_1.png.import[39m[0m
[  77% ] [90m[1msavepack[22m | Storing File: res://.godot/imported/zombie_0.png-e9fd716fd07bdcb433625c9d44b61519.ctex[39m[0m
[  77% ] [90m[1msavepack[22m | Storing File: res://assets/gfx/zombie_0.png.import[39m[0m
[  77% ] [90m[1msavepack[22m | Storing File: res://.godot/imported/zombie_1.png-162f8b0effc9cf3419eed92e02ad91ae.ctex[39m[0m
[  77% ] [90m[1msavepack[22m | Storing File: res://assets/gfx/zombie_1.png.import[39m[0m
[  78% ] [90m[1msavepack[22m | Storing File: res://.godot/imported/zombie_ligger_0.png-0d9c3be341a203748c9095d259891985.ctex[39m[0m
[  78% ] [90m[1msavepack[22m | Storing File: res://assets/gfx/zombie_ligger_0.png.import[39m[0m
[  78% ] [90m[1msavepack[22m | Storing File: res://.godot/imported/zombie_ligger_1.png-9bb2242d20e2db2b88551a3078686273.ctex[39m[0m
[  78% ] [90m[1msavepack[22m | Storing File: res://assets/gfx/zombie_ligger_1.png.import[39m[0m
[  79% ] [90m[1msavepack[22m | Storing File: res://.godot/imported/grindpostens_marsch.ogg-96a84d14a9f0601eb5685d18043413e6.oggvorbisstr[39m[0m
[  79% ] [90m[1msavepack[22m | Storing File: res://assets/ljud/grindpostens_marsch.ogg.import[39m[0m
[  79% ] [90m[1msavepack[22m | Storing File: res://data/kartor/granasen.json[39m[0m
[  80% ] [90m[1msavepack[22m | Storing File: res://data/scenarier/demonstrationen.json[39m[0m
[  80% ] [90m[1msavepack[22m | Storing File: res://data/scenarier/dronaren.json[39m[0m
[  81% ] [90m[1msavepack[22m | Storing File: res://data/scenarier/fotografen.json[39m[0m
[  81% ] [90m[1msavepack[22m | Storing File: res://data/scenarier/hantverkaren.json[39m[0m
[  82% ] [90m[1msavepack[22m | Storing File: res://data/scenarier/index.json[39m[0m
[  82% ] [90m[1msavepack[22m | Storing File: res://data/scenarier/slagsmalet.json[39m[0m
[  83% ] [90m[1msavepack[22m | Storing File: res://data/scenarier/yxmannen.json[39m[0m
[  83% ] [90m[1msavepack[22m | Storing File: res://data/scenarier/zombies.json[39m[0m
[  84% ] [90m[1msavepack[22m | Storing File: res://data/kamratsnack.json[39m[0m
[  84% ] [90m[1msavepack[22m | Storing File: res://data/lagrum.json[39m[0m
[  85% ] [90m[1msavepack[22m | Storing File: res://data/lagstodskort.json[39m[0m
[  85% ] [90m[1msavepack[22m | Storing File: res://data/radiobrus.json[39m[0m
[  86% ] [90m[1msavepack[22m | Storing File: res://data/samband.json[39m[0m
[  86% ] [90m[1msavepack[22m | Storing File: res://data/version.json[39m[0m
[  87% ] [90m[1msavepack[22m | Storing File: res://.godot/exported/133200997/export-3ad5c15c4f3250da0cc7c1af1770d85f-main.scn[39m[0m
[  87% ] [90m[1msavepack[22m | Storing File: res://scripts/core/datafil.gdc[39m[0m
[  88% ] [90m[1msavepack[22m | Storing File: res://scripts/core/demonstration.gdc[39m[0m
[  88% ] [90m[1msavepack[22m | Storing File: res://scripts/core/musik.gdc[39m[0m
[  89% ] [90m[1msavepack[22m | Storing File: res://scripts/core/radiotrafik.gdc[39m[0m
[  89% ] [90m[1msavepack[22m | Storing File: res://scripts/core/regelmotor.gdc[39m[0m
[  90% ] [90m[1msavepack[22m | Storing File: res://scripts/core/slagsmal.gdc[39m[0m
[  90% ] [90m[1msavepack[22m | Storing File: res://scripts/core/spel.gdc[39m[0m
[  91% ] [90m[1msavepack[22m | Storing File: res://scripts/ui/briefing.gdc[39m[0m
[  91% ] [90m[1msavepack[22m | Storing File: res://scripts/ui/debriefing.gdc[39m[0m
[  92% ] [90m[1msavepack[22m | Storing File: res://scripts/ui/hud.gdc[39m[0m
[  92% ] [90m[1msavepack[22m | Storing File: res://scripts/ui/kontakt.gdc[39m[0m
[  93% ] [90m[1msavepack[22m | Storing File: res://scripts/ui/redigerare.gdc[39m[0m
[  93% ] [90m[1msavepack[22m | Storing File: res://scripts/ui/scenarioval.gdc[39m[0m
[  94% ] [90m[1msavepack[22m | Storing File: res://scripts/ui/titelskarm.gdc[39m[0m
[  94% ] [90m[1msavepack[22m | Storing File: res://scripts/ui/ui_kit.gdc[39m[0m
[  95% ] [90m[1msavepack[22m | Storing File: res://scripts/ui/vrid_overlay.gdc[39m[0m
[  95% ] [90m[1msavepack[22m | Storing File: res://scripts/varld/aktor.gdc[39m[0m
[  96% ] [90m[1msavepack[22m | Storing File: res://scripts/varld/dronare.gdc[39m[0m
[  96% ] [90m[1msavepack[22m | Storing File: res://scripts/varld/kamratsnack.gdc[39m[0m
[  97% ] [90m[1msavepack[22m | Storing File: res://scripts/varld/varld.gdc[39m[0m
[  97% ] [90m[1msavepack[22m | Storing File: res://scripts/main.gdc[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://.godot/imported/icon.svg-218a8f2b3041327d8a5756f3a245f83b.ctex[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://icon.svg.import[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scenes/main.tscn.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scripts/core/datafil.gd.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scripts/core/demonstration.gd.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scripts/core/musik.gd.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scripts/core/radiotrafik.gd.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scripts/core/regelmotor.gd.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scripts/core/slagsmal.gd.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scripts/core/spel.gd.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scripts/ui/briefing.gd.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scripts/ui/debriefing.gd.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scripts/ui/hud.gd.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scripts/ui/kontakt.gd.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scripts/ui/redigerare.gd.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scripts/ui/scenarioval.gd.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scripts/ui/titelskarm.gd.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scripts/ui/ui_kit.gd.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scripts/ui/vrid_overlay.gd.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scripts/varld/aktor.gd.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scripts/varld/dronare.gd.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scripts/varld/kamratsnack.gd.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scripts/varld/varld.gd.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://scripts/main.gd.remap[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://.godot/global_script_class_cache.cfg[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://icon.svg[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://assets/gfx/startbild.png[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://.godot/uid_cache.bin[39m[0m
[  98% ] [90m[1msavepack[22m | Storing File: res://project.binary[39m[0m
[92m[ DONE ][39m [1msavepack[22m
[0m

--- import.log (sista 40 rader) ---
[  81% ] [90m[1mreimport[22m | ljus.png[39m[0m
[  82% ] [90m[1mreimport[22m | logga.png[39m[0m
[  83% ] [90m[1mreimport[22m | lykta.png[39m[0m
[  83% ] [90m[1mreimport[22m | markor_hover.png[39m[0m
[  84% ] [90m[1mreimport[22m | markor_larm.png[39m[0m
[  84% ] [90m[1mreimport[22m | markor_mal.png[39m[0m
[  85% ] [90m[1mreimport[22m | mynningsflamma.png[39m[0m
[  86% ] [90m[1mreimport[22m | objektskarta.png[39m[0m
[  86% ] [90m[1mreimport[22m | objektskarta_byggnad.png[39m[0m
[  87% ] [90m[1mreimport[22m | objektskarta_lastbil.png[39m[0m
[  88% ] [90m[1mreimport[22m | objektskarta_radiomast.png[39m[0m
[  88% ] [90m[1mreimport[22m | objektskarta_vapenforrad.png[39m[0m
[  89% ] [90m[1mreimport[22m | demonstrant_d_0.png[39m[0m
[  89% ] [90m[1mreimport[22m | demonstrant_d_1.png[39m[0m
[  90% ] [90m[1mreimport[22m | demonstrant_d_sitter_0.png[39m[0m
[  91% ] [90m[1mreimport[22m | demonstrant_d_sitter_1.png[39m[0m
[  91% ] [90m[1mreimport[22m | demonstrant_d_skadad_0.png[39m[0m
[  92% ] [90m[1mreimport[22m | demonstrant_d_skadad_1.png[39m[0m
[  93% ] [90m[1mreimport[22m | dronare_0.png[39m[0m
[  93% ] [90m[1mreimport[22m | dronare_1.png[39m[0m
[  94% ] [90m[1mreimport[22m | dronare_skugga.png[39m[0m
[  94% ] [90m[1mreimport[22m | dronare_vrak.png[39m[0m
[  95% ] [90m[1mreimport[22m | dronpilot_0.png[39m[0m
[  96% ] [90m[1mreimport[22m | dronpilot_1.png[39m[0m
[  96% ] [90m[1mreimport[22m | dronpilot_sitter_0.png[39m[0m
[  97% ] [90m[1mreimport[22m | dronpilot_sitter_1.png[39m[0m
[  98% ] [90m[1mreimport[22m | gran.png[39m[0m
[  98% ] [90m[1mreimport[22m | gran_liten.png[39m[0m
[  99% ] [90m[1mreimport[22m | Finalizing Asset Import...[39m[0m
[92m[ DONE ][39m [1mreimport[22m
[0m
[   0% ] [90m[1mreimport[22m | Started (Re)Importing Assets (158 steps)[39m[0m
[   0% ] [90m[1mreimport[22m | Executing post-reimport operations...[39m[0m
[92m[ DONE ][39m [1mreimport[22m
[0m
[   0% ] [90m[1mloading_editor_layout[22m | Started Loading editor (5 steps)[39m[0m
[   0% ] [90m[1mloading_editor_layout[22m | Loading editor layout...[39m[0m
[  16% ] [90m[1mloading_editor_layout[22m | Loading docks...[39m[0m
[92m[ DONE ][39m [1mloading_editor_layout[22m
[0m
