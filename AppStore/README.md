# Materiali App Store A56 Napoli

Gli screenshot italiani si trovano in `Screenshots/it/`, in 1320 × 2868 e 1206 × 2622 pixel. Le quattro scene derivano dalle catture native in `docs/screenshots/app-store-source/`: mappa, programmazione, dettaglio rampa e confronto percorso. Gli avvisi sono dimostrativi e dichiarati come tali nell'artwork; il percorso è stato calcolato da MapKit con luoghi pubblici. Nessun indirizzo personale è incluso.

Per rigenerarli su macOS con Python 3 e Pillow:

```sh
python3 AppStore/Scripts/render_screenshots.py
```

`ScreenshotManifest.json` registra sorgenti, dimensioni e hash; `Preview-it.png` raccoglie le quattro scene. Il renderer non modifica le catture dell'app, oltre a ridimensionarle e inserirle in una cornice, e non effettua upload.

Con le sole variabili `ASC_KEY_ID`, `ASC_ISSUER_ID` e `ASC_KEY_PATH` nell'ambiente, lo script `Scripts/prepare_assets.py audit` legge gli asset della bozza A56. Il comando esplicito `screenshots` carica le otto immagini e ne verifica elaborazione e ordinamento; non carica binari e non invia alla revisione. Dipendenze degli script in `Scripts/requirements.txt`; nessuna dipendenza di terze parti entra nell'app iOS. `UploadManifest.json` contiene soltanto identificativi asset e hash, senza credenziali o URL firmati.

I testi e le verifiche di pubblicabilità sono in `docs/app-store/`. Le procedure di test, archivio, esportazione locale e aggiornamento dei soli metadati sono descritte in `fastlane/README.md`.

Le immagini sono materiali di preparazione. Prima dell'invio confrontarle con il comportamento della build finale; non attestano autorizzazioni sui feed o accettazione da parte di Apple.
