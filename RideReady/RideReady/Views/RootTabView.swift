import SwiftUI

/// Bike inspection, rides, lap timer and appearance settings.
struct RootTabView: View {
    let store: RideReadyStoring
    let journal: RideJournalRepository
    let scheduler: NotificationScheduling
    @ObservedObject var router: AppRouter
    @ObservedObject var appearance: AppearanceSettings

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab("Bike", systemImage: "motorcycle", value: AppTab.bike) {
                BikeView(store: store, path: $router.bikePath)
            }
            Tab("Ride", systemImage: "road.lanes", value: AppTab.ride) {
                RideView(store: store, journal: journal, scheduler: scheduler, router: router)
            }
            Tab("Lap Timer", systemImage: "stopwatch", value: AppTab.lapTimer) {
                LapTimerView(store: store, onExit: { router.selectedTab = .bike })
            }
            Tab("Appearance", systemImage: "circle.lefthalf.filled", value: AppTab.appearance) {
                AppearanceView(settings: appearance)
            }
        }
        .preferredColorScheme(appearance.mode.colorScheme)
        .onOpenURL { url in
            router.openWidgetURL(url, store: store)
        }
        .alert("Can't open check", isPresented: Binding(
            get: { router.widgetError != nil },
            set: { if !$0 { router.widgetError = nil } }
        )) {
            Button("OK", role: .cancel) { router.widgetError = nil }
        } message: {
            Text(router.widgetError ?? "")
        }
    }
}
