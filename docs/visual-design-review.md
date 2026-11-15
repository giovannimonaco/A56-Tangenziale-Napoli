# Finitura visiva A56 Napoli

15 novembre 2026. Ambito: componenti, HomeView, OverviewMapView, Palette/colori e finitura TripView (esclusi interchanges/interchange riservati alla correzione percorsi). Scope esteso dalla centrale alle sole icone decorative di ClosureDetailView. Nessun commit, push o upload.

## Analisi prima dell'intervento

Esaminate le catture di `screenshots/ui-audit`, le sorgenti native in `screenshots/app-store-source` e `../AppStore/Preview-it.png`. La base nativa è solida e i precedenti interventi su Dynamic Type e bersagli da 44 pt vanno preservati. Il problema estetico è la mancanza di una gerarchia dei trattamenti: lavaggi rossi/verdi, bordi colorati, ombre e angoli generosi ricorrono su elementi con importanza diversa. Lo schema A56 sembra una collana di badge luminosi; il pannello mappa contiene più superfici arrotondate concorrenti; le giornate future hanno la stessa intensità cromatica di uno stato attuale.

## Direzione scelta

Un taccuino di viaggio autostradale italiano, preciso e quieto. Avorio freddo in chiaro e grafite in scuro; verde petrolio A56 come firma, rosso e ambra solo per limitazioni e cautela. Sistema SF con pesi e spaziature intenzionali, cifre orarie allineate. Nessuna illustrazione o decorazione fine a sé stessa.

- Superfici neutre, bordi neutri sottili. Eliminati gradienti e ombre decorative delle schede. Nessuna barra laterale, bordo colorato o microaccento decorativo.
- Selettore direzione con selezione distinta tramite superficie neutra e testo, mantenendo stato dati e testo completo accessibile. Anche il controllo Adesso/Programmate usa superficie selezionata neutra, senza sottolineature decorative.
- Schema stradale più tecnico: linea netta, nodi senza glow, differenza tra nodi normali e interessati da chiusura; larghezza minima scalata e scorrimento AX conservati.
- Stato attuale più autorevole; giornate programmate bianche/grafite, rosso concentrato su numero limitazioni e simboli. Ritmo verticale più deciso tra sezioni.
- Mappa con controlli ordinati e pannello di contesto meno pesante, senza perdere Adesso/Programmate, freschezza o attribuzioni.
- Percorsi con la stessa grammatica delle superfici e un'azione primaria riconoscibile, nessun intervento sul matching o sulle indicazioni degli svincoli.

## Implementazione conclusa

**COMPLETATO — 15 novembre 2026, 15:21 Europe/Rome.** Handoff esclusivo rispettato. Nessun ulteriore edit UI in corso da questa chat. La centrale può integrare i nuovi helper geometrici delle chiusure in OverviewMapView e rigenerare l’artwork dalle sorgenti finali.

File modificati da questo incarico: `Utilities/Palette.swift`, `Views/Components/DirectionSwitch.swift`, `Views/Components/A56SchematicView.swift`, `Views/HomeView.swift`, `Views/OverviewMapView.swift`, `Views/TripView.swift`; dopo estensione esplicita dello scope, soli simboli decorativi in `Views/ClosureDetailView.swift`. Nessuna modifica di questa chat a Data, Models, ViewModels, AppTabView, InfoView, progetto, test permanenti o widget. Le modifiche concorrenti degli altri proprietari sono preservate. Nessun commit, push, archivio o upload.

La preferenza esplicita dell’utente contro le barre decorative è recepita nella versione finale: nessuna barra laterale, bordo accento o microaccento sostitutivo sulle schede. Anche i controlli selezionati usano bordi/superfici neutri. Il parametro `accent` di `a56Surface` rimane compatibile con i call site esistenti ma non disegna decorazioni sulla superficie. Le linee colorate di mappa e schema rappresentano la strada e le chiusure.

## Prima / dopo

| Elemento | Prima | Dopo verificato |
| --- | --- | --- |
| Chiusure | Lavaggio verde/rosso, glow dei nodi, stessa intensità delle schede attuali/future | Superfici neutre, testata A56 contenuta, titolo a piena larghezza, giornate scandite dal testo; solo i nodi interessati sono pieni in rosso |
| Schema | Nodi pieni con ombre diffuse | Nodi contornati nitidi, stato critico pieno; rail e scorrimento AX conservati |
| Mappa | Controlli con ombre colorate e selezioni molto arrotondate | Raggi coerenti, ombre neutre, selezione per superficie, timestamp/attribuzione preservati |
| Percorsi | Azione primaria resa come riga della List | Vero pulsante nativo, singola freccia, stato disabilitato riconoscibile e navigazione verificata |
| AX5 | Simboli Home/dettaglio oltre i frame; selezione marker8 poteva attivare7; tray compresso | Cap sui soli simboli, `Annotation.anchor` corretto con area48×48, tray scorrevole con nome/stato completi |

Confronti: [Chiusure prima](screenshots/ui-audit/max-light-closures.png) → [Chiusure dopo](screenshots/app-store-source/fixture-programmate.png); [Mappa prima](screenshots/ui-audit/max-light-map-scheduled.png) → [Mappa dopo](screenshots/app-store-source/fixture-map.png); [Percorsi prima](screenshots/ui-audit/se-light-trips.png) → [Percorsi dopo](screenshots/visual-design/se-neutral-light-trips.png). [Scuro finale](screenshots/visual-design/max-neutral-dark-closures.png).

## Verifiche effettive

Applicata `swiftui-specialist` (struttura, modificatori, localizzazione, environment e identità). `swiftui-design` e `apple-hig` locali sono voci catalogo, non workflow completi; nessun workflow inesistente dichiarato. Applicata `device-interaction` con verificatore separato sul solo SE, come richiesto dalla skill. Tool DeviceInteraction/DeviceEvent assenti: fallback XCUITest + simctl, gerarchie lette prima delle interazioni, screenshot letti a piena risoluzione dopo.

- A56 UI Small: SE3, `225AC0D1-FDA0-4760-90E3-001B9720628C`, 375×667 pt, 750×1334 px.
- A56 UI Large: iPhone 18 Pro Max, `C3144A48-E9E9-430C-8FAD-34CCC0CE3A6D`, 440×956 pt, 1320×2868 px.
- Harness temporanei esterni al repository: `/tmp/a56-design-harness` e `/tmp/a56-design-se-harness`; nessun target/test aggiunto al progetto.

| Prova | Esito |
| --- | --- |
| Build Debug finale app + widget dal progetto normale del checkout | SUCCEEDED, `/tmp/a56-design-build-final-integration.log` |
| Pro Max, flusso completo normale e AX5 durante il ciclo | PASS, rispettivamente 94,98 s e 83,31 s; chiusure/dettagli, Info/privacy/archivio, filtri, Percorsi/ricerca/preferiti |
| SE, versione neutra finale, AX5 scuro + Aumenta contrasto + Reduce Motion | PASS 99,92 s; Home/disclosure → dettaglio/alternative → Percorsi/CTA → mappa/filtri/Programmate |
| SE, versione neutra, chiaro normale | PASS 12,99 s; Home/disclosure/Percorsi, CTA ≥44 pt |
| Pro Max, neutro scuro normale + cache/indisponibile | PASS 2 test, 34,58 s, 0 errori |
| Pro Max, fonti Store + simboli AX5 neutri | PASS 2 test, 82,37 s, 0 errori; entrambe le ricerche MapKit e arrivo al confronto richiedono assert, nessun ritorno silenzioso |
| SE, correzione finale anchor, scuro/AX5/contrasto/Reduce Motion | PASS 18,36 s, 0 errori; **primo tap su Camaldoli apre esattamente Uscita 8**, nome/stato completi scorrendo, ritorno e chiusura da 44 pt |
| Pro Max, ricattura mappa dopo anchor + tap esatto Camaldoli 8 + chiusura + Percorsi | PASS 29,17 s, 0 errori |
| Diff dei file assegnati | `git diff --check` PASS |

Le ultime modifiche sono state ricontrollate con prove mirate. Le prove iniziali avevano rilevato doppia freccia CTA, simboli AX fuori contenitore e attivazione errata del marker: corrette e rieseguite; non sono state nascoste dietro assert generici. Il tentativo di spostare il solo label SwiftUI non bastava: la correzione verificata usa l’anchor nativo MapKit. Il frame accessibile è passato da 19×24 a 48×48 pt. Le posizioni dei connettori e dei marker rimangono coerenti con la strada.

La dipendenza widget mancante introdotta nell’integrazione concorrente è stata risolta dalla centrale; l’ultima app e tutte le verifiche finali dell’anchor provengono dal **progetto normale del checkout**. Nessuna app da copia temporanea è stata utilizzata.

Palette di stato e relativi valori di contrasto già verificati nell’[audit UI](ui-ux-audit.md) preservati; i lavaggi delle schede sono rimossi. Testi/stati di cautela, cache e indisponibilità restano distinti da “nessuna chiusura segnalata”. Nessuna nuova animazione decorativa; Reduce Motion verificato anche con l’assert del flag UIAccessibility effettivo. Nessun limite alla scala dei testi introdotto.

## Evidenze finali e sorgenti Store

Per la mappa AX finale usare solo `screenshots/visual-design/se-neutral-final-map-anchor-*`: [tray superiore](screenshots/visual-design/se-neutral-final-map-anchor-tray-top.png), [stato completo dopo scroll](screenshots/visual-design/se-neutral-final-map-anchor-tray-bottom.png), [tray chiuso](screenshots/visual-design/se-neutral-final-map-anchor-tray-closed.png). Le catture senza `anchor` conservano passaggi intermedi e non attestano l’ultima correzione. Le 84 catture della prima iterazione non neutra sono fuori dalla consegna, in `/tmp/a56-design-intermediate-screenshots`.

Altre prove finali: [Home SE](screenshots/visual-design/se-neutral-light-closures.png), [dettaglio AX5](screenshots/visual-design/se-neutral-ax5-dark-detail.png), [alternative AX5](screenshots/visual-design/se-neutral-ax5-dark-alternatives.png), [Percorsi AX5](screenshots/visual-design/se-neutral-ax5-dark-trip-action.png). Report indipendente SE: `/tmp/a56-design-verification-se.md`; gerarchie/log/xcresult nei rispettivi harness.

Quattro fonti native Store **1320×2868** ricatturate e lette, senza artwork o ritocchi, italiano/chiaro/testo normale/status 09:41:

1. [Mappa Programmate](screenshots/app-store-source/fixture-map.png), ultima ricattura 15:20 dopo anchor.
2. [Programmate](screenshots/app-store-source/fixture-programmate.png), 15:12.
3. [Dettaglio rampa](screenshots/app-store-source/fixture-dettaglio-rampa.png), 15:12.
4. [Confronto percorso](screenshots/app-store-source/fixture-avvisi-mapkit-percorso.png), 15:13.

[Manifest](screenshots/app-store-source/manifest.json) con dimensioni/SHA-256/provenienza aggiornati. `info-privacy.png` conserva la cattura originale 14:44, contenuto invariato. I quattro `fixture-*` usano **avvisi dimostrativi**, non feed live. Il confronto combina un itinerario reale MapKit con questi avvisi; l’assenza di alternativa viene dichiarata senza inventarla. Timestamp dati effettivi, 09:41 soltanto cosmetico. La centrale deve rigenerare l’artwork: la precedente `AppStore/Preview-it.png` è superata.

## Limiti e riconsegna

Solo simulatori iOS 27.2; nessun telefono fisico o runtime iOS 18. Nessun ascolto umano VoiceOver né certificazione di accessibilità globale. L’assert del marker dimostra il caso Camaldoli 8 nei profili provati, non ogni svincolo/zoom possibile. Le mappe dipendono dal servizio Apple. Stato del feed reale, nuovi helper dei segmenti fisici, test unitari finali, Release/archivio/pubblicazione restano coordinati dalla centrale.

Nessun difetto residuo nei flussi UI eseguiti. Simulatori A56 Small e Large riconsegnati spenti, aspetto light/testo large/contrasto disattivato; preferenze Motion e override status ripristinati. Nessun simulatore Orya/Audiva usato o modificato.
