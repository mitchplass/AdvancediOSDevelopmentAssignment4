import Foundation

/// Converts domain data to a read-only summary without exposing photos or history.
struct BuildWidgetSnapshotUseCase {
    let store: RideReadyStoring

    func execute() -> RideReadyWidgetSnapshot {
        guard let motorcycle = store.motorcycle() else {
            return RideReadyWidgetSnapshot(motorcycleName: nil)
        }
        var snapshot = RideReadyWidgetSnapshot(motorcycleName: motorcycle.name)
        // Only associate history with the current motorcycle configuration.
        let last = store.completedInspections().first { $0.motorcycle == motorcycle }
        snapshot.lastCompletedAt = last?.completedAt
        if let active = store.activeInspection() {
            let required = active.motorcycle.requiredInspectionItems()
            let recorded = Set(active.findings.map(\.item))
            snapshot.hasActiveInspection = true
            snapshot.requiredItems = required.count
            snapshot.checkedItems = required.filter { recorded.contains($0) }.count
            snapshot.needsAttention = active.findings.contains { $0.result == .needsAttention }
            snapshot.flaggedItems = flaggedItems(in: active)
            return snapshot
        }

        // Editing bike specifications invalidates a previously passed check.
        guard let last else {
            return snapshot
        }
        snapshot.lastCompletedAt = last.completedAt
        snapshot.needsAttention = last.readiness == .notRideReady
            || last.findings.contains { $0.result == .needsAttention }
        snapshot.flaggedItems = flaggedItems(in: last)
        snapshot.lastCheckPassed = last.readiness == .readyToRide
            && last.completedAt != nil
            && last.motorcycle.requiredInspectionItems().allSatisfy { item in
                last.findings.contains { $0.item == item && $0.result == .ok }
            }
            && !snapshot.needsAttention
        return snapshot
    }

    private func flaggedItems(in inspection: PreRideInspection) -> [String] {
        inspection.motorcycle.requiredInspectionItems().filter { item in
            inspection.findings.contains { $0.item == item && $0.result == .needsAttention }
        }.map(\.title)
    }
}
