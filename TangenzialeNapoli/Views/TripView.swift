import MapKit
import SwiftUI

struct TripView: View {
    let closures: ClosuresViewModel
    @State private var planner = TripPlanner()
    @State private var location = TripLocation()
    @AppStorage("tripFavoriteDestinations") private var favoriteData = Data()
    @State private var editing: Endpoint?
    @State private var shouldCompareAfterLocation = false
    @State private var selectedRoute: RouteKind?
    @State private var camera: MapCameraPosition = .automatic

    private enum Endpoint: String, Identifiable {
        case origin = "Partenza"
        case destination = "Destinazione"
        case favorite = "Aggiungi preferito"

        var id: Self { self }
    }

    private enum ScrollTarget: Hashable {
        case top
    }

    private enum RouteKind: String {
        case withA56 = "Con Tangenziale"
        case withoutA56 = "Senza Tangenziale"
        case uncertain = "Percorso da verificare"

        var color: Color {
            switch self {
            case .withA56: .a56Open
            case .withoutA56: .a56Unknown
            case .uncertain: .secondary
            }
        }
    }

    var body: some View {
        Group {
            if let result = planner.result {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        tripSummary
                        comparison(result)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    returnToSearch
                }
            } else {
                searchList
            }
        }
        .background(Color.a56Canvas.ignoresSafeArea())
        .navigationTitle("Percorsi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if planner.result != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Aggiorna confronto", systemImage: "arrow.clockwise", action: compareRoutes)
                        .labelStyle(.iconOnly)
                }
            }
        }
        .navigationDestination(for: RoadClosure.self) { closure in
            ClosureDetailView(closure: closure, viewModel: closures)
        }
        .sheet(item: $editing) { endpoint in
            TripPlaceSearch(title: endpoint.rawValue) { place in
                switch endpoint {
                case .origin: planner.origin = place
                case .destination: planner.destination = place
                case .favorite: addFavorite(place)
                }
                editing = nil
            }
        }
        .onChange(of: location.revision) {
            let compare = shouldCompareAfterLocation
            shouldCompareAfterLocation = false
            guard let place = location.place else { return }
            planner.origin = place
            if compare { compareRoutes() }
        }
    }

    private var favorites: [TripFavorite] {
        (try? JSONDecoder().decode([TripFavorite].self, from: favoriteData)) ?? []
    }

    private var searchList: some View {
        let saved = favorites
        return ScrollViewReader { scroll in
            List {
                tripForm
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 14, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .id(ScrollTarget.top)

                Section {
                    if saved.isEmpty {
                        Text("Salva le destinazioni che raggiungi spesso.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    ForEach(saved) { favorite in
                        favoriteRow(favorite) {
                            startFavoriteTrip(favorite)
                            scroll.scrollTo(ScrollTarget.top, anchor: .top)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                storeFavorites(favorites.filter { $0.id != favorite.id })
                            } label: {
                                Label("Rimuovi", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                        .listRowBackground(Color.a56Surface)
                    }
                } header: {
                    favoritesHeader(hasFavorites: !saved.isEmpty)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func favoritesHeader(hasFavorites: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Label("Preferiti", systemImage: "star")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button {
                    editing = .favorite
                } label: {
                    Label("Aggiungi", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .accessibilityLabel("Aggiungi destinazione preferita")
            }
            if hasFavorites {
                Text("Tocca per controllare il percorso. Scorri a sinistra per rimuovere.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .textCase(nil)
        .padding(.bottom, 6)
    }

    private func favoriteRow(_ favorite: TripFavorite, onRoute: @escaping () -> Void) -> some View {
        Button(action: onRoute) {
            HStack(spacing: 12) {
                Image(systemName: "location")
                    .foregroundStyle(Color.a56Open)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(favorite.name)
                        .font(.body.weight(.medium))
                    if let subtitle = favorite.subtitle, !subtitle.isEmpty, subtitle != favorite.name {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Controlla il percorso dalla tua posizione")
    }

    private func addFavorite(_ place: TripPlanner.Place) {
        let saved = favorites
        guard !saved.contains(where: { $0.matches(place) }) else { return }
        storeFavorites(saved + [TripFavorite(place: place)])
    }

    private func storeFavorites(_ saved: [TripFavorite]) {
        if let data = try? JSONEncoder().encode(saved) { favoriteData = data }
    }

    private func startFavoriteTrip(_ favorite: TripFavorite) {
        planner.origin = nil
        planner.destination = favorite.place
        shouldCompareAfterLocation = true
        location.locate()
    }

    private func compareRoutes() {
        selectedRoute = nil
        camera = .automatic
        Task {
            async let refresh: Void = closures.refreshIfStale()
            await planner.calculate()
            await refresh
        }
    }

    private var tripForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Dove vai?")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("Confronta il viaggio con e senza Tangenziale.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 0) {
                endpointButton(.origin, place: planner.origin, icon: "circle.circle",
                               placeholder: "Scegli partenza")
                HStack(spacing: 12) {
                    Capsule()
                        .fill(Color.a56Open.opacity(0.28))
                        .frame(width: 2, height: 25)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    locationButton
                }
                Divider().padding(.leading, 36)
                endpointButton(.destination, place: planner.destination, icon: "mappin.circle.fill",
                               placeholder: "Scegli destinazione")
            }
            .a56Surface()

            if let error = location.error ?? planner.error {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button(action: compareRoutes) {
                Group {
                    if planner.isCalculating {
                        HStack {
                            ProgressView().tint(.white)
                            Text("Calcolo in corso…")
                        }
                    } else {
                        Text("Controlla percorso")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 26)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(planner.origin == nil || planner.destination == nil || planner.isCalculating || location.isLocating)
        }
    }

    private var locationButton: some View {
        Button {
            location.locate()
        } label: {
            Label(location.isLocating ? "Ricerca posizione…"
                  : planner.origin?.name == "La mia posizione" ? "Aggiorna la mia posizione" : "Usa la mia posizione",
                  systemImage: "location")
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
        }
        .disabled(location.isLocating)
    }

    private func endpointButton(
        _ endpoint: Endpoint, place: TripPlanner.Place?, icon: String, placeholder: String
    ) -> some View {
        Button {
            shouldCompareAfterLocation = false
            if endpoint == .origin { location.cancel() }
            editing = endpoint
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color.a56Open)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(endpoint.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(place?.name ?? placeholder)
                        .font(.body.weight(.semibold))
                    if let subtitle = place?.subtitle, subtitle != place?.name {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 7)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var tripSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Il tuo itinerario")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(planner.destination?.name ?? "Destinazione")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            if let origin = planner.origin {
                Label("Da \(origin.name)", systemImage: "location")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var returnToSearch: some View {
        Button {
            planner.resetComparison()
        } label: {
            Label("Torna alla ricerca", systemImage: "magnifyingglass")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 26)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.a56Canvas)
    }

    private func comparison(_ result: TripPlanner.Result) -> some View {
        let withA56 = result.preferredA56(closures: closures.closures, departure: closures.now)
        let impacts = withA56?.impacts(closures: closures.closures, departure: closures.now) ?? []
        let status = statusFor(impacts: impacts, withA56: withA56, result: result)
        let nextImpact = withA56?.nextImpactAfterTrip(closures: closures.closures, departure: closures.now)
        let route = selectedRoute ?? status.recommended
        let blocked = impacts.contains { $0.kind == .roadBlock }
        return VStack(alignment: .leading, spacing: 18) {
            statusCard(status, impacts: impacts)
                .a56Surface(accent: status.tone.surfaceAccent)
            if let nextImpact {
                upcomingClosureCard(nextImpact)
                    .a56Surface(accent: StatusTone.caution.surfaceAccent)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Itinerari a confronto")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 0) {
                    routeRow(.withA56, option: withA56, selected: route,
                             empty: missingRoute(result, withA56: true), blocked: blocked)
                    if let withA56 {
                        interchanges(withA56.a56Traversals)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 10)
                    }
                    Divider()
                    routeRow(.withoutA56, option: result.withoutA56, selected: route,
                             empty: missingRoute(result, withA56: false))
                    if withA56 == nil, result.withoutA56 == nil, let uncertain = result.uncertain {
                        Divider()
                        routeRow(.uncertain, option: uncertain, selected: route, empty: "")
                    }
                }
                navigationHandoff(
                    selection: route, a56Route: withA56, a56Blocked: blocked,
                    hasA56Impacts: !impacts.isEmpty
                )
                routeMap(
                    withA56: withA56, withoutA56: result.withoutA56, uncertain: result.uncertain,
                    selection: route, blocked: blocked
                )
                Text("Tempi e distanze stimati da Mappe di Apple.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .a56Surface()
        }
    }

    @ViewBuilder
    private func navigationHandoff(
        selection: RouteKind?, a56Route: TripPlanner.Option?, a56Blocked: Bool, hasA56Impacts: Bool
    ) -> some View {
        if a56Blocked && (selection == nil || selection == .withA56) {
            Label("La chiusura impedisce di aprire il percorso con Tangenziale.", systemImage: "exclamationmark.circle")
                .font(.footnote)
                .foregroundStyle(Color.a56Block)
        } else if let selection, let origin = planner.origin, let destination = planner.destination {
            let waypoints = selection == .withA56 && !hasA56Impacts
                ? (a56Route?.a56Traversals.compactMap(A56TripMatcher.waypoint(for:)) ?? [])
                : []
            let links = TripNavigationLinks(
                origin: origin.coordinate,
                destination: destination.coordinate,
                waypoints: waypoints,
                avoidsHighways: selection == .withoutA56
            )
            VStack(alignment: .leading, spacing: 4) {
                Menu {
                    if let url = links.appleMapsURL(supportsUnifiedURLs: supportsUnifiedMapsURLs) {
                        Link(destination: url) { Label("Mappe di Apple", systemImage: "map") }
                    }
                    if let url = links.googleMapsURL {
                        Link(destination: url) { Label("Google Maps", systemImage: "map") }
                    }
                } label: {
                    Label("Apri nel navigatore", systemImage: "arrow.up.right.square")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.bordered)
                Text("Il navigatore ricalcola il tragitto. Controlla l’itinerario prima di partire.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if selection == .withoutA56 && !supportsUnifiedMapsURLs {
                    Text("In Mappe di Apple, seleziona le opzioni per evitare autostrade e pedaggi.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var supportsUnifiedMapsURLs: Bool {
        if #available(iOS 18.4, *) { return true }
        return false
    }

    private func missingRoute(_ result: TripPlanner.Result, withA56: Bool) -> String {
        if result.searchIncomplete { return "Ricerca incompleta. Riprova." }
        if result.uncertain != nil { return "Non è stato possibile verificare un percorso di questo tipo." }
        return withA56
            ? "Mappe di Apple non ha proposto un percorso sulla A56."
            : "Mappe di Apple non ha proposto un’alternativa che eviti la A56."
    }

    private enum StatusTone {
        case open, neutral, caution, blocked

        var color: Color {
            switch self {
            case .open: .a56Open
            case .neutral: .a56Unknown
            case .caution: .a56Caution
            case .blocked: .a56Block
            }
        }

        var surfaceAccent: Color {
            self == .caution ? color.opacity(0.8) : color
        }

        var alertTextColor: Color? {
            switch self {
            case .caution, .blocked: color
            case .open, .neutral: nil
            }
        }
    }

    private struct Status {
        let title: String
        let detail: String
        let icon: String
        let tone: StatusTone
        let recommended: RouteKind?
    }

    private func statusFor(
        impacts: [A56TripMatcher.Impact], withA56: TripPlanner.Option?, result: TripPlanner.Result
    ) -> Status {
        let alternative: RouteKind? = result.withoutA56 != nil ? .withoutA56 : nil
        let warning = "exclamationmark.triangle"
        if withA56 == nil {
            if result.withoutA56 != nil {
                return Status(title: "Percorso senza Tangenziale",
                              detail: "Tra i percorsi calcolati, nessuno è stato riconosciuto sulla A56.",
                              icon: "arrow.turn.up.right", tone: .neutral, recommended: .withoutA56)
            }
            return Status(title: "Uso della Tangenziale da verificare",
                          detail: "Non è stato possibile stabilire se il percorso usa la A56.",
                          icon: warning, tone: .caution, recommended: .uncertain)
        }
        let fresh = !closures.dataNeedsVerification
        let roadBlocks = impacts.filter { $0.kind == .roadBlock }
        if !roadBlocks.isEmpty {
            let startsDuringTrip = roadBlocks.allSatisfy { $0.closure.start > closures.now }
            let title = startsDuringTrip ? "Chiusura prevista durante il viaggio" : "Tangenziale da evitare"
            return Status(title: fresh ? title : "Chiusura segnalata sul percorso",
                          detail: fresh
                            ? "Il percorso A56 attraversa un tratto chiuso durante la finestra stimata del viaggio."
                            : "Una chiusura interessa il percorso, ma i dati più recenti non sono confermati.",
                          icon: warning, tone: .blocked, recommended: alternative)
        }
        if !impacts.isEmpty {
            return Status(title: "Tangenziale da verificare",
                          detail: "Il percorso passa vicino a una rampa o al limite di un tratto segnalato chiuso.",
                          icon: warning, tone: .caution, recommended: alternative)
        }
        if closures.isLoading {
            return Status(title: "Controllo chiusure in corso",
                          detail: "Sto aggiornando gli avvisi di viabilità della A56.",
                          icon: "arrow.clockwise", tone: .caution, recommended: alternative)
        }
        if !fresh {
            return Status(title: "Tangenziale da verificare",
                          detail: "I dati di viabilità non sono completi o aggiornati.",
                          icon: warning, tone: .caution, recommended: alternative)
        }
        return Status(title: "A56 senza chiusure segnalate",
                      detail: "Gli avvisi disponibili non indicano chiusure A56 durante la finestra stimata del viaggio.",
                      icon: "checkmark.circle", tone: .open, recommended: .withA56)
    }

    private func statusCard(_ status: Status, impacts: [A56TripMatcher.Impact]) -> some View {
        let alertTextColor = status.tone.alertTextColor
        return VStack(alignment: .leading, spacing: 6) {
            Text("Partenza adesso")
                .font(.caption.weight(.semibold))
                .foregroundStyle(alertTextColor ?? .secondary)
            Label(status.title, systemImage: status.icon)
                .font(.headline)
                .foregroundStyle(status.tone.color)
                .accessibilityAddTraits(.isHeader)
            Text(status.detail)
                .font(.subheadline)
                .foregroundStyle(alertTextColor ?? .primary)
            if let freshness = closures.freshness {
                switch freshness {
                case .fresh(let date), .partial(let date, _), .expired(let date), .cache(let date):
                    Text("Avvisi: \(ClosureFormat.updateTimeLabel(date, reference: closures.now))")
                        .font(.caption)
                        .foregroundStyle(alertTextColor ?? .secondary)
                case .unavailable:
                    EmptyView()
                }
            }
            ForEach(impacts, id: \.closure.id) { impact in
                impactRow(impact, showDate: impact.closure.start > closures.now,
                          color: alertTextColor ?? .a56Open)
            }
            if status.icon == "exclamationmark.triangle" {
                Link("Avvisi del gestore", destination: AppLinks.plannedNotices)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(status.tone.color)
                    .tint(status.tone.color)
                    .padding(.top, 3)
            }
        }
    }

    private func upcomingClosureCard(_ impact: A56TripMatcher.Impact) -> some View {
        let secondsUntilStart = impact.closure.start.timeIntervalSince(closures.now)
        let imminent = secondsUntilStart <= 60 * 60
        let minutesUntilStart = max(1, Int((secondsUntilStart / 60).rounded(.up)))
        let possibleImpact = impact.kind != .roadBlock
        let title = if imminent {
            possibleImpact ? "Possibile limitazione imminente" : "Chiusura imminente sulla Tangenziale"
        } else {
            possibleImpact ? "Prossima possibile limitazione" : "Prossima chiusura programmata"
        }
        return VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: imminent ? "exclamationmark.triangle" : "clock")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if imminent {
                Text("Prevista tra \(minutesUntilStart) min. Può incidere se parti più tardi.")
                    .font(.subheadline)
            }
            if closures.dataNeedsVerification {
                Text("Orario da verificare. Gli avvisi potrebbero essere incompleti o non aggiornati.")
                    .font(.footnote)
            }
            impactRow(impact, showDate: true, color: .a56Caution)
        }
        .foregroundStyle(Color.a56Caution)
    }

    private func impactRow(_ impact: A56TripMatcher.Impact, showDate: Bool, color: Color) -> some View {
        let closure = impact.closure
        let place = closure.kind == .roadBlocked
            ? "\(A56Line.driverLabel(for: closure.fromExit)) → \(A56Line.driverLabel(for: closure.toExit))"
            : "\(impact.ramp?.shortLabel ?? closure.headline) · \(A56Line.driverLabel(for: closure.rampExitNumber))"
        let direction = closure.affectsBothDirections ? "Entrambe le direzioni" : closure.direction.towardLabel
        let time = ClosureFormat.timeRange(closure)
        let schedule = showDate ? "\(ClosureFormat.dayLabel(closure.start)) · \(time)" : time
        return NavigationLink(value: closure) {
            VStack(alignment: .leading, spacing: 3) {
                Text(place)
                    .font(.subheadline.weight(.semibold))
                Text("\(direction) · \(schedule)")
                    .font(.caption)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private func routeRow(
        _ kind: RouteKind, option: TripPlanner.Option?, selected: RouteKind?, empty: String, blocked: Bool = false
    ) -> some View {
        let isSelected = selected == kind
        let color = blocked ? Color.a56Block : kind.color
        return Group {
            if let option {
                let route = option.route
                Button {
                    selectedRoute = kind
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(color)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(kind.rawValue)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            if blocked {
                                Text("Chiusura sul tragitto")
                                    .font(.caption)
                                    .foregroundStyle(color)
                            }
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(routeDuration(route))
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.primary)
                            Text("\((route.distance / 1000).formatted(.number.precision(.fractionLength(0...1)))) km")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .frame(minHeight: 52)
                    .background(isSelected ? color.opacity(0.08) : .clear, in: .rect(cornerRadius: 12))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityHint("Evidenzia il percorso sulla mappa")
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.rawValue).font(.subheadline.weight(.semibold))
                    Text(empty).font(.caption).foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func interchanges(_ traversals: [A56TripMatcher.Traversal]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(traversals.enumerated()), id: \.offset) { index, traversal in
                VStack(alignment: .leading, spacing: 4) {
                    Text(traversals.count > 1
                         ? "Tratto \(index + 1) · \(traversal.direction.towardLabel)"
                         : traversal.direction.towardLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    interchange("Ingresso", access: traversal.entry, entering: true)
                    interchange("Uscita", access: traversal.exit, entering: false)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func interchange(_ title: String, access: A56TripMatcher.Access, entering: Bool) -> some View {
        let name: String
        switch access {
        case .interchange(let junction): name = junction.isEntranceOnly ? junction.name : junction.shortLabel
        case .onCarriageway: name = entering ? "Partenza già sulla A56" : "Arrivo sulla A56"
        case .unidentified: name = "Svincolo da verificare"
        }
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: entering ? "arrow.down.right" : "arrow.up.right")
                .foregroundStyle(Color.a56Open)
                .accessibilityHidden(true)
            Text("\(title) · \(name)")
                .foregroundStyle(.primary)
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
    }

    private func routeDuration(_ route: MKRoute) -> String {
        let minutes = max(1, Int((route.expectedTravelTime / 60).rounded()))
        return Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    private func routeMap(
        withA56: TripPlanner.Option?, withoutA56: TripPlanner.Option?, uncertain: TripPlanner.Option?,
        selection: RouteKind?, blocked: Bool
    ) -> some View {
        let display: [(RouteKind, TripPlanner.Option)] = [
            withA56.map { (.withA56, $0) },
            withoutA56.map { (.withoutA56, $0) },
            withA56 == nil && withoutA56 == nil ? uncertain.map { (.uncertain, $0) } : nil
        ].compactMap { $0 }
        return Map(position: $camera, interactionModes: [.pan, .zoom]) {
            ForEach(display, id: \.0) { kind, option in
                let color = kind == .withA56 && blocked ? Color.a56Block : kind.color
                MapPolyline(option.route.polyline)
                    .stroke(color.opacity(selection == kind ? 1 : 0.72),
                            style: StrokeStyle(lineWidth: selection == kind ? 6 : 4, lineCap: .round,
                                               dash: kind == .withA56 ? [] : [8, 6]))
                    .mapOverlayLevel(level: selection == kind ? .aboveLabels : .aboveRoads)
            }
            if let origin = planner.origin {
                Marker("Partenza", systemImage: "location", coordinate: origin.coordinate)
                    .tint(.a56Open)
            }
            if let destination = planner.destination {
                Marker("Arrivo", systemImage: "flag.checkered", coordinate: destination.coordinate)
                    .tint(.primary)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .frame(height: 250)
        .clipShape(.rect(cornerRadius: 14))
        .accessibilityLabel("Mappa dei percorsi in auto")
    }
}

private struct TripPlaceSearch: View {
    let title: String
    let onSelect: (TripPlanner.Place) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var suggestions = TripPlaceSuggestions()
    @State private var search: MKLocalSearch?
    @State private var results: [TripPlanner.Place] = []
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if search != nil {
                    ProgressView("Ricerca in Mappe di Apple…")
                } else if let error {
                    ContentUnavailableView("Ricerca indirizzi", systemImage: "magnifyingglass", description: Text(error))
                } else if !results.isEmpty {
                    List(results.indices, id: \.self) { index in
                        let place = results[index]
                        Button {
                            onSelect(place)
                        } label: {
                            placeLabel(place.name, subtitle: place.subtitle)
                        }
                    }
                } else if !suggestions.results.isEmpty {
                    List(suggestions.results, id: \.self) { suggestion in
                        Button {
                            Task { await findPlaces(for: suggestion) }
                        } label: {
                            placeLabel(suggestion.title, subtitle: suggestion.subtitle)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Cerca un luogo", systemImage: "mappin.and.ellipse",
                        description: Text(suggestions.isUnavailable
                            ? "Suggerimenti non disponibili. Scrivi l’indirizzo completo e tocca Cerca."
                            : "Digita una via, un civico o il nome di un luogo per vedere i suggerimenti. Puoi anche toccare Cerca.")
                    )
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Indirizzo o luogo")
            .onSubmit(of: .search) { Task { await findPlaces() } }
            .onChange(of: query) { _, query in
                clearResults()
                suggestions.update(query)
            }
            .onDisappear {
                clearResults()
                suggestions.cancel()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
        }
    }

    private func placeLabel(_ title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).foregroundStyle(.primary)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func clearResults() {
        search?.cancel()
        search = nil
        results = []
        error = nil
    }

    private func findPlaces(for suggestion: MKLocalSearchCompletion? = nil) async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        clearResults()
        suggestions.cancel()

        let request: MKLocalSearch.Request
        if let suggestion {
            request = MKLocalSearch.Request(completion: suggestion)
        } else {
            request = MKLocalSearch.Request()
            request.naturalLanguageQuery = term
        }
        request.resultTypes = [.address, .pointOfInterest]
        request.region = TripPlaceSuggestions.searchRegion
        let current = MKLocalSearch(request: request)
        search = current
        defer { if search === current { search = nil } }
        do {
            let response = try await current.start()
            guard search === current else { return }
            let places = response.mapItems.map { item in
                TripPlanner.Place(name: item.name ?? item.tripAddress ?? "Luogo sulla mappa",
                                  subtitle: item.tripAddress, item: item)
            }
            if suggestion != nil, places.count == 1, let place = places.first {
                onSelect(place)
            } else {
                results = places
                if places.isEmpty { error = "Nessun risultato. Prova ad aggiungere il comune all’indirizzo." }
            }
        } catch {
            guard search === current else { return }
            if (error as? MKError)?.code == .placemarkNotFound {
                self.error = "Nessun risultato. Prova ad aggiungere il comune all’indirizzo."
            } else {
                self.error = "Ricerca non disponibile. Controlla la connessione e riprova."
            }
        }
    }
}

private extension MKMapItem {
    var tripAddress: String? {
        if #available(iOS 26.0, *) { return address?.fullAddress }
        return placemark.title
    }
}
