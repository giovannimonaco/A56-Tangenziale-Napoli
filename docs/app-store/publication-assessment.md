# A56 Napoli: valutazione della pubblicazione su App Store

Verifica: **15 novembre 2026**, fuso Europe/Rome. Perimetro: app iPhone indipendente, feed Autostrade, archivio locale e widget. Nessuna autorizzazione ai feed è già acquisita. Ricerca su fonti ufficiali e lettura del checkout, inclusa [rights-and-sources.md](rights-and-sources.md). Questo documento valuta il problema dei diritti e delle fonti; non certifica tutti gli altri requisiti della release.

## Esito operativo

**La pubblicazione è un obiettivo plausibile, ma le evidenze raccolte non bastano per dichiarare risolto l'uso dei feed nella versione attuale. Un banner di indipendenza e limitazione informativa, da solo, non chiude il punto.** La scelta consigliata è ottenere condizioni applicabili documentabili: possono essere una licenza pubblica adeguata, un'autorizzazione del soggetto competente oppure un accesso ufficiale al riuso con condizioni compatibili. Non serve necessariamente una lettera personalizzata se esistono già termini sufficienti.

Non è emerso un divieto specifico verificato di questo preciso uso dei due endpoint. Non sarebbe quindi corretto concludere che l'app sia certamente illecita. Allo stesso tempo, accessibilità senza login, finalità utile, gratuità e rielaborazione dei dati non dimostrano da sole che l'accesso automatizzato e l'uso continuativo siano permessi.

| Conclusione | Evidenza / grado di certezza |
| --- | --- |
| Il disclaimer può chiarire indipendenza e limiti delle informazioni | Alto: è una misura di trasparenza; non concede diritti del gestore |
| Apple può chiedere prova del permesso relativo al servizio terzo | Alto: regola 5.2.2 consultata nella fonte ufficiale |
| I singoli fatti stradali non richiedono automaticamente una licenza copyright | Alto come distinzione generale; non decide i diritti sulla raccolta o sul servizio |
| Nel materiale esaminato manca una base di riuso documentata per questi feed | Alto sul perimetro della ricerca; non prova che non esista altrove |
| Il download e riuso attuale violano certamente una banca dati protetta | Non dimostrato: mancano informazioni su investimenti, titolarità e condizioni applicabili |
| NAP/CCISS offre già un sostituto A56 equivalente e liberamente utilizzabile | Non verificato: nessun dataset con copertura e licenza sufficienti è stato identificato |
| Apple accetterà la release dopo una determinata modifica | Non prevedibile: la valutazione resta di App Review |

## Cosa fa effettivamente questa build

Riscontri nel codice, da ricontrollare sull'archivio finale:

- [LiveClosureProvider.swift](../../TangenzialeNapoli/Data/LiveClosureProvider.swift) scarica `https://viabilita.autostrade.it/json/previsioni.json` ed `eventi.json` in parallelo. **Scarica i file nazionali prima del filtro A56**, senza una richiesta selettiva al server. Usa sessione effimera senza cookie e senza cache HTTP, con parametro casuale `index` per evitare risposte in cache. Questo parametro non è una tecnica di autorizzazione né prova un aggiramento di protezioni.
- I [mapper programmato](../../TangenzialeNapoli/Data/AutostradeClosureMapper.swift) e [in tempo reale](../../TangenzialeNapoli/Data/AutostradeRealtimeClosureMapper.swift) filtrano A56 e producono orari, tratta, direzione, rampe, motivo e suggerimenti strutturati. Il testo `t_des_it` è analizzato durante l'elaborazione. Non viene conservato integralmente come proprietà del modello `RoadClosure`; il motivo breve `t_des_fra_cau_it` viene invece mantenuto e mostrato. Dire che non viene riprodotto l'avviso integrale è sostenibile; dire che ogni espressione è scritta autonomamente sarebbe inesatto.
- [ClosureArchive.swift](../../TangenzialeNapoli/Data/ClosureArchive.swift) conserva avvisi strutturati sul dispositivo, anche dopo la scomparsa dal feed: 10 giorni predefiniti dopo la fine, intervallo impostabile 1–60. La migrazione allo schema 3 elimina il testo originale degli archivi precedenti tramite ricodifica. Non emerge un server del produttore dell'app che redistribuisca i feed.
- L'app ha un controllo periodico in primo piano: [AppTabView.swift](../../TangenzialeNapoli/Views/AppTabView.swift) ha un timer di un minuto, mentre [ClosuresViewModel.swift](../../TangenzialeNapoli/ViewModels/ClosuresViewModel.swift) limita ordinariamente il tentativo automatico a dati vecchi di cinque minuti, con intervallo fino a due minuti per alcuni stati incompleti/da verificare. Avvio, ritorno in primo piano e aggiornamento manuale vanno inclusi nella descrizione dell'accesso. Non è corretto descrivere tutta l'app come un solo prelievo ogni 30 minuti.
- [WidgetSnapshot.swift](../../TangenzialeNapoli/Data/WidgetSnapshot.swift) usa autonomamente lo stesso provider, conserva snapshot e un proprio archivio nel contenitore dell'estensione. Non condivide tramite App Group le impostazioni dell'app: il widget usa normalmente la ritenzione predefinita del proprio dominio. [A56Widget.swift](../../A56Widget/A56Widget.swift) propone il prossimo aggiornamento dopo 30 minuti più 0–120 secondi; iOS decide l'esecuzione effettiva. È una richiesta di pianificazione, non una frequenza garantita o un tetto contrattuale dimostrato.
- App e widget possono quindi generare richieste separate, moltiplicate per dispositivi e possibili istanze. Un refresh completo richiede due GET. L'archivio locale riduce la distribuzione centralizzata, ma non elimina le questioni di estrazione, conservazione e presentazione agli utenti.
- Sono già presenti avvisi di prudenza nella [pagina Info](../../TangenzialeNapoli/Views/InfoView.swift), collegamenti alle fonti nel dettaglio e stati di incompletezza/scadenza. Il widget considera i dati non recenti dopo cinque minuti: non promette che iOS effettui richieste ogni cinque minuti.

Questi riscontri descrivono l'implementazione; non sono una misura sul campo del traffico generato da una popolazione di utenti.

## Banner e disclaimer: risposta concreta

| Tema | Cosa può fare il testo | Cosa resta da risolvere |
| --- | --- | --- |
| Affiliazione | Rendere esplicito che A56 Napoli è un prodotto indipendente | Nome, icona, scheda Store e schermate devono essere coerenti: una nota nascosta non corregge un'identità complessivamente ingannevole |
| Provenienza | Attribuire i dati e separare l'elaborazione propria dalla fonte | Attribuzione non equivale ad autorizzazione; rispettare il testo eventualmente imposto dalla licenza |
| Affidamento dell'utente | Spiegare ritardi, incompletezza, trasformazioni e priorità della segnaletica | Occorrono comportamenti coerenti: data dell'ultimo controllo, stato scaduto e nessuna promessa di strada certamente libera |
| Accesso ai feed / banca dati | Nessun effetto autorizzativo | Licenza, diritto applicabile, condizioni del servizio, estrazione ripetuta, cache e widget |
| Responsabilità | Descrivere ragionevolmente funzione e limiti | Non può garantire un esonero generale, né vincolare il gestore o cancellare responsabilità inderogabili |
| App Review | Aiutare a comprendere il prodotto | Non sostituisce la prova che Apple può richiedere ai sensi della 5.2.2 |

Bozza di avviso, **da adeguare alle condizioni della fonte quando chiarite**, senza introdurla ora nell'app:

> A56 Napoli è un'app indipendente, non affiliata né approvata da Autostrade per l'Italia o Tangenziale di Napoli. Elabora dati di viabilità provenienti dai loro canali; l'elaborazione può contenere errori e gli avvisi possono essere incompleti o in ritardo. Controlla l'ora dell'ultimo aggiornamento e consulta i canali del gestore prima di partire. L'assenza di avvisi non garantisce la percorribilità. Durante il viaggio segui segnaletica e indicazioni delle autorità. Non usare l'app mentre guidi.

Nel widget serve una sintesi leggibile con ora/stato dei dati e rinvio al dettaglio. Un consenso obbligatorio al primo avvio non crea il permesso del titolare e non è, da solo, più efficace di informazioni chiare nei punti d'uso.

Evitare formule come «nessuna responsabilità per qualsiasi danno». L'[art. 1229 del Codice civile](https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:regio.decreto:1942-03-16;262:2~art1229) rende nulli gli esoneri preventivi per dolo/colpa grave e per violazione di obblighi derivanti da norme di ordine pubblico. Se si configurano un rapporto professionista-consumatore e condizioni contrattuali, vanno inoltre considerati i limiti dell'[art. 33 del Codice del consumo](https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.legislativo:2005-09-06;206~art33): non si presume qui che ogni clausola proposta sia valida o che l'app gratuita elimini il problema.

## Distinzione dei diritti realmente pertinenti

### Fatti singoli e formulazione degli avvisi

«Chiusura della rampa X dalle 23 alle 6» contiene fatti. Non si può dedurre un'esclusiva copyright su quel fatto solo perché è pubblicato da un operatore. L'[art. 2, n. 9, legge 633/1941](https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:legge:1941-04-22;633~art2) distingue la tutela della banca dati da eventuali diritti sul suo contenuto. La protezione di una formulazione testuale dipende dai suoi requisiti, non dal solo formato JSON.

L'interfaccia strutturata e l'assenza di copia integrale degli avvisi riducono il problema della riproduzione del testo. Non dimostrano però che non vi sia estrazione di una raccolta: posizione, date e stati sono precisamente elementi della raccolta. Né la mera trasformazione dei dati produce automaticamente una nuova libertà di riuso. Non è stata invocata una generica eccezione di citazione, cronaca o text and data mining per giustificare l'intero servizio continuativo.

### Banca dati: tutela possibile, non automatica

Gli [artt. 102-bis](https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:legge:1941-04-22;633~art102bis) e [102-ter](https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:legge:1941-04-22;633~art102ter) della legge 633/1941 distinguono il diritto del costitutore dall'uso di parti non sostanziali dell'utente legittimo. Sono rilevanti quantità, qualità, investimenti e uso nel tempo. Le estrazioni ripetute di parti piccole non sono sempre vietate: il divieto richiede le condizioni previste dalla norma, tra cui contrasto con la normale gestione o pregiudizio ingiustificato.

La Corte di giustizia, [C-203/02, 9 novembre 2004](https://eur-lex.europa.eu/legal-content/IT/TXT/PDF/?uri=CELEX%3A62002CJ0203), distingue investimenti nel conseguimento/verifica/presentazione da quelli nella creazione dei dati. Non basta che il gestore abbia costi per organizzare lavori stradali per provare questo diritto. Non abbiamo contabilità, processo di raccolta o altri elementi per accertarlo nel caso concreto.

**Applicazione al codice, come inferenza:** il download temporaneo dei file nazionali è un punto più delicato della sola visualizzazione A56. Il fatto che dopo si scartino molte righe non rende automaticamente irrilevante il trasferimento iniziale. Senza dati sull'insieme protetto non si può comunque qualificare definitivamente il singolo file come totalità o parte sostanziale. Archivio, continuità e numero di utenti vanno valutati insieme, senza inventare una soglia percentuale sicura.

### Termini del servizio: ricerca e limiti

Il 15 novembre sono state esaminate home, navigazione/footer e pagine ufficiali pertinenti di [Autostrade](https://www.autostrade.it/it/home) e [Tangenziale](https://www.tangenzialedinapoli.it/), con ricerche mirate su licenza, copyright, riuso e condizioni. Non è stata individuata una licenza open data o una documentazione di API che identifichi i due JSON e consenta l'uso descritto.

- I [termini Muovy Cashback](https://www.autostrade.it/it/muovy/cashback/termini-condizioni), aggiornati al **1 giugno 2026**, contengono restrizioni di riproduzione. L'art. 1.1 definisce però il perimetro come app e sezione Muovy Cashback del sito, oltre al servizio cashback. **Non li estendo automaticamente ai feed di viabilità**: non provano né un divieto generale di questi endpoint né un permesso.
- La pagina [Condizioni di utilizzo dell'infrastruttura](https://www.tangenzialedinapoli.it/informazioni-generali-su-utilizzo-e-gestione-dell-infrastruttura-e-dei-servizi/condizioni-di-utilizzo-dell-infrastruttura) tratta l'infrastruttura e l'informazione sui cantieri; non contiene una licenza per app terze. Le [informative privacy Tangenziale](https://www.tangenzialedinapoli.it/informativa-privacy) e la [sezione privacy Autostrade](https://www.autostrade.it/it/privacy) non sono, per questo, licenze dei dati di traffico.
- La sentenza [C-30/14, 15 gennaio 2015](https://eur-lex.europa.eu/legal-content/IT/TXT/PDF/?uri=celex%3A62014CJ0030) chiarisce che l'assenza di tutela della banca dati ai sensi della direttiva non esclude di per sé limitazioni contrattuali secondo il diritto nazionale. Non dimostra che qui sia stato concluso un contratto: conoscibilità, accettazione e validità di termini specifici restano da accertare. Viceversa, non tutti i termini possono cancellare i diritti inderogabili dell'utente legittimo di una banca tutelata.

Un eventuale `©`, `robots.txt`, header di cache o CORS non risolverebbe da solo l'intera questione: ha funzioni diverse da una licenza che copra accesso e riuso. Il silenzio del gestore non viene considerato autorizzazione.

### NAP/CCISS e norme ITS: alternativa concreta da qualificare

Il [regolamento delegato UE 2022/670](https://eur-lex.europa.eu/legal-content/IT/TXT/?uri=CELEX%3A32022R0670), applicabile dal **1 gennaio 2025**, sostituisce il 2015/962. Prevede accessibilità, scambio e riuso di categorie di dati stradali tramite NAP, con condizioni e requisiti di qualità; gli artt. 5–6 riguardano restrizioni e stato della rete. È quindi pertinente alla ricerca di un canale per le chiusure. La transizione fino a fine 2027 non esclude in blocco le autostrade: art. 14. Da ciò **non ricavo una licenza indiscriminata dei JSON web**. L'applicazione concreta richiede identificare dati disponibili, titolare, canale e condizioni; l'art. 1.3 rinvia inoltre al quadro di attuazione della direttiva ITS. Per l'app possono essere pertinenti anche doveri di aggiornamento e trattamento affidabile dei dati, non soltanto facoltà di prelievo.

Il [regolamento UE 886/2013](https://eur-lex.europa.eu/legal-content/IT/TXT/?uri=celex%3A32013R0886) riguarda informazioni minime di sicurezza, con categorie specifiche fra cui lavori stradali di breve durata. Non coincide con ogni avviso programmato. La gratuità per l'utente finale non dimostra che ogni canale o licenza a monte sia gratuito e senza condizioni.

La [pagina illustrativa CCISS sul NAP](https://www.cciss.it/web/cciss/-/bozza), pubblicata il **22 luglio 2020**, resta un riscontro del ruolo del NAP; il richiamo al 2015/962 è storico e non va usato come unica descrizione della disciplina attuale. Il portale [NAP multimodale](https://www.cciss.it/nap/mmtis/public/static/multimodal) descrive soprattutto dati NeTEx/SIRI e servizi multimodali: non prova di offrire le chiusure A56 cercate.

**Risultato della ricerca:** non è stato identificato un record/dataset con endpoint, licenza, chiusure A56 programmate e attive, rampe e condizioni di archivio/widget equivalenti alla build. Non significa che tale fornitura non esista. Il contatto utile è il canale istituzionale [CCISS](https://www.cciss.it/web/cciss/contatti), chiedendo il percorso RTTI/SRTI pertinente e i metadati del dataset, senza aprire account o accettare condizioni in questo incarico.

Controllo concreto dell'[RSS CCISS](https://www.cciss.it/rss) e della [pagina RSS](https://www.cciss.it/web/cciss/rss-feed): entrambi hanno restituito HTTP 200 e XML con 100 elementi; nel campione non figuravano le stringhe «A56» o «Tangenziale di Napoli», né tag di licenza/copyright/rights. Questo non dimostra assenza permanente di eventi A56 o inesistenza di condizioni esterne, ma impedisce di considerare quel campione una prova di copertura e licenza equivalenti. Nessun RSS è stato integrato nell'app.

### Riuso dell'informazione pubblica in Italia

Il [d.lgs. 36/2006, art. 1](https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.legislativo:2006-01-24;36~art1), modificato nel 2021, comprende anche categorie di imprese e, al comma 2-quater, gestori di servizi pubblici per servizi di pubblico interesse. È una pista pertinente: non va scartata soltanto perché l'operatore ha forma societaria privata. L'[art. 3](https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.legislativo:2006-01-24;36~art3) contiene esclusioni, tra cui diritti di terzi e parti composte solo da logotipi/stemmi/distintivi. Il quadro UE di riferimento è la [direttiva 2019/1024](https://eur-lex.europa.eu/eli/dir/2019/1024/oj?locale=it).

Non è stata accertata l'intera catena titolare-documento-servizio-regime applicabile ai due file. Perciò non assegno loro automaticamente una licenza aperta o un permesso di pubblicazione in ogni paese. Questa disciplina può fondare una richiesta motivata di accesso/riuso; non viene sostituita dall'equazione «sito consultabile = open data».

### Attribuzione, nome e logo

L'attribuzione può essere dovuta per licenza o essere opportuna per trasparenza. Deve descrivere la provenienza senza far apparire il gestore autore dell'elaborazione o garante dell'app. «Dati di fonte Autostrade/Tangenziale; elaborazione indipendente di A56 Napoli» è un'impostazione da adattare al titolare effettivo e ai termini concordati. Un'autorizzazione ai dati non autorizza necessariamente i loghi, e una licenza del logo non autorizza i feed.

Il nome **A56 Napoli** ha un'impostazione geografica/riferita alla strada; questo riduce alcune ambiguità, ma non è una verifica di disponibilità del marchio. L'[art. 21 del Codice della proprietà industriale](https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.legislativo:2005-02-10;30~art21) contempla usi descrittivi e di riferimento subordinati alla correttezza e vieta usi confusori. Non è corretto dire che qualunque menzione testuale di Autostrade richieda automaticamente il consenso, né che aggiungere «non ufficiale» renda lecito qualunque nome o grafica.

Nel checkout l'identità mostrata in Info è A56 Napoli con simbolo stradale; non è emersa dal codice letto una pretesa di essere il gestore. Non sono stati eseguiti una ricerca completa UIBM/EUIPO/WIPO, un confronto dei marchi figurativi o una certificazione della provenienza/licenza di ogni asset dell'icona. Prima del rilascio verificare icona composita, nome, sottotitolo, screenshot e descrizione finali. Evitare loghi e imitazioni dell'identità del gestore in assenza del relativo titolo.

## Apple: cosa deve essere sostenibile in review

La [regola 5.2.2](https://developer.apple.com/app-store/review/guidelines/#intellectual-property) riguarda anche il semplice accesso a un servizio terzo: richiede permesso specifico nelle condizioni e prova su richiesta. La 5.2.1 riguarda materiali protetti e rappresentazioni ingannevoli. Sono requisiti distinti dalla valutazione giuridica del singolo dato fattuale.

La documentazione [Content Rights di App Store Connect](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information) contempla diritti necessari **oppure un utilizzo altrimenti consentito dalla legge** nei paesi di disponibilità. Non richiede di essere proprietari di ogni fatto. Qui manca però un dossier sufficiente per sostenere l'intero uso corrente del servizio: non confermare quel requisito soltanto perché è stato aggiunto un banner. Se si scegliesse una base legale senza licenza esplicita, andrebbe documentata sul caso concreto e resterebbe incerto come App Review applicherebbe la 5.2.2.

L'approvazione Apple non conferisce diritti del gestore. La gratuità non esenta dalla 5.2.2. La [regola 4.2](https://developer.apple.com/app-store/review/guidelines/#minimum-functionality) rende inoltre debole una versione ridotta a semplice raccolta di collegamenti. Queste conclusioni non anticipano il risultato di review.

## Scenari praticabili

| Scenario | Condizione per procedere | Valutazione attuale |
| --- | --- | --- |
| Feed attuali con licenza pubblica adeguata | Trovare termini identificabili che coprano accesso automatizzato, elaborazione, app, widget e conservazione; rispettarne i limiti | Possibile, ma tali termini non sono stati trovati |
| Feed attuali con risposta scritta | Risposta del titolare o soggetto autorizzato che descriva l'uso e indichi condizioni e limiti | Percorso più diretto per preservare il prodotto; richiesta ancora da inviare |
| Fonte ufficiale NAP/CCISS o feed indicato dal gestore | Dataset e condizioni verificati, copertura A56 sufficiente e prova tecnica delle differenze | Percorso promettente, non sostituto già pronto |
| Feed attuali basandosi su facoltà legali senza permesso espresso | Valutazione specifica di banca dati, uso legittimo, termini e regime di riuso; dossier per Apple | Non escluso in astratto, ma più incerto con download nazionale ripetuto; la sola analisi qui raccolta non chiude il punto |
| Versione senza questi feed | Eliminare realmente richieste app/widget, archivio derivato e promesse di chiusure; conservare un'utilità autonoma fondata su dati utilizzabili | Potenzialmente valida solo come prodotto ripensato: mappa degli svincoli, strumenti di percorso e preferiti possono essere una base, da verificare. Non basta spegnere una schermata o mostrare fixture |

Una versione senza feed non deve mostrare vecchi dati come correnti, lasciare attivi i widget che li scaricano o diventare un semplice elenco di link. Restano i diritti sulle mappe e sui dati statici. La geometria di [A56RouteGeometry.swift](../../TangenzialeNapoli/Data/A56RouteGeometry.swift) dichiara origine OSM: [ODbL e attribuzione](https://www.openstreetmap.org/copyright) vanno rispettate, con verifica dell'eventuale banca derivata e dei suoi obblighi. La licenza MIT del codice non copre i dati esterni. Non è stato eseguito un nuovo audit completo ODbL/MapKit.

## Percorso minimo per decidere

1. **Fissare il perimetro da chiedere:** iPhone; entrambi gli endpoint; download nazionale e filtro A56; uso dei motivi brevi; app e widget autonomi; archivio separato e ritenzioni; aggiornamenti automatici/manuali; paesi Store e modello economico effettivamente scelti. Non presentare come già deciso un prezzo o una distribuzione mondiale.
2. **Chiedere prima condizioni o canale corretto**, senza presumere una violazione: contatto generale [Tangenziale](https://www.tangenzialedinapoli.it/contatti-e-customer-care) / [Autostrade](https://www.autostrade.it/it/web/autostrade/contatti), chiedendo inoltro al responsabile della concessione dei dati. Non usare i moduli di reclamo per sinistri come se fossero un ufficio licenze. In alternativa, richiesta tecnica al [CCISS](https://www.cciss.it/web/cciss/contatti) su dataset, fornitore e condizioni RTTI/SRTI.
3. **Acquisire una risposta o licenza verificabile:** soggetto che può concedere i diritti, ambito dati/servizio, trasformazione, app/widget, archivio, limiti di richiesta e utenti, commerciale/non commerciale, attribuzione, territori, durata/revoca e modalità di aggiornamento. Una risposta «il sito è pubblico» non risponde a tutti questi punti. Il mancato riscontro non li risolve.
4. **Se c'è un limite incompatibile, rendere concreta una variante tecnica** prima della release: intervalli concordati, API filtrata o altro canale, archivio ridotto o disabilitato, widget coperti. Nessuna di queste modifiche è stata fatta ora. Un proxy non è automaticamente autorizzato e può introdurre ulteriore redistribuzione.
5. **Preparare il dossier di review:** copia datata dei termini/risposta e relativa applicabilità, breve descrizione di fonti e trasformazioni, indipendenza, frequenze non garantite da iOS, attribuzioni e schermate finali. La prova privata può restare fuori dal repository. Poi completare gli altri punti di [readiness.md](readiness.md) e decidere la submission. Non promettere esito positivo.

Se non arrivano condizioni utili, la decisione residua è fra una valutazione giuridica mirata su questi fatti e un prodotto senza quei feed. Una revisione professionale sarebbe utile soprattutto sul download nazionale ripetuto e sul regime italiano di riuso; non serve come avvertenza astratta su ogni singolo orario mostrato.

## Bozza di contatto — NON INVIATA

**Oggetto:** A56 Napoli — condizioni di riuso dei dati di viabilità in app iPhone e widget

> Buongiorno,
>
> sto sviluppando A56 Napoli, un'app iPhone indipendente, bundle ID `com.giovannimonaco.TangenzialeNapoli`, per consultare le chiusure della Tangenziale prima di partire. Non ho attualmente un'autorizzazione al riuso dei vostri feed e vorrei individuare le condizioni o il canale corretto prima della pubblicazione su App Store.
>
> L'implementazione legge `https://viabilita.autostrade.it/json/previsioni.json` e `https://viabilita.autostrade.it/json/eventi.json`. Scarica i file nazionali, seleziona gli eventi A56 e ne ricava dati strutturati: tratta, direzione, rampe, orari, motivo breve e indicazioni alternative. Non riproduce integralmente i testi degli avvisi né utilizza i vostri loghi. Prevede attribuzione della fonte, collegamenti ai vostri canali e una dichiarazione chiara di indipendenza.
>
> Le richieste partono dai dispositivi, senza un nostro server di redistribuzione. L'app aggiorna automaticamente in primo piano normalmente dopo cinque minuti, con alcuni tentativi dopo due minuti in caso di dati da verificare, oltre ad avvio e aggiornamenti manuali. Il widget fa richieste autonome, proponendo aggiornamenti dopo circa 30–32 minuti; iOS ne determina i tempi effettivi. Ogni aggiornamento completo consulta entrambi i file.
>
> Sono previsti dati salvati offline e uno storico locale, normalmente dieci giorni dopo la fine dell'avviso; nell'app l'utente può scegliere da uno a sessanta giorni. Il widget conserva un proprio snapshot e archivio, normalmente con la durata predefinita. Non è un servizio di navigazione o un canale ufficiale.
>
> Potete indicarci se esistono condizioni pubbliche che consentano questo accesso e utilizzo, oppure il soggetto competente a concederlo? Vorremmo chiarire uso in app e widget, trasformazione, conservazione, attribuzione, frequenza e volumi consentiti, eventuali condizioni economiche o limiti a uso commerciale, territori e durata. Prezzo e paesi di distribuzione saranno comunicati e definiti prima di concordare l'ambito finale; non chiediamo di presumere che l'app sia già distribuita o gratuita.
>
> Se questi endpoint non sono destinati a tale uso, potete indicarci un'API o dataset ufficiale, anche tramite NAP/CCISS, che copra chiusure A56 programmate, attive e di rampe? Possiamo adeguare l'implementazione ai limiti concordati. Vi chiediamo anche di indicare il titolare dei dati/servizio e il riferimento alle condizioni da conservare per eventuali richieste di App Review.
>
> Grazie,
> Giovanni Monaco

Per CCISS usare una richiesta più breve sul dataset RTTI/SRTI A56: endpoint e accesso, licenza/contratto, fornitore, chiusure programmate e attive, rampe, copertura, frequenza, archivio e redistribuzione su dispositivi. Non presumere equivalenza con il NAP multimodale.

## Tracciabilità e limiti della verifica

Tutte le fonti linkate sono istituzionali, dei titolari o del progetto OSM e sono state consultate il **15 novembre 2026**; le date dell'atto o di aggiornamento sono distinte dalla data di consultazione. Per le norme italiane sono stati letti gli articoli su Normattiva. Per EUR-Lex la ricerca ufficiale ha restituito testo e riferimenti, ma alcune aperture dirette hanno incontrato verifica JavaScript o reindirizzamenti: non si dichiara una verifica integrale di ogni possibile modifica o atto attuativo nazionale ITS successivo. Il browser interattivo non era disponibile in questa sessione.

Il registro già presente [link-checks.json](link-checks.json) riporta due HTTP 200 ai feed alle 13:21 UTC del 15 novembre. I nuovi GET di questa indagine, senza cookie e con client Python predefinito, hanno ricevuto **403** per entrambi; alcune pagine dei siti sono risultate accessibili usando un normale User-Agent. Questa differenza dipende potenzialmente da client/rete/protezioni e non prova né una revoca generale né una licenza né la causa del rifiuto. Non sono stati aggirati controlli di accesso o cercati endpoint nascosti. Le conclusioni sul formato e sul comportamento dell'app derivano dal codice e dal registro esistente, non da una nuova cattura riuscita dei feed.

Restano non verificati: titolare e investimenti della banca, termini effettivamente applicabili agli endpoint, qualifica completa nel regime di riuso, disponibilità/condizioni di un dataset A56 alternativo, qualità comparata della copertura, disponibilità dei marchi e licenze di ogni asset, paesi/prezzo finali e giudizio Apple. Non si interpreta l'assenza di risultati di ricerca come prova di assenza di diritti o di licenze.

In questo incarico è stato creato soltanto questo report. Nessun contatto a terzi, modifica di app/feed/altre documentazioni, upload, commit, push o intervento su App Store Connect.
