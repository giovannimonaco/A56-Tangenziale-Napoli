# Verifica UI dell'integrazione finale

15 novembre 2026. **PASS per le integrazioni eseguite e i quattro smoke test permanenti.** Nessuna modifica ai sorgenti di produzione o al progetto Xcode da questo incarico.

## Ambiente e metodo

- Xcode 27.2, iOS Simulator 27.2, iPhone 18 Pro (402 × 874 pt).
- Simulatore dedicato **A56 Integration QA**, `5A7DC467-B7ED-4738-B550-733358ECCFBC`, riconsegnato spento. Nessun simulatore Orya/Audiva o delle altre chat usato o modificato.
- Applicata la skill `device-interaction`; gli strumenti DeviceInteraction non sono disponibili. Fallback tramite XCUITest, screenshot, gerarchia accessibilità e simctl. Prima e dopo le interazioni sono state salvate le evidenze.
- Harness esterno in `/tmp/a56-final-integration-qa/Integration.xcodeproj`: copie delle viste e dei sorgenti condivisi. Il corpo delle viste coincide con quello di produzione. La copia rende `TripComparisonView` interna e aggiunge soltanto un inizializzatore per iniettare lo stato del test. La copia di `TripPlanner` scrive diagnostica delle risposte e aggiunge un setter QA, senza cambiare il calcolo. Il wrapper `@main` sostituisce l'avvio dell'app e fornisce una chiusura dimostrativa attiva.
- Il wrapper chiama `refreshNow()` dopo aver creato il VM di anteprima: senza questo passaggio il factory Debug può avere `now` di pochi microsecondi precedente al timestamp assegnato alla preview. Gli screenshot conclusivi sono stati ricatturati con questo ordine corretto. Non è stato alterato il controllo di freschezza delle viste.
- [Hash dei sorgenti originali](screenshots/final-integration/source-hashes.json) registrati e riconfrontati alla fine: corrispondono ancora alle versioni testate.

## Chiusura fisica e mappa

La fixture usa i due estremi pubblicati `(40.877, 14.28987)` e `(40.87185, 14.28325)`, direzione Pozzuoli, e un intervallo attivo durante la prova. Non rappresenta un avviso attivo reale del 15 novembre.

- Il dettaglio mostra **Secondigliano-Aeroporto** e **Capodichino**, con ruoli “Inizio/Fine del tratto indicato dal gestore”, e la frase che comprende il collegamento autostradale interessato. Test e ispezione visiva **PASS**.
- La mappa della stessa vista `OverviewMapView` usa `closureSegment` e disegna la chiusura in rosso. Il percorso risolto contiene **12 coordinate**, misura **815,0835 m** e copre l'intervallo `-417,0462...398,0371 m` rispetto all'origine della geometria A56. La porzione sul raccordo resta distinta dalla classificazione A56. [Prova numerica](screenshots/final-integration/physical-proof.json).
- La cattura conclusiva della mappa è l'overview. I tentativi intermedi di pan/zoom non dimostrano che l'intero segmento sia visibile a zoom ravvicinato; non vengono usati come prova della sua lunghezza. Questa è attestata dal percorso effettivo fornito alla vista e dalle regressioni geometriche separate.

Evidenze: [dettaglio](screenshots/final-integration/detail-physical-endpoints.png), [gerarchia dettaglio](screenshots/final-integration/detail-physical-endpoints.txt), [mappa](screenshots/final-integration/map-physical-segment.png), [gerarchia mappa](screenshots/final-integration/map-physical-segment.txt).

## Risposta reale MapKit sul solo raccordo A1

Richieste reali fra i punti pubblici del raccordo `(40.8767072, 14.2896228)` e `(40.8744877, 14.2879174)`, senza posizione personale. Entrambe le richieste (autostrade consentite/evitate) restituiscono **286 m**, quattro vertici e `route.name = "A56"`; i soli passi sono vuoto e “Destinazione raggiunta”. La geometria è quella del raccordo A1 già verificato separatamente su OSM.

Questa discrepanza spiega il risultato **`.uncertain`** dell'app: il nome di MapKit cita A56, mentre la geometria non conferma una percorrenza A56. È stato verificato il comportamento prudente senza forzare la classificazione per soddisfare il test.

- UI **“Chiusura sul collegamento”** e spiegazione “anche se non percorre la A56”: **PASS**.
- Riga **“Percorso da verificare” / “Chiusura sul tragitto”**, percorso rosso: **PASS**.
- Nessuna raccomandazione dell'alternativa come libera e nessuna selezione automatica della riga colpita: **PASS**.
- La selezione manuale della riga conserva l'avviso: **PASS**.

La prima asserzione cercava specificamente la riga “Senza Tangenziale” ed è fallita. Il fallimento è conservato in `/tmp/a56-final-integration-qa/integration-verified.xcresult`; non è stato nascosto né interpretato come un pass. Sono stati esaminati i metadati effettivi e verificato separatamente il ramo `.uncertain`, come richiesto dalla centrale.

Evidenze: [risposta consentita](screenshots/final-integration/directions-allow.json), [risposta evitata](screenshots/final-integration/directions-avoid.json), [avviso reale su fixture di chiusura](screenshots/final-integration/trip-connection-warning.png), [riga colpita non selezionata](screenshots/final-integration/trip-blocked-alternative-unselected.png), [dopo selezione](screenshots/final-integration/trip-blocked-alternative-selected.png).

## Ramo `.withoutA56` verificato con fixture dichiarata

Il wrapper ha riutilizzato lo stesso **MKRoute reale** e ha iniettato soltanto `Option.usage = .withoutA56` in un risultato del planner, per coprire esplicitamente il ramo UI senza dipendere dalla denominazione restituita da Apple. Questa prova non verifica il classificatore, già coperto dalle regressioni di routing, e non viene presentata come classificazione di una nuova risposta MapKit.

- Titolo **“Chiusura sul collegamento”**: **PASS**.
- Riga **“Senza Tangenziale”**, sottotitolo **“Chiusura sul tragitto”** e tracciato rosso: **PASS**.
- Riga inizialmente non selezionata e assenza della raccomandazione come alternativa libera: **PASS**.
- Selezione manuale e permanenza dell'avviso: **PASS**.

[Provenienza della fixture](screenshots/final-integration/without-fixture-proof.json), [prima della selezione](screenshots/final-integration/without-fixture-blocked-unselected.png), [dopo la selezione](screenshots/final-integration/without-fixture-blocked-selected.png).

## Esecuzioni e risultati

- Harness finale: **3 test PASS**, 0 fallimenti, `/tmp/a56-final-integration-qa/integration-final.xcresult`.
- Caso aggiuntivo categoria `.withoutA56`: **1 test PASS**, 0 fallimenti, `/tmp/a56-final-integration-qa/without-fixture.xcresult`.
- Acquisizione mappa aggiuntiva: **1 test PASS**, `/tmp/a56-final-integration-qa/map-close.xcresult`; il close-up è una cattura intermedia, non una prova conclusiva del segmento completo.
- Target **di produzione** `A56UITests`, schema `A56UI`, sullo stesso simulatore: **4 test PASS**, 0 fallimenti. Risultato `build/final-ui-tests.xcresult`, log `build/final-ui-tests.log`, riepilogo `build/final-ui-tests-summary.json`.

Gli smoke permanenti verificano warning cache, navigazione tab/ricerca manuale, indisponibilità senza conferma di strada libera e collegamento del widget verso Chiusure.

## Limiti

Verifica su simulatore iOS 27.2, testo standard e aspetto chiaro per questi casi specifici; nessun nuovo test su iPhone fisico, iOS 18 o ascolto VoiceOver. Le verifiche AX5/scuro/contrasto del designer sono distinte. Le fixture di chiusura sono dimostrative; le richieste di itinerario sono reali. L'esecuzione dei quattro smoke permanenti usa l'app effettiva, mentre le scene fisiche specifiche usano l'harness documentato. Nessun upload, commit o push.

## Riesecuzione dopo sincronizzazione widget — build 1.0 (8)

15 novembre 2026, conclusa alle **16:03 Europe/Rome**. Su richiesta della centrale, dopo il congelamento `WIDGET_SYNC_READY`, sono stati eseguiti **soltanto i quattro test permanenti `A56UI`**, senza altre fixture o modifiche ai sorgenti. Usato lo stesso simulatore dedicato e la DerivedData della suite dell'app.

**Risultato: TEST SUCCEEDED — 4 test, 4 passati, 0 fallimenti, 0 saltati.**

| Test | Esito | Durata |
| --- | --- | --- |
| Warning della copia offline conservato attraverso i tab | PASS | 21,259 s |
| Tab e ricerca percorso con indirizzo manuale | PASS | 20,944 s |
| Dati indisponibili senza conferma di strada libera | PASS | 7,396 s |
| Collegamento widget che apre Chiusure da un altro tab | PASS | 11,520 s |

Verificati anche i plist dei prodotti compilati: **app `com.giovannimonaco.TangenzialeNapoli` e widget `.widgets` sono entrambi 1.0 (8)**. La nuova versione di `AppTabView` contiene l'observer che pubblica lo snapshot dopo un caricamento reale concluso; i flag delle fixture e le anteprime disabilitano tale pubblicazione. Questa suite verifica la regressione dell'interfaccia con il nuovo hook compilato; non costituisce una nuova prova positiva di download o refresh schedulato di WidgetKit.

Comando eseguito:

```sh
xcodebuild test -project TangenzialeNapoli.xcodeproj -scheme A56UI \
  -destination 'platform=iOS Simulator,id=5A7DC467-B7ED-4738-B550-733358ECCFBC' \
  -derivedDataPath build/ui-test-results/DerivedData \
  -resultBundlePath build/final-sync-ui-tests.xcresult \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

Artefatti: `build/final-sync-ui-tests.xcresult`, `build/final-sync-ui-tests.log` e riepilogo estratto con `xcresulttool` in `build/final-sync-ui-tests-summary.json`. I precedenti hash e le scene dell'harness sopra descrivono la verifica precedente alla sincronizzazione; non vengono presentati come hash della build 8. Il simulatore dedicato è stato spento dopo questa riesecuzione; nessun altro simulatore è stato toccato. Nessun commit, push o upload.
