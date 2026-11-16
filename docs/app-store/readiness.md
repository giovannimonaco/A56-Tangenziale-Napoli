# A56 Napoli — stato della preparazione App Store

Aggiornamento: **16 novembre 2026**. App solo iPhone, iOS 18+, versione **1.0 (9)**, bundle `com.giovannimonaco.TangenzialeNapoli`. La build 9 è stata caricata, elaborata e distribuita su richiesta ai gruppi TestFlight **Personal** ed **External**, stato **`IN_BETA_TESTING`**. [Report del rilascio e verifiche](testflight-9.md). La versione App Store resta `PREPARE_FOR_SUBMISSION`; le evidenze della preparazione precedente e i punti per la pubblicazione Store sono riportati sotto.

## Completato e verificato

| Area | Risultato |
| --- | --- |
| Feed attuali | Audit live di produzione **48/48**, entrambe le fonti disponibili, nessuna riga irrisolta o errore topologico. Corretto il collasso dei nomi del tratto orientale. [Diagnosi e regressioni](../feed-completeness-fix.md). |
| Percorsi | Svincolli, punti già sulla carreggiata e collegamenti distinti. Geometria OSM del raccordo A1 separata dalla classificazione A56; chiusure fisiche valutate anche sui viaggi solo A1. **90 test passati localmente e in CI remota**, zero failure/saltati. [Report](../route-boundary-fix.md). |
| UI/UX | Correzioni su iPhone piccolo/grande, chiaro/scuro, testo Accessibilità massimo, bersagli, contrasti e marker. Finitura senza barre decorative. [Audit](../ui-ux-audit.md), [finitura](../visual-design-review.md), [regole visive](../../DESIGN.md). |
| Widget | Small/medium, rete autonoma e scadenza verificati. Ora cache App Group condivisa e reload dopo refresh reale dell’app, protezione da risposte fuori ordine e migrazione. Condivisione firmata verificata su iPhone: 48 avvisi identici a quelli dell’app. [Prove iniziali](../widget-verification.md), [sincronizzazione finale](../widget-sync-fix.md). |
| Archivio ed export | Archivio Release e IPA locale **1.0 (8)** riusciti e verificati. App ed estensione: firma valida, profili App Store, niente entitlement debug, App Group comune, iPhone `[1]`, minimo 18.0, privacy manifest presenti. `build/A56Napoli-1.0-8.xcarchive`, `build/AppStore-1.0-8/TangenzialeNapoli.ipa` (7.308.575 byte). |
| iPhone fisico | Build 8 installata e avviata. Fetch alle 16:01:12 Europe/Rome: **48 avvisi correnti/futuri**, completi, identici nello snapshot App Group e nell’archivio privato. Vecchie cache widget migrate e rimosse. Non equivale a una verifica visiva del telefono. |
| Privacy e supporto online | Policy e pagina assistenza pubblicate nel ramo collegato; confronto anonimo byte per byte con i file locali riuscito. Recapito riutilizzato su autorizzazione dell'utente. [Policy](https://github.com/giovannimonaco/A56-Tangenziale-Napoli/blob/review/general-audit/docs/privacy.md), [supporto](https://github.com/giovannimonaco/A56-Tangenziale-Napoli/blob/review/general-audit/docs/app-store/support.md). |
| Bozza App Store Connect | App **6782002695**, versione 1.0 in `PREPARE_FOR_SUBMISSION`, nome **A56 Napoli**, lingua principale **it**, categoria **Navigation**, rilascio **manuale**. Testi, URL e note review aggiornate confrontati con i materiali locali. Referente privato App Review riutilizzato dal record Audiva dopo verifica di nome ed email. |
| Questionario età | Compilato sulle funzioni effettive; risposte rilette via API, risultato Apple **4+**. [Risposte](age-rating.json). Non è una dichiarazione di app progettata per bambini. |
| Screenshot | **8 immagini** italiane nei formati 1320×2868 e 1206×2622, caricate e collocate nella bozza. Catture native, avvisi dimostrativi dichiarati. [Anteprima](../../AppStore/Preview-it.png), [manifest locale](../../AppStore/ScreenshotManifest.json), [identificativi caricati](../../AppStore/UploadManifest.json). |
| Strumenti | Swift Testing, schema UI separato, simulatori isolati, CI, audit live esplicito e Fastlane per test/archivio/export/metadati. Nessuna dipendenza di terze parti inclusa nell'app iOS. |

La lettura completa dei dati non elimina le divergenze pubblicate dal gestore: per sette occorrenze la fine generale/testuale è 06:00 e quella giornaliera 06:59. L'app conserva la fascia più ampia e indica il conflitto sulla singola chiusura, senza trasformarlo in un errore globale.

## Verifiche finali

La mappa rappresenta il percorso fisico completo e le schede mostrano i nomi degli estremi pubblicati. Nessuna alternativa che attraversi un collegamento chiuso viene raccomandata come libera, anche con uso A56 incerto o assente. Sono passate tre prove UI mirate, una prova aggiuntiva della categoria senza A56 e i quattro smoke test permanenti. Dopo la sincronizzazione widget sono passati **90 test iOS in 9 suite**, più i controlli standalone. Anche la riesecuzione dei **4 smoke test UI sulla build 8** è passata, zero errori o test saltati. [Report integrazione](../final-integration-ui.md).

La prima CI remota ha passato la UI e trovato una differenza di Foundation nella gestione di NaN rispetto all’SDK locale. La conversione delle date ora rifiuta esplicitamente NaN e infinito; la regressione è inclusa nei 90 test passati. La nuova [CI remota](https://github.com/giovannimonaco/A56-Tangenziale-Napoli/actions/runs/43727730056) sul commit sorgenti `f3422b8` è **completamente verde**: 90 test (146 esecuzioni parametrizzate) e 4 test UI, zero errori/saltati, Xcode 26.6 e simulatore iOS 26.5. Questo conferma la correzione su entrambi gli SDK.

## Cosa rimane per distribuire

1. **Condizioni di riuso dei dati:** non è stata acquisita un'autorizzazione né identificata una licenza applicabile. Non è neppure stato dimostrato un divieto specifico. Il disclaimer non documenta il permesso che Apple può richiedere. [Valutazione con fonti](publication-assessment.md), [richiesta pronta e non inviata](feed-permission-request.txt). Nessun contatto a terzi effettuato.
2. **Dichiarazioni finali App Privacy e Content Rights:** completare sulla fonte effettivamente concordata e senza attestare diritti non documentati. Il manifest descrive le pratiche dell'app, non sostituisce le risposte Store. [Audit privacy](privacy-audit.md).
3. **Prezzo, territori e conformità account/DSA:** non sono stati scelti o dichiarati automaticamente sulla base delle altre app; vanno allineati al modello di distribuzione e alle condizioni della fonte.
4. **TestFlight completato; selezione per App Store separata:** build **1.0 (9)** caricata ed elaborata senza errori o warning, stato `VALID`, assegnata a Personal ed External con stato esterno `IN_BETA_TESTING`. La selezione della build per la versione App Store e la revisione per la pubblicazione non sono state eseguite. [Report](testflight-9.md).
5. **Limiti delle prove:** test locali su simulatore iOS 27.2 e remoti su iOS 26.5; non eseguito runtime iOS 18. Due tentativi UI sul telefono si sono fermati prima dei test, durante l'abilitazione dell'automazione. Restano verifica su iOS 18, ridisegno del widget su telefono e ascolto umano VoiceOver; non dichiarare certificazioni globali di accessibilità.

## Materiali

[Testi italiani](metadata.md) · [note review](review-notes.txt) · [requisiti Apple consultati](apple-requirements.md) · [fonti e diritti](rights-and-sources.md) · [privacy locale](../privacy.md) · [procedure Fastlane](../../fastlane/README.md).
