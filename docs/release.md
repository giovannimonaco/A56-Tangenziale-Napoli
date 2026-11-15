# Preparazione della 1.0 — A56 Napoli

App iPhone, bundle `com.giovannimonaco.TangenzialeNapoli`, requisito locale iniziale iOS 18. Stato e blocchi aggiornati al 15 novembre 2026 in [app-store/readiness.md](app-store/readiness.md). **Materiali preparati non significa app pronta all’invio.** Questa attività non autorizza upload, pubblicazione, modifica App Store Connect, messaggi al gestore, commit o push.

## Materiali da usare

- [Metadati italiani e screenshot richiesti](app-store/metadata.md), file pronti in `app-store/metadata/it/`.
- [Note per App Review](app-store/review-notes.txt), da confermare sulla build finale.
- [Informativa privacy](privacy.md), [audit privacy](app-store/privacy-audit.md) e [pagina supporto da completare/pubblicare](app-store/support.md).
- [Fonti, diritti e bozza non inviata al gestore](app-store/rights-and-sources.md).
- [Requisiti Apple verificati live](app-store/apple-requirements.md) e [registro delle verifiche URL](app-store/link-checks.json).

## Sequenza di chiusura

1. Risolvere i diritti sui feed, compresi accesso autonomo dei widget e conservazione locale. Non assumere una licenza dal solo HTTP 200. Non cambiare fonte senza coordinamento e test dei mapper.
2. Terminare e verificare app e widget: dati aggiornati/parziali/scaduti/offline, archivio, preferiti, percorsi manuali e posizione negata/revocata/approssimativa. Provare le operazioni comuni su iPhone fisico con VoiceOver e dimensioni Accessibilità. Documentare il risultato, senza convertire prove di simulatore in prove su device.
3. Pubblicare la policy finale e il supporto con recapito verificato. L’URL policy nell’app punta ora al ramo pubblico `review/general-audit`, verificato leggibile, ma quel contenuto è precedente e non include i widget; il vecchio percorso `main` è 404. La semplice presenza del file locale non pubblica nulla. Verificare il contenuto anonimo prima di usare l’URL definitivo in app e ASC.
4. Eseguire le suite previste dal checkout finale. La procedura shell esistente `Tests/check-a56.sh` va provata anche con `TZ=America/New_York`; i file live eventuali sono prima programmazione, poi tempo reale. Integrare le nuove suite XCTest/widget secondo [documentazione test](testing-project-ready.md), se presente, senza dichiararle eseguite solo perché configurate.
5. Creare archivio Release e controllare app e `.appex`: versione, build, iPhone, icona, permesso posizione, profili/entitlements, manifest in entrambi i bundle. Eseguire privacy report e Validate App con distribuzione appropriata. Un archive firmato Apple Development non prova un export App Store valido.
6. Preparare screenshot finali iPhone grande e gli eventuali set aggiuntivi, con mappe attribuite e dati non personali. I widget si aggiornano quando iOS lo consente; non promettere aggiornamenti continui o ogni 30 minuti garantiti.
7. Completare e verificare i campi ASC: nome “A56 Napoli” (remoto attuale “TangenzialeNapoli”), italiano, categoria/prezzo/disponibilità, età, Content Rights con prova, App Privacy, DSA, export compliance, contatti privati review e note. L’app remota esiste già in bozza 1.0; non crearne una duplicata. Non è stato attestato che questi campi siano completi.
8. Solo in un successivo passaggio autorizzato: upload, elaborazione, selezione build, rilettura dei metadati/asset e invio in review. Pubblicazione e rilascio restano decisioni separate del titolare.

La checklist dettagliata distingue evidenze, proposte e blocchi in [readiness.md](app-store/readiness.md). Ricontrollare le fonti Apple alla data dell’invio.
