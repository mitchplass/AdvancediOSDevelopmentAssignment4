import SwiftUI

/// Placeholder for the Ride tab until trip recording ships.
/// Replace before App Store submission (guideline 2.1 rejects placeholder content).
struct RideComingSoonView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Road trips are coming soon", systemImage: "map")
            } description: {
                Text("Record your route, mark moments along the way, and keep a journal of every ride.")
            }
            .navigationTitle("Ride")
        }
    }
}

#Preview {
    RideComingSoonView()
}
