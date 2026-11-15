# A56 Napoli — verifica test e configurazione Xcode

Data: 15 novembre 2026. Ambiente locale: Xcode 27.2 (`27B52`), macOS 27.0.1, iOS Simulator 27.2 (`24B8117`), iPhone 18 Pro.

## Modifiche di questa chat

- Aggiunto target iOS unit test `A56Tests` con Swift Testing e dipendenza dall'app, usando `@testable import TangenzialeNapoli`.
- Aggiunto schema condiviso `TangenzialeNapoli`, con test abilitati, raccolta test senza cloni paralleli e processo test in `Pacific/Honolulu` per verificare l'indipendenza dal fuso del dispositivo.
- Nessuna modifica ai sorgenti di produzione in `Views/`, `Data/`, `ViewModels/` o `Models/`.
- Aggiunti test in `Tests/UnitTests/`, istruzioni in `Tests/README.md`, script `Tests/test-xcode.sh` e workflow `.github/workflows/tests.yml`.
- Lo script esegue anche i controlli shell originali, crea un nuovo iPhone compatibile chiamato `A56 Tests` e rimuove esclusivamente quel simulatore al termine. Restituisce l'errore di `xcodebuild` e conserva log e `.xcresult`.
- La proprietà di `project.pbxproj` è stata restituita alla chat centrale mediante `docs/testing-project-ready.md`; la chat centrale ha poi integrato `A56WidgetExtension`. I test successivi includono l'app con l'estensione incorporata.

## Copertura funzionale

| Ambito | Casi verificati |
| --- | --- |
| Mapping | Alias e ambiguità, estremi nei due sensi, conflitti tra codice e testo o identificatore e luogo, entrambe le direzioni, accesso solo entrata Italia ’90, ricorrenze parziali, intervalli scaduti, autostrade estranee, timestamp in secondi o non finiti, fine live non pubblicata, identificatori stabili, righe JSON illeggibili |
| Orari e scadenza | Fuso Europe/Rome in inverno/estate, entrambi i cambi ora legale, date impossibili, ore 24:00, notte attraverso il cambio ora, confine esatto di 300 secondi, orologio spostato indietro, refresh in foreground, inclusione dell'inizio ed esclusione della fine |
| HTTP | Feed assenti singolarmente o insieme, 206, Content-Range anche con 200, pubblicazione vecchia o futura, Last-Modified assente, JSON invalido, schema rinominato, array vuoto, copertura vuota A56 verificata con altre autostrade leggibili; tutte risposte locali con URLProtocol |
| Archivio | Persistenza attraverso nuova istanza actor, cancellazione idempotente, file mancante/corrotto e recupero, migrazione schema 1→3 applicata una sola volta, rimozione testo legacy, retention limitata a 1–60 giorni e inclusione del confine, omissioni verificate e non verificate, deduplicazione osservazioni |
| Fallback e preferiti | Primo avvio offline, ripristino ultima cache con data corretta, errore dopo un caricamento riuscito, cancellazione storico, round trip Codable dei preferiti con identità e coordinate |
| Widget | Stato completo/parziale/scaduto/offline/indisponibile, scadenza esatta e rollback orologio, riepilogo per direzione e chiusure comuni, prossima chiusura con parità deterministica, timeline ordinata e deduplicata con orizzonte e limite, conservazione della scadenza con feed molto denso, cache indipendente e provider iniettato, file corrotto e primo avvio offline |

I controlli shell esistenti aggiungono regressioni sulla geometria, sugli accessi numerati e sugli impatti di strada/rampe durante un viaggio; sono rimasti invariati.

## Comandi ed esiti reali

1. `bash Tests/check-a56.sh` — **PASS**, tutte e tre le matrici originali: routing, resilienza feed/cache, avvisi.
2. `plutil -lint TangenzialeNapoli.xcodeproj/project.pbxproj` — **PASS** dopo l'aggiunta del target.
3. `xcodebuild -list -project TangenzialeNapoli.xcodeproj` — **PASS**, target `A56Tests` e schema condiviso rilevati.
4. Prima esecuzione `xcodebuild test` sul simulatore dedicato `B0D76B31-50ED-4CB9-97B4-218046879E98`, DerivedData `/tmp/A56Tests-DerivedData`, risultato `/tmp/A56Tests-first.xcresult` — **TEST SUCCEEDED**, 31 test Swift Testing, 0 errori, 0 saltati. Log `/tmp/A56Tests-first.log`.
5. `A56_TEST_OUTPUT=/tmp/A56Tests-CI bash Tests/test-xcode.sh` — **PASS** locale dello stesso script configurato per CI. Controlli shell eseguiti in Honolulu; app ed estensione widget compilate; **39 test**, 0 errori, 0 saltati. Simulatore esclusivo `F08AA6CA-28B0-4186-9324-DA3B43E8E24B` creato e poi eliminato automaticamente. Artefatti: `/tmp/A56Tests-CI/A56Tests.xcresult`, `/tmp/A56Tests-CI/xcodebuild.log`, `/tmp/A56Tests-CI/summary.json`.

6. Primo tentativo della verifica finale con code coverage (`/tmp/A56Tests-final.xcresult`) — compilazione test interrotta per l'espansione di `#expect` su `allSatisfy` con key path. Corretto il solo test usando una closure esplicita; nessun errore nei sorgenti di produzione.
7. Verifica finale completa, con i tre casi aggiunti dopo l'esecuzione CI — **TEST SUCCEEDED**, **42 test dichiarati / 76 esecuzioni comprendendo i parametri**, **6 suite**, **0 errori, 0 saltati, 0 expected failure**. App ed estensione incorporate compilano. Comando realmente eseguito:

   ```sh
   xcodebuild test \
     -project TangenzialeNapoli.xcodeproj \
     -scheme TangenzialeNapoli \
     -destination 'platform=iOS Simulator,id=B0D76B31-50ED-4CB9-97B4-218046879E98' \
     -derivedDataPath /tmp/A56Tests-CI/DerivedData \
     -resultBundlePath /tmp/A56Tests-verified.xcresult \
     -enableCodeCoverage YES \
     -parallel-testing-enabled NO \
     CODE_SIGNING_ALLOWED=NO
   ```

   Log: `/tmp/A56Tests-verified.log`. Riepilogo estratto con `xcrun xcresulttool get test-results summary --path /tmp/A56Tests-verified.xcresult`: `/tmp/A56Tests-verified-summary.json`. Copertura estratta con `xcrun xccov view --report --json /tmp/A56Tests-verified.xcresult`: `/tmp/A56Tests-coverage.json`.
8. Validazione finale dello schema condiviso XML, sintassi di entrambi gli script con `bash -n`, parsing YAML del workflow con Ruby, `plutil -lint` del progetto dopo integrazione widget e `git diff --check` — **PASS**.

Il simulatore iniziale `B0D76B31-50ED-4CB9-97B4-218046879E98` è stato eliminato al termine della verifica. Gli artefatti locali in `/tmp` sono temporanei; lo script consente di rigenerarli.

## Copertura misurata

Valori di line coverage estratti dall'ultima esecuzione Xcode; non includono i controlli shell, che compilano un eseguibile separato.

| File di produzione | Linee eseguite |
| --- | --- |
| AutostradeClosureMapper.swift | 90,7% — 341/376 |
| AutostradeRealtimeClosureMapper.swift | 80,9% — 161/199 |
| AutostradeEvent.swift | 93,0% — 40/43 |
| LiveClosureProvider.swift | 89,0% — 202/227 |
| ClosureArchive.swift | 78,1% — 203/260 |
| ClosuresViewModel.swift | 73,8% — 276/374 |
| WidgetSnapshot.swift | 88,7% — 94/106 |
| TripFavorite.swift | 100% — 24/24 |

La copertura dell'intero target app è 28,9%, poiché le view e i flussi MapKit interattivi non sono oggetto di questi unit test. I file condivisi con l'estensione possono apparire anche sotto quel target nel report Xcode: questi numeri non attestano una sessione UI di WidgetKit.

## Bug e limiti

- La chat centrale ha identificato e corretto un difetto in `WidgetSnapshot.timelineDates`: oltre 48 transizioni precedenti alla scadenza potevano escludere l'entry di scadenza, lasciando sullo schermo un'indicazione di freschezza non più valida se il sistema rinviava il refresh. Aggiunto il caso `Dense transitions cannot displace the freshness expiry entry`, con 70 chiusure concentrate prima dei 300 secondi: **PASS** nella verifica finale. Il fix di produzione appartiene alla chat centrale.
- Nessun altro difetto di produzione è emerso dalle esecuzioni completate; non sono state nascoste failure con skip o expected failure.
- GitHub Actions è configurato ma non è stato eseguito sul servizio remoto: il suo script è stato eseguito localmente con esito positivo.
- Le esecuzioni riportate qui verificano la logica e la compilazione dell'app con estensione. La chat centrale ha successivamente aggiunto il target persistente XCTest UI `A56UITests`, nello schema separato `A56UI`, con quattro smoke test: tab e ricerca manuale senza posizione, indisponibilità senza conferma di strada libera, avvertenza cache persistente e deep link del widget. L'esecuzione su iPhone fisico è gestita dalla chat centrale, con risultato previsto in `build/A56UI-Device.xcresult`; al momento di questo aggiornamento non ne viene attestato l'esito. La presentazione di WidgetKit in SpringBoard resta una verifica distinta.
- In questo host è installato il solo runtime iOS 27.2. Le esecuzioni unit di questa chat non coprono il minimo iOS 18 né iPhone fisico; firma, archive di distribuzione, upload e revisione App Store non rientrano in questa verifica. La verifica UI fisica della chat centrale deve essere consultata nel relativo report.
- Nessun simulatore Orya/Audiva è stato avviato, arrestato, riconfigurato o usato per test. Nessun commit, push o upload effettuato.

**Stato finale:** lavoro test/configurazione completato; nessun blocco aperto per la suite. Il progetto resta disponibile alla chat centrale.
