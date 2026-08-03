//
//  OverviewMapView.swift
//  TangenzialeNapoli
//
//  Visual A56 status on Apple Maps. The home remains the detailed dashboard;
//  this screen answers "where is it?" at a glance and reveals details on tap.
//

import SwiftUI
import MapKit

struct OverviewMapView: View {
    let closures: [RoadClosure]
    @Binding var direction: Direction
    var now: Date = .now
    var lastUpdatedAt: Date?
    var dataIsStale = false
    var isLoading = false
    let onReload: () async -> Void

    @State private var scope: Scope
    @State private var isReloading = false
    @State private var selectedWindowID: String?
    @State private var selectedExitNumber: Int?
    @State private var visibleLongitudeDelta = 0.250
    @State private var isAtStandardPosition = true
    @State private var isLegendPresented = false
    @State private var mapViewportSize: CGSize = .zero
    @State private var scopePanelHeight: CGFloat = 180
    @Namespace private var mapScope
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.850, longitude: 14.190),
            span: MKCoordinateSpan(latitudeDelta: 0.075, longitudeDelta: 0.250)
        )
    )

    enum Scope: String, CaseIterable, Identifiable {
        case now, scheduled

        var id: String { rawValue }
        var label: String {
            switch self {
            case .now: "Adesso"
            case .scheduled: "Programmate"
            }
        }
    }

    init(
        closures: [RoadClosure],
        direction: Binding<Direction>,
        now: Date = .now,
        lastUpdatedAt: Date? = nil,
        dataIsStale: Bool = false,
        isLoading: Bool = false,
        initialScope: Scope = .now,
        onReload: @escaping () async -> Void = {}
    ) {
        self.closures = closures
        _direction = direction
        self.now = now
        self.lastUpdatedAt = lastUpdatedAt
        self.dataIsStale = dataIsStale
        self.isLoading = isLoading
        self.onReload = onReload
        _scope = State(initialValue: initialScope)
#if DEBUG
        if let focusArgument = CommandLine.arguments.first(where: {
            $0.hasPrefix("--map-focus-exit=")
        }),
           let exitNumber = Int(focusArgument.split(separator: "=").last ?? ""),
           let focus = A56RouteGeometry.coordinate(
               for: exitNumber,
               direction: direction.wrappedValue
           ) {
            let longitudeDelta = 0.035
            _visibleLongitudeDelta = State(initialValue: longitudeDelta)
            _isAtStandardPosition = State(initialValue: false)
            _camera = State(
                initialValue: .region(
                    MKCoordinateRegion(
                        center: focus,
                        span: MKCoordinateSpan(
                            latitudeDelta: 0.026,
                            longitudeDelta: longitudeDelta
                        )
                    )
                )
            )
        }
#endif
    }

    private struct ClosureTimeWindow: Identifiable {
        let id: String
        let start: Date
        let end: Date
        let closures: [RoadClosure]
    }

    private struct ExitRampStatus {
        let label: String
        let systemImage: String
    }

    var body: some View {
        Map(
            position: $camera,
            interactionModes: [.pan, .zoom, .rotate],
            scope: mapScope
        ) {
            MapPolyline(coordinates: routeCoordinates)
                .stroke(Color.a56RouteCasing.opacity(0.95), lineWidth: isOverviewZoom ? 7 : 9)
            MapPolyline(coordinates: routeCoordinates)
                .stroke(routeOpenColor, lineWidth: isOverviewZoom ? 4 : 5)

            ForEach(scoped.filter { $0.kind == .roadBlocked }) { closure in
                MapPolyline(coordinates: coordinates(for: closure))
                    .stroke(
                        .a56Block,
                        style: StrokeStyle(lineWidth: isOverviewZoom ? 7 : 10, lineCap: .round)
                    )
            }

            ForEach(referenceExits) { exit in
                Annotation(exit.shortLabel, coordinate: coordinate(for: exit), anchor: .center) {
                    Button {
                        withAnimation(reduceMotion ? nil : .snappy) {
                            selectedExitNumber = exit.number
                        }
                    } label: {
                        exitAnnotation(exit)
                    }
                    .buttonStyle(A56PressButtonStyle())
                    .accessibilityLabel(
                        exit.commercialNumber.map { "Uscita \($0), \(exit.name)" }
                            ?? "Accesso Italia 90, \(exit.name)"
                    )
                    .accessibilityValue(
                        exitHasProblem(exit)
                            ? problemAccessibilityValue(for: exit)
                            : (dataIsStale
                                ? "Stato non confermato"
                                : "Nessuna limitazione nella fascia selezionata")
                    )
                    .accessibilityHint("Mostra i dettagli dello svincolo")
                    .zIndex(2)
                }
                .annotationTitles(.hidden)
            }

        }
        .mapStyle(
            .standard(
                elevation: .flat,
                emphasis: .muted,
                pointsOfInterest: .excludingAll,
                showsTraffic: true
            )
        )
        .mapControls {
            MapScaleView()
        }
        .overlay(alignment: .top) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    legendControl

                    if !isAtStandardPosition {
                        mapResetControl
                            .transition(.scale.combined(with: .opacity))
                    }

                    if isLegendPresented {
                        legendPanel
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }

                Spacer()

                MapCompass(scope: mapScope)
                    .frame(width: 56, height: 56)
            }
            .padding(.top, scopePanelHeight + 8)
            .padding(.horizontal, 10)
        }
        .mapScope(mapScope)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            guard size.width > 0, size.height > 0, size != mapViewportSize else {
                return
            }
            mapViewportSize = size
            if isAtStandardPosition {
                setOverviewCamera(viewportSize: size, animated: false)
            }
        }
        .overlay(alignment: .top) {
            scopePanel
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    guard height > 0, abs(height - scopePanelHeight) > 0.5 else { return }
                    scopePanelHeight = height
                    if isAtStandardPosition {
                        setOverviewCamera(animated: false)
                    }
                }
                .zIndex(10)
        }
        .overlay(alignment: .bottom) {
            bottomPanel
                .padding(.horizontal, 10)
                .padding(.bottom, 30)
        }
//        .overlay(alignment: .bottomLeading) {
//            Link("A56 © OpenStreetMap", destination: A56RouteGeometry.attributionURL)
//                .font(.system(size: 8, weight: .medium))
//                .foregroundStyle(.secondary)
//                .padding(.horizontal, 5)
//                .padding(.vertical, 3)
//                .background(.regularMaterial, in: Capsule())
//                .padding(.leading, 8)
//                .padding(.bottom, 34)
//                .accessibilityLabel("Tracciato A56 da OpenStreetMap")
//        }
        .navigationTitle("Mappa A56")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    guard !refreshInProgress else { return }
                    isReloading = true
                    Task {
                        await onReload()
                        isReloading = false
                    }
                } label: {
                    if refreshInProgress {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(refreshInProgress)
                .accessibilityLabel(refreshInProgress ? "Aggiornamento in corso" : "Aggiorna dati")
            }

        }
        .onMapCameraChange(frequency: .onEnd) { context in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                visibleLongitudeDelta = context.region.span.longitudeDelta
                isAtStandardPosition = !camera.positionedByUser
            }
        }
        .onChange(of: scope) { _, _ in
            selectedWindowID = nil
            selectedExitNumber = nil
        }
        .onChange(of: direction) { _, _ in
            selectedExitNumber = nil
            if isAtStandardPosition {
                setOverviewCamera(animated: false)
            }
        }
    }

    // MARK: - Time scope

    private var scoped: [RoadClosure] {
        if scope == .now {
            return activeClosures(for: direction)
        }
        return (selectedTimeWindow?.closures ?? []).filter {
            $0.matches(direction: direction)
        }
    }

    private var refreshInProgress: Bool { isLoading || isReloading }

    private var initialFetchInProgress: Bool {
        refreshInProgress && lastUpdatedAt == nil && closures.isEmpty
    }

    /// Keep the route neutral until the first response arrives: painting it
    /// as open early would communicate an all-clear that has not been checked.
    private var routeOpenColor: Color {
        dataIsStale ? .a56Unknown : .a56Open
    }

    private func activeClosures(for direction: Direction) -> [RoadClosure] {
        closures.filter {
            $0.matches(direction: direction) && $0.start <= now && $0.end > now
        }
    }

    private var availableTimeWindows: [ClosureTimeWindow] {
        guard scope == .scheduled else { return [] }
        let calendar = Calendar.current
        let upcoming = closures.filter { $0.start > now }
        let grouped = Dictionary(grouping: upcoming) {
            calendar.startOfDay(for: $0.start)
        }
        return grouped.map { day, _ in
            let allClosuresForDay = closures.filter {
                $0.end > now
                    && $0.scheduleDays(notBefore: now, calendar: calendar).contains(day)
            }
            let sorted = allClosuresForDay.sorted { $0.start < $1.start }
            return ClosureTimeWindow(
                id: "night#\(Int(day.timeIntervalSince1970))",
                start: day,
                end: calendar.date(byAdding: .day, value: 1, to: day) ?? day,
                closures: sorted
            )
        }
        .sorted { lhs, rhs in
            lhs.start == rhs.start ? lhs.end < rhs.end : lhs.start < rhs.start
        }
    }

    private var selectedTimeWindow: ClosureTimeWindow? {
        if let selectedWindowID,
           let selected = availableTimeWindows.first(where: { $0.id == selectedWindowID }) {
            return selected
        }
        return availableTimeWindows.first
    }

    // MARK: - Map content

    /// The line numbering is a stable visual layer: every exit remains visible
    /// in teal unless a closure marks that exit red.
    private var referenceExits: [A56Exit] {
        A56Line.exits
    }

    private var selectedExit: A56Exit? {
        selectedExitNumber.flatMap(A56Line.exit)
    }

    private var isOverviewZoom: Bool {
        visibleLongitudeDelta > 0.16
    }

    private var fallbackOverviewRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.850, longitude: 14.190),
            span: MKCoordinateSpan(latitudeDelta: 0.075, longitudeDelta: 0.250)
        )
    }

    private func resetMapPosition() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
            selectedExitNumber = nil
            setOverviewCamera(animated: false)
        }
    }

    private func setOverviewCamera(
        viewportSize: CGSize? = nil,
        animated: Bool
    ) {
        let size = viewportSize ?? mapViewportSize
        let mapRect = overviewMapRect(viewportSize: size)
        let region = mapRect.map(MKCoordinateRegion.init) ?? fallbackOverviewRegion
        let update = {
            camera = mapRect.map(MapCameraPosition.rect)
                ?? .region(fallbackOverviewRegion)
            visibleLongitudeDelta = region.span.longitudeDelta
            isAtStandardPosition = true
        }

        if animated {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35), update)
        } else {
            update()
        }
    }

    private func overviewMapRect(viewportSize: CGSize) -> MKMapRect? {
        guard viewportSize.width > 0,
              viewportSize.height > 0,
              let routeRect = routeBoundingMapRect
        else { return nil }

        // The controls cover a large part of the map on compact displays.
        // Fit the route inside the genuinely visible area instead of centring
        // it in the full Map frame, where the eastern exits would be hidden.
        // Reserve the larger "Programmate" panel in both modes so changing
        // the time scope never changes the camera.
        let reservedPanelHeight = max(180, scopePanelHeight + 8)
        let horizontalPadding: CGFloat = viewportSize.width < 430 ? 26 : 34
        let verticalPadding: CGFloat = 24
        let bottomObstruction = min(
            130,
            max(96, viewportSize.height * 0.11)
        )
        let usableWidth = max(1, viewportSize.width - 2 * horizontalPadding)
        let usableHeight = max(
            1,
            viewportSize.height
                - reservedPanelHeight
                - bottomObstruction
                - 2 * verticalPadding
        )
        let mapPointsPerScreenPoint = max(
            routeRect.width / usableWidth,
            routeRect.height / usableHeight
        ) * 1.08

        let visibleWidth = viewportSize.width * mapPointsPerScreenPoint
        let visibleHeight = viewportSize.height * mapPointsPerScreenPoint
        let routeScreenCenterY = reservedPanelHeight
            + verticalPadding
            + usableHeight / 2

        return MKMapRect(
            x: routeRect.midX - visibleWidth / 2,
            y: routeRect.midY - routeScreenCenterY * mapPointsPerScreenPoint,
            width: visibleWidth,
            height: visibleHeight
        )
    }

    private var routeBoundingMapRect: MKMapRect? {
        guard let first = routeCoordinates.first else { return nil }

        let firstPoint = MKMapPoint(first)
        var minimumX = firstPoint.x
        var maximumX = firstPoint.x
        var minimumY = firstPoint.y
        var maximumY = firstPoint.y

        for coordinate in routeCoordinates.dropFirst() {
            let point = MKMapPoint(coordinate)
            minimumX = min(minimumX, point.x)
            maximumX = max(maximumX, point.x)
            minimumY = min(minimumY, point.y)
            maximumY = max(maximumY, point.y)
        }

        return MKMapRect(
            x: minimumX,
            y: minimumY,
            width: max(1, maximumX - minimumX),
            height: max(1, maximumY - minimumY)
        )
    }

    private var mapResetControl: some View {
        Button {
            resetMapPosition()
        } label: {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.a56GlassBorder.opacity(0.45), lineWidth: 0.5)
                    }
                    .shadow(color: Color.a56Open.opacity(0.13), radius: 5, y: 2)

                Image(systemName: "viewfinder")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 56, height: 56)
            .contentShape(Circle())
        }
        .buttonStyle(A56PressButtonStyle())
        .zIndex(20)
        .accessibilityLabel("Mostra tutta la tangenziale")
    }

    private var legendControl: some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy) {
                isLegendPresented.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.a56GlassBorder.opacity(0.45), lineWidth: 0.5)
                    }
                    .shadow(color: Color.a56Open.opacity(0.13), radius: 5, y: 2)

                Image(systemName: isLegendPresented ? "xmark" : "list.bullet")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 56, height: 56)
            .contentShape(Circle())
        }
        .buttonStyle(A56PressButtonStyle())
        .zIndex(20)
        .accessibilityLabel(
            isLegendPresented ? "Chiudi legenda" : "Apri legenda"
        )
    }

    private var routeCoordinates: [CLLocationCoordinate2D] {
        let detailed = A56RouteGeometry.coordinates(for: direction)
        return detailed.isEmpty ? A56Line.coordinates : detailed
    }

    private func coordinates(for closure: RoadClosure) -> [CLLocationCoordinate2D] {
        A56RouteGeometry.segment(
            from: closure.lowerExit,
            to: closure.upperExit,
            direction: direction
        )
    }

    private func coordinate(for exit: A56Exit) -> CLLocationCoordinate2D {
        A56RouteGeometry.coordinate(for: exit.number, direction: direction) ?? exit.coordinate
    }

    private func exitAnnotation(_ exit: A56Exit) -> some View {
        let offset = exitMarkerVerticalOffset(exit)
        let color = exitHasProblem(exit) ? Color.a56Block : routeOpenColor
        let rampStatus = exitRampStatus(exit)

        return ZStack {
            if offset != 0 {
                Capsule()
                    .fill(color.opacity(0.85))
                    .frame(width: 1.5, height: abs(offset))
                    .offset(y: offset / 2)

                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                    .overlay { Circle().strokeBorder(.a56MarkerBorder, lineWidth: 1) }
            }

            exitMarker(exit)
                .offset(y: offset)

            if !isOverviewZoom, let rampStatus {
                rampStatusBadge(rampStatus)
                    .offset(y: exit.number.isMultiple(of: 2) ? -34 : 34)
            }
        }
        .frame(width: 48, height: 48)
    }

    private func exitMarker(_ exit: A56Exit) -> some View {
        let label = exit.commercialNumber.map(String.init) ?? "I90"
        let diameter: CGFloat = isOverviewZoom ? 18 : 23
        let highlightsProblem = exitHasProblem(exit)
        return Text(label)
            .font(.system(size: isOverviewZoom ? 9 : 11, weight: .bold, design: .rounded))
            .foregroundStyle(.a56OnStatus)
            .frame(
                width: exit.commercialNumber == nil ? diameter + 10 : diameter,
                height: diameter
            )
            .background {
                if highlightsProblem {
                    Capsule().fill(Color.a56Block)
                } else {
                    Capsule().fill(routeOpenColor)
                }
            }
            .overlay {
                Capsule().strokeBorder(Color.a56MarkerBorder.opacity(0.9), lineWidth: 1)
            }
            .shadow(
                color: (highlightsProblem ? Color.a56Block : routeOpenColor).opacity(0.4),
                radius: highlightsProblem ? 5 : 3,
                y: 1
            )
    }

    private func exitHasProblem(_ exit: A56Exit) -> Bool {
        scoped.contains { closureAffects($0, exit: exit) }
    }

    private func closureAffects(_ closure: RoadClosure, exit: A56Exit) -> Bool {
        switch closure.kind {
        case .roadBlocked:
            return closure.contains(exit: exit.number)
        case .rampsClosed:
            if closure.closedRamps.isEmpty {
                // Compatibility with archives created before ramp impacts were
                // stored explicitly.
                return closure.rampExitNumber == exit.number
            }
            return closure.closedRamps(for: direction).contains {
                $0.exitNumber == exit.number
            }
        }
    }

    private func exitRampStatus(_ exit: A56Exit) -> ExitRampStatus? {
        let impacts = scoped
            .flatMap { $0.closedRamps(for: direction) }
            .filter { $0.exitNumber == exit.number }
        let hasEntrance = impacts.contains { $0.kind == .entrance }
        let hasExit = impacts.contains { $0.kind == .exit }

        switch (hasEntrance, hasExit) {
        case (true, true):
            return ExitRampStatus(
                label: "Entrata + uscita",
                systemImage: "arrow.up.and.down"
            )
        case (true, false):
            return ExitRampStatus(label: "Entrata", systemImage: "arrow.uturn.up")
        case (false, true):
            return ExitRampStatus(label: "Uscita", systemImage: "arrow.uturn.down")
        case (false, false):
            return nil
        }
    }

    private func problemAccessibilityValue(for exit: A56Exit) -> String {
        let problem = exitRampStatus(exit)?.label ?? "Tratto chiuso"
        return dataIsStale ? "\(problem), dato da verificare" : problem
    }

    private func rampStatusBadge(_ status: ExitRampStatus) -> some View {
        HStack(spacing: 4) {
            Image(systemName: status.systemImage)
            Text(status.label)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(.a56OnStatus)
        .padding(.horizontal, 7)
        .frame(height: 26)
        .fixedSize()
        .background(Color.a56Block, in: Capsule())
        .overlay { Capsule().strokeBorder(.a56MarkerBorder, lineWidth: 2) }
        .shadow(color: Color.a56Block.opacity(0.4), radius: 5, y: 2)
    }

    private func exitMarkerVerticalOffset(_ exit: A56Exit) -> CGFloat {
        guard isOverviewZoom else { return 0 }
        switch exit.number {
        case 1: return -16
        case 2: return 0
        case 3: return 14
        case 4: return -8
        default: break
        }
        return exit.number.isMultiple(of: 2) ? -12 : 12
    }

    // MARK: - Floating controls

    private var scopePanel: some View {
        VStack(spacing: 10) {
            currentDirectionControl

            scopeControl

            if scope == .scheduled {
                scheduledTimeControl
            }

            updateTimestamp
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.a56GlassBorder.opacity(0.48), lineWidth: 0.6)
        }
        .shadow(color: Color.a56Open.opacity(0.10), radius: 14, y: 6)
        .animation(reduceMotion ? nil : .snappy, value: scope)
    }

    private var scopeControl: some View {
        HStack(spacing: 4) {
            ForEach(Scope.allCases) { candidate in
                scopeSegment(candidate)
            }
        }
        .padding(4)
        .background(Color.a56ControlFill, in: RoundedRectangle(cornerRadius: 16))
    }

    private func scopeSegment(_ candidate: Scope) -> some View {
        let isSelected = scope == candidate
        return Button {
            scope = candidate
        } label: {
            Text(candidate.label)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.a56Selection.opacity(0.88))
                            .shadow(color: Color.a56Open.opacity(0.09), radius: 4, y: 2)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(A56PressButtonStyle())
        .accessibilityLabel(candidate.label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var currentDirectionControl: some View {
        DirectionSwitch(selection: $direction) { candidate in
            let relevant = statusClosures(for: candidate)
            return (
                label: currentStatusLabel(for: candidate),
                color: initialFetchInProgress
                    ? Color.secondary
                    : (relevant.isEmpty
                        ? (dataIsStale ? .a56Unknown : .a56Open)
                        : .a56Block)
            )
        }
    }

    private func statusClosures(for candidate: Direction) -> [RoadClosure] {
        if scope == .now {
            return activeClosures(for: candidate)
        }
        guard let window = selectedTimeWindow else { return [] }
        return windowClosures(window, direction: candidate)
    }

    private func currentStatusLabel(for candidate: Direction) -> String {
        if initialFetchInProgress { return "Controllo in corso" }
        let relevant = statusClosures(for: candidate)
        guard !relevant.isEmpty else {
            return dataIsStale ? "Nessuna segnalazione" : "Tutto aperto"
        }

        let roadCount = relevant.filter { $0.kind == .roadBlocked }.count
        let rampCount = relevant
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

    private var updateTimestamp: some View {
        HStack(spacing: 6) {
            Image(
                systemName: refreshInProgress
                    ? "arrow.trianglehead.2.clockwise.rotate.90"
                    : (dataIsStale ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
            )
            Text(updateTimestampLabel)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(dataIsStale && !refreshInProgress ? Color.a56Caution : Color.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    private var updateTimestampLabel: String {
        if refreshInProgress { return "Aggiornamento in corso…" }
        guard let lastUpdatedAt else { return "Servizio non raggiungibile · verifica il gestore" }
        return dataIsStale
            ? "Dati non aggiornati · ultimo \(timeLabel(lastUpdatedAt))"
            : "Aggiornato alle \(timeLabel(lastUpdatedAt))"
    }

    @ViewBuilder
    private var scheduledTimeControl: some View {
        if availableTimeWindows.isEmpty {
            Label(
                dataIsStale
                    ? "Nessun orario disponibile"
                    : "Nessuna chiusura programmata",
                systemImage: "calendar"
            )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(dataIsStale ? Color.a56Caution : Color.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
        } else {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(availableTimeWindows) { window in
                        scheduleWindowChip(window)
                    }
                }
            }
            .contentMargins(.horizontal, 4, for: .scrollContent)
            .frame(height: 62)
            .scrollClipDisabled()
            .scrollIndicators(.hidden)
        }
    }

    private func scheduleWindowChip(_ window: ClosureTimeWindow) -> some View {
        let isSelected = window.id == selectedTimeWindow?.id
        return Button {
            withAnimation(reduceMotion ? nil : .snappy) {
                selectedWindowID = window.id
                selectedExitNumber = nil
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(scheduledDayTitle(window.start))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(scheduledTimeSummary(window, direction: direction))
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? Color.a56Selection.opacity(0.9)
                    : Color.a56ControlFill,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color.primary.opacity(0.18) : .clear,
                        lineWidth: 0.75
                    )
            }
            .shadow(
                color: isSelected ? Color.a56Shadow.opacity(0.07) : .clear,
                radius: 2,
                y: 1
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(A56PressButtonStyle())
        .accessibilityLabel(
            "\(scheduledDayTitle(window.start)), "
            + "\(scheduledTimeSummary(window, direction: direction)), "
            + windowImpactLabel(window, direction: direction)
            + (dataIsStale ? ", dato da verificare" : "")
        )
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var bottomPanel: some View {
        if let selectedExit {
            selectedExitTray(selectedExit)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var legendPanel: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 7) {
            GridRow {
                Text("Tratto")
                legendState("Aperto", color: .a56Open, usesLine: true)
                legendState("Chiuso", color: .a56Block, usesLine: true)
            }

            Divider()
                .gridCellColumns(3)

            GridRow {
                Text("Entrata/uscita")
                legendState("Aperte", color: .a56Open, usesLine: false)
                legendState("Limitate", color: .a56Block, usesLine: false)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: true, vertical: true)
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.a56GlassBorder.opacity(0.55), lineWidth: 0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Legenda: colore verde petrolio per tratto o accesso percorribile; rosso per chiusura o limitazione"
        )
    }

    private func legendState(
        _ label: String,
        color: Color,
        usesLine: Bool
    ) -> some View {
        HStack(spacing: 5) {
            if usesLine {
                Capsule()
                    .fill(color)
                    .frame(width: 16, height: 4)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 11, height: 11)
                    .frame(width: 16)
            }
            Text(label)
                .fontWeight(.semibold)
        }
    }

    private func selectedExitTray(_ exit: A56Exit) -> some View {
        let problems = problems(at: exit)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(exit.commercialNumber.map(String.init) ?? "I90")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.a56OnStatus)
                    .frame(minWidth: 36, minHeight: 36)
                    .padding(.horizontal, exit.commercialNumber == nil ? 3 : 0)
                    .background(
                        problems.isEmpty
                            ? (dataIsStale ? Color.a56Caution : Color.a56Open)
                            : Color.a56Block,
                        in: Capsule()
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(exit.commercialNumber == nil ? "Accesso Italia 90" : "Uscita \(exit.commercialNumber!)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(exit.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Button {
                    withAnimation(reduceMotion ? nil : .snappy) { selectedExitNumber = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(A56PressButtonStyle())
                .accessibilityLabel("Chiudi dettagli")
            }

            if dataIsStale {
                Label(
                    problems.isEmpty
                        ? "Stato non confermato: aggiorna o verifica il gestore"
                        : "Limitazione non aggiornata: verifica prima di partire",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(.a56Caution)
            }

            if problems.isEmpty {
                if !dataIsStale {
                    Label(
                        "Nessuna limitazione nella fascia selezionata",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.a56Open)
                }
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(problems) { closure in
                            NavigationLink(value: closure) {
                                compactClosure(closure)
                            }
                            .buttonStyle(A56PressButtonStyle())
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.a56GlassBorder.opacity(0.5), lineWidth: 0.6)
        }
        .shadow(color: Color.a56Open.opacity(0.12), radius: 12, y: 5)
    }

    private func problems(at exit: A56Exit) -> [RoadClosure] {
        scoped.filter { closureAffects($0, exit: exit) }
    }

    private func compactClosure(_ closure: RoadClosure) -> some View {
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: closure.kind == .roadBlocked ? "nosign" : "arrow.trianglehead.branch")
                Text(closure.headline)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.a56Block)

            Text(mapTime(closure))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            if closure.affectsBothDirections {
                Text("Entrambe le direzioni")
            }
        }
        .font(.caption)
        .padding(12)
        .frame(width: 210, alignment: .leading)
        .background(Color.a56MapCard, in: RoundedRectangle(cornerRadius: 14))
    }

    private func mapTime(_ closure: RoadClosure) -> String {
        closure.evidence == .realtime && closure.start <= now
            ? ClosureFormat.endLabel(closure, reference: now)
            : ClosureFormat.timeRange(closure)
    }

    private func scheduledDayTitle(_ date: Date) -> String {
        let relative = relativeDayLabel(date)
        if ["oggi", "domani", "dopodomani"].contains(relative) {
            return relative.capitalized
        }
        return date.formatted(
            .dateTime
                .weekday(.abbreviated)
                .day(.twoDigits)
                .month(.abbreviated)
                .locale(Locale(identifier: "it_IT"))
        )
    }

    private func windowClosures(
        _ window: ClosureTimeWindow,
        direction: Direction
    ) -> [RoadClosure] {
        window.closures.filter { $0.matches(direction: direction) }
    }

    private func windowImpactLabel(
        _ window: ClosureTimeWindow,
        direction: Direction
    ) -> String {
        let relevant = windowClosures(window, direction: direction)
        guard !relevant.isEmpty else { return "Nessuna limitazione \(direction.headingPhrase)" }

        let roadCount = relevant.filter { $0.kind == .roadBlocked }.count
        let rampCount = relevant
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

    private func scheduledTimeSummary(
        _ window: ClosureTimeWindow,
        direction: Direction
    ) -> String {
        let calendar = Calendar.current
        let scheduled = windowClosures(window, direction: direction).filter {
            $0.start > now && calendar.isDate($0.start, inSameDayAs: window.start)
        }
        guard let earliestStart = scheduled.map(\.start).min(),
              let latestEnd = scheduled.map(\.end).max()
        else { return "Nessuna nuova chiusura" }

        let hasMultiDayNotice = scheduled.contains {
            !calendar.isDate($0.start, inSameDayAs: $0.end)
                && calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: $0.start),
                    to: calendar.startOfDay(for: $0.end)
                ).day ?? 0 > 1
        }
        if hasMultiDayNotice {
            return "dalle \(timeLabel(earliestStart))"
        }
        return "\(timeLabel(earliestStart))–\(timeLabel(latestEnd))"
    }

    private func timeLabel(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .locale(Locale(identifier: "it_IT"))
        )
    }

    private func relativeDayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        let delta = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        switch delta {
        case -1: return "ieri"
        case 0: return "oggi"
        case 1: return "domani"
        case 2: return "dopodomani"
        default:
            return date.formatted(
                .dateTime.day(.twoDigits).month(.abbreviated)
                    .locale(Locale(identifier: "it_IT"))
            )
        }
    }
}

#Preview {
    NavigationStack {
        OverviewMapView(
            closures: SampleClosures.make(),
            direction: .constant(.towardPozzuoli)
        )
            .navigationDestination(for: RoadClosure.self) { ClosureDetailView(closure: $0) }
    }
}
