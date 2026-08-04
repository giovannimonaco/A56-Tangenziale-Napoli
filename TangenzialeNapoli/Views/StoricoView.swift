import SwiftUI

/// On-device history of past closures for one direction, grouped by day
/// (most recent first), with the retention setting.
struct StoricoView: View {
    let viewModel: ClosuresViewModel
    @Binding var direction: Direction

    @AppStorage(ClosureArchive.retentionKey) private var retentionDays = ClosureArchive.defaultRetentionDays

    private var days: [ClosuresViewModel.DirectionDay] { viewModel.pastDays(for: direction) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                DirectionSwitch(selection: $direction)
                retentionControl

                if days.isEmpty {
                    emptyState
                } else {
                    ForEach(days) { day in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(day.label)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)

                            ForEach(day.roadBlocks) { closure in link(closure) }
                            ForEach(day.rampClosures) { closure in link(closure) }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color.a56Canvas)
        .navigationTitle("Archivio locale")
        .navigationBarTitleDisplayMode(.inline)
        // Re-apply the new duration to the stored archive immediately (no network).
        .onChange(of: retentionDays) { _, _ in viewModel.applyRetentionChange() }
    }

    // MARK: - Duration setting

    private var retentionControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Stepper(value: $retentionDays, in: 1...60) {
                Label("Conserva per \(retentionDays) giorni", systemImage: "clock.arrow.circlepath")
                    .font(.subheadline.weight(.medium))
            }
            Text("Le chiusure più vecchie di \(retentionDays) giorni vengono rimosse dall'archivio.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Raccolta tecnica salvata su questo dispositivo: non è uno storico ufficiale o completo.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .a56Surface(radius: 16)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Nessun evento archiviato \(direction.headingPhrase)")
                .font(.headline)
            Text("Gli eventi compaiono qui solo se questo dispositivo li ha ricevuti in precedenza.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    @ViewBuilder
    private func link(_ closure: RoadClosure) -> some View {
        NavigationLink(value: closure) {
            if closure.kind == .roadBlocked {
                RoadBlockCard(closure: closure)
            } else {
                RampClosureCard(closure: closure)
            }
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("Con storico") {
    // Sample closures dated a few days ago so they count as "past" history.
    let pastReference = Calendar.current.date(byAdding: .day, value: -4, to: .now)!
    NavigationStack {
        StoricoView(
            viewModel: .preview(closures: SampleClosures.make(reference: pastReference)),
            direction: .constant(.towardPozzuoli)
        )
    }
}

#Preview("Vuoto") {
    NavigationStack {
        StoricoView(
            viewModel: .preview(closures: []),
            direction: .constant(.towardCapodichino)
        )
    }
}
#endif
