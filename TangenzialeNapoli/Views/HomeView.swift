//
//  HomeView.swift
//  TangenzialeNapoli
//
//  Current and future A56 restrictions on a stable west-to-east schematic.
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel: ClosuresViewModel
    @State private var isInfoPresented = false
    @AppStorage("selectedDirection") private var direction: Direction = .towardPozzuoli
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: ClosuresViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? ClosuresViewModel())
    }

    private struct RampCategoryGroup: Identifiable {
        let id: String
        let kind: ClosureRampImpact.Kind
        let closures: [RoadClosure]
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Chiusure")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: RoadClosure.self) {
                    ClosureDetailView(closure: $0)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            guard !viewModel.isLoading else { return }
                            Task { await viewModel.load() }
                        } label: {
                            if viewModel.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(viewModel.isLoading)
                        .accessibilityLabel(
                            viewModel.isLoading
                                ? "Aggiornamento in corso"
                                : "Aggiorna dati"
                            )
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isInfoPresented = true
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .accessibilityLabel("Info")
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    closuresControlPanel
                }
                .refreshable { await viewModel.load() }
                .onChange(of: direction) { _, newValue in
                    AppLog.log("direction → \(newValue.shortName)", "ui")
                }
                .sheet(isPresented: $isInfoPresented) {
                    NavigationStack {
                        InfoView(
                            viewModel: viewModel,
                            direction: $direction
                        )
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Fine") {
                                    isInfoPresented = false
                                }
                            }
                        }
                    }
                }
        }
        .tint(direction.tint)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.dataSource == nil {
            loadingOverview
        } else {
            closureOverview
        }
    }

    private var activeNow: [RoadClosure] {
        viewModel.activeClosures(for: direction)
    }

    private var closureOverview: some View {
        // Materialized once per render: `upcomingDays` does Calendar work for
        // every closure, and three separate reads per body would repeat it.
        let scheduledDays = viewModel.upcomingDays(for: direction).filter { !$0.isEmpty }
        let scheduledCount = scheduledDays.reduce(0) { total, day in
            total + day.roadBlocks.count + day.rampClosures.count
        }

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                nowPanel

                scheduledSectionHeader(count: scheduledCount)

                if scheduledDays.isEmpty {
                    if dataIsStale {
                        scheduledUnavailablePanel
                    } else {
                        noScheduledPanel
                    }
                } else {
                    ForEach(scheduledDays) { day in
                        scheduledPanel(day)
                    }
                }

            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .background(Color.a56Canvas)
        .animation(reduceMotion ? nil : .snappy, value: direction)
    }

    private var loadingOverview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Color.a56ControlFill)
                            .frame(width: 46, height: 46)
                        VStack(alignment: .leading, spacing: 7) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.a56ControlFill)
                                .frame(width: 76, height: 11)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.a56ControlFill)
                                .frame(width: 190, height: 19)
                        }
                    }
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.a56ControlFill)
                        .frame(height: 20)
                }
                .a56Surface()

                HStack(spacing: 8) {
                    ProgressView()
                    Text("Controllo della A56 in corso…")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)

                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.a56Surface)
                        .frame(height: 150)
                        .overlay(alignment: .topLeading) {
                            VStack(alignment: .leading, spacing: 10) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.a56ControlFill)
                                    .frame(width: 120, height: 15)
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.a56ControlFill)
                                    .frame(height: 12)
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.a56ControlFill)
                                    .frame(width: 220, height: 12)
                            }
                            .padding(16)
                        }
                }
            }
            .padding(16)
        }
        .background(Color.a56Canvas)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Caricamento delle chiusure A56 in corso")
    }

    private var closuresControlPanel: some View {
        VStack(spacing: 10) {
            DirectionSwitch(selection: $direction) { candidate in
                let closures = viewModel.activeClosures(for: candidate)
                return (
                    label: directionStatusLabel(closures, needsVerification: dataIsStale),
                    color: closures.isEmpty
                        ? (dataIsStale ? .a56Unknown : .a56Open)
                        : .a56Block
                )
            }

            if let source = viewModel.dataSource {
                dataSourceRow(source)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.55)
        }
    }

    private func directionStatusLabel(
        _ closures: [RoadClosure],
        needsVerification: Bool
    ) -> String {
        guard !closures.isEmpty else {
            return needsVerification ? "Nessuna segnalazione" : "Tutto aperto"
        }

        let roadCount = closures.filter { $0.kind == .roadBlocked }.count
        let rampCount = closures
            .filter { $0.kind == .rampsClosed }
            .reduce(0) { $0 + max(1, $1.closedRamps.count) }
        var parts: [String] = []
        if roadCount > 0 {
            parts.append("\(roadCount) \(roadCount == 1 ? "tratto" : "tratti")")
        }
        if rampCount > 0 {
            parts.append("\(rampCount) \(rampCount == 1 ? "accesso" : "accessi")")
        }
        return parts.joined(separator: " · ")
    }

    private var nowPanel: some View {
        let hasRoadBlock = activeNow.contains { $0.kind == .roadBlocked }
        let needsVerification = dataIsStale
        let accent = activeNow.isEmpty
            ? (needsVerification ? Color.a56Caution : Color.a56Open)
            : Color.a56Block

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(
                    systemName: needsVerification && activeNow.isEmpty
                        ? "exclamationmark.triangle.fill"
                        : (activeNow.isEmpty ? "checkmark" : (hasRoadBlock ? "nosign" : "arrow.trianglehead.branch"))
                )
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.a56OnStatus)
                    .frame(width: 46, height: 46)
                    .background(accent, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Adesso · \(direction.headingPhrase)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(nowHeadline(hasRoadBlock: hasRoadBlock, needsVerification: needsVerification))
                        .font(.title3.weight(.bold))
                        .tracking(-0.25)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(nowSupportingText(hasRoadBlock: hasRoadBlock, needsVerification: needsVerification))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            A56SchematicView(
                closures: activeNow,
                direction: direction,
                showsEndpointLabels: false,
                isStatusKnown: !needsVerification
            )

            if !activeNow.isEmpty {
                Divider()
                closureRows(activeNow, active: true)
            }
        }
        .a56Surface(accent: accent)
    }

    private var noScheduledPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.a56Open)
                    .frame(width: 40, height: 40)
                    .background(Color.a56Open.opacity(0.11), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Nessuna chiusura pubblicata")
                        .font(.headline)
                    Text("Non risultano altre limitazioni nelle giornate disponibili.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            A56SchematicView(
                closures: [],
                direction: direction,
                showsEndpointLabels: false
            )
        }
        .a56Surface()
    }

    private var scheduledUnavailablePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.a56Caution)
                    .frame(width: 40, height: 40)
                    .background(Color.a56Caution.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Nessun orario disponibile")
                        .font(.headline)
                    Text("I dati non sono completi o aggiornati. Riprova e controlla i canali del gestore.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            A56SchematicView(
                closures: [],
                direction: direction,
                showsEndpointLabels: false,
                isStatusKnown: false
            )
        }
        .a56Surface(accent: .a56Caution)
    }

    private func scheduledPanel(_ day: ClosuresViewModel.DirectionDay) -> some View {
        let closures = closures(in: day)
        return VStack(alignment: .leading, spacing: 14) {
            scheduledDayHeader(day, closures: closures)

            A56SchematicView(
                closures: closures,
                direction: direction,
                showsEndpointLabels: false,
                isStatusKnown: !dataIsStale
            )

            Divider()

            closureRows(closures, active: false, scheduledDay: day.date)
        }
        .a56Surface(
            accent: closures.isEmpty ? nil : .a56Block
        )
    }

    private func scheduledDayHeader(
        _ day: ClosuresViewModel.DirectionDay,
        closures: [RoadClosure]
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                dayHeading(day)
                Spacer()
                statusLabel(for: closures, emptyLabel: "Nessuna")
            }

            VStack(alignment: .leading, spacing: 8) {
                dayHeading(day)
                statusLabel(for: closures, emptyLabel: "Nessuna")
            }
        }
    }

    private func dayHeading(_ day: ClosuresViewModel.DirectionDay) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(day.label)
                .font(.headline)
            Text(ClosureFormat.dayDateLabel(day.date))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func scheduledSectionHeader(count: Int) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                scheduledSectionTitle
                Spacer()
                scheduledCountLabel(count: count)
            }

            VStack(alignment: .leading, spacing: 5) {
                scheduledSectionTitle
                scheduledCountLabel(count: count)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private var scheduledSectionTitle: some View {
        Label("Programmate", systemImage: "calendar")
            .font(.title2.weight(.bold))
            .tracking(-0.35)
    }

    @ViewBuilder
    private func scheduledCountLabel(count: Int) -> some View {
        if count > 0 {
            Text("\(count) \(count == 1 ? "chiusura" : "chiusure")")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func nowHeadline(hasRoadBlock: Bool, needsVerification: Bool) -> String {
        if needsVerification {
            if activeNow.isEmpty { return "Nessuna segnalazione salvata" }
            return hasRoadBlock ? "Interruzione segnalata" : "Accessi segnalati"
        }
        if activeNow.isEmpty { return "Percorso regolare" }
        return hasRoadBlock ? "Tangenziale interrotta" : "Accessi limitati"
    }

    private func nowSupportingText(hasRoadBlock: Bool, needsVerification: Bool) -> String {
        if needsVerification {
            if activeNow.isEmpty {
                return "I dati salvati non indicano limitazioni, ma lo stato attuale non è confermato."
            }
            if hasRoadBlock {
                return "L’ultimo dato indica uno o più tratti chiusi, ma la segnalazione non è aggiornata."
            }
            return "L’ultimo dato indica accessi chiusi, ma la segnalazione non è aggiornata."
        }
        if activeNow.isEmpty {
            return "Nessuna limitazione nota nella direzione selezionata."
        }
        if hasRoadBlock {
            return "Uno o più tratti non sono percorribili: apri il dettaglio prima di partire."
        }
        return "La carreggiata resta percorribile, ma alcune entrate o uscite sono chiuse."
    }

    private var dataIsStale: Bool {
        viewModel.dataSource?.isStale ?? true
    }

    private func closures(in day: ClosuresViewModel.DirectionDay) -> [RoadClosure] {
        (day.roadBlocks + day.rampClosures).sorted { $0.start < $1.start }
    }

    @ViewBuilder
    private func closureRows(
        _ closures: [RoadClosure],
        active: Bool,
        scheduledDay: Date? = nil
    ) -> some View {
        let roadBlocks = closures.filter { $0.kind == .roadBlocked }
        let rampGroups = rampCategoryGroups(in: closures)

        VStack(spacing: 0) {
            ForEach(Array(roadBlocks.enumerated()), id: \.element.id) { index, closure in
                roadBlockDisclosure(closure, active: active, scheduledDay: scheduledDay)
                if index < roadBlocks.count - 1 || !rampGroups.isEmpty {
                    Divider()
                        .padding(.leading, 42)
                }
            }

            ForEach(Array(rampGroups.enumerated()), id: \.element.id) { index, group in
                rampCategoryGroup(group, active: active, scheduledDay: scheduledDay)

                if index < rampGroups.count - 1 {
                    Divider()
                        .padding(.leading, 42)
                }
            }
        }
    }

    private func rampCategoryGroups(in closures: [RoadClosure]) -> [RampCategoryGroup] {
        [ClosureRampImpact.Kind.entrance, .exit].compactMap { kind in
            let matchingClosures = closures
                .filter { closure in
                    closure.kind == .rampsClosed
                        && closure.closedRamps.contains { $0.kind == kind }
                }
                .sorted { $0.rampExitNumber < $1.rampExitNumber }
            guard !matchingClosures.isEmpty else { return nil }
            return RampCategoryGroup(
                id: kind.rawValue,
                kind: kind,
                closures: matchingClosures
            )
        }
    }

    private func rowTime(
        _ closure: RoadClosure,
        active: Bool,
        scheduledDay: Date?
    ) -> String {
        if active {
            return ClosureFormat.endLabel(closure, reference: viewModel.now)
        }
        if let scheduledDay {
            return ClosureFormat.scheduledTimeLabel(closure, on: scheduledDay)
        }
        return ClosureFormat.timeRange(closure)
    }

    private func compactRowTime(
        _ closure: RoadClosure,
        active: Bool,
        scheduledDay: Date?
    ) -> String {
        rowTime(closure, active: active, scheduledDay: scheduledDay)
            .replacingOccurrences(of: "fino alle ", with: "fino ")
            .replacingOccurrences(of: " – ", with: "–")
            .replacingOccurrences(of: " (+1)", with: " +1")
    }

    private func groupHasOneTime(
        _ group: RampCategoryGroup,
        active: Bool,
        scheduledDay: Date?
    ) -> Bool {
        Set(group.closures.map {
            compactRowTime($0, active: active, scheduledDay: scheduledDay)
        }).count == 1
    }

    private func rampCategoryGroup(
        _ group: RampCategoryGroup,
        active: Bool,
        scheduledDay: Date?
    ) -> some View {
        let impactCount = group.closures.reduce(0) { count, closure in
            count + closure.closedRamps.filter { $0.kind == group.kind }.count
        }

        return DisclosureGroup {
            VStack(spacing: 0) {
                ForEach(Array(group.closures.enumerated()), id: \.element.id) { index, closure in
                    rampClosureLink(
                        closure,
                        kind: group.kind,
                        active: active,
                        scheduledDay: scheduledDay
                    )
                        .padding(.leading, 8)
                    if index < group.closures.count - 1 {
                        Divider()
                            .padding(.leading, 50)
                    }
                }
            }
        } label: {
            HStack(spacing: 11) {
                Image(systemName: group.kind.systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.a56OnStatus)
                    .frame(width: 30, height: 30)
                    .background(Color.a56Block, in: RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 3) {
                    Text(rampCategoryTitle(kind: group.kind, count: impactCount))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if let first = group.closures.first,
                       groupHasOneTime(group, active: active, scheduledDay: scheduledDay) {
                        Text(compactRowTime(first, active: active, scheduledDay: scheduledDay))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 6)
            }
            .padding(.vertical, 10)
        }
        .tint(.secondary)
    }

    private func rampCategoryTitle(
        kind: ClosureRampImpact.Kind,
        count: Int
    ) -> String {
        switch (kind, count) {
        case (.entrance, 1): "1 entrata chiusa"
        case (.entrance, _): "\(count) entrate chiuse"
        case (.exit, 1): "1 uscita chiusa"
        case (.exit, _): "\(count) uscite chiuse"
        }
    }

    private func rampClosureLink(
        _ closure: RoadClosure,
        kind: ClosureRampImpact.Kind,
        active: Bool,
        scheduledDay: Date?
    ) -> some View {
        NavigationLink(value: closure) {
            HStack(spacing: 10) {
                Image(systemName: kind.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.a56Block)
                    .frame(width: 26, height: 26)
                    .background(Color.a56Block.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(A56Line.interchangeLabel(for: closure.rampExitNumber))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if scheduledDay != nil {
                        Text(compactRowTime(
                            closure,
                            active: active,
                            scheduledDay: scheduledDay
                        ))
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func roadBlockDisclosure(
        _ closure: RoadClosure,
        active: Bool,
        scheduledDay: Date?
    ) -> some View {
        DisclosureGroup {
            let exits = closedStretchExits(closure)
            VStack(spacing: 0) {
                ForEach(Array(exits.enumerated()), id: \.element.id) { index, exit in
                    NavigationLink(value: closure) {
                        HStack(spacing: 10) {
                            Image(systemName: "road.lanes")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.a56Block)
                                .frame(width: 26, height: 26)
                                .background(Color.a56Block.opacity(0.12), in: Circle())

                            Text(A56Line.interchangeLabel(for: exit.number))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 6)

                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                    .padding(.vertical, 9)

                    if index < exits.count - 1 {
                        Divider()
                            .padding(.leading, 50)
                    }
                }
            }
        } label: {
            HStack(spacing: 11) {
                Image(systemName: closureIcon(closure))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.a56OnStatus)
                    .frame(width: 30, height: 30)
                    .background(Color.a56Block, in: RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 3) {
                    Text(closure.headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(rowTime(closure, active: active, scheduledDay: scheduledDay))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 6)
            }
            .padding(.vertical, 10)
        }
        .tint(.secondary)
    }

    private func closedStretchExits(_ closure: RoadClosure) -> [A56Exit] {
        let exits = A56Line.exits(from: closure.fromExit, to: closure.toExit)
        return closure.direction.goesUpTheLine ? exits : Array(exits.reversed())
    }

    private func closureIcon(_ closure: RoadClosure) -> String {
        guard closure.kind == .rampsClosed else { return "nosign" }
        return switch (!closure.closedEntrances.isEmpty, !closure.closedExits.isEmpty) {
        case (true, true): "arrow.up.and.down"
        case (true, false): "arrow.uturn.up"
        default: "arrow.uturn.down"
        }
    }

    private func closurePlace(_ closure: RoadClosure) -> String {
        if closure.kind == .rampsClosed {
            return A56Line.interchangeLabel(for: closure.rampExitNumber)
        }
        return "\(A56Line.driverLabel(for: closure.fromExit)) → "
            + A56Line.driverLabel(for: closure.toExit)
    }

    private func statusLabel(
        for closures: [RoadClosure],
        emptyLabel: String
    ) -> some View {
        let isEmpty = closures.isEmpty
        let color = isEmpty ? Color.a56Open : Color.a56Block
        let summary = isEmpty
            ? emptyLabel
            : "\(closures.count) \(closures.count == 1 ? "limitazione" : "limitazioni")"
        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(summary)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
    }

    private func dataSourceRow(_ source: ClosuresViewModel.DataSource) -> some View {
        HStack(spacing: 6) {
            Image(
                systemName: viewModel.isLoading
                    ? "arrow.trianglehead.2.clockwise.rotate.90"
                    : (source.isStale ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
            )
            Text(updateTimestampLabel(for: source))
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(source.isStale ? Color.a56Caution : Color.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    private func updateTimestampLabel(
        for source: ClosuresViewModel.DataSource
    ) -> String {
        if viewModel.isLoading { return "Aggiornamento in corso…" }

        switch source {
        case .live(let timestamp, _):
            return source.isStale
                ? "Dati non aggiornati · ultimo \(timestamp.formatted(date: .omitted, time: .shortened))"
                : "Aggiornato alle \(timestamp.formatted(date: .omitted, time: .shortened))"
        case .cache(let timestamp):
            return "Dati non aggiornati · ultimo \(timestamp.formatted(date: .omitted, time: .shortened))"
        case .unavailable:
            return "Servizio non raggiungibile · verifica i canali del gestore"
        }
    }
}

#if DEBUG
#Preview {
    HomeView(viewModel: .preview(closures: SampleClosures.make()))
}
#endif
