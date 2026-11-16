# TestFlight — versione 1.0 (9)

16 novembre 2026. Sorgenti: commit `30b737bb9329e9705909db9fdcbf610a983c0590`, ramo `review/general-audit`. Il numero build è stato incrementato da 8 a 9 per app ed estensione widget, nelle configurazioni Debug e Release; nessuna modifica funzionale rispetto alla build 8.

## Verifiche

- Controlli standalone e **90 test iOS in 9 suite** passati sul simulatore locale; zero errori o test saltati.
- **4 smoke test UI** passati; zero errori o test saltati.
- [CI del commit di rilascio](https://github.com/giovannimonaco/A56-Tangenziale-Napoli/actions/runs/43885545117) completata con successo per entrambi gli schemi.
- Archivio Release `build/A56Napoli-1.0-9.xcarchive` ed export `build/AppStore-1.0-9/TangenzialeNapoli.ipa` riusciti. App e widget: versione 1.0, build 9, solo iPhone, iOS 18+, firme valide, profili App Store senza entitlement debug, manifest privacy e App Group `group.com.giovannimonaco.TangenzialeNapoli` presenti.
- IPA: **7.308.600 byte**, SHA-256 `6313939373fa1bea4d9a586aba41f5518f1c8b7c03850b23db8336612b16c1bb`.

## Caricamento e distribuzione

Pacchetto ricevuto da Apple alle **15:36 Europe/Rome**, tramite le API ufficiali Build Upload. Il client altool corrente aveva incontrato un timeout; quello legacy un errore locale relativo a `Defaults.properties`. È stata riutilizzata la stessa prenotazione di upload, senza incrementare nuovamente la build.

File upload `8678dc6e-3d83-4998-a4ce-c2fea5bfa1e0`: stato `COMPLETE`, nessun errore o warning. Build upload `5fd06df5-859b-4cb1-b543-6609ccef2ade`: stato `COMPLETE`, nessun errore o warning. La build elaborata ha lo stesso identificativo e stato `VALID`.

Su richiesta dell'utente, la build è stata assegnata ai gruppi TestFlight esistenti **Personal** ed **External**. L'appartenenza è stata riletta da entrambi i gruppi. Stato esterno finale: **`IN_BETA_TESTING`**. [Link TestFlight del gruppo External](https://testflight.apple.com/join/UuQkHCRt).

Sono state aggiunte la localizzazione TestFlight italiana (descrizione già presente nel progetto, recapito di assistenza e privacy URL) e le note su cosa provare. È stata eseguita la submission beta richiesta da Apple, riletta con stato **`APPROVED`**; la build è disponibile per il test esterno. La versione App Store resta `PREPARE_FOR_SUBMISSION`: nessuna pubblicazione o revisione App Store è stata inviata.

Log, risultati XCTest, hash e risposte di verifica sono conservati in `build/testflight-9/` e `.build/test-results/`, ignorati da Git. Le prove precedenti su telefono e i limiti di compatibilità/accessibilità restano documentati nel [report di preparazione](readiness.md).
