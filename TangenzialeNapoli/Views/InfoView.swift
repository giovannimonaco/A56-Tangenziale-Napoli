//
//  InfoView.swift
//  TangenzialeNapoli
//
//  Concise product, safety, source, privacy and attribution information.
//

import SwiftUI

struct InfoView: View {
    let viewModel: ClosuresViewModel
    @Binding var direction: Direction

    private let previsioniA56URL = URL(
        string: "https://www.autostrade.it/it/previsioni?strada=A56"
    )!
    private let tangenzialeCampaniaURL = URL(
        string: "https://www.tangenzialedinapoli.it/it/servizi/traffico/traffico-in-campania"
    )!
    private let autostradePrivacyURL = URL(
        string: "https://www.autostrade.it/it/privacy/sito-web"
    )!
    private let appleMapsTermsURL = URL(
        string: "https://www.apple.com/legal/internet-services/maps/terms-it.html"
    )!

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
            detailsSection

            if AppFeatures.showsLocalHistoryInInfo {
                localHistorySection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Info")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: RoadClosure.self) {
            ClosureDetailView(closure: $0)
        }
    }

    private var appIdentity: some View {
        Section {
            HStack(spacing: 14) {
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

                Spacer(minLength: 4)

                Text("v\(appVersion)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
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
                title: "Percorribile",
                detail: "tratto, entrata o uscita senza limitazioni note"
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

    private var dataSection: some View {
        List {
            Section {
                Text(
                    "L’app combina la programmazione A56 con il flusso di viabilità "
                    + "in tempo reale pubblicamente accessibile. L’integrazione non "
                    + "è un’API documentata o garantita dal gestore."
                )

                Text(
                    "L’aggiornamento avviene all’apertura, al ritorno in primo piano "
                    + "e con il pulsante di ricarica. Se la rete non è disponibile, "
                    + "l’app indica chiaramente l’ultimo dato salvato."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("Verifica sul sito del gestore") {
                Link(destination: previsioniA56URL) {
                    Label("Previsioni A56 · Autostrade", systemImage: "safari")
                }
                Link(destination: tangenzialeCampaniaURL) {
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
                Label("Privacy", systemImage: "hand.raised")
            }
            NavigationLink {
                legalDetails
            } label: {
                Label("Fonti, licenze e indipendenza", systemImage: "doc.text")
            }
        }
    }

    private var privacyDetails: some View {
        List {
            Section {
                Text(
                    "L’app non crea account, non richiede la posizione e non integra "
                    + "sistemi di analytics o pubblicità."
                )

                Text(
                    "Sul dispositivo salva soltanto la direzione scelta e una cache "
                    + "tecnica degli avvisi. Per scaricare dati e cartografia comunica "
                    + "con servizi esterni, che possono ricevere normali informazioni "
                    + "di rete, come l’indirizzo IP, secondo le rispettive informative."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section {
                Link(destination: autostradePrivacyURL) {
                    Label("Privacy · Autostrade per l’Italia", systemImage: "safari")
                }
            }
        }
        .navigationTitle("Privacy")
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
                Link(destination: appleMapsTermsURL) {
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
