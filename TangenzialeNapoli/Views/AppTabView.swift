//
//  AppTabView.swift
//  TangenzialeNapoli
//
//  Persistent primary navigation: each top-level job gets one stable tab.
//

import SwiftUI
import Combine

struct AppTabView: View {
    private enum AppTab: Hashable {
        case closures, map
    }

    @State private var viewModel: ClosuresViewModel
    @State private var selectedTab: AppTab
    @State private var isInfoPresented = false
    @AppStorage("selectedDirection") private var direction: Direction = .towardPozzuoli
    @Environment(\.scenePhase) private var scenePhase

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
                : .map
        )
#else
        _viewModel = State(initialValue: viewModel ?? ClosuresViewModel())
        _selectedTab = State(initialValue: .map)
#endif
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                OverviewMapView(
                    closures: viewModel.closures,
                    direction: $direction,
                    now: viewModel.now,
                    lastUpdatedAt: mapDataTimestamp,
                    dataIsStale: viewModel.dataSource?.isStale ?? true,
                    isLoading: viewModel.isLoading,
                    initialScope: mapInitialScope,
                    onReload: {
                        if !viewModel.isLoading {
                            await viewModel.load()
                        }
                    }
                )
                    .navigationDestination(for: RoadClosure.self) { closure in
                        ClosureDetailView(closure: closure)
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
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            viewModel.refreshNow()
        }
        .onChange(of: scenePhase) { _, phase in
            AppLog.log("scenePhase → \(phase)", "ui")
            if phase == .active {
                Task { await viewModel.refreshIfStale() }
            }
        }
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

    private var mapDataTimestamp: Date? {
        switch viewModel.dataSource {
        case .live(let timestamp, _), .cache(let timestamp):
            timestamp
        case .unavailable, nil:
            nil
        }
    }
}

#if DEBUG
#Preview {
    AppTabView(viewModel: .preview(closures: SampleClosures.make()))
}
#endif
