import SwiftUI
import WidgetKit

struct A56WidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    var isPreview = false

    /// Synthetic notices are used only by WidgetKit's gallery preview.
    /// The production snapshot and timeline always read the independent store.
    static func preview(at date: Date = .now) -> A56WidgetEntry {
        let closures = [
            RoadClosure(
                id: "widget-preview-active", start: date.addingTimeInterval(-1800),
                end: date.addingTimeInterval(3600), direction: .towardCapodichino,
                fromExit: 9, toExit: 5, reason: "Esempio", isFullClosure: true
            ),
            RoadClosure(
                id: "widget-preview-next", start: date.addingTimeInterval(7200),
                end: date.addingTimeInterval(14400), direction: .towardPozzuoli,
                fromExit: 10, toExit: 12, reason: "Esempio", isFullClosure: true
            )
        ]
        return A56WidgetEntry(
            date: date,
            snapshot: WidgetSnapshot(fetchedAt: date, closures: closures, isComplete: true),
            isPreview: true
        )
    }
}

struct A56TimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> A56WidgetEntry {
        A56WidgetEntry(date: .now, snapshot: .unavailable)
    }

    func getSnapshot(in context: Context, completion: @escaping (A56WidgetEntry) -> Void) {
        if context.isPreview {
            completion(.preview())
            return
        }
        Task {
            let snapshot = await WidgetSnapshotStore.shared.cached()
            completion(A56WidgetEntry(date: .now, snapshot: snapshot))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<A56WidgetEntry>) -> Void) {
        Task {
            let snapshot = await WidgetSnapshotStore.shared.refresh()
            let now = Date()
            let entries = snapshot.timelineDates(from: now).map {
                A56WidgetEntry(date: $0, snapshot: snapshot)
            }
            // Jitter avoids having every installation contact the feed at once.
            let nextRefresh = now.addingTimeInterval(WidgetSnapshot.refreshInterval + Double.random(in: 0...120))
            completion(Timeline(entries: entries, policy: .after(nextRefresh)))
        }
    }
}

struct A56WidgetView: View {
    let entry: A56WidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 4) {
            A56WidgetHeader(
                status: entry.snapshot.status(at: entry.date), isPreview: entry.isPreview,
                isCompact: family == .systemSmall
            )
            if family == .systemSmall {
                ForEach(Direction.allCases) { direction in
                    A56WidgetCompactRow(
                        summary: entry.snapshot.summary(for: direction, at: entry.date),
                        hasData: entry.snapshot.fetchedAt != nil
                    )
                }
            } else {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(Direction.allCases) { direction in
                        A56WidgetDirectionColumn(
                            summary: entry.snapshot.summary(for: direction, at: entry.date),
                            hasData: entry.snapshot.fetchedAt != nil
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            Spacer(minLength: 0)
            A56WidgetFooter(fetchedAt: entry.snapshot.fetchedAt, reference: entry.date, isPreview: entry.isPreview)
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "a56napoli://closures"))
    }
}

private struct A56WidgetHeader: View {
    let status: WidgetSnapshot.Status
    let isPreview: Bool
    let isCompact: Bool

    var body: some View {
        if isCompact {
            VStack(alignment: .leading, spacing: 3) {
                A56WidgetTitle(isCompact: true)
                A56WidgetStatus(status: status, isPreview: isPreview)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                A56WidgetTitle(isCompact: false)
                Spacer(minLength: 0)
                A56WidgetStatus(status: status, isPreview: isPreview)
            }
        }
    }
}

private struct A56WidgetTitle: View {
    let isCompact: Bool

    var body: some View {
        Label("Chiusure A56", systemImage: "road.lanes")
            .font(isCompact ? .subheadline.weight(.semibold) : .headline)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }
}

private struct A56WidgetStatus: View {
    let status: WidgetSnapshot.Status
    let isPreview: Bool

    var body: some View {
        Text(isPreview ? "Esempio di anteprima" : status.label)
            .font(.caption2)
            .foregroundStyle(status == .current ? Color.secondary : Color.a56Caution)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }
}

private struct A56WidgetCompactRow: View {
    let summary: WidgetSnapshot.DirectionSummary
    let hasData: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(summary.direction.shortName)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 2)
            Text(hasData ? "\(summary.activeCount)" : "—")
                .font(.headline.monospacedDigit())
                .foregroundStyle(summary.activeCount > 0 ? Color.a56Block : Color.primary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hasData
            ? "\(summary.direction.towardLabel), \(summary.activeCount) chiusure segnalate in corso"
            : "\(summary.direction.towardLabel), dati non disponibili")
    }
}

private struct A56WidgetDirectionColumn: View {
    let summary: WidgetSnapshot.DirectionSummary
    let hasData: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(summary.direction.shortName, systemImage: summary.direction.systemImage)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(hasData ? "\(summary.activeCount) in corso" : "Da verificare")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(summary.activeCount > 0 ? Color.a56Block : Color.primary)
            if let next = summary.nextClosure {
                Text("Prossima \(next.start.formatted(ClosureFormat.dateStyle.day(.twoDigits).month(.twoDigits))) · \(ClosureFormat.timeLabel(next.start))")
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(next.isRampOnly
                     ? A56Line.driverLabel(for: next.rampExitNumber)
                     : "\(A56Line.driverLabel(for: next.fromExit)) → \(A56Line.driverLabel(for: next.toExit))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(hasData ? "Nessuna prossima segnalata" : "Apri per i dettagli")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct A56WidgetFooter: View {
    let fetchedAt: Date?
    let reference: Date
    let isPreview: Bool

    var body: some View {
        if isPreview {
            Text("Dati di esempio")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else if let fetchedAt {
            Text("Controllo \(ClosureFormat.updateTimeLabel(fetchedAt, reference: reference))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        } else {
            Text("Tocca per verificare gli avvisi")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

@main
struct A56WidgetBundle: WidgetBundle {
    var body: some Widget { A56ClosuresWidget() }
}

struct A56ClosuresWidget: Widget {
    let kind = "A56ClosuresWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: A56TimelineProvider()) { entry in
            A56WidgetView(entry: entry)
        }
        .configurationDisplayName("Chiusure A56")
        .description("Chiusure segnalate nelle due direzioni e prossimi avvisi. Si aggiorna online senza aprire l’app, con tempi decisi da iOS.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
