# Sincronizzazione app e widget A56

15 novembre 2026. Questa modifica sostituisce l’architettura a due cache indipendenti descritta nella precedente verifica widget. Il problema era reale: aggiornare l’app non pubblicava nulla nella cache letta dall’estensione, quindi i due timestamp potevano divergere fino al successivo refresh autonomo del widget.

## Comportamento

Al termine di ogni richiesta riuscita dell’app, iniziale, manuale o automatica, il risultato viene pubblicato nel contenitore App Group e viene richiesto il reload di `A56ClosuresWidget`. L’estensione legge per prima la copia condivisa. Se ha meno di cinque minuti, anche se parziale, la usa direttamente: nessuna seconda richiesta di rete viene avviata solo per mostrare dati appena scaricati dall’app.

Se la copia manca o è scaduta, il widget mantiene la propria richiesta autonoma ai feed reali e pubblica il risultato nello stesso store. A rete non disponibile riusa la copia condivisa, conservandone timestamp e completezza; senza copia resta indisponibile. Un errore di una vecchia richiesta del widget non rende offline una risposta dell’app arrivata nel frattempo.

Il widget richiede comunque il refresh autonomo dopo circa trenta minuti, con jitter fino a due minuti. La timeline continua a includere il passaggio “Da aggiornare” a cinque minuti e i cambiamenti di chiusure noti. `WidgetCenter.reloadTimelines` è una richiesta a iOS: i dati sono disponibili subito nel contenitore, ma l’istante in cui la Home viene ridisegnata dipende dal sistema. La sincronizzazione non abilita notifiche push o un aggiornamento ogni secondo.

## API e integrazione

- `WidgetSnapshotStore.appGroupIdentifier`: `group.com.giovannimonaco.TangenzialeNapoli`.
- `WidgetSnapshotStore.widgetKind`: `A56ClosuresWidget`.
- `publishFromApp(_ snapshot: WidgetSnapshot) async -> Bool`: pubblicazione atomica; restituisce vero e richiede il reload solo se la scrittura ha sostituito con successo lo stato precedente.
- `snapshotForTimeline(using:at:)`: cache condivisa fresca prima della rete; `refresh(using:)` rimane la variante che esegue sempre la rete.
- `WidgetSnapshot.requestStartedAt`: nuovo campo opzionale, compatibile con le cache precedenti. `fetchedAt` rimane il momento della risposta, usato per stato e orario mostrato.
- `ClosuresViewModel.lastRequestStartedAt`: solo getter del `lastAttemptAt` esistente; nessun cambio al caricamento o ai mapper.
- `AppTabView` osserva `lastLoadedAt`, che cambia soltanto dopo una richiesta riuscita. Copia subito avvisi, qualità e inizio richiesta in uno snapshot prima di creare il Task di pubblicazione. Copre anche i refresh avviati nelle viste figlie. I ViewModel iniettati, gli argomenti `--sample-data`, `--stale-sample-data`, `--unavailable-data` e le preview Xcode disabilitano la pubblicazione; la galleria conserva i propri esempi solo nel ramo `context.isPreview`.

Entrambi i target devono avere l’entitlement `com.apple.security.application-groups` con il gruppo indicato e profili firmati corrispondenti. La chat centrale gestisce `Configuration/A56SharedData.entitlements`, progetto, registrazione e verifica dei profili: questi file non sono stati modificati da questa attività. La centrale ha confermato la disponibilità del gruppo nei profili e nella firma di app ed estensione; la prova finale su iPhone firmato rimane di sua competenza.

La directory predefinita è `AppGroup/Library/Application Support/A56Widget/`. In assenza del gruppo si ripiega su Application Support del processo e si scrive un messaggio diagnostico DEBUG: il widget mantiene autonomia, ma questa modalità non sincronizza due sandbox diverse. Il costruttore accetta ancora `directory:` per test senza entitlement e aggiunge `legacyDirectory:`, `clock:` e il callback asincrono `requestReload:` per test deterministici.

## Concorrenza, ordine e fallimenti

Un actor protegge i chiamanti dello stesso processo; un lock BSD `flock` su un file stabile protegge la transazione di lettura, confronto e sostituzione anche tra processi e istanze diverse. La scrittura JSON è atomica. Nessun lock viene mantenuto durante una richiesta di rete o durante un `await`.

Un candidato deve avere `fetchedAt` più recente e un `requestStartedAt` non precedente allo stato già salvato. Quindi una richiesta vecchia che termina tardi, sia dell’app sia del widget, non seppellisce una risposta a una richiesta iniziata dopo. Timestamp uguali conservano il primo stato. Se l’app pubblica mentre un vecchio fetch widget è sospeso, il widget restituisce il nuovo stato anziché sovrascriverlo.

Una cache con timestamp oltre un minuto nel futuro non partecipa al confronto come uno stato imbattibile: il successivo risultato valido la può sostituire. La stessa tolleranza vale per l’inizio richiesta. Il clock è iniettabile nei test, così il caso di correzione dell’orologio non richiede modificare il computer o altri simulatori. Gli stati con età negativa restano comunque scaduti, mai correnti.

Il widget applica le regole esistenti di `ClosureArchive` su un archivio temporaneo distinto per ogni refresh, inizializzato dallo snapshot condiviso: conserva avvisi già attivi e accetta cancellazioni future solo quando consentito dal provider. L’archivio temporaneo viene rimosso dopo il merge. Non esiste un secondo archivio widget persistente che possa reintrodurre copie vecchie o competere tra processi. Se fallisce la scrittura, non viene richiesto un reload dell’app; una risposta reale riuscita può comunque essere mostrata nella timeline corrente del widget.

## Dati locali, migrazione e cancellazione

La copia condivisa contiene solo avvisi che terminano dopo `fetchedAt`. Lo storico completo dell’app resta nel suo archivio privato, con le impostazioni di durata esistenti. Il widget non condivide posizione, ricerche, preferiti o preferenze; non è stata introdotta alcuna suite UserDefaults App Group.

Alla prima lettura vengono considerate le vecchie copie private `a56_widget_snapshot.json` e `a56_widget_archive.json`. Si importa la più recente, filtrata agli avvisi rilevanti; un vecchio archivio senza qualità verificabile diventa parziale. I due file obsoleti vengono eliminati solo dopo che esiste una copia valida nello store di destinazione. La migrazione non tocca `a56_archive.json` dell’app e non sostituisce uno snapshot condiviso più recente. Nel nuovo contenitore non viene scritto `a56_widget_archive.json`.

Directory e snapshot sono esclusi dal backup. Su iOS lo snapshot usa protezione fino alla prima autenticazione dopo il riavvio, per consentire letture del widget a dispositivo nuovamente bloccato. Prima del primo sblocco il sistema può non rendere disponibile il contenuto.

“Info → Archivio locale → Elimina archivio” continua a eliminare lo storico dell’app, senza eliminare la copia corrente di avvisi attivi/futuri condivisa con il widget. Questa distinzione è ora esplicita in `InfoView`. Disinstallare l’app rimuove i dati locali di app e widget; togliere soltanto l’icona dalla Home non equivale alla disinstallazione. Il prossimo aggiornamento può nuovamente salvare gli avvisi del gestore.

## Verifica

I test usano directory temporanee, provider iniettati e callback di reload osservabile; non accedono ai feed o alle cache dell’utente.

Eseguiti **28 test in due suite**, `WidgetSyncTests` e i precedenti `WidgetSnapshotTests`: tutti riusciti. Copertura significativa:

- pubblicazione app visibile da una nuova istanza, con reload osservato soltanto dopo la scrittura;
- risposta fresca completa o parziale riutilizzata senza seconda rete;
- pubblicazioni vecchie o uguali respinte, incluso fetch app precedente a quello widget e completamento widget precedente a una nuova pubblicazione app;
- 24 writer su istanze distinte senza regressione del timestamp finale;
- offline con dati condivisi, primo avvio senza cache e autonomia della rete widget;
- mantenimento di avvisi attivi e cancellazioni future verificate;
- migrazione e rimozione dei vecchi file, esclusione di avvisi terminati;
- recupero dopo correzione all’indietro dell’orologio, sia da app sia da rete widget;
- errore di disco senza reload e senza nascondere un risultato di rete valido;
- scadenza a cinque minuti e transizioni di timeline già coperte dalla suite precedente.

Comando riproducibile sul simulatore dedicato A56 Widget QA:

```sh
xcodebuild test -project TangenzialeNapoli.xcodeproj -scheme TangenzialeNapoli \
  -destination 'platform=iOS Simulator,id=E2A1AAB5-A37D-4596-A7AC-7E7A228964C8' \
  -derivedDataPath /tmp/a56-widget-sync-build \
  -resultBundlePath /tmp/a56-widget-sync-final-tests.xcresult \
  -parallel-testing-enabled NO \
  -only-testing:A56Tests/WidgetSyncTests -only-testing:A56Tests/WidgetSnapshotTests \
  CODE_SIGNING_ALLOWED=NO
```

Risultati: `/tmp/a56-widget-sync-final-tests.xcresult`, log `/tmp/a56-widget-sync-final-tests.log`. Come ultimo controllo sui sorgenti congelati è passato anche lo script completo `Tests/test-xcode.sh`: controlli standalone macOS (geometria/impatti, resilienza cache/rete e matrice avvisi) e **90 test iOS in 9 suite**, zero fallimenti e zero test saltati. Include la nuova regressione NaN/±infinito della chat centrale. Il riepilogo di xcresult conta 146 esecuzioni considerando i parametri, corrispondenti a 90 test dichiarati.

Comando eseguito: `A56_TEST_OUTPUT=/tmp/a56-widget-sync-full-tests bash Tests/test-xcode.sh`. Log `/tmp/a56-widget-sync-full-tests.log`, risultati `/tmp/a56-widget-sync-full-tests/A56Tests.xcresult`, riepilogo `/tmp/a56-widget-sync-full-tests/summary.json`. Lo script ha creato e poi eliminato il proprio simulatore `A56 Tests` (`76704FD4-7199-4FF9-BEBD-A5110306031F`), senza toccare i simulatori delle altre chat. La prova di callback verifica l’ordine richiesta di reload/scrittura; la consegna effettiva del reload da parte di iOS richiede la verifica runtime separata.

Build finale app/estensione Debug: **BUILD SUCCEEDED**, `/tmp/a56-widget-sync-freeze-build.log`.

Verifica runtime tramite skill device-interaction e harness XCUITest esterno, sul solo simulatore dedicato A56 Widget QA: refresh reale dall’app e lettura Info riusciti. Dopo “Aggiorna dati”, il fallback privato dell’app contiene una nuova risposta alle `2026-11-15T14:54:27.243037Z`, 48 chiusure e qualità completa. Ulteriore prova manuale alle **15:58:00 Europe/Rome**: lo stdout reale dell’app registra `published shared snapshot Optional(2026-11-15 14:58:00 +0000); requesting widget reload`. Il tap manuale è correlato a `requestStartedAt = 2026-11-15T14:58:00.131148Z` e `fetchedAt = 2026-11-15T14:58:00.378787Z`, 48 avvisi completi. Questo conferma l’osservatore di `AppTabView` e il percorso reale verso il callback predefinito di WidgetCenter, oltre al solo test unitario iniettato. Prove `/tmp/a56-widget-sync-device/app-console-unbuffered.log:72`, `/tmp/a56-widget-sync-device/manual-console-proof.json`, `/tmp/a56-widget-sync-device/console-unbuffered.xcresult` (**PASS**).

L’estensione continua a recuperare dati autonomamente. Il testo Info è interamente leggibile; screenshot temporaneo `/tmp/a56-widget-sync-device/info-widget-explanation.png`.

**Limite osservato:** con `CODE_SIGNING_ALLOWED=NO` il simulatore non registra alcun App Group (`matchingAppGroups=[]`). I processi usano quindi il fallback dichiarato e non una cache comune. Questo test prova l’aggiornamento/publisher dell’app e l’autonomia del widget, ma **non** la consegna della stessa risposta tra le due sandbox o l’assenza di refetch nel processo WidgetKit. Tale prova va eseguita dalla centrale con i profili firmati già verificati. Non è stato alterato l’ambiente per simulare un entitlement funzionante, né sono stati usati dati fixture per la prova reale.

Il solo simulatore QA è stato spento al termine delle prove; il simulatore temporaneo dei test completi è stato eliminato dal proprio script.

Marker di consegna: **WIDGET_SYNC_READY**. Nessuna modifica ai sorgenti dopo il freeze e il passaggio della suite completa. Nessun commit, push o upload eseguito.

## Verifica centrale su iPhone firmato, build 8

La centrale ha compilato, installato e avviato la build **1.0 (8)** sull’iPhone fisico. App ed estensione hanno entrambi il gruppo `group.com.giovannimonaco.TangenzialeNapoli` nei rispettivi entitlement firmati e profili di provisioning. Il contenitore App Group è accessibile sul dispositivo.

Alle **16:01:12 Europe/Rome**, il nuovo snapshot condiviso contiene **48 avvisi correnti/futuri**, qualità completa e stato online. Il timestamp corrisponde esattamente a quello del nuovo archivio privato dell’app; il confronto di tutti gli avvisi correnti/futuri per ID e contenuto è identico. L’archivio completo dell’app contiene anche lo storico, che non viene condiviso.

Prima dell’aggiornamento era presente lo snapshot privato dell’estensione, letto alle 15:39. Dopo installazione/avvio e richiesta di reload, la directory Application Support privata del widget è vuota: la migrazione dell’estensione ha rimosso entrambi i file obsoleti. Nel gruppo sono presenti soltanto snapshot e lock. Queste prove completano la verifica della condivisione fra sandbox firmate che il simulatore unsigned non poteva eseguire.

Artefatti locali: `build/device-verification/shared-build8-proof.json`, `shared-build8.json`, `app-build8.json`, `widget-private-files-build8.json` e `group-files-build8.json`. Non contengono dati di posizione o preferiti, soltanto avvisi pubblici e metadati di aggiornamento. Non è attestata una nuova automazione UI sul telefono né misurato il tempo di ridisegno: iOS decide quando consegnare la richiesta WidgetCenter.
