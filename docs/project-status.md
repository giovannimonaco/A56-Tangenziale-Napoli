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

- Test Swift Testing integrati in Xcode, schema condiviso e workflow CI; prima verifica finale: 42 test / 76 esecuzioni parametrizzate, tutti superati. Vedere [report test](testing-report.md).
- Quattro test UI permanenti nello schema separato `A56UI`, tutti passati su simulatore tramite lo script usato dalla CI. Due tentativi su iPhone fisico si sono fermati durante l'abilitazione dell'automazione, prima dei test.
- Widget small/medium: rete del processo WidgetKit provata prima del primo avvio dell'app, cache autonoma, stati offline e scadenza, tap reale verso Chiusure. Vedere [verifica widget](widget-verification.md).
- Audit su iPhone piccolo/grande, testo Accessibilità, chiaro/scuro, contrasti, posizione negata e MapKit: [audit UI](ui-ux-audit.md). La finitura visiva successiva ha verifiche proprie.
- Primo archivio Release firmato ed export App Store riusciti per app ed estensione, entrambi iPhone e iOS 18+. Sono artefatti iniziali 1.0 (1), da sostituire con l'archivio finale 1.0 (7).
- App Store Connect: app `6782002695`, bozza 1.0 `PREPARE_FOR_SUBMISSION`, nome A56 Napoli, lingua principale italiana, categoria Navigation, rilascio manuale. Testi e URL confrontati con i file locali. Questionario età compilato sul contenuto dell'app; risultato Apple 4+.
- Policy e assistenza aggiornate pubblicate e confrontate senza autenticazione con i file locali. Commit `ed94708`, ramo `review/general-audit`.
- Otto immagini Store in due formati, con avvisi dimostrativi esplicitamente dichiarati; saranno rigenerate sulla finitura finale. [Anteprima](../AppStore/Preview-it.png).

## Lavori ancora attivi

1. [Ingressi, uscite e collegamenti nei percorsi](route-boundary-fix.md): distinguere svincoli, prosecuzioni della strada e punti già sulla carreggiata; verificare falsi allineamenti e istruzioni reali di MapKit.
2. [Completezza feed](feed-completeness-fix.md): correggere la singola occorrenza che produce 47/48 e lo stato globale incompleto sui dati attuali, conservando i controlli per problemi reali della fonte.
3. [Finitura visiva](visual-design-review.md): verificare e catturare la UI finale senza barre decorative, preservando le correzioni di accessibilità.
4. Convergere sul codice finale, rieseguire i controlli pertinenti, produrre archivio/export 1.0 (7), aggiornare screenshot e documentazione, commit/push e verifica CI remota.

## Pubblicazione e decisioni esterne

La [valutazione di pubblicabilità](app-store/publication-assessment.md) distingue fatti, banca dati, condizioni del servizio e regola Apple 5.2.2. Il disclaimer chiarisce indipendenza e limiti informativi, ma non documenta il permesso di uso dei feed. Non è stato individuato né un permesso applicabile né un divieto specifico dimostrato.

La [richiesta pronta](app-store/feed-permission-request.txt) è indirizzata a Tangenziale di Napoli, con Autostrade in copia, chiedendo inoltro al referente competente. Non è stata inviata. NAP/CCISS è un'alternativa da qualificare, non ancora un sostituto equivalente verificato.

Prezzo e territori finali, dichiarazioni App Privacy e Content Rights, conformità DSA e submission richiedono la chiusura dei rispettivi punti con evidenze. Non sono state copiate dichiarazioni delle altre app come se fossero automaticamente applicabili ad A56. Nessun nuovo binario è stato caricato e non è stata inviata la revisione in questa lavorazione.
