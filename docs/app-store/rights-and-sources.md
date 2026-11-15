# Fonti, riutilizzo e attribuzioni

Verifica del 15 novembre 2026. Non è stata inviata alcuna richiesta al gestore e non sono stati cambiati i feed.

## Avvisi Autostrade / Tangenziale di Napoli — blocco aperto

La build usa [previsioni.json](https://viabilita.autostrade.it/json/previsioni.json) ed [eventi.json](https://viabilita.autostrade.it/json/eventi.json). Entrambi hanno risposto HTTP 200 con oggetto JSON `events` e `Last-Modified` recente: dettaglio nel [registro HTTP](link-checks.json). Questo dimostra raggiungibilità nel momento della prova, non continuità, copertura completa, licenza o autorizzazione di riutilizzo.

Non è stata trovata nel checkout un’autorizzazione scritta o una condizione pubblica specifica che consenta l’accesso automatizzato, trasformazione, visualizzazione in app/widget e conservazione degli avvisi. Gli endpoint sono pubblicamente raggiungibili ma non risultano API pubbliche documentate in questa verifica. I percorsi tentati `/it/note-legali` e `/it/disclaimer` restituiscono 404; il footer consultato rimanda alla privacy, senza fornire una licenza specifica per i feed. Non si conclude che non esistano condizioni altrove.

La [regola Apple 5.2.2](https://developer.apple.com/app-store/review/guidelines/#intellectual-property) richiede che l’uso di servizi e contenuti terzi sia specificamente permesso e che la prova sia disponibile su richiesta. L’indipendenza dell’app, il link al gestore e l’uso di dati strutturati riducono l’ambiguità, ma non provano il diritto. **Non confermare in Content Rights di possedere tutti i diritti prima di avere evidenza applicabile.**

Per chiudere il blocco, conservare una licenza/condizione applicabile o risposta scritta con titolare, app e bundle ID, endpoint, visualizzazione in app e widget, conservazione locale, attribuzione, limiti di frequenza, eventuali limiti commerciali e validità. Una prova privata può essere conservata fuori dal repository; qui registrare solo riferimento e ambito. Il widget aumenta le richieste indipendenti: includerlo nella valutazione della frequenza autorizzata.

Bozza non inviata, da usare solo dopo decisione del titolare dell’app:

> Buongiorno, sviluppo A56 Napoli (`com.giovannimonaco.TangenzialeNapoli`), un’app iPhone indipendente per consultare prima di partire le chiusure della Tangenziale. Vorrei accedere ai feed `previsioni.json` ed `eventi.json` per mostrare dati strutturati A56 in app e widget, rimandare ai vostri avvisi e conservare sul dispositivo uno storico degli avvisi terminati per 1–60 giorni (10 predefiniti). I widget richiedono aggiornamenti indipendenti, con frequenza gestita da iOS. Potete indicare le condizioni che permettono questo riutilizzo su App Store o autorizzarlo per iscritto, specificando attribuzione e limiti di accesso? In alternativa, qual è il feed destinato a questo utilizzo?

Canali ufficiali raggiungibili: [Tangenziale di Napoli — contatti](https://www.tangenzialedinapoli.it/contatti-e-customer-care), [Autostrade — contatti](https://www.autostrade.it/it/web/autostrade/contatti). Nessun messaggio spedito.

## Alternativa da studiare, senza cambio automatico

Il [Punto di Accesso Nazionale CCISS](https://www.cciss.it/web/cciss/-/bozza) descrive l’accesso ai dati e il riutilizzo. La pagina consultata non identifica un dataset A56 già pronto con copertura, condizioni e aggiornamento equivalenti. Prima di cambiare fonte occorrono uno specifico dataset, licenza, modalità d’accesso, test di chiusure programmate/attive e rampe, e coordinamento con chi mantiene il mapper. Il solo RSS nazionale non prova la completezza del quadro A56.

## Geometria e mappe

`A56RouteGeometry.swift` dichiara una derivazione dalla relazione OpenStreetMap 1577415 e dai relativi ways, semplificati al 27 luglio 2026. La [licenza OSM](https://www.openstreetmap.org/copyright) richiede attribuzione e può imporre condivisione della banca dati derivata con la stessa licenza. Nel codice sono presenti attribuzione sulla mappa e richiamo ODbL nella pagina Info; verificarne leggibilità e link nella build finale. Non è stata ricostruita la catena di estrazione né verificata la completezza degli obblighi ODbL: conservare sorgente dati, data, trasformazione e modalità di accesso alla derivazione distribuita.

Il repository MIT non sostituisce le licenze dei dati. La cartografia e i percorsi sono di Apple: mantenere i crediti MapKit e rispettare le [condizioni Mappe di Apple](https://www.apple.com/legal/internet-services/maps/terms-it.html). Non nasconderli nelle schermate App Store. Non usare loghi del gestore o descrivere l’app come ufficiale; nome, icona e metadati finali devono essere controllati per evitare affiliazioni implicite. Nessuna verifica marchi esaustiva è stata eseguita.
