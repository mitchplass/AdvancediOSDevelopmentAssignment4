import Foundation

/// One atomic JSON file in the App Group. Only the containing app writes it.
struct WidgetSnapshotFile {
    let fileURL: URL?

    init(fileURL: URL?) {
        self.fileURL = fileURL
    }

    init() {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "RideReadyAppGroup") as? String,
              !group.isEmpty,
              let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: group
              ) else {
            fileURL = nil
            return
        }
        fileURL = container.appendingPathComponent("pre-ride-widget-v2.json")
    }

    func read() -> RideReadyWidgetSnapshot? {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(RideReadyWidgetSnapshot.self, from: data),
              snapshot.version == 2 else { return nil }
        return snapshot
    }

    /// Returns false when the existing snapshot is identical.
    @discardableResult
    func write(_ snapshot: RideReadyWidgetSnapshot) throws -> Bool {
        guard let fileURL else { throw SnapshotError.appGroupUnavailable }
        if read() == snapshot { return false }
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
        return true
    }

    enum SnapshotError: Error { case appGroupUnavailable }
}
