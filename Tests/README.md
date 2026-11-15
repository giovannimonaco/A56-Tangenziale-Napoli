# Test A56 Napoli

## Esecuzione completa

```sh
bash Tests/test-xcode.sh
```

Richiede Xcode e un runtime iOS Simulator compatibile con iPhone. Lo script esegue prima i controlli shell su macOS, poi crea un simulatore dedicato **A56 Tests**, esegue `xcodebuild test` e lo elimina anche in caso di errore. Non usa simulatori già esistenti. Il target unit test è **A56Tests**, nello schema condiviso **TangenzialeNapoli**.

Gli artefatti sono conservati in `.build/test-results/<esecuzione>/`: `A56Tests.xcresult`, `xcodebuild.log`, `summary.json` e DerivedData. È possibile impostare `A56_TEST_OUTPUT` a una directory nuova per scegliere un'altra destinazione. `A56_SIMULATOR_RUNTIME` e `A56_SIMULATOR_DEVICE_TYPE` accettano identificatori `simctl` per scegliere runtime e iPhone compatibili.

Per un simulatore dedicato già creato:

```sh
xcodebuild test \
  -project TangenzialeNapoli.xcodeproj \
  -scheme TangenzialeNapoli \
  -destination 'platform=iOS Simulator,id=UUID_DEL_SIMULATORE' \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO
```

## Suite

- `UnitTests/MappingTests.swift`: decodifica feed, località ambigue, direzioni, finestre ricorrenti, date e copertura incompleta.
- `UnitTests/TimeAndFreshnessTests.swift`: fuso di Napoli, cambio ora legale, scadenza e aggiornamento in foreground, estremi degli intervalli.
- `UnitTests/ArchiveAndFallbackTests.swift`: persistenza, migrazione, dati corrotti, retention, cancellazioni verificate, offline e preferiti.
- `UnitTests/FeedValidationTests.swift`: HTTP e pubblicazioni non attendibili, feed parziali o illeggibili; risposte locali mediante `URLProtocol`.
- `UnitTests/WidgetSnapshotTests.swift`: stato, scadenza, direzioni, timeline limitata, cache e aggiornamento del widget indipendente dall'app.

Ogni test usa directory temporanee proprie. Nessun test dipende dalla disponibilità dei feed pubblici. Il processo test usa `TZ=Pacific/Honolulu` nello schema per verificare che le etichette restino ancorate a Napoli. Solo la suite retention modifica la preferenza dedicata e ripristina il valore precedente.

## Controlli shell

```sh
bash Tests/check-a56.sh
```

I controlli originali rimangono disponibili anche senza avviare iOS Simulator e coprono inoltre geometria del percorso e impatti sulle rampe. Due percorsi a snapshot JSON possono essere passati come argomenti per un audit dei feed salvati; non vengono scaricati automaticamente.

## Smoke test UI separati

La chat centrale mantiene il target XCTest UI `A56UITests`, in `Tests/UITests/A56UITests.swift`, nello schema condiviso **A56UI**. Copre tab e ricerca manuale senza posizione, stato indisponibile, avvertenza persistente della cache e deep link del widget. Lo schema unit e lo script CI qui descritti restano separati da questa suite.

Per eseguirla su un simulatore dedicato già creato, usare il comando Xcode sopra sostituendo `-scheme TangenzialeNapoli` con `-scheme A56UI`. Su dispositivo fisico è necessaria una configurazione di firma valida; l'esecuzione su iPhone e il suo esito sono gestiti e documentati dalla chat centrale.

La CI è configurata in `.github/workflows/tests.yml`. Gli esiti realmente eseguiti e i limiti della verifica locale sono in `docs/testing-report.md`.
