# Handoff UI al designer

**READY — handoff completato il 15 novembre 2026.** InfoView, correzioni di accessibilità, audit e catture sono completati. Da questo marker l’autore dell’audit non effettuerà ulteriori modifiche ai file UI. Il designer può iniziare la finitura nel perimetro assegnato dalla chat centrale.

## Stato consegnato

- Info include istruzioni per aggiungere «Chiusure A56» dalla galleria Home, scaricamento autonomo, frequenza decisa da iOS e controllo dell’ora dei dati.
- Privacy include copia separata degli avvisi del widget, nessuna posizione/ricerca/preferito nel widget e distinzione dalla cancellazione dell’archivio dell’app.
- Assistenza riservata tramite `AppLinks.contact`; segnalazioni GitHub esplicitamente pubbliche.
- Ultima compilazione UI verificata: app + widget 1.0 (7), con Info finale; log `/tmp/a56-ui-verify-info-final.log`.
- Nessun commit, push o upload da questo incarico. Le altre modifiche attualmente nel checkout appartengono ai rispettivi proprietari: non ripristinarle.

## Simulatori da riutilizzare

Entrambi esistono già e sono **spenti**, verificato al momento dell’handoff. Non occorre creare nuove VM. Nessun simulatore Orya/Audiva è stato usato o modificato.

| Nome | Modello | Dimensioni | UDID |
| --- | --- | --- | --- |
| A56 UI Small | iPhone SE, terza generazione | 375×667 pt; 750×1334 px | `225AC0D1-FDA0-4760-90E3-001B9720628C` |
| A56 UI Large | iPhone 18 Pro Max | 440×956 pt; 1320×2868 px | `C3144A48-E9E9-430C-8FAD-34CCC0CE3A6D` |

Runtime: `com.apple.CoreSimulator.SimRuntime.iOS-27-2`, iOS 27.2; Xcode 27.2. Appearance ripristinata a light, testo large predefinito, Aumenta contrasto disattivato, override della status bar rimossi. Permesso posizione del SE ripristinato.

Avvio del simulatore piccolo:

```sh
xcrun simctl boot 225AC0D1-FDA0-4760-90E3-001B9720628C
```

L’app è già installata; dopo modifiche serve ricompilare e reinstallare. DerivedData dell’audit: `/tmp/a56-ui-verify`; prima baseline: `/tmp/a56-ui-build`. Evitare di scrivere nei percorsi di build della chat centrale.

## Verifica disponibile

DeviceInteraction non è esposto. Il fallback già funzionante è simctl + harness XCUITest esterno `/tmp/a56-ui-harness/A56UI.xcodeproj`, schema `A56UI`, DerivedData `/tmp/a56-ui-harness/build`. Il codice temporaneo è `Audit.swift`; report dettagliato `/tmp/a56-ui-verification.md`. Nel repository la centrale ha aggiunto separatamente lo schema permanente `A56UI`: non confonderlo con quello temporaneo e non modificarne il progetto senza assegnazione.

Launch argument utili già supportati:

- `--sample-data`: avvisi dimostrativi.
- `--stale-sample-data`: ultimi avvisi salvati, non aggiornati.
- `--unavailable-data`: nessun avviso disponibile.
- `--show-closures`: apre Chiusure.
- `--map-focus-exit=8`: zoom sullo svincolo per verifica mirata.
- Italiano nell’harness: `-AppleLanguages (it) -AppleLocale it_IT`.

Per AX5 è stato usato `xcrun simctl ui <UDID> content_size accessibility-extra-extra-extra-large`; per ripristinare usare `large`. Chiaro/scuro con `xcrun simctl ui <UDID> appearance light` oppure `dark`.

## Comportamenti da preservare durante la finitura

- Alle dimensioni accessibili il pannello direzione di Home **scorre con il contenuto**: prima copriva quasi tutto il SE e rendeva le programmate illeggibili.
- Lo schema A56 aumenta la larghezza minima quando crescono i nodi e scorre orizzontalmente. L’allineamento `.topLeading` del rail e il padding verticale evitano spostamento dei nodi e ombre tagliate. La sintesi VoiceOver riassume stato e direzione.
- Titolo/orario delle schede archivio, confronto percorsi, intestazione preferiti e identità/versione in Info si dispongono verticalmente ad AX5. Il testo non è limitato artificialmente.
- Solo i simboli decorativi degli estremi e dello scambio in Percorsi hanno un limite superiore alla scala: altrimenti uscivano dai frame e toccavano il testo.
- Mantenere bersagli di almeno 44 pt nei comandi e nei link corretti, tratti selezionati e intestazioni accessibili. L’icona decorativa checkmark non deve tornare a essere annunciata come «Selezionato».
- Ricerca luoghi e sottotitolo dei filtri usano colori di testo semantici espliciti; la `.secondary` gerarchica dentro un Button produceva una tinta troppo pallida. Il badge gravità ha testo primario e conserva la tinta su simbolo/sfondo.
- I colori A56Unknown e A56Caution sono stati corretti anche per il lavaggio della superficie al 16%. Contrasto minimo misurato 4,66:1 per Unknown e 4,91:1 per Caution; tabella completa nell’audit. Non ripristinare i precedenti valori per una semplice preferenza estetica.
- Stati cache/indisponibile e avvisi da verificare devono restare distinti da «nessuna chiusura segnalata»; non usare solo il colore come indicatore.
- Reduce Motion e Reduce Transparency sono già considerati nei componenti condivisi; mantenere tale comportamento. Aumenta contrasto è stato esercitato sul SE.

## Evidenze e sorgenti Store

- Report stabile: [`ui-ux-audit.md`](ui-ux-audit.md), con difetti, matrice, comandi e limiti.
- Evidenze UI: [`screenshots/ui-audit/`](screenshots/ui-audit/). Alcune conservano passaggi intermedi; il report indica i confronti utili.
- Cinque sorgenti finali native 1320×2868: [`screenshots/app-store-source/`](screenshots/app-store-source/), acquisite 14:44–14:45. [`manifest.json`](screenshots/app-store-source/manifest.json) registra SHA-256, timestamp e provenienza.
- I file `fixture-*` contengono avvisi dimostrativi. Il confronto percorso combina un itinerario MapKit reale con avvisi dimostrativi: non presentarlo come viabilità live.
- Ora 09:41 cosmetica nella status bar; gli orari dei dati sono quelli reali della sessione. Dopo una finitura visiva, le sorgenti interessate vanno ricatturate e il manifest aggiornato prima di riutilizzarle come immagini finali.

## Coordinamento e limiti

AppTabView e WidgetKit restano alla centrale salvo nuova assegnazione. Lo specialista percorsi possiede matcher/TripPlanner/geometria e, se necessario, le sole funzioni `interchanges`/`interchange` di TripView per i nuovi casi Access; riferimento [`route-boundary-fix.md`](route-boundary-fix.md). Coordinare eventuali interventi concorrenti su TripView.

La prova Via Campana con due direzioni A56 è coerente con le istruzioni grezze di MapKit: uscita, inversione e rientro verso Capodichino. Dump stabile [`ui-route-mapkit-evidence.json`](ui-route-mapkit-evidence.json), copia operativa `/tmp/a56-route-evidence.json`. Questo non sostituisce l’indagine separata sugli estremi della Tangenziale.

Verificati SE/Pro Max, chiaro/scuro, AX5, stati sample/cache/indisponibili, posizione negata, ricerca, scambio estremi, preferiti e percorsi reali. Info finale AX5: 0 errori; catture Store finali: 0 errori. Nessuna sessione vocale VoiceOver su telefono, nessuna verifica GPS fisica, nessun runtime iOS 18 disponibile nell’audit. Il report distingue questi limiti dalle prove concluse.
