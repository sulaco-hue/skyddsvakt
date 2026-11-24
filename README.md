# Halt, militär skyddsvakt!

*Utbildningsspel för militära skyddsvakter (prototyp).*

Ett isometriskt pixelspel för att träna militära skyddsvakter på att fatta beslut med rätt lagstöd.
Prototypen har fem scenarier (se nedan).

> **Observera:** Lagstödet i `data/lagrum.json` är ett utkast och är **inte juridiskt granskat**.
> Lagrum markerade `[§ – jurist]` ska fastställas av jurist. Spelet visar detta i debriefingen
> tills `"granskad": true` sätts i filen.

## Scenarier

Spelet startar med ett scenarioval (listan i `data/scenarier/index.json`):

1. **Fotografen vid staketet** – avbildningsförbud, identitet (10 §), avlägsnande/omhändertagande (12 §), gripande (13 §).
2. **Drönaren vid sjön** – tillträdesförbud i luften, identitet när piloten står långt bort, våld mot
   obemannad farkost (11 §). Två varianter: *med pilot* (pappa med dottern Elsa vid sjön) och
   *utan pilot* (drönaren kommer från nordost och försvinner). Situationsknappen **Bekämpa drönaren [B]**
   finns för att träna bedömningen.
3. **Hantverkaren vid grinden** – passerkontroll i dagsljus: skyldigheterna i 10 § (identitet, fordon)
   och skillnaden mellan att *neka tillträde* och att *avvisa* enligt 12 §. Två varianter: *ärlig*
   (bara inte föranmäld) och *oriktig* (fel legitimation, vägrar undersökning av bilen).
4. **Yxmannen vid norra stigen** – nödvärn (BrB 24:1) och skjutvapen vid vakttjänst (förordning 1992:98,
   FFS 2010:7). Mitt i natten kommer en man ut ur skogen med en yxa och vrålar ”Jag ska döda dig din
   jävel!”. Så fort kamraten upptäcker honom visas situationsknapparna **Halt-order [H]**,
   **Varningsskott [V]** och **Verkanseld [F]**. Bedömningen beror på om varning getts, om varningsskott
   föregick verkanselden, hur nära han var (*omedelbart förestående*) och om angreppet fortfarande pågick.
   Efter verkanseld: **Larma sjukvård [S]** och **Första hjälpen [J]**. Två varianter: *skarp* (stannar
   inte) och *ger upp* (släpper yxan efter varning). Når han fram brottas han ner – men det bedöms
   som att ni agerade för sent. Efteråt: envarsgripande (BrB 24:7) och överlämning till polis.
5. **Zombieapokalypsen** – ett skämtscenario. Ett dussin zombies kommer i vågor från olika håll.
   Samma knappar som för yxmannen (**Halt-order**, **Varningsskott**, **Verkanseld**), men varningarna
   biter inte. Verkanselden träffar närmaste zombie, och bedömningen följer samma regler (avstånd,
   varning, varningsskott). Du och kamraten har svårt att tro det: *"Du, vad säger SoldF om zombies?"* –
   *"Vette fan. Eldstöt?"* – *"Metkrok?"*. Debriefingen frågar om en zombie är en ”person” och om det är
   nödvärn eller nöd. Radion ballar ur: Norra grinden, Västra posten och Rondpatrullen överkörs en
   efter en, och till sist faller CQ. Därefter svarar ingen på anrop (`samband_tyst` i scenariofilen),
   och du och kamraten pratar oroligt med varandra i stället.

**Skyddsobjektet slumpas** vid varje genomförande: byggnaden, "helikoptern" (lastbil med HELIKOPTER målat på sidan), ett vapenförråd
(lagerbyggnad i plåt) eller en radiomast med teknikbod. Typerna finns under `objekttyper` i kartfilen;
i scenariotexterna ersätts `{objekt}` med objektets namn och `{objekt_bestamd}` med t.ex. "masten".

Scenarierna delar kartan `data/kartor/granasen.json` och använder namngivna platser (`punkter`).
Varje scenario kan ha `varianter` (egna fakta och bedömningar), `bedomning` (scenariospecifik
bedömning av en handling) och `slutkrav` (t.ex. att händelsen måste rapporteras till CQ).

### Radiotrafik som följer läget

CQ ropar inte själv upp Grindposten, det är vi som larmar. Men det vi säger, och CQ:s svar, följer
vad som har hänt. `lagestext` ({lage} i lägesrapporten) och varje nyckel i `sambandstexter` (t.ex.
{svar} för CQ:s svar och {polis} i polisbegäran) väljs efter händelsens fas: `fakta:<nyckel>` när ett
faktum är sant (t.ex. `fakta:dronare_nedskjuten`), annars `lamnat`, `kontakt`, `efter` eller `fore`,
även per variant (`kontakt_oriktig`). Har vi skjutit ner drönaren rapporterar vi alltså inte att den
cirklar över objektet.

`radio` i scenariofilen innehåller trafik mellan andra enheter som följer händelserna (t.ex. Norra
grinden som ser bilen köra iväg), se `scripts/core/radiotrafik.gd`. Krokar: `upptackt`, `kontakt_start`,
`kontakt_slut`, `npc_lamnar`, `dronare_flyger_bort`, `dronare_landar`, `motpart_ger_upp`,
`motpart_skjuten`, `angrepp_nadde_fram` och `handling:<id>`. Inslagen kan ha `efter_s`, `variant`,
`om_ej_handling` / `om_handling` och `om_fakta`, och väntar tills kanalen är ledig.

## Spela i webbläsaren

**https://sulaco-hue.github.io/skyddsvakt/**

**På mobil/surfplatta (t.ex. iPhone/iPad i Safari):** spelet går i kompakt läge med större text och
knappar. Håll enheten liggande. Tryck där du vill gå, på en person för kontakt och på kamraten för
”tyst nu”. **DBG** i toppraden visar debugraden. Tips: *Dela → Lägg till på hemskärmen* ger helskärm
utan adressfält.

Varje push till `main` bygger och publicerar spelet automatiskt (se nedan). Ladda om sidan efter
några minuter för att få senaste versionen.

## Automatiskt bygge (GitHub Actions)

Arbetsflödet `.github/workflows/bygg-och-publicera.yml` körs vid varje push till `main`:

1. Hämtar senaste stabila Godot och exportmallar (cachas).
2. **Kontroll** (`tester/kontroll.tscn`): laddar alla skript, kontrollerar JSON-filerna och dialogens
   kopplingar mot `lagrum.json` och radiokrokarna, och spelar igenom alla scenarier och deras
   varianter automatiskt utan grafik (bl.a. yxmannen: ger upp, skarp, för tidig verkanseld, når fram).
   Bygget stoppas om något skriptfel uppstår.
3. Exporterar för **webb** (publiceras på GitHub Pages) och **Windows** (laddas ner under
   *Actions → senaste körningen → Artifacts → skyddsvakt-windows*).
4. Skriver resultatet till grenen `ci-status` (filen `status.md`).

**Spela efter manus med skärmdumpar:** `tester/spela.tscn` kör spelet med grafik efter ett manus
(JSON-lista med steg: starta scenario, forcera händelse, ta kontakt, välj åtgärd, ta bild …) och
sparar skärmdumpar och beslutslogg. Stegen beskrivs överst i `tester/spela.gd`. Exempel (Linux utan
skärm, med xvfb):

```
xvfb-run -a godot --path . --resolution 1334x750 res://tester/spela.tscn -- --manus=manus.json --ut=/tmp/bilder --kompakt
```

`--kompakt` ger mobilläget. Så kan spelet provas utan att någon sitter vid skärmen.

**Förhandsbild vid länkning:** `webb/delningsbild.png` (1200×630) kopieras till sidan av bygget och anges
som `og:image` i webbexportens `head_include`, så att en länk till spelet visar spelets logga i stället för
Godots. `assets/gfx/startbild.png` visas medan spelet laddar. Båda skapas av
`python3 verktyg/generera_delningsbild.py`.

**Versionsnummer:** bygget skriver `data/version.json` med antalet commits, och spelet visar det
(t.ex. *v44*) i nedre högra hörnet. Varje push ger en högre siffra. Lokalt visas *dev*.

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
| | **R** samband · **N** anteckna · **T** tyst nu · **I** instruktion · **M** musik av/på · **F3** debugrad · **Esc** avsluta pass |
| | Situationsknappar vid högerkanten när något händer: **B** bekämpa drönaren · **H** halt-order · **V** varningsskott · **F** verkanseld · **S** larma sjukvård · **J** första hjälpen |
| Kontakt | Välj svar med musen eller **1–4**. Under svaren finns alltid **åtgärdsraden**: Begär uppgifter (namn, födelsetid, hemvist – 10 §), Be om leg. (frivilligt), Visitera, Undersök fordon, Beslag, Avvisa, Avlägsna, Omhänderta, Gripa, Låt gå. Med debug på visas inom parentes bedömningen just nu och vart valet leder, t.ex. *(DISKUTABELT → omhandertagen)* |
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

## Åtgärdsraden i kontaktläget

Samma åtgärder finns i varje dialogsteg, så att urvalet inte avslöjar vad som är rimligt. Bedömningen
görs mot läget just då (har han vägrat uppge identitet? är förbudet konstaterat?). Motpartens reaktion
står under `atgarder` i scenariofilen och kan ersättas per dialogsteg med nodens egen `atgarder`
(`"atgarder": false` döljer raden). En reaktion har `nasta` (nästa steg) eller en egen `replik` – då
står samtalet kvar i samma steg. `atgarder_lista` begränsar vilka åtgärder som visas. Hittills har
fotografen fått reaktioner på alla åtgärder.

## Lagstödskortet

Under **Instruktion [I]** finns fliken **Lagstöd** med en sammanfattning i egna ord av
skyddslagens befogenheter 10–17 §§, nödvärn och envarsgripande (BrB 24:1 och 24:7) och reglerna för
skjutvapen vid vakttjänst (`data/lagstodskort.json`). Sammanfattningen ersätter inte lagtexten.

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

- **krav** är fakta som alla måste vara sanna i scenariot (`"fakta"` i scenariofilen), t.ex. behovsrekvisitet `behov_avlagsna`.
- **krav_utfall** / **grupp_utfall** graderar bristerna: det allvarligaste saknade kravet avgör utfallet,
  och **text_krav** ger dess förklaring. Exempel: verkanseld när angreppet upphört = *saknar lagstöd*,
  verkanseld utan föregående varningsskott = *diskutabelt*.
- **krav_grupper** är grupper där minst ett måste vara sant, t.ex. *inom ELLER invid* och grunderna i 12 §
  (*förbud ELLER identitet ELLER oriktiga uppgifter ELLER visitation ELLER fordon*).
- Är allt uppfyllt blir utfallet *lagstöd*, annars det som står i `vid_brist` (`warn` = diskutabelt, `bad` = saknar lagstöd).
- Debriefingen visar **uppfyllda** och **ej uppfyllda rekvisit** i klartext (`meta.rekvisit`).
- **Anteckna [N]** blir *protokoll enligt 16 §* när en åtgärd som kräver protokoll har genomförts.
- **foljdkrav** kontrolleras när passet är slut: anmälan till polis (17 §) och protokoll (16 §) efter omhändertagande, gripande, beslag, visitation och våld mot farkost.
- Dialogval kan ändra fakta (`"satt_fakta"`), så samma handling kan få olika bedömning beroende på vad som hänt tidigare.

En jurist kan alltså ändra lagrum, krav och texter i JSON-filen utan att röra koden.

## Stridspar, zoner och samband

- **Stridspar:** man är alltid två. Kamraten (`V` på kartan) följer efter spelaren när passet börjat, går
  genom grinden och ställer sig och skyddar vid kontakt.
- **Zoner:** positionsrutan visar **På skyddsobjektet**, **Invid skyddsobjektet (bedömning)** eller **Utanför**.
  ”Invid” är en lösare definition; hur långt ut den sträcker sig styrs av `karta.invid_avstand` (rutor).
- **Samband:** stridsparet tillsammans är **Grindposten**; du är **ettan** och din stridsparskamrat **tvåan**. Vaktchefen är **CQ** (Caesar Qvintus) och befinner sig på annan plats.
  Fraseologi: ”Grindposten, Grindposten.” – ”Grindposten kom.” – ”Från CQ, …, kom.” – ”Uppfattat, kom.” –
  ”…, slut kom.” – ”Klart slut.” Allt ligger i scenariofilen:
  - `anropssignaler`, `samband` (radiologgen vid passets start)
  - `sambandsval`: valen under **R / Samband**. Varje val pekar på en handling i `lagrum.json`; `efter` = sekunder.
    `{lage}` ersätts med texten i `lagestext`.
  - `handelser[].kamrat`: vad kamraten säger när händelsen upptäcks.
  - Sambandsfönstret är tomt från start. Varje rad bleknar efter ca 12 s och försvinner.
  - **Radiobrus:** `data/radiobrus.json` innehåller trafik mellan CQ och andra enheter
    (rondpatrullen, hundpatrullen, kökstjänst …) som glider förbi var 30–70:e sekund. Den visas
    dämpat; trafik till/från Grindposten syns tydligt.
  - Sambandsprov: ”Från CQ, förbindelsen provas, kom.” – ”Hörbarhet femma, kom.” (skala 5–1, 5 bäst).

## Händelser, upptäckt och debugrad

Varje händelse i `handelser` har ett `id` (t.ex. `"1"`) och ett `namn`. Det finns ingen avvikelseruta:
i stället har stridsparskamraten en intern **upptäcktstimer** (`handelser[].upptackt`):

- En grundtid slumpas mellan `min_s` och `max_s` sekunder (nu 2–10 s) – ibland snabbt, ibland långsamt.
- Timern går fortare ju närmare ni är (`referensavstand` / avstånd, begränsat till 0,3–3 gånger).
- Är ni längre bort än `max_avstand` rutor står timern still (fotografen 14, drönaren 18 – den hörs längre).
- När den når 100 % reagerar kamraten (repliken i `kamrat`) och personen markeras.
- Upptäcker du personen själv och tar kontakt innan dess, avbryts timern.
- **Missade händelser:** en händelse som stridsparet aldrig upptäcker (t.ex. för att ni var för långt
  bort) visas i debriefingen som *saknar lagstöd* med hur länge den pågick och hur nära ni som närmast var.
- Fotografen ger sig av efter `lamnar_efter_s` sekunder (30) om ingen kontakt tagits.

**Debugraden** (överst, av från start – **F3** eller **DBG** visar/döljer) har en knapp per händelse som startar den direkt,
och visar upptäcktstimerns status. **INFO** öppnar en panel med klocka, händelser, positioner och zoner,
figurernas tillstånd, upptäcktstimern, alla fakta och loggstorlek.

## Kamratens småprat

`data/kamratsnack.json` innehåller kamratens prat (sport, elpriser, datorspel, film, mat, väder …).
Varje rad kan ha egna `svar` som ettan (du) ibland ger; annars används `allmanna_svar`, eller så
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

## Kartan

Kartan (standard 52×52 rutor) genereras av `verktyg/generera_karta.py [storlek]`, som skriver in
den i scenariofilen och flyttar med alla koordinater (start, mål, skyddsområde). Skyddsobjektet
placeras nära mitten; runt det skapas skog, väg med korsning, stigar (bl.a. patrullstig runt
staketet), stugor, lada, brevlådor, sjö, stenar och buskar. Kameran följer spelaren.
Förhandsbild utan Godot: `python3 verktyg/forhandsvisa_karta.py . bild.png`.

## Ändra kartan

Kartan i scenariofilen består av två lager med ett tecken per ruta. Den kan genereras om (se ovan) eller redigeras för hand:

- `mark`: `.` gräs, `i` gräs innanför staket, `g` grus, `a` asfalt, `d` asfalt med mittlinje, `p` stig, `w` vatten
- `objekt`: `F` staket, `S` staket med skylt, `G` grind/bom (öppnas för spelaren, stängd för andra figurer; bilden förutsätter grind längs kartans y-led), `B` byggnad (4×3), `K` vaktkur, `T`/`t` gran, `L` lyktstolpe, `C` bil, `P` spelarens start, `V` stridsparskamrat, `H`/`h` röd stuga, `I`/`i` gul stuga, `A`/`j` lada (versal = ankare där bilden ritas), `R` sten, `U` buske, `M` brevlåda

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
