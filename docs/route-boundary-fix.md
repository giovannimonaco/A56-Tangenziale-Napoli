# Correzione accessi e confini nei Percorsi

15 novembre 2026. **ROUTING_READY** — implementazione, integrazione feed e verifiche concluse. Responsabilità: routing worker, coordinato dalla chat centrale. Nessun commit, push o upload.


## Stato attuale - ROUTING_READY

Sorgenti routing congelabili. Esecuzione finale completa `bash Tests/test-xcode.sh`: **70 test in 8 suite PASS, 0 fallimenti, 0 saltati**, app e widget compilati, tutte le matrici standalone macOS PASS. Artefatti: `.build/test-results/20261115T141912Z-5323/A56Tests.xcresult` e relativo `summary.json`. Lo script ha eliminato il proprio simulatore isolato. Il precedente fallimento widget e i PASS precedenti sono riportati come cronologia, non come esito finale.

La chiusura fisica e' lunga 815.08 m verso Pozzuoli / 824.56 m verso Capodichino, usa i veri ways OSM A1 e si proietta anche oltre il punto schematico 2. La classificazione A56 non incorpora l'A1. Due richieste reali solo sul raccordo A1 rimangono withoutA56 e ricevono comunque l'impatto di chiusura. Estremi invertiti, partenze gia' sulla A56, viaggi interni aperti, coordinate invalide, senso opposto e sovrappassi sono verificati.

**Dipendenze UI della centrale, non ancora applicate da questo worker:**

1. OverviewMapView deve chiamare `A56RouteGeometry.closureSegment(for:direction:)` per le polilinee delle chiusure. Per eventuali marker dedicati usare `resolvedReportedSegment(...).startCoordinate/endCoordinate` e `startLabel/endLabel`, lasciando invariati i marker generali degli svincoli.
2. Un'opzione withoutA56 puo' attraversare l'A1 fisicamente chiusa. `TripPlanner.Option.impacts` e `nextImpactAfterTrip` ora lo segnalano anche senza traversals A56. TripView attualmente controlla solo l'opzione withA56: la centrale deve usare gli impatti dell'alternativa per non consigliarla come strada aperta. Non serve cambiare l'enum Usage o chiamare A1 una A56.

Queste sono integrazioni di chiamata/status per la centrale/designer; nessun altro edit routing e' in corso. Nessun commit/push/upload.

## Risultato

Il matcher distingue ora gli svincoli dalle prosecuzioni stradali ai due estremi della geometria incorporata. Non usa il nome di uno svincolo per nascondere un accesso incerto. Riconosce inoltre l'ingresso curvo di Capodimonte, usa la fine dei passi MapKit per individuare le uscite e non trasforma la rampa aeroportuale parallela alla carreggiata opposta in un secondo tratto A56.

File modificati da questo worker:

- `TangenzialeNapoli/Data/A56TripMatcher.swift`
- `TangenzialeNapoli/Data/A56RouteGeometry.swift`
- `TangenzialeNapoli/ViewModels/TripPlanner.swift`
- Solo il caso aggiunto allo switch di `interchange` in `TangenzialeNapoli/Views/TripView.swift`, come autorizzato dalla centrale.
- `Tests/UnitTests/RoutingBoundaryTests.swift`
- Questo report.

A56Line, polilinee A56 esistenti, widget e progetto Xcode non sono stati modificati da questo worker. Sono stati aggiunti separatamente i due ways reali A1 per supportare chiusure pubblicate sul collegamento. La centrale gestisce membership widget e integrazione mappe.

## Cause e correzioni

1. Il vecchio `Access` distingueva solo svincolo, punto già sulla carreggiata e sconosciuto. Un attraversamento continuo dell'estremo finiva nel raggio degli svincoli vicini, diventando un falso ingresso Arco Felice o un accesso non identificato a Capodichino. `Access.continuation(.capodichino/.domitiana)` richiede ora progressione nella stessa direzione attraverso l'estremo: il campione del tratto deve trovarsi entro 55 m dall'estremo e il percorso 120 m prima/dopo deve proseguire almeno 60 m oltre, allineato entro 30° e distante non più di 35 m dalla tangente. Non basta la vicinanza.
2. “Partenza già sulla A56” / “Arrivo sulla A56” usava solo la distanza lungo il percorso dall'ultimo campione, entro 55 m. Una rampa negli ultimi metri poteva ereditare questa etichetta. Ora viene proiettato anche il vero endpoint, con direzione coerente e distanza massima 12 m dalla carreggiata.
3. `TripPlanner` passava soltanto il primo punto di ogni `MKRoute.Step`. Un passo “Take exit 13 toward Cuma” può iniziare molti chilometri prima dell'uscita. `Maneuver` conserva anche `endCoordinate`; le istruzioni numerate vengono confrontate con la fine del passo e con la progressione sul percorso, evitando di mescolare uscite vicine percorse in momenti diversi. La prova numerata resta distinta dall'inferenza geometrica.
4. L'ingresso Capodimonte può diventare stabilmente allineato solo alcune centinaia di metri dopo lo svincolo. A quel punto i candidati Capodimonte e Arenella sono troppo vicini per sceglierne uno. Un'istruzione esplicita di immissione, vicina e coerente con la geometria della rampa, permette di risolvere il punto corretto. Senza istruzione l'ambiguità resta.
5. A Via Oreste Salomone la rampa locale corre brevemente accanto alla carreggiata orientale prima di immettersi verso Pozzuoli. Il vecchio matcher aggiungeva circa 174 m verso Capodichino. Ora un tratto corto viene escluso solo se è contenuto in un passo su una strada locale e segue un'immissione esplicita nella carreggiata opposta, confermata dal successivo tratto. Il test conserva sia le istruzioni inglesi originali sia l'equivalente italiano. Se manca la prova testuale, non viene inventato uno svincolo.

Le nuove etichette sono **“Collegamento autostrade · Capodichino”** e **“Collegamento Domitiana · Arco Felice”**. Le prosecuzioni non sono rampe: una rampa chiusa vicina non blocca automaticamente chi prosegue sulla carreggiata; una chiusura del tratto principale continua invece a incidere.

## Riproduzioni reali e ipotesi degli estremi

Harness macOS separato in `/tmp/a56-boundary-investigation`, compilato direttamente con MapKit e gli stessi sorgenti del matcher. Sono state effettuate richieste reali `MKDirections`, oltre al replay di `docs/ui-route-mapkit-evidence.json`. Nessun simulatore Orya/Audiva o appartenente alle altre chat è stato usato. Le fixture versionate contengono soltanto coordinate di strade pubbliche e istruzioni pubbliche MapKit; nessuna posizione personale. I test non usano la rete.

| Caso riprodotto | Evidenza e comportamento corretto | Ipotesi degli estremi |
| --- | --- | --- |
| Piazza Garibaldi → Via Campana, percorso A56 | Richiesta fresca: circa 20.772 m. Ingresso Corso Malta, uscita Via Campana, giro alla rotatoria, nuovo ingresso Via Campana verso Capodichino e arrivo sulla A56. I due tratti dello screenshot sono reali nella risposta MapKit; l'arrivo è il punto pubblico restituito dalla ricerca, proiettato sulla carreggiata. | **Smentita** per questo screenshot; nessuno dei due tratti raggiunge un estremo A56. |
| Garibaldi → Via Campana, variante Via Cesare Rosaroll | Il vecchio replay dava ingresso sconosciuto: il primo allineamento stabile cadeva circa 368 m dopo Capodimonte, con Arenella a circa 434 m. Ora ingresso Capodimonte quando è presente l'istruzione di immissione. | **Smentita**; è un ingresso interno curvo. |
| Casoria / Via Charles Lindbergh → Zona Ospedaliera, variante A56 dal raccordo | Il tratto attraversa l'estremo orientale. Prima ingresso non identificato, ora collegamento Capodichino. | **Confermata per l'estremo della geometria**. |
| Zona Ospedaliera → Casoria, variante A56 | Il tratto raggiunge e oltrepassa l'estremo orientale. Prima uscita non identificata, ora collegamento Capodichino. | **Confermata per l'estremo della geometria**. |
| Via Montenuovo Licola Patria / accesso SS7 quater → Zona Ospedaliera | La strada prosegue attraverso il limite occidentale. Prima ingresso “14 · Arco Felice”, ora collegamento Domitiana. | **Confermata per l'estremo della geometria**, con precedente falsa etichetta di rampa. |
| Zona Ospedaliera → coordinata pubblica della carreggiata occidentale 40.839304, 14.0864667 | Richiesta reale; il percorso supera il limite occidentale. Ora collegamento Domitiana, senza inventare un'uscita Arco Felice. | **Confermata per l'estremo della geometria**. |
| Zona Ospedaliera → Via Montenuovo Licola Patria, uscita Cuma | L'uscita vera è la 13 commerciale, Cuma. Il primo punto del passo è a 40.8551004, 14.2207712; l'ultimo a 40.8412434, 14.0927652. La fine del passo risolve Cuma; senza istruzione resta da verificare. | **Smentita**: è uno svincolo vicino all'estremo, non una prosecuzione. |
| Variante aeroporto da Via Oreste Salomone | Prima apparivano un breve tratto verso Capodichino e quello verso Pozzuoli. Le istruzioni identificano il primo come rampa locale prima dell'immissione opposta. Ora resta solo il tratto principale verso Pozzuoli. | **Smentita**: falso positivo su rampa parallela. |

Le query iniziali esterne sono luoghi pubblici: Casoria 40.8903, 14.3012; zona ospedaliera 40.8650, 14.2310; area Via Montenuovo Licola Patria 40.8550, 14.0670. MapKit può spostare il punto richiesto sulla strada e proporre alternative diverse in seguito. Ad esempio, un primo tentativo occidentale a 40.83920, 14.0865 veniva collocato sulla carreggiata opposta e produceva correttamente uscita Cuma e inversione; non è stato scambiato per una prosecuzione occidentale.

### Estremo della geometria e termine amministrativo

Non sono sinonimi. Il codice incorporato termina vicino a Capodichino e Arco Felice, ma i ways OSM adiacenti mantengono `ref=A56` oltre quegli estremi. Per questo le etichette dicono “Collegamento”, senza affermare “Inizio/Fine Tangenziale” su una coordinata non verificata come confine legale.

Fonti primarie consultate il 15 novembre 2026: [Carta dei servizi 2026](https://www.tangenzialedinapoli.it/documents/d/guest/carta-dei-servizi-2026_rev-maggio2026), [relazione OSM 1577415](https://www.openstreetmap.org/relation/1577415), [prosecuzione occidentale est](https://www.openstreetmap.org/way/106758620), [prosecuzione occidentale ovest](https://www.openstreetmap.org/way/8161760). Le polilinee A56 non sono state cambiate; i due ways A1 aggiunti separatamente sono documentati sotto.

## Prima integrazione schematica feed (superata dalla verifica fisica sotto)

La centrale ha segnalato la distinta chiusura ufficiale Fine Tangenziale / Secondigliano-Aeroporto. Il mapper è di proprietà dell'altro worker. Il suo fix conserva i due identificatori ufficiali distinti e li risolve nelle posizioni adiacenti 1 e 2, evitando un tratto artificiale `fromExit == toExit`.

Il matcher proietta il punto 1 all'estremo orientale incorporato e il punto 2 più all'interno. La nuova regressione `A closed eastern connection blocks a crossing but not an interior trip` verifica entrambe le direzioni: una chiusura principale 1↔2 deve bloccare le tracce pubbliche che attraversano il collegamento e non incidere sui viaggi interni 5↔10. La regressione separata sulle rampe impedisce di trattare la prosecuzione come ingresso aeroportuale chiuso.

## Verifica

- Prima esecuzione `bash Tests/test-xcode.sh`: **53 test in 7 suite PASS**, più tutte le matrici standalone macOS. Artefatti `.build/test-results/20261115T135501Z-89445/A56Tests.xcresult`.
- Esecuzione completa successiva, con il falso positivo aeroportuale e la correzione feed concorrente: **60 test in 8 suite PASS**, `TEST SUCCEEDED`. Artefatti `.build/test-results/20261115-route-boundary-final.xcresult`.
- Ultimo controllo mirato, dopo l'aggiunta del caso di chiusura collegamento: **13 test di routing PASS**, `TEST SUCCEEDED`, comprese entrambe le direzioni della chiusura orientale. Artefatti `.build/test-results/20261115-route-connection-closure.xcresult`.
- `bash Tests/check-a56.sh` finale: **PASS** per geometria/impatti/feed, resilienza/cache/orari Napoli e matrice avvisi.

I simulatori di test sono stati creati appositamente. Entrambi sono stati spenti/eliminati dopo i controlli. Compilazione dell'app e dello switch UI completata nell'esecuzione completa.

## Limiti

Il matcher usa geometria bidimensionale semplificata, non quote stradali né geometrie complete di tutte le rampe. Non può identificare con certezza qualsiasi strada parallela entro pochi metri dalla A56. Il test copre sovrappassi, viabilità parallela fuori dal corridoio, allineamenti paralleli deboli, e il falso positivo aeroportuale realmente riprodotto. I casi ambigui conservano “Svincolo da verificare”; non sono stati allargati indiscriminatamente il raggio di scelta o la tolleranza del corridoio. Le istruzioni inglesi/italiane verificate sono prove aggiuntive; altre formulazioni possono lasciare un accesso incerto. Il test del collegamento feed verifica i punti distinti del modello corrente, senza attribuire precisione amministrativa maggiore alla geometria esistente.

## Handoff precedente (superato dalla riapertura fisica sotto)

`ROUTING_EDITS_COMPLETE`: nessun altro edit previsto da questo worker. Tutti i casi `Access` sono gestiti nello switch UI autorizzato. Non serve una modifica a A56Line o alle polilinee per questa correzione. La regressione sul collegamento chiuso 1↔2 passa con il fix mapper concorrente. Le altre modifiche presenti nella checkout appartengono alle rispettive chat e non sono state alterate.

## Physical segment coordination - in progress

Accepted feed API: RoadClosure.reportedSegment, first/second.latitude/longitude, firstLabel/secondLabel. OSM confirms that the original A56 endpoint meets A1 Ramo Capodichino: adjacent directed ways 274444620 westbound and 106831583 eastbound cover the official eastern coordinate. The A56 geometry itself is not missing an A56 member; the published closure extends onto the connecting A1 road. I will preserve A56 classification and add a separate static connection geometry. UI/central should use the forthcoming A56RouteGeometry.closureSegment(for:direction:) for drawing and resolvedReportedSegment(for:direction:) for physical anchor coordinates and ordered labels. Matcher impacts will use the same resolved physical interval, including its portion west of schematic point 2. Model/archive worker can finish the existing reportedSegment API without further schema changes.

### API for central map integration (implemented)

- `A56RouteGeometry.closureSegment(for: closure, direction: direction)` returns the physical OSM path when reportedSegment exists; otherwise it preserves the prior schematic-exit path. Invalid published geometry returns an empty path, never a fictitious physical stretch.
- `A56RouteGeometry.resolvedReportedSegment(for: closure, direction: direction)` returns optional `coordinates`, directed `startCoordinate/endCoordinate`, directed `startLabel/endLabel`, and metre positions `start/end` relative to the original A56 carriageway. Raw feed point order does not affect travel order.
- Map UI owners should replace their closure-specific `segment(from:to:direction:)` calls with `closureSegment`, and use the resolved coordinates/labels for closure-specific endpoint markers, without moving the general interchange annotations. I am not editing OverviewMapView or ClosureDetailView.
- The separate OSM connection paths do not alter `coordinates(for:)` or A56 usage classification; the connecting road stays A1, not an invented A56 extension.

### A1-only route handling / UI integration dependency

`TripPlanner.Option.impacts` and `nextImpactAfterTrip` now also supply the raw route coordinates. A56TripMatcher independently checks the published closure's A1-only geometry for a sustained directed overlap; it does NOT create an A56 traversal. This also warns a trip that never reaches A56 but drives through the closed A1 connection. The new tests explicitly reject classifying that trip as withA56 or as an arrival on A56, reject the opposite direction and an overpass, and retain the future-closure warning.

Central/UI follow-up: TripView currently reads impacts only from its preferred withA56 option. A withoutA56 option can now legitimately have a physical-connection impact via its existing `impacts(closures:departure:)` method. Do not present such an option as an unaffected alternative or recommend it as safe. This requires comparison/status UI logic outside the original narrow interchange switch scope; central can apply that change together with the closure map helper integration. No change to Usage case names is needed.

### Fresh public A1-only MKDirections verification

Two fresh requests on 2026-11-15, between public OSM road points on A1 Ramo Capodichino, reproduced the non-A56 case in both directions: westbound 286 m, eastbound 281 m. Both return `withoutA56`; both return `.roadBlock` for the physical reported closure through the independent impact check. Their four-vertex MapKit polylines are preserved in RoutingBoundaryTests. No A1 path was appended to the A56 usage geometry.

The first complete build for this extension stopped on the widget target because LiveClosureProvider now references A56RouteGeometry but that file was not in the widget target. Central has fixed target membership. A new full run including feed, widget and routing tests is now running; the failed attempt is retained in `/tmp/a56-boundary-investigation/physical-xcode-tests.log`.

### OSM geometry and shared impact interval

New static source: directed [OSM way 274444620](https://www.openstreetmap.org/way/274444620) westbound and [OSM way 106831583](https://www.openstreetmap.org/way/106831583) eastbound, downloaded on 2026-11-15 from each /api/0.6/way/ID/full.json. Both have ref=A1 and name=A1 Ramo Capodichino. All eight source vertices per way are stored without invented intermediate lines. They connect exactly to the original A56 endpoints (rounding difference below one metre). OSM attribution remains the existing map attribution.

Official pair (40.877,14.28987) / (40.87185,14.28325) resolves onto the directed roads within 15 m per endpoint. The actual drawn length is 815.0835 m westbound and 824.5572 m eastbound. The westbound interval is -417.0462...398.0371 m relative to the original A56 origin; the eastbound interval is 19196.9468...20021.5040 m. No endpoint is clamped to schematic point 1 or 2. Published pairs more than 45 m from the directed physical road, non-finite pairs or coincident pairs are rejected; a rejected physical pair never silently confirms a coarse schematic block. Provider validation also checks this resolution.

The deterministic tests cover raw endpoint reversal, both directions, full connection crossings, departure already on A56 between schematic points 2 and 3 (the old coarse interval missed this), unaffected 3-to-4 and 5-to-10 trips, invalid coordinates, an A1-only crossing, reverse travel, an overpass and future closure timing. A1-only MapKit responses are included as real public fixtures.

`ROUTING_READY` - final sources and all 70 tests verified. No further source edits in progress.
