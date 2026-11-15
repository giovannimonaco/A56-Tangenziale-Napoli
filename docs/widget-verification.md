# Verifica widget A56

Verifica del 15 novembre 2026. Ambito sorgenti: solo `A56Widget/A56Widget.swift`; nessuna modifica al progetto, al modello/store condiviso o ai test esistenti. Nessun commit, push o upload.

## Modifiche

- Anteprima della galleria con una chiusura in corso verso Capodichino e una futura verso Pozzuoli, entrambe sintetiche e indicate da “Esempio di anteprima” / “Dati di esempio”. Il factory viene chiamato soltanto da `getSnapshot` quando `context.isPreview` è vero. Il placeholder resta indisponibile; snapshot e timeline reali usano lo store autonomo, senza fixture o fallback sintetici.
- Nel medium, titolo e stato affiancati, spazi verticali ridotti e località su un massimo di due righe senza compressione verticale: la galleria reale aveva troncato “Agnano”.
- Intestazione small più compatta: il rendering a 170 pt mostrava “Chiusure…”. Titolo su una riga con dimensione adattata alla famiglia, riduzione controllata e nomi delle direzioni su una riga.

## Ambiente e metodo

- Xcode 27.2 (27B52), iOS Simulator 27.2 (24B8117), iPhone 18 Pro, 402 × 874 pt.
- Simulatore dedicato **A56 Widget QA**, UDID `E2A1AAB5-A37D-4596-A7AC-7E7A228964C8`. Nessun altro simulatore usato o spento.
- Non erano disponibili i tool `DeviceInteraction`; interazione reale tramite harness XCUITest esterno al repository, `xcrun simctl` e gerarchia accessibilità. Harness SpringBoard: `/tmp/a56-widget-device-qa/WidgetQA.xcodeproj`.
- Harness separato `/tmp/a56-widget-render/Render.app`, bundle `com.a56.qa.renderer`, compilato con gli stessi sorgenti condivisi e la stessa `A56WidgetView`. Per selezionare la famiglia fuori da WidgetKit, la copia temporanea sostituisce soltanto la lettura dell'environment `widgetFamily` con un parametro; rimuove inoltre `@main` dal bundle widget. Il corpo delle viste è quello del sorgente finale. `ImageRenderer` su iOS produce PNG @3x con margini simulati di 16 pt, small 170 × 170 pt e medium 364 × 170 pt. Questi PNG **non sono screenshot di widget ospitati da SpringBoard**.

## Store e rete reali

L'harness iOS ha eseguito `WidgetSnapshotStore.refresh()` con il `LiveClosureProvider` originale, su directory inizialmente vuota, senza aprire l'app A56 e senza iniettare dati nei feed.

Risultato alle **14:34:07 Europe/Rome** (`2026-11-15T13:34:07Z`):

| Prova | Risultato |
| --- | --- |
| Cache iniziale vuota | `.unavailable` |
| Richiesta reale ai due feed ufficiali | 47 chiusure, timestamp nuovo, stato `.partial`, `isComplete == false` |
| Nuova istanza dello store sulla stessa directory | timestamp e 47 chiusure ripristinati |
| Errore di rete iniettato con provider che lancia `URLError.notConnectedToInternet` | `.offline`, timestamp e chiusure conservati |
| Stesso errore su store nuovo senza cache | `.unavailable` |
| Età esatta di 300 secondi | `.stale` |
| Date della timeline | presente la voce a `fetchedAt + 300` |

Lo stato incompleto della risposta reale è stato mantenuto: una risposta HTTP recente non equivale a verifica completa degli avvisi. Gli errori offline sono stati iniettati nel solo harness, senza disabilitare la rete del computer o dei simulatori delle altre chat. Questa prova dello store non sostituisce la prova del processo WidgetKit, riportata separatamente sotto.

Il risultato JSON dettagliato del primo passaggio è in `/tmp/a56-widget-render/proof.json`. Dopo l’ultimo ritocco UI, secondo passaggio alle **14:41:46 Europe/Rome**: ancora 47 chiusure, stato parziale e tutte le verifiche della tabella riuscite; `/tmp/a56-widget-render/final-proof.json`. Nessun ID `widget-preview-*` nel payload reale. Il payload resta nella sandbox dell’harness, senza essere aggiunto al repository.

## Layout con fixture

In `screenshots/widgets/`, tutti i file con `fixture` nel nome sono rendering dell'harness. Riferimento fisso **15/11/2026 ore 22:00 Europe/Rome**; una chiusura attiva verso Capodichino e una futura verso Pozzuoli. Non rappresentano la situazione stradale rilevata durante la prova rete.

Matrice: **small / medium × light / dark × current / partial / stale / offline / unavailable / gallery-preview** (24 PNG), più quattro rendering `narrow` current a 155 × 155 pt / 329 × 155 pt per controllare lo spazio ridotto. La fixture scaduta usa +301 secondi, quella offline +600 secondi. Gli stati senza dati mostrano trattini nel formato piccolo e “Da verificare” nel medio; quelli scaduti e offline mantengono il controllo temporale e l'avvertimento. Non viene mostrato uno stato “strada aperta”.

La verifica visiva controlla titolo, nomi delle direzioni, conteggi, stato, prossima chiusura, orario e contrasto nelle due apparenze. Il font è quello standard; VoiceOver e tutte le dimensioni Dynamic Type non sono stati verificati su dispositivo.

## WidgetKit e SpringBoard reali

Prove eseguite senza avviare l'app contenitore fino al tap del widget:

1. Installazione di app ed estensione, registrazione verificata con `pluginkit`; ricerca “A56” nella galleria di SpringBoard prima del primo avvio dell'app. Entrambe le famiglie disponibili, esempi di anteprima etichettati.
2. Aggiunta effettiva del widget medium alla Home. Alle **14:37:25 Europe/Rome** il processo `A56WidgetExtension` (PID 78166) ha richiesto entrambi i feed: HTTP 200, `cache_hit=false`, timeline completata. Il widget mostrava “Avvisi incompleti”, conteggi 0/0 e prossime chiusure reali del 16/11 alle 23:00.
3. Prima del tap, cache dello store con `fetchedAt = 2026-11-15T13:37:25.630648Z`, **47 chiusure**, `isComplete=false`, `isOffline=false`. La directory Application Support del contenitore dell'app principale era vuota. La rete non dipende quindi da un precedente avvio dell'app.
4. Tap effettivo sul widget in SpringBoard tramite XCUITest: l'app si apre con barra di navigazione **Chiusure** e tab **Chiusure selezionato**. Il test ha controllato entrambi. È la prima apertura dell'app; il tab di default sarebbe Mappa. `.widgetURL` contiene `a56napoli://closures` e il gestore dell'app seleziona Chiusure.

Dopo le modifiche UI finali, small e medium aggiunti e ispezionati sulla Home sia in chiaro sia in scuro. Dimensioni effettive sul dispositivo selezionato: small 164,33 × 164,33 pt; medium 349,67 × 164,33 pt. Entrambi i titoli sono interi; il medium mostra integralmente gli svincoli su due righe.

Prove locali dettagliate: `/tmp/a56-widget-device-qa/independent-live-proof.json`, `/tmp/a56-widget-device-qa/extension-independent-network.log`, risultati `/tmp/a56-widget-device-qa/tap.xcresult`.

**Limite del simulatore non firmato:** il processo dell'estensione risolve Application Support in `SIM/data/Library/Application Support/`, anziché in un contenitore `PluginKitPlugin` dedicato. La prova dimostra l'esecuzione autonoma dell'estensione e l'assenza di dipendenza dai dati dell'app, ma non verifica l'isolamento della sandbox su dispositivo firmato. Il codice usa la directory Application Support del processo e non un App Group; la verifica su dispositivo firmato resta da eseguire.

## Build e risultati

Build finale Debug di app ed estensione: **BUILD SUCCEEDED**.

```sh
xcodebuild -project TangenzialeNapoli.xcodeproj \
  -scheme TangenzialeNapoli -configuration Debug \
  -destination 'id=E2A1AAB5-A37D-4596-A7AC-7E7A228964C8' \
  -derivedDataPath /tmp/a56-widget-device-qa/app-build \
  CODE_SIGNING_ALLOWED=NO build
```

Log: `/tmp/a56-widget-device-qa/app-build-final-ui.log`. XCUITest del tap e XCUITest finale galleria/aggiunta: **TEST EXECUTE SUCCEEDED** (`tap.xcresult`, `final-gallery.xcresult`). Non modificata o rieseguita l’intera suite di regressione del repository; verifica mirata tramite gli harness esterni. SHA-256 del sorgente finale `A56Widget/A56Widget.swift`: `3feadcbe5b4eda39ba11b5927e0a02d429dc53121aa446ded792878f37050f42`.

## Screenshot durevoli

**35 PNG**: 28 fixture/rendering e 7 acquisizioni reali. I rendering includono nel nome `fixture`; le acquisizioni reali sono:

- [Ricerca A56 prima di aprire l’app](screenshots/widgets/gallery-search-before-app-launch.png).
- [Galleria small finale](screenshots/widgets/gallery-small-real-host.png) e [medium finale](screenshots/widgets/gallery-medium-real-host.png), entrambe con dati di esempio dichiarati. Il lieve angolo della card appartiene al carosello nativo della galleria.
- [Medium con rete autonoma prima del primo avvio dell’app](screenshots/widgets/springboard-medium-independent-live-light.png); acquisizione precedente al solo ritocco finale del layout medium.
- [Home finale chiara](screenshots/widgets/springboard-small-medium-live-light.png) e [scura](screenshots/widgets/springboard-small-medium-live-dark.png), con entrambi i widget e dati reali.
- [Chiusure dopo il tap sul widget](screenshots/widgets/widget-tap-opens-closures.png).

## Aggiornamento e limiti

Il provider richiede un nuovo refresh dopo 30 minuti con jitter fino a 120 secondi. La timeline include scadenza a cinque minuti e transizioni note. La richiesta non garantisce che iOS esegua la rete ogni trenta minuti: scadenza e stato salvato restano visibili anche se il sistema posticipa il reload. Non è stata eseguita un'attesa reale di trenta minuti o una prova su iPhone fisico, TestFlight, StandBy o Home con aspetto tinto.

Il simulatore dedicato è stato spento a fine verifica, senza eliminarlo; resta disponibile con app e widget installati.

I percorsi `/tmp` sono artefatti locali di verifica e possono essere rimossi dal sistema. Le evidenze durevoli sono questo documento e i PNG nel repository.
