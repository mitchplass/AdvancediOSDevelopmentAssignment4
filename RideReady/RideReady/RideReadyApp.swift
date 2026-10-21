import SwiftUI

@main
struct RideReadyApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootTabView(
                store: appDelegate.store,
                journal: appDelegate.journal,
                scheduler: appDelegate.scheduler,
                router: appDelegate.router,
                appearance: appDelegate.appearance
            )
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { appDelegate.store.refreshWidget() }
            }
        }
    }
}
