# Privacy: evidenze per la release 1.0

Verifica del 15 novembre 2026, aggiornata dopo la sincronizzazione widget. Revisione del checkout e dei manifest; non equivale a una cattura completa del traffico. App e widget condividono sul dispositivo gli avvisi correnti/futuri tramite file App Group; il widget mantiene richieste autonome e non usa la posizione. Prove e limiti sono nel [report di sincronizzazione](../widget-sync-fix.md).

## Flussi riscontrati

| Dato / operazione | Destinatario e conservazione riscontrata | Evidenza nel checkout |
| --- | --- | --- |
| Posizione facoltativa | Core Location, poi servizi Apple per indirizzo e percorso; in memoria nell’app. Nessuna richiesta Always o localizzazione continua trovata. | `ViewModels/TripPlanner.swift`: `requestWhenInUseAuthorization`, `requestLocation`, accuratezza richiesta 10 m; indirizzo con `MKReverseGeocodingRequest` da iOS 26, `CLGeocoder` su iOS precedenti. |
| Ricerca luoghi | Apple: frammenti di query, ricerca, area geografica dei suggerimenti. | `TripPlaceSuggestions.swift`: `MKLocalSearchCompleter`; `TripView.swift`: `MKLocalSearch`. |
| Percorso | Apple: partenza, destinazione, preferenze del percorso automobilistico. Nessun archivio di itinerari implementato. | `TripPlanner.swift`: `MKDirections`. |
| Destinazioni preferite | Nome, sottotitolo/indirizzo, latitudine, longitudine e UUID, solo in `@AppStorage("tripFavoriteDestinations")`. Cancellazione dalla lista preferiti. | `TripFavorite.swift`, `TripView.swift`. |
| Preferenze | Direzione, ultima scheda e durata archivio, in UserDefaults dell’app. | `AppTabView.swift`, `InfoView.swift`, `ClosureArchive.swift`. |
| Avvisi | GET dirette ad Autostrade; nessun invio esplicito di posizione, query o preferiti. Il server riceve IP e metadati HTTP. Sessione effimera, cookie disabilitati, URLCache disabilitata. | `LiveClosureProvider.swift`, due URL costanti e nessun identificatore utente inserito nella richiesta. |
| Archivio | JSON in Application Support; avvisi strutturati, aggiornamento e migrazioni. Predefinito 10 giorni dalla fine, selezionabili 1–60. Pruning durante operazioni archivio; nessun timer autonomo di eliminazione. | `ClosureArchive.swift`: `a56_archive.json`, `retention`, `prune`, `clear`. |
| Backup | Application Support e UserDefaults possono rientrare nei backup iOS. Non è implementata una sincronizzazione propria. | Nessuna esclusione esplicita dal backup trovata per questi dati. |
| Diagnostica propria | `AppLog` scrive nella console solo con `DEBUG`; nessun SDK analytics/ads/crash reporting trovato. | `Utilities/AppLog.swift`; progetto senza dipendenze SPM esterne riscontrate nella revisione iniziale. |
| Widget | File App Group condivisi con l'app per gli avvisi correnti/futuri; nessuna posizione, ricerca o preferito condiviso. Rete autonoma quando lo snapshot manca o è scaduto, refresh richiesto circa 30 minuti e deciso da iOS. | `A56Widget/A56Widget.swift`, `Data/WidgetSnapshot.swift`, `AppTabView.swift`: pubblicazione dopo caricamento riuscito, reload richiesto, scrittura atomica con lock tra processi. Nessuna suite UserDefaults App Group. |
| Assistenza esterna | Apertura di GitHub nel browser; eventuale segnalazione pubblica fornita volontariamente dall’utente. | `AppLinks.support`; nessun invio automatico dall’app. |

## Risposte App Privacy proposte

**Raccolta da parte dello sviluppatore: nessuna riscontrata. Tracciamento: no.** La selezione finale in App Store Connect resta da completare e rileggere sulla build finale.

La [guida Apple App Privacy](https://developer.apple.com/app-store/app-privacy-details/) distingue trasmissione per servire una richiesta da conservazione ulteriore e precisa, nel caso MapKit, che non si devono dichiarare i dati raccolti da Apple. Preferiti e preferenze solo sul dispositivo non costituiscono raccolta per questa etichetta. La posizione opzionale non rende da sola dichiarabile o esente un dato: conta il flusso effettivo.

Per i feed, i metadati di connessione sono esposti al fornitore; non è stata verificata una policy specifica sulla retention dei log di `viabilita.autostrade.it`. L’[informativa generale Autostrade](https://www.autostrade.it/it/privacy/sito-web) è un riferimento pubblico, non una prova sul trattamento di questo endpoint. Non attribuire al fornitore l’assenza di conservazione. Confermare il rapporto con il fornitore e rivalutare l’etichetta se vengono aggiunti backend, identificatori, SDK o ulteriori dati nelle richieste.

## Manifest

`PrivacyInfo.xcprivacy`: `NSPrivacyTracking = false`, domini di tracciamento e tipi raccolti vuoti; UserDefaults con `CA92.1`. Le preferenze lette/scritte sono dell’app stessa: corrispondono alla [ragione Apple CA92.1](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype). Non sono stati trovati usi diretti delle altre categorie required reason (timestamp file, spazio disco, uptime, tastiere attive). `Date()` e `FileManager` per creare/eliminare file non dimostrano da soli l’uso di quelle API coperte.

Apple richiede il manifest anche nel bundle di ciascun eseguibile che usa API coperte: [documentazione](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api). App e widget includono il manifest. `CA92.1` resta coerente con gli accessi UserDefaults, che riguardano solo preferenze del rispettivo processo: i dati condivisi sono file, non una suite UserDefaults App Group. La presenza di un App Group non implica da sola l'uso dell'API UserDefaults condivisa. Il controllo va mantenuto sul binario finale.

## Controlli prima di chiudere l’audit

- [ ] Primo avvio senza richiesta di posizione; percorso manuale funzionante con permesso negato.
- [ ] Selezione posizione/preferito: consenso contestuale, revoca e posizione approssimativa gestite; nessuna raccolta in background.
- [ ] Osservare il traffico della build finale, includendo suggerimenti, reverse geocoding, feed e widget; non usare endpoint di intercettazione esterni per dati personali.
- [ ] Preferiti rimossi dopo chiusura e riavvio; cancellazione archivio distinta dai preferiti e dalla cache widget.
- [ ] Sincronizzazione App Group su dispositivo firmato e conservazione degli avvisi correnti verificate sulla build finale; assenza di posizione nel widget e manifest già controllati.
- [ ] Policy web pubblicata e leggibile senza login, coerente con testo in **Info → Informativa privacy**, incluso il widget.
- [ ] Canale privato per richieste riservate definito e verificato; oggi il solo canale accertato è pubblico.
