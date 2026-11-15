import SwiftUI

struct InfoView: View {
    let viewModel: ClosuresViewModel
    @Binding var direction: Direction
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        List {
            appIdentity
            safetySection
            readingSection
            widgetSection
            detailsSection

            if AppFeatures.showsLocalHistoryInInfo {
                localHistorySection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Info")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: RoadClosure.self) {
            ClosureDetailView(closure: $0, viewModel: viewModel)
        }
    }

    private var appIdentity: some View {
        Section {
            let identityLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(spacing: 14))
            identityLayout {
                Image(systemName: "road.lanes")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 3) {
                    Text("A56 Napoli")
                        .font(.headline)
                    Text("Situazione corrente e chiusure programmate")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 4) }

                Text("v\(appVersion)")
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var safetySection: some View {
        Section("Prima di partire") {
            Label {
                Text("Strumento informativo indipendente")
                    .fontWeight(.semibold)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.a56Block)
            }

            Text(
                "I dati possono essere in ritardo, incompleti o cambiare. Prima di "
                + "partire verifica i canali del gestore; sulla strada fanno sempre "
                + "fede segnaletica, personale e autorità."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)

            Text("Non consultare o interagire con l’app mentre guidi.")
                .font(.footnote.weight(.semibold))
        }
    }

    private var readingSection: some View {
        Section("Come leggerla") {
            legendRow(
                color: .a56Open,
                title: "Nessuna chiusura segnalata",
                detail: "negli avvisi disponibili per la fascia selezionata"
            )
            legendRow(
                color: .a56Block,
                title: "Limitazione",
                detail: "chiusura o limitazione nella fascia selezionata"
            )
            LabeledContent("Adesso") {
                Text("ciò che risulta in corso")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Programmate") {
                Text("finestre future pubblicate")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var widgetSection: some View {
        Section("Widget nella schermata Home") {
            Text("Apri la galleria dei widget dalla schermata Home, cerca «A56 Napoli» e aggiungi «Chiusure A56».")
            Text(
                "Il widget scarica gli avvisi anche senza aprire l’app. iOS decide quando aggiornarlo: "
                + "controlla sempre l’ora dei dati mostrata nel widget."
            )
            .font(.footnote)
            .foregroundStyle(Color.secondary)
            Label("Tocca il widget per aprire le chiusure nell’app.", systemImage: "hand.tap")
                .font(.footnote)
        }
    }

    private var dataSection: some View {
        List {
            Section {
                Text(
                    "L’app combina la programmazione A56 con il flusso di viabilità "
                    + "in tempo reale pubblicamente accessibile. L’integrazione non "
                    + "è un’API documentata o garantita dal gestore."
                )

                Text(
                    "Gli avvisi si aggiornano all’apertura, periodicamente mentre usi l’app "
                    + "e con il pulsante di ricarica. Se non è possibile verificarli, l’app mostra "
                    + "l’ultimo dato disponibile con un avviso. Gli orari si riferiscono a Napoli."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("Verifica sul sito del gestore") {
                Link(destination: AppLinks.plannedNotices) {
                    Label("Previsioni A56 · Autostrade", systemImage: "safari")
                }
                Link(destination: AppLinks.liveTraffic) {
                    Label("Traffico in Campania · Tangenziale", systemImage: "safari")
                }
            }
        }
        .navigationTitle("Dati e aggiornamenti")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var detailsSection: some View {
        Section("Approfondimenti") {
            NavigationLink {
                dataSection
            } label: {
                Label("Dati e aggiornamenti", systemImage: "arrow.triangle.2.circlepath")
            }
            NavigationLink {
                privacyDetails
            } label: {
                Label("Informativa privacy", systemImage: "hand.raised")
            }
            NavigationLink {
                legalDetails
            } label: {
                Label("Fonti, licenze e indipendenza", systemImage: "doc.text")
            }
            Link(destination: AppLinks.contact) {
                Label("Assistenza via email", systemImage: "envelope")
            }
            Link(destination: AppLinks.support) {
                Label("Segnalazioni pubbliche", systemImage: "questionmark.circle")
            }
        }
    }

    private var privacyDetails: some View {
        List {
            Section("A56 Napoli · Giovanni Monaco") {
                Text(
                    "L’app non richiede un account e non usa pubblicità, strumenti di analisi o tracciamento. "
                    + "Lo sviluppatore non gestisce un server per ricevere dati dagli utenti."
                )
            }
            Section("Posizione e percorsi") {
                Text(
                    "La posizione viene chiesta quando scegli «Usa la mia posizione» o tocchi un preferito per "
                    + "controllare il percorso. Puoi anche inserire la partenza a mano o revocare l’accesso in "
                    + "Impostazioni. Mappe di Apple usa le coordinate della posizione per trovare l’indirizzo di "
                    + "partenza e riceve anche le ricerche di luoghi e gli estremi del percorso. "
                    + "L’app salva sul dispositivo solo le destinazioni che aggiungi ai preferiti. "
                    + "Puoi rimuoverle dal tab Percorsi."
                )
                Link("Mappe di Apple e privacy", destination: AppLinks.appleMapsPrivacy)
            }
            Section("Avvisi e preferenze") {
                Text(
                    "Per scaricare gli avvisi, il dispositivo si collega ad Autostrade per l’Italia, "
                    + "che può ricevere informazioni di connessione come l’indirizzo IP. "
                    + "L’app non invia al gestore posizione, ricerche o itinerari."
                )
                Text(
                    "L’app salva sul dispositivo preferenze, preferiti e avvisi. Per impostazione predefinita "
                    + "gli avvisi terminati restano per 10 giorni; puoi scegliere da 1 a 60 giorni e cancellare "
                    + "gli avvisi dell’app da Info → Archivio locale."
                )
                Link("Informativa di Autostrade per l’Italia", destination: AppLinks.autostradePrivacy)
            }
            Section("Widget") {
                Text(
                    "Il widget può scaricare gli avvisi direttamente dal gestore quando iOS gli consente "
                    + "di aggiornarsi, senza aprire l’app. Non usa la tua posizione, le ricerche o i preferiti."
                )
                Text(
                    "Conserva una copia separata degli avvisi sul dispositivo. «Elimina archivio locale» "
                    + "nell’app non cancella questa copia. Per rimuovere i dati locali dell’app e del widget, "
                    + "elimina l’app dalle impostazioni di iOS: rimuovere solo l’icona dalla Home non basta."
                )
            }
            Section("Contatti") {
                Link("Informativa privacy sul web", destination: AppLinks.privacyPolicy)
                Link("Email per assistenza e richieste riservate", destination: AppLinks.contact)
                Text(
                    "Lo sviluppatore riceve il tuo indirizzo email e ciò che scegli di inviare per rispondere "
                    + "alla richiesta. Evita dati personali non necessari."
                )
                .font(.footnote)
                .foregroundStyle(Color.secondary)
                Link("Segnalazioni pubbliche su GitHub", destination: AppLinks.support)
                Text("Le segnalazioni su GitHub sono pubbliche: non pubblicare indirizzi, posizione, itinerari o altri dati personali.")
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }
        }
        .navigationTitle("Informativa privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var legalDetails: some View {
        List {
            Section {
                Text(
                    "In caso di differenze, fanno fede i canali del gestore e le "
                    + "indicazioni presenti sulla strada."
                )
            } header: {
                Text("Fonte")
            }

            Section {
                Link(destination: A56RouteGeometry.attributionURL) {
                    Label("© OpenStreetMap contributors · ODbL", systemImage: "map")
                }
                Link(destination: AppLinks.appleMapsTerms) {
                    Label("Condizioni d’uso · Mappe Apple", systemImage: "doc.text")
                }

                Text(
                    "La base cartografica è Mappe Apple. La geometria A56 sovrapposta "
                    + "usa dati OpenStreetMap disponibili con licenza ODbL."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            } header: {
                Text("Cartografia")
            }

            Section("Indipendenza") {
                Text(
                    "App non affiliata, sponsorizzata o approvata da Autostrade per "
                    + "l’Italia o Tangenziale di Napoli. Marchi e denominazioni "
                    + "appartengono ai rispettivi titolari."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Fonti e licenze")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var localHistorySection: some View {
        Section {
            NavigationLink {
                StoricoView(viewModel: viewModel, direction: $direction)
            } label: {
                Label("Archivio locale", systemImage: "clock.arrow.circlepath")
            }
        } header: {
            Text("Strumenti secondari")
        } footer: {
            Text(
                "Raccolta tecnica del dispositivo, utile per controlli e diagnosi. "
                + "Non è un archivio storico ufficiale o completo."
            )
        }
    }

    private func legendRow(
        color: Color,
        title: String,
        detail: String
    ) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        InfoView(
            viewModel: .preview(closures: SampleClosures.make()),
            direction: .constant(.towardPozzuoli)
        )
    }
}
#endif
