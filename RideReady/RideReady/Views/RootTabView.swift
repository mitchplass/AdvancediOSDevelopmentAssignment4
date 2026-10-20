import SwiftUI

/// The app's top-level areas: the bike and its pre-ride check, rides, and the lap timer.
struct RootTabView: View {
    let store: RideReadyStoring
    let scheduler: NotificationScheduling
    @ObservedObject var router: AppRouter
    @ObservedObject var appearance: AppearanceSettings

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab("Bike", systemImage: "motorcycle", value: AppTab.bike) {
                BikeView(store: store)
            }
            Tab("Ride", systemImage: "road.lanes", value: AppTab.ride) {
                RideView(store: store, scheduler: scheduler, router: router)
            }
            Tab("Lap Timer", systemImage: "stopwatch", value: AppTab.lapTimer) {
                LapTimerView(store: store, onExit: { router.selectedTab = .bike })
            Tab("Appearance", systemImage: "circle.lefthalf.filled", value: AppTab.appearance) {
                AppearanceView(settings: appearance)
            }
        }
        .preferredColorScheme(appearance.mode.colorScheme)
    }
}
