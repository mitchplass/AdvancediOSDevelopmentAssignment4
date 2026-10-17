import SwiftUI

/// The app's two top-level areas: the bike and its pre-ride check, and rides.
struct RootTabView: View {
    let store: RideReadyStoring

    var body: some View {
        TabView {
            Tab("Bike", systemImage: "motorcycle") {
                BikeView(store: store)
            }
            Tab("Ride", systemImage: "road.lanes") {
                RideComingSoonView()
            }
        }
    }
}
