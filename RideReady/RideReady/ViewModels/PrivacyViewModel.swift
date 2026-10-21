import Combine
import Foundation

/// Privacy screen state: the on-device policy summary and erasing ride data.
@MainActor
final class PrivacyViewModel: ObservableObject {
    @Published var didErase = false

    private let eraseRideData: EraseRideDataUseCase

    init(store: RideReadyStoring, journal: RideJournalRepository) {
        eraseRideData = EraseRideDataUseCase(store: store, journal: journal)
    }

    func erase() {
        eraseRideData.erase()
        didErase = true
    }

    var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) (\(build))"
    }
}
