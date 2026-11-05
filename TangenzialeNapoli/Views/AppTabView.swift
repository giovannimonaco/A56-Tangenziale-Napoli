import SwiftUI
import Combine

struct AppTabView: View {
    private enum AppTab: String, Hashable {
        case closures, map, trips
    }

    private static let lastTabKey = "lastSelectedTab"

    /// Last selected tab, so the app reopens where it was left.
    private static var storedTab: AppTab {
        UserDefaults.standard.string(forKey: lastTabKey)
            .flatMap(AppTab.init(rawValue:)) ?? .map
    }

    @State private var viewModel: ClosuresViewModel
    @State private var selectedTab: AppTab
    @State private var isInfoPresented = false
    @AppStorage("selectedDirection") private var direction: Direction = .towardPozzuoli
    @Environment(\.scenePhase) private var scenePhase

    /// Stored once: a publisher built inside `body` would be replaced on every
    /// render, restarting its countdown.
    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    init(viewModel: ClosuresViewModel? = nil) {
#if DEBUG
        let initialViewModel: ClosuresViewModel
        if let viewModel {
            initialViewModel = viewModel
        } else if CommandLine.arguments.contains("--unavailable-data") {
            initialViewModel = .previewUnavailable()
        } else if CommandLine.arguments.contains("--stale-sample-data") {
            initialViewModel = .previewCached(closures: SampleClosures.make())
        } else if CommandLine.arguments.contains("--sample-data") {
            initialViewModel = .preview(closures: SampleClosures.make())
        } else {
            initialViewModel = ClosuresViewModel()
        }
        _viewModel = State(initialValue: initialViewModel)
        _selectedTab = State(
            initialValue: CommandLine.arguments.contains("--show-closures")
                ? .closures
                : Self.storedTab
        )
#else
        _viewModel = State(initialValue: viewModel ?? ClosuresViewModel())
        _selectedTab = State(initialValue: Self.storedTab)
#endif
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                OverviewMapView(
                    closures: viewModel.closures,
                    direction: $direction,
                    now: viewModel.now,
                    freshness: viewModel.freshness,
                    isLoading: viewModel.isLoading,
                    initialScope: mapInitialScope,
                    onReload: {
                        if !viewModel.isLoading {
                            await viewModel.load()
                        }
                    }
                )
                    .navigationDestination(for: RoadClosure.self) { closure in
                        ClosureDetailView(closure: closure, viewModel: viewModel)
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                isInfoPresented = true
                            } label: {
                                Image(systemName: "info.circle")
                            }
                            .accessibilityLabel("Info")
                        }
                    }
            }
            .tabItem {
                Label("Mappa", systemImage: "map.fill")
            }
            .tag(AppTab.map)

            HomeView(viewModel: viewModel)
                .tabItem {
                    Label("Chiusure", systemImage: "road.lanes")
                }
                .tag(AppTab.closures)

            TripView(closures: viewModel)
                .tabItem {
                    Label("Percorsi", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                }
                .tag(AppTab.trips)
        }
        .tint(.a56Open)
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
        .task {
            if viewModel.dataSource == nil { await viewModel.load() }
        }
        .onReceive(minuteTimer) { _ in
            guard scenePhase == .active else { return }
            Task { await refreshOnTimer() }
        }
        .onChange(of: scenePhase) { _, phase in
            AppLog.log("scenePhase: \(phase)", "ui")
            if phase == .active {
                Task { await refreshOnTimer() }
            }
        }
        .onChange(of: selectedTab) { _, tab in
            UserDefaults.standard.set(tab.rawValue, forKey: Self.lastTabKey)
        }
    }

    private func refreshOnTimer() async {
#if DEBUG
        let previewArguments = ["--sample-data", "--stale-sample-data", "--unavailable-data"]
        if CommandLine.arguments.contains(where: previewArguments.contains) {
            viewModel.refreshNow()
            return
        }
#endif
        await viewModel.refreshIfStale()
    }

    private var mapInitialScope: OverviewMapView.Scope {
#if DEBUG
        if CommandLine.arguments.contains("--map-tomorrow")
            || CommandLine.arguments.contains("--map-today") {
            return .scheduled
        }
#endif
        return .now
    }
}

#if DEBUG
#Preview {
    AppTabView(viewModel: .preview(closures: SampleClosures.make()))
}
#endif
