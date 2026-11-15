# Centro di lavoro A56 Napoli

Aggiornato il 15 novembre 2026. L'utente comunica nella sola chat centrale; assegnazioni, dipendenze e risultati delle chat specializzate sono gestiti dalla centrale.

## Vincoli confermati

- Solo iPhone, iOS 18 o successivo. Nome prodotto A56 Napoli.
- Qualità estetica, semplicità e affidabilità sono requisiti del prodotto.
- Nessuna barra decorativa colorata sui bordi delle schede. Le linee che rappresentano la strada hanno una funzione informativa distinta.
- Widget utili anche senza aprire l'app, con rete autonoma e data del controllo. La frequenza effettiva dipende da iOS.
- Riutilizzare il recapito già adottato per Audiva e Orya per assistenza e privacy.
- Nessuna autorizzazione ai feed già acquisita. Chiarire termini e riuso prima della distribuzione.

## Risultati verificati

- Corrette completezza feed **48/48**, classificazione ingressi/uscite e geometria dei collegamenti. La UI indica i capi fisici e impedisce raccomandazioni di alternative attraversate da chiusure. [Feed](feed-completeness-fix.md), [percorsi](route-boundary-fix.md), [integrazione UI](final-integration-ui.md).
- **90 test iOS in 9 suite** e controlli standalone passati. Quattro smoke test UI e prove mirate passati prima dell’ultima sincronizzazione; riesecuzione finale in corso. Due tentativi di UI automation sul telefono si sono fermati prima dei test durante l’abilitazione del servizio.
- Widget autonomi, small/medium, cache/offline e scadenza. Ora sincronizzazione App Group e richiesta di reload dopo ogni refresh riuscito dell’app: **48 avvisi identici su iPhone firmato**, cache private obsolete rimosse. [Report finale](widget-sync-fix.md).
- UI iPhone piccolo/grande, chiaro/scuro, testo Accessibilità massimo e bersagli verificati, finitura senza barre decorative. [Audit](ui-ux-audit.md), [finitura](visual-design-review.md).
- Build **1.0 (8)** installata e avviata sul telefono, archivio Release riuscito. Export finale in verifica; precedente archivio/IPA 7 verificati. App ed estensione iPhone e iOS 18+, entrambi abilitati al medesimo App Group.
- Bozza App Store `6782002695`, 1.0 `PREPARE_FOR_SUBMISSION`, nome A56 Napoli, lingua it, Navigation, rilascio manuale, questionario età 4+. Otto screenshot finali caricati e collocati nella bozza. [Anteprima](../AppStore/Preview-it.png).
- Policy e assistenza pubblicate nel ramo collegato; nuova policy aggiornata per la condivisione locale widget pronta nel checkout. Nessun nuovo binario caricato e nessuna revisione inviata.

## Lavori ancora attivi

Export/firma finale 8, riesecuzione smoke UI, commit/push e conferma CI remota. La prima esecuzione remota ha passato la UI e rilevato una diversa gestione di NaN nell’SDK del runner; correzione esplicita verificata nella suite locale completa. Nessun fallimento viene ignorato o test saltato.

## Pubblicazione e decisioni esterne

La [valutazione di pubblicabilità](app-store/publication-assessment.md) distingue fatti, banca dati, condizioni del servizio e regola Apple 5.2.2. Il disclaimer chiarisce indipendenza e limiti informativi, ma non documenta il permesso di uso dei feed. Non è stato individuato né un permesso applicabile né un divieto specifico dimostrato.

La [richiesta pronta](app-store/feed-permission-request.txt) è indirizzata a Tangenziale di Napoli, con Autostrade in copia, chiedendo inoltro al referente competente. Non è stata inviata. NAP/CCISS è un'alternativa da qualificare, non ancora un sostituto equivalente verificato.

Prezzo e territori finali, dichiarazioni App Privacy e Content Rights, conformità DSA e submission richiedono la chiusura dei rispettivi punti con evidenze. Non sono state copiate dichiarazioni delle altre app come se fossero automaticamente applicabili ad A56. Nessun nuovo binario è stato caricato e non è stata inviata la revisione in questa lavorazione.
