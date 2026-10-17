import Combine
import Foundation

/// Pre-ride check state: every item on one page with its guidance and the
/// rider's OK / Issue answer, then logging the finished walk-around.
final class ChecklistViewModel: ObservableObject {
    struct Row: Identifiable {
        let item: InspectionItem
        var id: InspectionItem { item }
        let title: String
        let guidance: String
        let result: InspectionResult?
    }

    @Published private(set) var rows: [Row] = []
    /// Items whose guidance is showing. Unanswered items start open; answering closes one.
    @Published private(set) var expandedItems: Set<InspectionItem> = []
    /// Bumps on every recorded answer so the view can play a haptic.
    @Published private(set) var answerCount = 0
    @Published private(set) var didLog = false
    @Published var riderError: String?

    private let store: RideReadyStoring
    private let recordFinding: RecordInspectionFindingUseCase
    private let completeInspection: CompletePreRideInspectionUseCase

    init(store: RideReadyStoring) {
        self.store = store
        recordFinding = RecordInspectionFindingUseCase(store: store)
        completeInspection = CompletePreRideInspectionUseCase(store: store)
        reload()
        expandedItems = Set(rows.filter { $0.result == nil }.map(\.item))
    }

    var checkedCount: Int {
        rows.filter { $0.result != nil }.count
    }

    var progress: Double {
        rows.isEmpty ? 0 : Double(checkedCount) / Double(rows.count)
    }

    var progressText: String {
        "\(checkedCount) of \(rows.count) checked"
    }

    var remainingText: String {
        let remaining = rows.count - checkedCount
        return remaining == 1 ? "1 check left" : "\(remaining) checks left"
    }

    var isComplete: Bool {
        !rows.isEmpty && checkedCount == rows.count
    }

    var hasIssue: Bool {
        rows.contains { $0.result == .needsAttention }
    }

    var summaryTitle: String {
        hasIssue ? "Not ride ready yet" : "You're ride ready"
    }

    var summaryDetail: String {
        hasIssue
            ? "Something needs attention. Do not treat this bike as ride ready."
            : "All checks passed."
    }

    var logButtonTitle: String {
        guard isComplete else { return "Log check" }
        return hasIssue ? "Log as not ride ready" : "Log ride ready"
    }

    func isExpanded(_ item: InspectionItem) -> Bool {
        expandedItems.contains(item)
    }

    func toggleGuidance(for item: InspectionItem) {
        if expandedItems.contains(item) {
            expandedItems.remove(item)
        } else {
            expandedItems.insert(item)
        }
    }

    func record(_ result: InspectionResult, for item: InspectionItem) {
        do {
            _ = try recordFinding.record(result, for: item)
            riderError = nil
            reload()
            expandedItems.remove(item)
            answerCount += 1
        } catch {
            riderError = error.localizedDescription
        }
    }

    func logCheck() {
        do {
            _ = try completeInspection.complete(as: hasIssue ? .notRideReady : .readyToRide)
            riderError = nil
            didLog = true
        } catch {
            riderError = error.localizedDescription
        }
    }

    private func reload() {
        guard let inspection = store.activeInspection() else {
            rows = []
            return
        }

        let motorcycle = inspection.motorcycle
        rows = motorcycle.requiredInspectionItems().map { item in
            Row(
                item: item,
                title: item.title,
                guidance: item.guidance(for: motorcycle),
                result: inspection.findings.first { $0.item == item }?.result
            )
        }
    }
}
