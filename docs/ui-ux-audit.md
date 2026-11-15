# Audit UI/UX iPhone A56 Napoli

Audit completato — 15 novembre 2026, ore 14:45 italiane. App 1.0 (7), compilazione app + widget riuscita. Nessun blocco UI residuo nei flussi eseguiti. Proprietà: Views/ (escluso AppTabView.swift dal nuovo incarico della chat centrale), Utilities/Palette.swift, risorse colore. Nessuna modifica a progetto, Tests, Data, ViewModels o manifest.

## Coordinamento verifica

Skill applicate: swiftui-specialist e device-interaction. La seconda ha richiesto verifica dedicata; eseguita da agente di verifica separato tramite fallback XCUITest.

- DeviceInteraction non è esposto nell’ambiente; fallback simctl + harness XCUITest temporaneo esterno al repository.
- Simulatori dedicati creati: A56 UI Small (iPhone SE 3, 375×667 pt), UUID 225AC0D1-FDA0-4760-90E3-001B9720628C; A56 UI Large (iPhone 18 Pro Max), UUID C3144A48-E9E9-430C-8FAD-34CCC0CE3A6D. Runtime iOS 27.2.
- DerivedData UI separata: /tmp/a56-ui-build. Non usare o spegnere simulatori Orya/Audiva.
- Baseline build Debug simulatore completata.

## Difetti corretti e verificati

1. **Chiusure, Dynamic Type AX5, iPhone SE:** il pannello direzione fisso assorbiva quasi tutta l’area utile; il contenuto era confinato sotto la tab bar. Alle dimensioni accessibili il pannello è ora il primo elemento del contenuto scorrevole. Baseline: `screenshots/ui-audit/before-se-closures-ax5.png`.
2. **Schema A56:** i nodi scalati con Dynamic Type avevano una distanza fissa derivata dalla larghezza disponibile e potevano sovrapporsi. Lo schema ha ora una larghezza minima proporzionata ai nodi e scorre orizzontalmente quando necessario; la sintesi VoiceOver rimane disponibile.
3. **Archivio:** rimosso il limite di una riga sul titolo e disposto orario sotto titolo alle dimensioni accessibili.
4. **Mappa:** bersagli dei filtri Adesso/Programmate, prossima chiusura e attribuzione portati ad almeno 44 pt; nome svincolo senza limite di due righe alle dimensioni accessibili.
5. **Percorsi:** intestazione Preferiti e righe confronto adattate verticalmente alle dimensioni accessibili; azioni dell’assenza dati disposte verticalmente alle stesse dimensioni.
6. **VoiceOver:** l’icona decorativa checkmark era esposta come «Selezionato». Nascosta; aggiunti tratti intestazione alle sezioni chiusure/dettaglio; corretta sintesi singolare «1 limitazione».

7. **Bersagli dei dettagli:** link delle righe tratto chiuso, impatti del percorso e fonte gestore ampliati a 44 pt nel contenuto effettivo del controllo.

8. **Simboli Percorsi AX5:** i simboli decorativi di partenza/destinazione e scambio crescevano oltre i rispettivi frame; scala limitata solo sui simboli, mantenendo il testo completamente adattivo. Sottotitoli dei filtri mappa e dei risultati di ricerca con colore secondario semantico esplicito per evitare tinta attenuata ereditata dai pulsanti. La cattura ricerca precedente evidenziava sottotitoli azzurri poco contrastati; ora i risultati usano testo primario/secondario di sistema.

9. **Badge gravità:** etichetta con testo primario esplicito; simbolo e sfondo mantengono la tinta di gravità. Il testo non eredita più il grigio attenuato o il colore su una seconda superficie tinta.

10. **Info, widget e privacy:** istruzioni per aggiungere «Chiusure A56», scaricamento autonomo e aggiornamento deciso da iOS con ora dei dati; cache widget separata, nessun accesso a posizione/ricerche/preferiti e cancellazione distinta dall’archivio app. Email riservata tramite AppLinks.contact e indicazione esplicita delle segnalazioni GitHub pubbliche. Identità/versione dell’app disposte verticalmente con testo accessibile.

## Palette

La superficie con lavaggio di accento al 16% faceva scendere il contrasto di A56Unknown sotto 4,5:1 (3,94 chiaro / 4,47 scuro). A56Caution chiaro poteva scendere a 4,46:1. Scelti valori più scuri in chiaro e più luminosi in scuro nelle sole risorse A56Unknown e A56Caution.

Contrasto sRGB calcolato sui valori delle risorse (rapporto WCAG):

| Colore | Superficie chiara | Superficie scura | Lavaggio 16% chiaro | Lavaggio 16% scuro |
| --- | ---: | ---: | ---: | ---: |
| AccentColor/aperto | 6,75:1 | 9,49:1 | 5,27:1 | 6,68:1 |
| A56Issue/chiusura | 6,63:1 | 7,14:1 | 5,07:1 | 5,40:1 |
| A56Caution/avviso | 6,22:1 | 9,54:1 | 4,91:1 | 6,72:1 |
| A56Unknown/non confermato | 5,80:1 | 6,49:1 | 4,66:1 | 4,91:1 |

Tutti superano 4,5:1 anche al lavaggio massimo. I valori non pretendono di certificare ogni pixel della cartografia o del materiale di sistema. Stato espresso anche con testo, simboli e/o tratto selezionato, non solo colore.

## Verifica funzionale e visiva

Harness XCUITest autonomo in `/tmp/a56-ui-harness`, prodotto da ruby xcodeproj e separato dal progetto applicativo; compilazione app in `/tmp/a56-ui-verify`. Le gerarchie sono lette prima delle interazioni e le schermate acquisite dopo. Il test usa selettori accessibili; coordinate derivate dal frame dell’elemento per i disclosure che il runtime classifica diversamente.

Passaggi completati:

- **iPhone SE, AX5:** flusso chiusure → programmate → espansione → Corso Malta → dettaglio, mappa → filtri → programmate, Percorsi/preferiti: 1 test, 0 errori (121 s).
- **iPhone Pro Max, AX5:** medesimo flusso: 1 test, 0 errori (59 s).
- **iPhone Pro Max, testo normale:** chiusure/dettaglio/fonte, Info/privacy/archivio, mappa Adesso/Programmate/svincolo, Percorsi/ricerca/preferiti; ricerca e itinerario reale MapKit: 2 test, 0 errori (181 s). Partenza Piazza Garibaldi Napoli, destinazione Via Campana Pozzuoli; scambio estremi verificato. MapKit ha proposto una soluzione A56 e nessuna alternativa senza A56; l’app lo dichiara senza inventare alternative.
- Le prime esecuzioni dell’harness si sono fermate per query di automazione (DisclosureTriangle esposto anche come Button, pulsante Indietro della navigazione sottostante a una sheet, elemento dietro il pannello fisso). Corrette le query e rieseguiti i flussi: non si trattava di errori applicativi.

Le catture `ui-audit/*route*` usano itinerari Apple MapKit reali, con **avvisi chiusure dimostrativi** del launch argument `--sample-data`. Nessun dato campione viene spacciato per feed live. Le catture dei casi stale e unavailable sono state ottenute rispettivamente con `--stale-sample-data` e `--unavailable-data`.

### Matrice finale

| Dispositivo / profilo | Copertura | Esito |
| --- | --- | --- |
| SE, chiaro e testo normale | Chiusure, dettagli, Info/privacy/archivio, mappa, ricerca | Verificati tramite catture e interazioni |
| SE, AX5 | Programmate raggiungibili, dettaglio, filtri, preferiti | PASS, 0 errori |
| SE, scuro + AX5 | Percorso MapKit reale e selezione riga | PASS, 0 errori |
| SE, scuro + AX5 + Aumenta contrasto | Percorsi/mappa, Info/privacy/archivio finali | PASS, 0 errori |
| SE, stati dati e posizione negata | Cache/indisponibili, azioni recupero, indirizzo manuale | PASS, 2 test, 0 errori |
| Pro Max, testo normale | Navigazione completa, ricerca, scambio estremi, preferito aggiunto e rimosso | PASS, 0 errori |
| Pro Max, AX5 | Chiusure/dettaglio/filtri/preferiti e percorso reale | PASS, 0 errori |
| Pro Max, scuro e stati dati | Mappa/chiusure/percorsi, cache/indisponibili | PASS, 0 errori |
| Pro Max, fonti Store finali | Cinque scene dopo ultime correzioni e Info aggiornata | PASS, 60,76 s, 0 errori |

Ultimo test Info AX5 sul SE: 65,85 s, 0 errori. Ultimo gruppo Pro Max scuro/stati/AX5 percorso/MapKit grezzo: 4 test, 117,36 s, 0 errori. Log compilazione finale: `/tmp/a56-ui-verify-info-final.log`; risultati e gerarchie in `/tmp/a56-ui-harness/`. Il report esteso temporaneo è `/tmp/a56-ui-verification.md`.

Esempio di comando effettivo del fallback:

```sh
xcodebuild -project /tmp/a56-ui-harness/A56UI.xcodeproj -scheme A56UI \
  -destination 'platform=iOS Simulator,id=225AC0D1-FDA0-4760-90E3-001B9720628C' \
  -derivedDataPath /tmp/a56-ui-harness/build \
  -only-testing:A56UI/Audit/testAccessibilityFlow \
  CODE_SIGNING_ALLOWED=NO test-without-building
```

L’harness è temporaneo, non aggiunge test o target al repository. I test permanenti sono gestiti dalla chat proprietaria del progetto.

### Evidenze selezionate

- [Prima della correzione, pannello fisso SE AX5](screenshots/ui-audit/before-se-closures-ax5.png) → [programmate raggiungibili dopo la correzione](screenshots/ui-audit/se-ax5-closures-scheduled.png).
- [SE scuro](screenshots/ui-audit/se-dark-closures.png), [Pro Max scuro](screenshots/ui-audit/max-dark-closures.png).
- [Avvisi salvati](screenshots/ui-audit/max-stale-map.png), [avvisi indisponibili](screenshots/ui-audit/max-unavailable-closures-actions.png), [posizione negata e alternativa manuale](screenshots/ui-audit/se-location-denied.png).
- [Percorso reale a testo massimo](screenshots/ui-audit/se-ax5-route-row.png), [Info finale AX5](screenshots/ui-audit/se-ax5-info.png), [privacy AX5](screenshots/ui-audit/se-ax5-privacy-scrolled.png).

Le catture di audit conservano i passaggi della verifica; le sorgenti Store sotto sono quelle finali aggiornate al termine del lavoro.

### Sorgenti native Store

Cinque PNG originali **1320×2868**, italiano, chiaro, testo normale. Catture finali tra le 14:44:28 e le 14:45:04 del 15 novembre 2026, app 1.0 (7). Nessun artwork, commit, push o upload. [Manifest con SHA-256 e provenienza](screenshots/app-store-source/manifest.json) e [note d’uso](screenshots/app-store-source/README.md).

1. [Mappa Programmate](screenshots/app-store-source/fixture-map.png).
2. [Elenco programmate](screenshots/app-store-source/fixture-programmate.png).
3. [Dettaglio rampa](screenshots/app-store-source/fixture-dettaglio-rampa.png).
4. [Confronto percorso](screenshots/app-store-source/fixture-avvisi-mapkit-percorso.png).
5. [Informativa privacy aggiornata](screenshots/app-store-source/info-privacy.png).

I quattro file con prefisso `fixture-` usano avvisi dimostrativi. Il confronto usa un itinerario reale MapKit con avvisi dimostrativi: **non è una schermata di viabilità live**. Lo status 09:41 è un override cosmetico; gli orari dei dati nell’app riflettono l’ora reale di acquisizione. Le mappe sono caricate e mantengono le attribuzioni.

### Limiti della verifica

- Nessun dispositivo fisico; i due simulatori utilizzano il solo runtime disponibile iOS 27.2. Il deployment minimo iOS 18 non è stato eseguito su runtime 18.
- Accessibilità verificata visivamente con AX5 e tramite etichette, tratti e struttura della gerarchia. Non eseguita una sessione umana di ascolto VoiceOver né verifica GPS fisico.
- Ricerche e calcolo percorsi dipendono da MapKit; tempi, distanza e disponibilità alternativa sono risultati del servizio al momento della prova.
- `LinearMapView` risulta senza call site nel prodotto; non è stata presentata come schermata di produzione verificata.

### Verifica dei due sensi A56 nel percorso Via Campana

**Non è un secondo tratto inventato dal matcher.** Un’interrogazione indipendente direttamente a MapKit, senza usare il matcher dell’app, ha confermato il rientro verso Capodichino per la destinazione selezionata. Evidenza: [`ui-route-mapkit-evidence.json`](ui-route-mapkit-evidence.json), acquisita il 15 novembre 2026 alle 14:43 italiane.

- Partenza scelta: Piazza Garibaldi, Piazza Giuseppe Garibaldi 98–112, Napoli, coordinate `40.8520277, 14.2701213`.
- Destinazione scelta dalla ricerca «Via Campana Pozzuoli»: Via Campana, coordinate `40.8388283318, 14.1170460565`, sul segmento A56 presso lo svincolo.
- Le istruzioni grezze mostrano uscita verso Pozzuoli/Via Campana, inversione alla rotonda per 592 m, seconda uscita verso Tangenziale A56 per 462 m e arrivo dopo altri 609 m.
- Il tratto finale della polilinea va da longitudine circa `14.112` a `14.117`, quindi verso Capodichino. La posizione finale coincide con la destinazione entro pochi metri.
- Tutte le sei alternative della risposta grezza, comprese quelle con preferenza evita autostrade/pedaggi, includono questo finale. La nuova interrogazione può variare tempi e alternative rispetto alla cattura precedente; l’andamento finale rimane coerente.

La schermata rappresenta quindi il percorso effettivamente proposto per quel risultato di ricerca. Nessuna modifica a `A56TripMatcher` o ai modelli è stata effettuata.

Impostazioni dei simulatori ripristinate e i soli due simulatori A56 UI spenti al termine. Gli interventi successivi dello specialista sui confini dei percorsi sono fuori da questa verifica e richiedono i suoi test; non ho modificato matcher, TripPlanner o geometria.
