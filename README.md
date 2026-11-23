# Skyddsvakt – utbildningsspel (prototyp)

Ett isometriskt pixelspel för att träna militära skyddsvakter på att fatta beslut med rätt lagstöd.
Detta är en första spelbar prototyp med ett scenario: **Fotografen vid staketet**.

> **Observera:** Lagstödet i `data/lagrum.json` är ett utkast och är **inte juridiskt granskat**.
> Lagrum markerade `[§ – jurist]` ska fastställas av jurist. Spelet visar detta i debriefingen
> tills `"granskad": true` sätts i filen.

## Spela i webbläsaren

**https://sulaco-hue.github.io/skyddsvakt/**

Varje push till `main` bygger och publicerar spelet automatiskt (se nedan). Ladda om sidan efter
några minuter för att få senaste versionen.

## Automatiskt bygge (GitHub Actions)

Arbetsflödet `.github/workflows/bygg-och-publicera.yml` körs vid varje push till `main`:

1. Hämtar senaste stabila Godot och exportmallar (cachas).
2. **Kontroll** (`tester/kontroll.tscn`): laddar alla skript, kontrollerar JSON-filerna och dialogens
   kopplingar mot `lagrum.json`, och spelar igenom scenario 1 automatiskt utan grafik.
   Bygget stoppas om något skriptfel uppstår.
3. Exporterar för **webb** (publiceras på GitHub Pages) och **Windows** (laddas ner under
   *Actions → senaste körningen → Artifacts → skyddsvakt-windows*).
4. Skriver resultatet till grenen `ci-status` (filen `status.md`).

I webbläsaren laddas debriefingloggen ner som en JSON-fil när man trycker *Spara logg*.

## Kom igång (Windows)

1. Ladda ner **Godot 4.3 eller senare** (standardversionen, inte .NET) från godotengine.org.
2. Starta Godot → **Importera** → välj `project.godot` i den här mappen.
3. Första gången importerar Godot grafik och typsnitt (några sekunder).
4. Tryck **F5** för att spela.

Om något går fel: titta i panelen **Utdata/Output** längst ner i editorn och skicka felmeddelandet.

## Så spelar du

| Läge | Styrning |
|---|---|
| Briefing | Läs omvärldsläge och uppdrag, **Starta pass** (eller Enter) |
| Patrull | **Klicka** på marken för att gå. Bommen vid grinden fälls upp automatiskt när du närmar dig. **Klicka på en person** för att ta kontakt |
| | **Q** observera · **R** samband · **N** anteckna · **T** tyst nu · **I** instruktion · **M** musik av/på · **F3** debugrad · **Esc** avsluta pass |
| Kontakt | Välj svar med musen eller **1–4** |
| Debriefing | Klicka på ett beslut i tidslinjen för lagrum och bedömning. **Spara logg** skriver en JSON-fil för instruktören |

## Projektets delar

```
data/
  lagrum.json                  Handlingar, krav (rekvisit), lagrum och bedömningstexter
  scenarier/fotografen.json    Omvärldsläge, briefing, karta, händelser, fakta och dialog
scripts/
  core/regelmotor.gd           Bedömer handlingar mot lagrum.json
  core/spel.gd                 Autoload "Spel": speltid, fakta, beslutslogg
  varld/varld.gd               Bygger den isometriska världen från kartan, klicka-för-att-gå
  varld/aktor.gd               Figurer som går längs rutnätet
  ui/                          Briefing, HUD, kontaktläge, debriefing och gemensam stil
assets/gfx/                    Pixelgrafik (genererad med verktyg/generera_grafik.py)
assets/fonts/                  VT323 och Jersey 15 (SIL Open Font License)
verktyg/                       Python-skript för grafik och förhandsvisning av kartan
```

## Så fungerar regelmotorn

Varje svarsalternativ eller knapp i spelet pekar på en **handling** i `lagrum.json`, till exempel `gripa_med_vald`:

```json
"gripa_med_vald": {
  "lagrum": "Skyddslagen 13 § (gripande) · Polislagen – våld [§ – jurist]",
  "krav": ["skal_att_anhalla"],
  "vid_brist": "bad",
  "foljdkrav": [{"fakta": "anmalan_polis", "lagrum": "Skyddslagen 17 §", "text": "..."}]
}
```

- **krav** är fakta som måste vara sanna i scenariot (`"fakta"` i scenariofilen). Är alla uppfyllda blir utfallet *lagstöd*, annars det som står i `vid_brist` (`warn` = diskutabelt, `bad` = saknar lagstöd).
- **foljdkrav** kontrolleras när passet är slut. Exempel: ett gripande eller beslag som inte anmälts till polis (17 § skyddslagen).
- Dialogval kan ändra fakta (`"satt_fakta"`), så samma handling kan få olika bedömning beroende på vad som hänt tidigare.

En jurist kan alltså ändra lagrum, krav och texter i JSON-filen utan att röra koden.

## Stridspar, zoner och samband

- **Stridspar:** man är alltid två. Kamraten (`V` på kartan) följer efter spelaren när passet börjat, går
  genom grinden och ställer sig och skyddar vid kontakt.
- **Zoner:** positionsrutan visar **På skyddsobjektet**, **Invid skyddsobjektet (bedömning)** eller **Utanför**.
  ”Invid” är en lösare definition; hur långt ut den sträcker sig styrs av `karta.invid_avstand` (rutor).
- **Samband:** vi är **Grindposten**, vaktchefen är **AQ** (Adam Qvintus) och befinner sig på annan plats.
  Fraseologi: ”Grindposten, Grindposten.” – ”Grindposten kom.” – ”Från AQ, …, kom.” – ”Uppfattat, kom.” –
  ”…, slut kom.” – ”Klart slut.” Allt ligger i scenariofilen:
  - `anropssignaler`, `samband` (radiologgen vid passets start)
  - `sambandsval`: valen under **R / Samband**. Varje val pekar på en handling i `lagrum.json`; `efter` = sekunder.
    `{lage}` ersätts med texten i `lagestext`.
  - `handelser[].kamrat`: vad kamraten säger när händelsen upptäcks.
  - Sambandsprov: ”Från AQ, förbindelsen provas, kom.” – ”Hörbarhet femma, kom.” (skala 5–1, 5 bäst).

## Händelser, upptäckt och debugrad

Varje händelse i `handelser` har ett `id` (t.ex. `"1"`) och ett `namn`. Det finns ingen avvikelseruta:
i stället har stridsparskamraten en intern **upptäcktstimer** (`handelser[].upptackt`):

- En grundtid slumpas mellan `min_s` och `max_s` sekunder (nu 2–10 s) – ibland snabbt, ibland långsamt.
- Timern går fortare ju närmare ni är (`referensavstand` / avstånd, begränsat till 0,3–3 gånger).
- När den når 100 % reagerar kamraten (repliken i `kamrat`) och personen markeras.
- Upptäcker du personen själv och tar kontakt innan dess, avbryts timern.

**Debugraden** (överst, **F3** visar/döljer) har en knapp per händelse som startar den direkt,
och visar upptäcktstimerns status. **INFO** öppnar en panel med klocka, händelser, positioner och zoner,
figurernas tillstånd, upptäcktstimern, alla fakta och loggstorlek.

## Kamratens småprat

`data/kamratsnack.json` innehåller kamratens prat (sport, elpriser, datorspel, film, mat, väder …).
Varje rad kan ha egna `svar` som Grindposten ibland ger; annars används `allmanna_svar`, eller så
suckar Grindposten (`suckar`). Hur ofta det pratas och chansen för suck/svar styrs under `installningar`.
**T** (tyst nu) säger en av `tyst_repliker` och tystar kamraten i `tystnad_s` sekunder.
Pratet pausas under kontakt och en stund efter att kamraten upptäckt en händelse (`paus_snack_s`).
Kamraten kan alltså vara mitt i en utläggning om elpriser när fotografen dyker upp …

## Viloanimationer

När en soldat står still spelas då och då en viloanimation upp: tittar åt sidorna, fipplar med
radion och hjälmen, dricker kaffe (med ånga) eller röker (med rökpuffar). Sekvenser och
sannolikheter finns i `VILA` och `VILA_VIKT` i `scripts/varld/aktor.gd`; bilderna
(`vakt_vila_*.png`) genereras av `verktyg/generera_grafik.py` (tabellen `VILA`).

## Repliker och ljud i världen

Repliker från figurerna visas som pratbubblor ovanför figuren (`hud.visa_bubbla(figur, text)`) och ljud
som text som stiger uppåt (`hud.visa_ljud(figur, "klick klick")`). Fotografens kameraljud står i
`npc.fotografen.ljud.fotograferar`. Samma funktion kan användas för t.ex. "klipp klipp" och "brak" i
kommande scenarier.


## Musik

`assets/ljud/grindpostens_marsch.ogg` är en nyskriven marsch i C64/SID-stil (pulsvågsmelodi, snabba
arpeggioackord, triangelbas och brustrummor), genererad med `verktyg/generera_marsch.py`.
Den spelas som slinga av autoloaden `Musik` (`scripts/core/musik.gd`), volym i `VOLYM_DB`.
Vill ni använda en annan låt: lägg en .ogg-fil i `assets/ljud/` och ändra `SOKVAG`.
Skyddade verk (t.ex. Hemvärnets marsch) kräver tillstånd från rättighetshavaren.

## Ändra kartan

Kartan i scenariofilen består av två lager med ett tecken per ruta (18×18):

- `mark`: `.` gräs, `i` gräs innanför staket, `g` grus, `a` asfalt, `d` asfalt med mittlinje
- `objekt`: `F` staket, `S` staket med skylt, `G` grind/bom (öppnas för spelaren, stängd för andra figurer; bilden förutsätter grind längs kartans y-led), `B` byggnad (4×3), `K` vaktkur, `T`/`t` gran, `L` lyktstolpe, `C` bil, `P` spelarens start, `V` stridsparskamrat

Staket kopplas ihop automatiskt med grannrutorna. `verktyg/forhandsvisa_karta.py` ritar en förhandsbild utan Godot.

## Bygga en .exe för Windows

1. I Godot: **Editor → Hantera exportmallar → Ladda ner och installera**.
2. **Projekt → Exportera → Lägg till… → Windows Desktop**.
3. **Exportera projekt** → välj en mapp. Du får en `.exe` (och en `.pck` om inbäddning är avstängd).

## Nästa steg (förslag)

- Juridisk granskning av `lagrum.json` och scenariot.
- Fler scenarier: drönare, inkräktare innanför staket, fordon vid grinden, demonstration.
- Instruktörsläge där händelser kan styras i realtid.
- Ritad grafik i stället för genererad, ljud och animationer.
- Mobilanpassning (Android/iOS) när PC-versionen är stabil.
