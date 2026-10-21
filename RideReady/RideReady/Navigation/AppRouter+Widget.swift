import Foundation

extension AppRouter {
    /// RootTabView receives links once; publishing the path also handles a cold launch.
    @discardableResult
    func openWidgetURL(_ url: URL, store: RideReadyStoring) -> Bool {
        guard let destination = RideReadyWidgetConfiguration.destination(for: url) else { return false }
        widgetError = nil
        selectedTab = .bike
        switch destination {
        case .home:
            bikePath = []
        case .check:
            guard store.motorcycle() != nil else {
                bikePath = [.bikeProfile]
                return true
            }
            do {
                if store.activeInspection() == nil {
                    _ = try StartPreRideInspectionUseCase(store: store).start()
                }
                bikePath = [.checklist]
            } catch {
                widgetError = error.localizedDescription
            }
        }
        return true
    }
}
