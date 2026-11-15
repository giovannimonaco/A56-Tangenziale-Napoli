# A56 Napoli — Fastlane

Comandi dalla radice del repository. Le lane usano il progetto esistente e i testi in `docs/app-store/metadata/it/`, senza duplicarli. Non esistono lane di upload binario, selezione build, invio in review o pubblicazione. La sola `metadata` scrive testi su App Store Connect: è stata preparata, non eseguita in questo incarico.

## Test e prodotti locali

```sh
fastlane ios metadata_check
fastlane ios test
fastlane ios archive
fastlane ios export
```

`test` richiama `Tests/test-xcode.sh`: regressioni shell e suite iOS su un simulatore iPhone dedicato, creato ed eliminato dallo script. Non riutilizza simulatori di altri progetti. Lo script accetta `A56_SIMULATOR_RUNTIME`, `A56_SIMULATOR_DEVICE_TYPE` e `A56_TEST_OUTPUT`; artefatti predefiniti in `.build/test-results/`.

`archive` crea una Release firmata secondo le impostazioni Xcode e le identità/profili locali, in `build/fastlane/A56Napoli.xcarchive`. È separato dall’archivio della chat centrale `build/A56Napoli.xcarchive`. Se il percorso esiste si ferma. Non incrementa automaticamente i numeri e non modifica `project.pbxproj`.

```sh
fastlane ios archive build_number:7 archive_path:build/fastlane/A56Napoli-7.xcarchive
fastlane ios export archive_path:build/fastlane/A56Napoli-7.xcarchive output_directory:build/fastlane/AppStore-7
```

`export` esegue `xcodebuild -exportArchive` con `method=app-store-connect`, `destination=export`, `manageAppVersionAndBuildNumber=false`, `uploadSymbols=false`. Non passa `-allowProvisioningUpdates`: richiede certificati/profili di distribuzione validi già installati. Non esegue Validate App su ASC. La directory di output non deve già esistere; il plist generato è `build/fastlane/configuration/ExportOptions.plist`.

Override via ambiente: `A56_ARCHIVE_PATH`, `A56_EXPORT_PATH`, `A56_BUILD_NUMBER` (sole cifre), `A56_TEAM_ID`. Senza `A56_TEAM_ID` si usa il team del progetto/archivio. `DEVELOPER_DIR` seleziona Xcode nel modo consueto. Usare un ambiente pulito da `GYM_*` di altri progetti.

## Soli metadati su App Store Connect

Dopo QA, nel passaggio di aggiornamento della bozza gestito dalla chat centrale:

```sh
fastlane ios metadata
```

La lane controlla prima i file e le note, poi richiede dall’ambiente:

- `ASC_KEY_ID`: ID della chiave API di team.
- `ASC_ISSUER_ID`: issuer della chiave API.
- `ASC_KEY_PATH`: percorso della chiave `.p8`, esterna al repository; assoluto o relativo alla radice.

Configurare l’ambiente tramite il proprio gestore di credenziali; non passare chiavi o token nella riga di comando. Il codice non legge né copia `.env` o chiavi di Orya/Audiva e non usa fallback Apple ID. Fastlane può caricare autonomamente dotenv: mantenerli ignorati e non aggiungerli al repository. Evitare `--verbose`, dump dell’ambiente e log HTTP autenticati. Le variabili `DELIVER_*` ereditate causano uno stop, per evitare opzioni remote estranee alla configurazione A56.

Viene richiesta l’app esistente `com.giovannimonaco.TangenzialeNapoli` con bozza **1.0 / PREPARE_FOR_SUBMISSION**. La lane invia i soli cinque campi italiani presenti (nome, sottotitolo, descrizione, promo, keyword) e le note in `docs/app-store/review-notes.txt`. Può aggiungere le localizzazioni italiane, ma non crea app/versioni, non seleziona build e non invia screenshot o binari. I contatti review esistenti non sono forniti o copiati dal codice; le note dichiarano che non serve un account demo.

La lingua principale remota riscontrata è `en-US`, con contenuti vuoti; la lane non la cambia automaticamente. Dopo l’upload rileggere i testi remoti e completare la scelta della lingua principale nel passaggio appropriato. Privacy/support URL, categoria, copyright, età, DSA, Content Rights ed export compliance restano separati: non sono inventati o compilati dai cinque file locali. La lane non imposta rilascio automatico o programmato. Stato e blocchi in [readiness](../docs/app-store/readiness.md).

## Verifiche eseguite e limiti

```sh
ruby -c fastlane/Fastfile
ruby -c fastlane/Appfile
ruby -c fastlane/lib/a56_release.rb
fastlane lanes
fastlane ios metadata_check
```

Tutti questi controlli sono passati. Verificate inoltre le opzioni delle lane con azioni simulate: export locale, soli metadati, nessun invio review, protezione da sovrascrittura. Quella prova non ha eseguito rete o compilazioni. `test`, `archive`, `export` e `metadata` non sono stati eseguiti tramite queste lane in questo incarico; gli esiti root di archivio/export sono evidenze distinte. Nessuno script di stato ASC è incluso. I report remoti restano in `build/`, ignorato da Git.

Il Fastfile disabilita la generazione automatica del README per conservare queste istruzioni. Implementazione verificata su Fastlane 2.241.2 installato; riferimenti: [build_app](https://docs.fastlane.tools/actions/build_app/), [metadati deliver](https://docs.fastlane.tools/actions/upload_to_app_store/), [chiave API](https://docs.fastlane.tools/actions/app_store_connect_api_key/).
