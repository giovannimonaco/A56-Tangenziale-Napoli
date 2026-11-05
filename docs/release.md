# Preparazione della 1.0

Questa procedura riguarda A56 Napoli (`com.giovannimonaco.TangenzialeNapoli`), app iPhone con requisito minimo iOS 18. Non caricare la build in App Store Connect finché non sono risolte le condizioni qui sotto.

## Fonte degli avvisi

- Conservare l’autorizzazione o le condizioni che consentono accesso, trasformazione, visualizzazione e conservazione locale degli avvisi A56 in un’app distribuita pubblicamente. I due endpoint del sito Autostrade non sono una API pubblica documentata. Il codice mostra dati strutturati e rimanda al gestore per il comunicato completo. Questo riduce la riproduzione del testo, ma non sostituisce il permesso richiesto dalla [regola Apple 5.2.2](https://developer.apple.com/app-store/review/guidelines/).
- Se il gestore non autorizza gli endpoint, verificare il [Punto di Accesso Nazionale del CCISS](https://www.cciss.it/web/cciss/-/bozza). La documentazione del NAP descrive l’accesso per il riutilizzo; occorre identificare uno specifico dataset A56 con condizioni, accesso e copertura adeguati. Il bollettino RSS nazionale da solo non va considerato un quadro completo delle rampe e delle chiusure programmate.
- Bozza di richiesta da inviare al [gestore](https://www.tangenzialedinapoli.it/contatti-e-customer-care) e al [fornitore del feed](https://www.autostrade.it/it/web/autostrade/contatti):

  > Buongiorno, sto sviluppando A56 Napoli, un’app iPhone indipendente che aiuta a verificare le chiusure della Tangenziale prima di partire. Vorrei usare i dati A56 dei feed `previsioni.json` ed `eventi.json` per mostrare orari, tratti e rampe interessate e conservare sul dispositivo uno storico con durata configurabile. L’app indica la provenienza dei dati, rimanda ai vostri avvisi e non si presenta come servizio ufficiale. Potete confermare per iscritto se l’accesso e il riutilizzo sono consentiti per la distribuzione tramite App Store, oppure indicare un feed e le condizioni applicabili? Mi sarebbe utile sapere anche quale attribuzione e quale frequenza di aggiornamento richiedete.

## Verifica tecnica

- Eseguire `Tests/check-a56.sh`, anche con `TZ=America/New_York`. Per provare i due feed in uso, passare i file JSON di un aggiornamento recente come argomenti (prima la programmazione, poi il tempo reale).
- Provare su iPhone fisico, incluso un dispositivo con iOS 18: primo avvio con e senza rete, riavvio con archivio, ritorno in primo piano, avviso automatico per i dati scaduti, VoiceOver, dimensioni testo Accessibilità, ricerca indirizzi, autorizzazione alla posizione negata e permesso revocato. Provare un percorso lungo la A56 e uno su viabilità parallela, anche senza alternativa proposta da Mappe.
- In Xcode, creare un archivio Release; verificare `PrivacyInfo.xcprivacy`, `NSLocationWhenInUseUsageDescription` e la presenza dell’icona. Eseguire **Validate App** nell’Organizer con la firma di distribuzione del team. Apple documenta la [creazione del profilo App Store Connect](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile). L’archiviazione con firma Apple Development non verifica l’export App Store.

## App Store Connect

- Pubblicare l’[informativa](privacy.md) nel percorso collegato dall’app, aprire il link senza autenticazione e usare lo stesso URL in App Store Connect. Aggiungere un contatto privato verificato per richieste sulla privacy e confermare il canale di assistenza.
- Compilare App Privacy sulla base dei flussi effettivi. Il manifest descrive le API e le pratiche proprie dell’app; non basta per rispondere per i servizi esterni. Verificare in particolare Mappe, termini di ricerca, estremi del percorso e posizione facoltativa rispetto alla [definizione Apple di raccolta](https://developer.apple.com/app-store/app-privacy-details/).
- Impostare italiano come lingua principale, completare il questionario per età e dichiarare lo [status DSA](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/) per l’Italia. Usare schermate della build finale, ad esempio 1206 × 2622 per iPhone 18 Pro; non usare le immagini ridotte del README. Dichiarare le funzionalità di accessibilità dopo averle provate.

**Nome:** A56 Napoli

**Sottotitolo:** Chiusure della Tangenziale

**Descrizione:** Consulta prima di partire gli avvisi di chiusura della A56 Tangenziale di Napoli. Guarda sulla mappa i tratti e gli svincoli interessati, esplora la programmazione per direzione e confronta i percorsi in auto proposti da Mappe di Apple. Gli orari sono quelli di Napoli. L’app indica quando gli avvisi non sono aggiornati o sono incompleti. A56 Napoli è un progetto indipendente: verifica le informazioni sui canali del gestore e non usare l’app mentre guidi.

**Note per App Review:** Non è richiesto un account. Aprire **Mappa → Programmate** oppure **Chiusure** per vedere gli avvisi disponibili per ciascuna direzione. In **Percorsi** si possono inserire partenza e destinazione senza concedere la posizione. La posizione viene chiesta quando si seleziona **Usa la mia posizione** o si avvia un percorso da dove ci si trova verso una destinazione preferita. Quando non ci sono chiusure in corso, l’app mostra la programmazione disponibile; i dati non verificabili sono indicati come tali. Allegare la documentazione che autorizza la fonte effettiva della build.
