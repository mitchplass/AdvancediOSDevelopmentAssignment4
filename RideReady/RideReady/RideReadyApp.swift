import SwiftUI

@main
struct RideReadyApp: App {
    private let store: RideReadyStoring

    init() {
        let store = UserDefaultsRideReadyStore()
        if store.motorcycle() == nil {
            store.save(.yamahaMT07())
        }
        self.store = store
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(store: store)
        }
    }
}
