import Combine
import Foundation

/// Bike tab state: the motorcycle and its specs, ride-ready status, streak,
/// recent checks, and starting or continuing a walk-around.
final class BikeViewModel: ObservableObject {
    /// One logged walk-around in the recent checks list.
    struct RecentCheck: Identifiable {
        let id: UUID
        let dateText: String
        let resultText: String
        let isRideReady: Bool
    }

    static let recentCheckLimit = 5

    @Published private(set) var motorcycleName = ""
    @Published private(set) var motorcyclePhoto: Data?
    @Published private(set) var specLines: [String] = []
    @Published private(set) var editButtonTitle = "Edit"
    @Published private(set) var streakText = "0 day streak"
    @Published private(set) var lastCheckText = "No checks logged yet"
    @Published private(set) var isRideReady = false
    @Published private(set) var rideReadyTitle = "Not ride ready"
    @Published private(set) var rideReadyDetail = "Do a pre-ride check before you leave."
    @Published private(set) var recentChecks: [RecentCheck] = []
    @Published private(set) var startButtonTitle = "Start pre-ride check"
    @Published var riderError: String?

    private let store: RideReadyStoring
    private let startInspection: StartPreRideInspectionUseCase

    init(store: RideReadyStoring) {
        self.store = store
        startInspection = StartPreRideInspectionUseCase(store: store)
        reload()
    }

    func reload() {
        let motorcycle = store.motorcycle()
        motorcycleName = motorcycle?.name ?? "No bike set up"
        specLines = motorcycle.map(Self.specLines(for:)) ?? ["Add your motorcycle so the check matches it."]
        editButtonTitle = motorcycle == nil ? "Set up" : "Edit"
        motorcyclePhoto = store.motorcyclePhoto()

        let days = store.streak().consecutiveDays
        streakText = days == 1 ? "1 day streak" : "\(days) day streak"

        let completed = store.completedInspections()
        if let last = completed.first?.completedAt {
            lastCheckText = "Last check: \(DayTimeText.string(for: last, capitalized: false))"
        } else {
            lastCheckText = "No checks logged yet"
        }
        recentChecks = completed.prefix(Self.recentCheckLimit).compactMap(Self.recentCheck(for:))
        updateRideReadyStatus(latest: completed.first)
        startButtonTitle = store.activeInspection() == nil
            ? "Start pre-ride check"
            : "Continue pre-ride check"
    }

    func startOrContinueCheck() -> Bool {
        riderError = nil
        if store.activeInspection() != nil {
            return true
        }
        do {
            _ = try startInspection.start()
            reload()
            return true
        } catch {
            riderError = error.localizedDescription
            return false
        }
    }

    private func updateRideReadyStatus(latest: PreRideInspection?) {
        if store.activeInspection() != nil {
            isRideReady = false
            rideReadyTitle = "Not ride ready"
            rideReadyDetail = "Finish this walk-around before you treat the bike as ride ready."
            return
        }

        if let latest,
           latest.readiness == .readyToRide,
           let completedAt = latest.completedAt,
           Calendar.current.isDateInToday(completedAt) {
            isRideReady = true
            rideReadyTitle = "Ride ready"
            rideReadyDetail = "All checks passed. You're ride ready."
            return
        }

        isRideReady = false
        rideReadyTitle = "Not ride ready"
        if latest?.readiness == .notRideReady {
            rideReadyDetail = "Last walk-around found something that needs attention."
        } else {
            rideReadyDetail = "Do a pre-ride check before you leave."
        }
    }

    private static func specLines(for motorcycle: Motorcycle) -> [String] {
        var lines = [
            "Final drive: \(motorcycle.finalDrive.title)",
            "Tyres: \(motorcycle.frontTyrePressurePSI) front · \(motorcycle.rearTyrePressurePSI) rear psi",
        ]
        if let min = motorcycle.chainSlackMinMillimetres,
           let max = motorcycle.chainSlackMaxMillimetres {
            lines.append("Chain slack: \(min)–\(max) mm")
        }
        return lines
    }

    private static func recentCheck(for inspection: PreRideInspection) -> RecentCheck? {
        guard let completedAt = inspection.completedAt else { return nil }
        let isRideReady = inspection.readiness == .readyToRide
        let flagged = inspection.findings
            .filter { $0.result == .needsAttention }
            .map(\.item.title)

        let resultText: String
        if isRideReady {
            resultText = "Ride ready"
        } else if flagged.isEmpty {
            resultText = "Not ride ready"
        } else {
            resultText = "\(flagged.joined(separator: ", ")) flagged"
        }

        return RecentCheck(
            id: inspection.id,
            dateText: DayTimeText.string(for: completedAt),
            resultText: resultText,
            isRideReady: isRideReady
        )
    }
}
