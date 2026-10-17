import SwiftUI

/// The app's two top-level areas: the bike and its pre-ride check, and rides.
struct RootTabView: View {
    let store: RideReadyStoring
    let scheduler: NotificationScheduling
    @ObservedObject var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab("Bike", systemImage: "motorcycle", value: AppTab.bike) {
                BikeView(store: store)
            }
            Tab("Ride", systemImage: "road.lanes", value: AppTab.ride) {
                RideView(store: store, scheduler: scheduler, router: router)
            }
        }
    }
}
