# Diagnosi feed e completezza A56

`FEED_API_EDITS_COMPLETE_PENDING_INTEGRATION_TEST`: le modifiche a mapper, decoder, modello, archivio e provider sono stabili; la centrale può completare progetto/UI e il route worker può ultimare il suo helper. Nessuna ulteriore modifica di API è prevista qui. La chat mantiene aperta la verifica finale e aggiornerà gli esiti.

**Dipendenza progetto concreta per la centrale:** il nuovo controllo di integrità condiviso in `LiveClosureProvider` chiama `A56RouteGeometry.resolvedReportedSegment`. La compilazione dell'app/macOS passa e l'audit live fisico conferma 48/48; la compilazione di `A56WidgetExtension` invece si ferma perché il suo elenco sorgenti esplicito non comprende `TangenzialeNapoli/Data/A56RouteGeometry.swift` (`cannot find A56RouteGeometry in scope`, `/tmp/a56-feed-audit/complete-physical.log:82`). Aggiungere quel file al target widget e allo script di integrazione widget, se mantenuto, senza modificare mapper o schema unit. Non è stata applicata una compilazione condizionale per saltare la verifica di geometria nel widget. Il progetto rimane di proprietà della centrale.

**Stato API aggiornato:** il route specialist ha ora implementato `A56RouteGeometry.resolvedReportedSegment(for:direction:)` e `closureSegment(for:direction:)`, con una distinta geometria del collegamento A1 verificata su OSM, senza estendere la classificazione A56. `A56TripMatcher` usa l'intervallo fisico comune al disegno. Questa chat ha aggiunto il controllo di integrità nel provider: se un `reportedSegment` plausibile regionalmente non è verificabile sulla geometria stradale, gli avvisi restano visibili ma la qualità rimane incompleta. Test di regressione completo in esecuzione in `/tmp/a56-feed-audit/complete-physical.xcresult`. La centrale/UI deve ora usare `closureSegment` e le coordinate/etichette ordinate da `resolvedReportedSegment` per il tratto chiuso e i suoi marker; non deve riposizionare gli svincoli generali.

**Aggiornamento geometrico per la centrale / route specialist:** il recupero 48/48 è riuscito, ma il nuovo test geometrico ha rilevato che il tratto schematico 1–2 proiettato è più corto dei 200 m attesi. I test sugli impatti passano; l'asserzione sulla lunghezza >200 m fallisce in entrambi i sensi. Analisi delle coordinate: punto ufficiale 11222 `(40.877,14.28987)` è circa 409–415 m oltre il limite est della geometria statica; punto 1117 `(40.87185,14.28325)` è sulla carreggiata, più a ovest della posizione schematica 2. Le ancore 1–2 proiettate rappresentano quindi soltanto una parte del tratto fisico. Prima di dichiarare risolto anche il routing servono estremi fisici opzionali dal feed e loro uso negli impatti, mantenendo la distinta continuazione Capodichino già introdotta dal route worker. Questa chat può aggiungere i campi opzionali al modello e decodificare le coordinate, ma non possiede `A56TripMatcher`. Nessun allargamento arbitrario a un altro svincolo e nessun abbassamento della soglia del test è stato applicato.

**Interfaccia pronta per route specialist/UI:** aggiunto al modello `RoadClosure.reportedSegment: RoadClosure.ReportedSegment?`, con `first` / `second` (`Point.latitude`, `.longitude`) e `firstLabel` / `secondLabel`. I mapper planned/live valorizzano questo campo per il segmento ufficiale 11222/1117 usando le quattro coordinate della fonte, validate per intervallo A56 e finitezza. Il campo è Codable opzionale, mantenuto da `confirmed(by:)` e `ended(at:)`. Il route worker può ora usare questi estremi negli impatti; la centrale/UI deve usarli per il disegno e i nomi effettivi quando il nuovo helper geometrico sarà disponibile. In seguito all'estensione esplicita dello scope, anche `ClosureArchive.reconcile` e `migrateFromSchema1` preservano il campo. Non modificare i mapper mentre questa chat termina la verifica.

**Ordine e provenienza:** `first` corrisponde esclusivamente a `n_crd_lat_ini` / `n_crd_lon_ini`, `second` a `n_crd_lat_fin` / `n_crd_lon_fin`; l'ordine è quello della fonte, non il senso di viaggio e non necessariamente l'ordine numerico di `fromExit` / `toExit`. Le etichette corrispondono agli ID pri/sec del segmento verificato. Non sono usati i campi `n_crd_lat` / `n_crd_lon` del marker. Per la riga attuale il secondo punto è entro circa 10 m dalla carreggiata statica; il primo è oltre il limite e va trattato come prosecuzione verificata, non come un punto della carreggiata ricavato da una semplice etichetta. Il recupero speciale richiede ora coordinate plausibili: in loro assenza torna incompleto invece di inventare l'estensione. I nuovi test includono round trip Codable, migrazione e riconciliazione e un impatto sul percorso 2–4 (e 4–2), che l'intervallo schematico 1–2 non copre.

15 novembre 2026, verifica iniziale 14:56 Europe/Rome. Lavoro in corso: questa chat possiede esclusivamente i mapper, `AutostradeEvent.swift`, `LiveClosureProvider.swift`, `NoticeText.swift` e i nuovi test di regressione feed; nessuna modifica a UI, widget, routing o progetto.

## Riproduzione prima della correzione

Download diretti degli endpoint originali, senza autenticazione, proxy alternativi o aggiramento di blocchi:

- `https://viabilita.autostrade.it/json/previsioni.json`: HTTP 200, 1.355.325 byte; Last-Modified `2026-11-15 13:56:08 GMT`, risposta `13:56:20 GMT`; 524 righe nazionali decodificate, 0 scartate, 24 righe A56.
- `https://viabilita.autostrade.it/json/eventi.json`: HTTP 200, 81.619 byte; Last-Modified `2026-11-15 13:56:08 GMT`, risposta `13:56:21 GMT`; 49 righe nazionali decodificate, 0 scartate, nessuna riga A56 attiva.
- Copie raw, header e diagnostica solo in `/tmp/a56-feed-audit/`; nessun avviso originale copiato nel repository.
- Mapper programmato: **47/48 occorrenze**; mapper realtime **0/0**. Fetch di produzione riprodotto: `plannedFeedAvailable=true`, `realtimeFeedAvailable=true`, `mappedRecords=47`, `expectedRecords=48`, `topologyIssues=[]`, un solo elemento in `unresolvedRecords`.
- Elemento irrisolto: evento `20261112_E23_SIV_P_00141_00001`, tipo tratto chiuso, direzione Pozzuoli, identificatori punto `11222` e `1117`, località strutturate Secondigliano-Aeroporto e Capodichino. L'occorrenza è del 20–21 novembre, con divergenza di orario finale da mantenere visibile.
- Il testo del tratto distingue il terminale e Secondigliano-Aeroporto, ma i due alias testuali restituiscono entrambi posizione 1. L'override contestuale di 1117 per il terminale collassa anche la seconda estremità su 1, e il controllo `a != b` scarta l'intera occorrenza. Sono invece due punti ufficiali distinti già riconosciuti dalla tabella dell'app come posizioni adiacenti 1 e 2.
- Sei altre segnalazioni di orari discordanti hanno `coveredByMappedWindow=true`: vengono già rappresentate con la fascia conservativa sulle rispettive chiusure e non producono il warning globale. Nessun feed era mancante, vuoto, frammentario o fuori dalla soglia temporale.

## Correzione in corso di verifica

Il parser conserva ora anche i due nomi originali del tratto. Solo per la coppia di alias terminali collassata, con **entrambi gli ID ufficiali 11222/1117** e nomi strutturati compatibili, il mapper usa i due punti distinti già noti invece dell'override del terminale. Gli altri conflitti restano errori di copertura; non cambiano i controlli HTTP, pubblicazione, qualità o i limiti di aggiornamento. La finestra temporale conserva ancora l'orario più ampio quando i campi della fonte differiscono.

## Prima verifica dopo la correzione

Il medesimo snapshot passa da **47/48 a 48/48**, senza scarti. Il fetch reale tramite `LiveClosureProvider` restituisce ora **48 chiusure, `isFullyVerified=true`, entrambe le fonti disponibili, `expectedRecords=mappedRecords=48`, `unresolvedRecords=[]`, `topologyIssues=[]`**. L'occorrenza recuperata conserva `reportedWindow`, quindi anche la sua divergenza di orario è visibile localmente.

Non è un marker a lunghezza nulla: la chiusura ha estremità distinte **1→2 verso Pozzuoli** e **2→1 nell'altro senso**. Sono i due punti già esistenti, associati agli ID ufficiali dalla tabella A56: non è stato inventato né aggiunto uno svincolo. La precisione grafica rimane quella della linea statica dell'app, che proietta i punti schematici sulla carreggiata.

I nuovi test `FeedCompletenessRegressionTests` richiedono che il tratto fisico conservato dalla fonte abbia lunghezza >200 m, venga riconosciuto e blocchi un percorso che lo percorre in ciascun senso, compreso il percorso 2–4 oltre la seconda ancora, e non blocchi un percorso distante (posizioni 5–8). Sono inoltre coperti ordine invertito degli ID, feed live, mantenimento della fascia temporale più ampia e rifiuto di ID assenti/sconosciuti o località contraddittorie. Questa chat non ha toccato `A56TripMatcher`, `A56RouteGeometry`, `TripPlanner`, `A56Line` o UI; `RoadClosure` e `ClosureArchive` sono stati estesi dopo autorizzazione esplicita della centrale.

La prima riesecuzione isolata dei controlli shell è stata interrotta perché `A56TripMatcher.swift` è stato modificato dall'altro worker durante la compilazione, non per un errore del mapper. Lo script completo è stato poi avviato nuovamente per verificare insieme shell e Swift Testing. Esiti finali in aggiornamento.

Audit live ripetuto **15:11:02 Europe/Rome**, dopo l'aggiunta degli estremi fisici al modello/decoder: **48/48**, qualità completa, entrambi i feed disponibili, nessuna riga irrisolta, nessun problema topologico; prove in `/tmp/a56-feed-audit/live-current.json`. I controlli shell esistenti dopo le modifiche al modello/archivio sono **PASS** (tutte e tre le matrici), log `/tmp/a56-feed-audit/shell-after.txt`. La prima suite completa ha segnalato soltanto le due asserzioni geometriche che hanno fatto emergere il secondo problema; le altre verifiche sono passate. Resta necessaria l'integrazione routing dei campi fisici prima del pass finale del nuovo test sul percorso 2–4.

Le sette divergenze temporali residue sono nella fonte, non righe perdute: eventi `20261112_E23_SIV_P_00150_00001`, `00132_00001`, `00134_00001`, `00130_00001`, `00152_00001`, `00156_00001`, `00141_00001` (medesimo prefisso). Tutte riguardano la notte 20–21 novembre: inizio 23:59, fine generale/testuale 06:00 contro fine `indisponibilita` 06:59. Si conserva 06:59 con `reportedWindow` a 06:00 e avvertenza locale; nessun orario viene corretto arbitrariamente.

Audit ripetibile separato dai test deterministici:

```sh
bash Tests/audit-live-feed.sh --live
bash Tests/audit-live-feed.sh --snapshots /tmp/a56-feed-audit/planned.json /tmp/a56-feed-audit/live.json
```

`--live` usa il provider di produzione e tutti i controlli HTTP/freschezza; restituisce errore se la qualità non è completa. `--snapshots` verifica soltanto decodifica e mapping delle copie e non attesta disponibilità o freschezza della rete. Nessuna dipendenza live è introdotta nella CI o nei test unitari.

## Esiti e dipendenza di integrazione al 15:15 Europe/Rome

- `bash Tests/check-a56.sh`: **PASS** dopo parser, modello, archivio e helper fisico; log `/tmp/a56-feed-audit/shell-physical.txt`.
- `bash Tests/audit-live-feed.sh --live`: **PASS** alle 15:13:43, **48/48**, **1 segmento fisico**, nessuna issue di copertura/topologia; `/tmp/a56-feed-audit/live-physical-current.json`.
- `bash Tests/audit-live-feed.sh --snapshots ...`: **PASS**, 48/48 sullo stesso snapshot inizialmente 47/48; `/tmp/a56-feed-audit/snapshot-after.json`.
- Prima suite completa: 61 test/8 suite, due asserzioni di lunghezza fallite che hanno fatto emergere il tratto fisico oltre le ancore; `/tmp/A56Tests-feed-fix/A56Tests.xcresult`. Il solo abbassamento della soglia non è stato usato come soluzione.
- Seconda esecuzione mirata, dopo aggiunta degli estremi fisici ma prima dell'integrazione del route worker: 9 test, due failure sul percorso 2–4 / 4–2, `/tmp/a56-feed-audit/regression.xcresult`. Sono i casi che hanno richiesto l'uso effettivo degli estremi negli impatti.
- Riesecuzione completa con integrazione fisica: interrotta in compilazione widget per file geometria non incluso nel target, `/tmp/a56-feed-audit/complete-physical.xcresult`, log omonimo `.log`. **Nessun pass finale Swift Testing attestato finché la centrale non aggiunge quel sorgente al target widget.**
- `bash -n Tests/audit-live-feed.sh` e `git diff --check`: **PASS**.

API e correzioni feed/modello/archivio sono pronte. Restano alla centrale l'inclusione del file nel widget e l'uso del nuovo helper in UI; poi si può ripetere `bash Tests/test-xcode.sh`. Nessun commit, push, upload o raw feed nel repository. I simulatori usati da questa chat sono dedicati; nessuna interazione con Orya/Audiva.
