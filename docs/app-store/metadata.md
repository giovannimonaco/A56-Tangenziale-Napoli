# Metadati 1.0 — italiano

Testi pronti in [`metadata/it/`](metadata/it/); **bozza per la release con widget, da usare solo dopo la verifica finale di tale funzione**. La presenza del testo non certifica un test, un upload né l’accettazione Apple. I blocchi sono in [readiness.md](readiness.md).

| Campo | Valore / decisione |
| --- | --- |
| Nome | A56 Napoli |
| Sottotitolo | Chiusure della Tangenziale |
| Lingua principale proposta | Italiano (`it`); remoto attuale `en-US` con contenuti vuoti e nessuna localizzazione italiana (`build/asc-draft-detail.json`). La lane metadati può aggiungere l’italiano, ma non cambia automaticamente la lingua principale. Non promettere un’interfaccia inglese per il solo README tradotto. |
| Categoria proposta | Navigation; seconda Utilities se appropriata alla scheda finale. Nessuna categoria impostata da questa verifica. |
| Copyright proposto | `2026 Giovanni Monaco` per il codice proprio; non è una rivendicazione di proprietà dei dati terzi. |
| Versioni e build | Progetto 1.0 (7), bundle `com.giovannimonaco.TangenzialeNapoli`; archivio/IPA iniziali verificati 1.0 (1). Su ASC esistono già build 1–6 VALID: rigenerare archivio/export 7 prima di un nuovo upload. |
| Dispositivi | iPhone, iOS 18 o successivo nel progetto iniziale; non promettere iPad, CarPlay, Apple Watch o navigazione vocale. |
| Prezzo / disponibilità | Da decidere dal titolare; non impostati. “Senza pubblicità” è riscontrato nel codice; non equivale a una decisione sul prezzo. |
| Privacy URL attuale app | [Policy nel ramo pubblico](https://github.com/giovannimonaco/A56-Tangenziale-Napoli/blob/review/general-audit/docs/privacy.md), HTTP 200 e contenuto verificato, ma versione precedente senza widget. Pubblicare la policy locale aggiornata prima di usarla in ASC. Il futuro percorso `main/docs/privacy.md` è oggi 404. |
| Supporto | [Issue del progetto](https://github.com/giovannimonaco/A56-Tangenziale-Napoli/issues), HTTP 200. Email riusata con consenso del titolare e inserita in [support.md](support.md) e policy locali; pagine aggiornate ancora da pubblicare e verificare. |
| Marketing URL | Facoltativo; nessun sito A56 dedicato verificato. Il repository pubblico è raggiungibile. |
| Novità | Non necessarie per la prima versione; non preparare note che fingano un aggiornamento già distribuito. |

## Limiti e qualità

Verifica locale documentata in `metadata-validation.json`: nome e sottotitolo ≤30 caratteri, promo ≤170, descrizione ≤4000, keyword ≤100 byte UTF-8. Le keyword non ripetono nome/sottotitolo né includono marchi concorrenti. Sono scelte editoriali, senza misura di volume o conversione. Riferimenti: [pagina prodotto](https://developer.apple.com/app-store/product-page/), [campi versione e limite keyword](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/).

## Note review e diritti

Copia pronta: [review-notes.txt](review-notes.txt). Non inviarla prima di aver provato i percorsi descritti nella build finale. Aggiungere come allegato l’evidenza applicabile dei diritti sui feed; non scrivere che l’autorizzazione esiste finché manca. Nessun account demo da inventare. Nome, email e telefono App Review devono essere verificati dal titolare e inseriti nel pannello privato, senza copiarli nel repository.

## Screenshot da produrre

Usare la build finale e l’interfaccia italiana: 1) mappa e direzione, 2) programmazione e orari, 3) dettaglio rampe, 4) confronto percorso, 5) preferiti, 6) widget con ora dei dati. Evitare indirizzi personali, dati simulati presentati come traffico live, mappe prive di attribuzioni e promesse di aggiornamento continuo.

Dalla [tabella Apple consultata](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/): preparare il set iPhone Dynamic Island grande a **1320 × 2868**; il set medio **1206 × 2622** è aggiuntivo e non sostituisce il grande. Non usare le immagini ridotte del README. La tabella attuale introduce screenshot iPhone Duo obbligatori dall’aprile 2027 per build con SDK iOS 27.1 o successivi: ricontrollare alla data dell’invio. Nessun set iPad richiesto per il perimetro solo iPhone.

Header prodotto e immagine per risultati di ricerca sono asset distinti e non sostituiscono gli screenshot. Prepararli solo se effettivamente richiesti dalla scheda; nessun asset caricato in questo incarico.

## Fastlane predisposto

Comandi e limiti in [fastlane/README.md](../../fastlane/README.md). `fastlane ios metadata_check` verifica questi cinque file e le note senza rete; esito PASS. `fastlane ios metadata` è una lane di **scrittura dei soli testi italiani e note review** sulla bozza 1.0 esistente, non eseguita qui; la chat centrale la userà nel passaggio autorizzato dopo QA. Non include privacy/support URL non ancora pubblicati, categorie, screenshot, binari, selezione build o review. Le credenziali provengono esclusivamente dall’ambiente e non sono state copiate.
