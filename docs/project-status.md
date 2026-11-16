# Centro di lavoro A56 Napoli

Aggiornato il 16 novembre 2026. L'utente comunica nella sola chat centrale; assegnazioni, dipendenze e risultati delle chat specializzate sono gestiti dalla centrale.

## Vincoli confermati

- Solo iPhone, iOS 18 o successivo. Nome prodotto A56 Napoli.
- Qualità estetica, semplicità e affidabilità sono requisiti del prodotto.
- Nessuna barra decorativa colorata sui bordi delle schede. Le linee che rappresentano la strada hanno una funzione informativa distinta.
- Widget utili anche senza aprire l'app, con rete autonoma e data del controllo. La frequenza effettiva dipende da iOS.
- Riutilizzare il recapito già adottato per Audiva e Orya per assistenza e privacy.
- Nessuna autorizzazione ai feed già acquisita. Chiarire termini e riuso prima della distribuzione.

## Risultati verificati

- **TestFlight 1.0 (9)** caricato, elaborato e distribuito ai gruppi Personal ed External su richiesta dell’utente. Stato `VALID` / `IN_BETA_TESTING`; 90 test iOS e 4 test UI locali passati, CI remota verde. [Report](app-store/testflight-9.md).

- Corrette completezza feed **48/48**, classificazione ingressi/uscite e geometria dei collegamenti. La UI indica i capi fisici e impedisce raccomandazioni di alternative attraversate da chiusure. [Feed](feed-completeness-fix.md), [percorsi](route-boundary-fix.md), [integrazione UI](final-integration-ui.md).
- **90 test iOS in 9 suite** e controlli standalone passati. Quattro smoke test UI e prove mirate passati; anche la riesecuzione finale dei quattro smoke test sulla build 8 è passata. Due tentativi di UI automation sul telefono si sono fermati prima dei test durante l’abilitazione del servizio.
- Widget autonomi, small/medium, cache/offline e scadenza. Ora sincronizzazione App Group e richiesta di reload dopo ogni refresh riuscito dell’app: **48 avvisi identici su iPhone firmato**, cache private obsolete rimosse. [Report finale](widget-sync-fix.md).
- UI iPhone piccolo/grande, chiaro/scuro, testo Accessibilità massimo e bersagli verificati, finitura senza barre decorative. [Audit](ui-ux-audit.md), [finitura](visual-design-review.md).
- Build **1.0 (8)** installata e avviata sul telefono, archivio Release ed export IPA 8 verificati con profili App Store. App ed estensione iPhone e iOS 18+, entrambi abilitati al medesimo App Group.
- Bozza App Store `6782002695`, 1.0 `PREPARE_FOR_SUBMISSION`, nome A56 Napoli, lingua it, Navigation, rilascio manuale, questionario età 4+. Otto screenshot finali caricati e collocati nella bozza. [Anteprima](../AppStore/Preview-it.png).
- Policy e assistenza pubblicate nel ramo collegato; nuova policy per la condivisione widget pubblicata e confrontata senza login con il file locale. La build 9 è disponibile su TestFlight; nessuna revisione per la pubblicazione App Store è stata inviata.

## Integrazione tecnica conclusa

[CI remota verde](https://github.com/giovannimonaco/A56-Tangenziale-Napoli/actions/runs/43727730056) sul commit sorgenti `f3422b8`: **90 test / 146 esecuzioni**, **4 test UI**, nessun errore o test saltato, runtime iOS 26.5. È confermata anche sul runner la correzione NaN/±infinito. Export/firma 8 e smoke UI locali completati. Convalida del pacchetto Apple `altool --validate-app`: **VERIFY SUCCEEDED, nessun errore**, senza upload/submission.

L’integrazione di queste modifiche è conclusa; la distribuzione richiede i punti esterni sotto. Il [report di preparazione](app-store/readiness.md) e il [riepilogo macchina](app-store/validation-summary.json) conservano gli esiti e i limiti. Le prove non attestano runtime iOS 18, un nuovo test UI sul telefono, tempi di ridisegno WidgetKit o una revisione umana VoiceOver.

## Pubblicazione e decisioni esterne

La [valutazione di pubblicabilità](app-store/publication-assessment.md) distingue fatti, banca dati, condizioni del servizio e regola Apple 5.2.2. Il disclaimer chiarisce indipendenza e limiti informativi, ma non documenta il permesso di uso dei feed. Non è stato individuato né un permesso applicabile né un divieto specifico dimostrato.

La [richiesta pronta](app-store/feed-permission-request.txt) è indirizzata a Tangenziale di Napoli, con Autostrade in copia, chiedendo inoltro al referente competente. Non è stata inviata. NAP/CCISS è un'alternativa da qualificare, non ancora un sostituto equivalente verificato.

Prezzo e territori finali, dichiarazioni App Privacy e Content Rights, conformità DSA e submission richiedono la chiusura dei rispettivi punti con evidenze. Non sono state copiate dichiarazioni delle altre app come se fossero automaticamente applicabili ad A56. La distribuzione TestFlight della build 9 è stata completata su richiesta; la revisione per la pubblicazione App Store non è stata inviata.
