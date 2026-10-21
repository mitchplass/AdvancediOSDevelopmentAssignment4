import SwiftUI
import WidgetKit

/// Matches `RideReadyWidgetSnapshot` in the app. The stored names must stay in step.
struct RideReadyWidgetSnapshot: Codable {
    var bikeName: String
    var isRideReady: Bool
    var detail: String
    var streakDays: Int
    var ridePhase: String

    static let appGroupID = "group.com.iosdev.RideReady"
    static let storageKey = "rideReady.widgetSnapshot"

    static let placeholder = RideReadyWidgetSnapshot(
        bikeName: "Yamaha MT-07",
        isRideReady: true,
        detail: "All checks passed today.",
        streakDays: 6,
        ridePhase: "Not riding"
    )

    static func load() -> RideReadyWidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(RideReadyWidgetSnapshot.self, from: data)
    }

    var statusTitle: String {
        isRideReady ? "Ride ready" : "Not ride ready"
    }

    var streakText: String {
        streakDays == 1 ? "1 day streak" : "\(streakDays) day streak"
    }
}

struct RideReadyEntry: TimelineEntry {
    let date: Date
    let snapshot: RideReadyWidgetSnapshot
}

struct RideReadyProvider: TimelineProvider {
    func placeholder(in context: Context) -> RideReadyEntry {
        RideReadyEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (RideReadyEntry) -> Void) {
        let snapshot = context.isPreview ? RideReadyWidgetSnapshot.placeholder : (RideReadyWidgetSnapshot.load() ?? .placeholder)
        completion(RideReadyEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RideReadyEntry>) -> Void) {
        let snapshot = RideReadyWidgetSnapshot.load() ?? RideReadyWidgetSnapshot(
            bikeName: "RideReady",
            isRideReady: false,
            detail: "Open RideReady to set up your bike.",
            streakDays: 0,
            ridePhase: "Not riding"
        )
        let entry = RideReadyEntry(date: Date(), snapshot: snapshot)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct RideReadyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: RideReadyEntry

    private var accent: Color { Color(red: 0.831, green: 0.392, blue: 0.165) }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(entry.snapshot.statusTitle) · \(entry.snapshot.streakText)")
        case .accessoryCircular:
            VStack(spacing: 2) {
                Image(systemName: entry.snapshot.isRideReady ? "checkmark" : "exclamationmark")
                    .font(.headline)
                    .widgetAccentable()
                Text("\(entry.snapshot.streakDays)")
                    .font(.caption2.weight(.semibold))
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.snapshot.statusTitle)
                    .font(.headline)
                    .widgetAccentable()
                Text(entry.snapshot.bikeName)
                    .font(.caption)
                Text(entry.snapshot.streakText)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            home
        }
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: entry.snapshot.isRideReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(entry.snapshot.isRideReady ? Color.green : accent)
                    .widgetAccentable()
                    .accessibilityHidden(true)
                Text(entry.snapshot.statusTitle)
                    .font(.headline)
                Spacer(minLength: 0)
            }
            Text(entry.snapshot.bikeName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            Text(entry.snapshot.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(family == .systemSmall ? 2 : 3)
            Spacer(minLength: 0)
            HStack {
                Label(entry.snapshot.streakText, systemImage: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                    .widgetAccentable()
                Spacer(minLength: 0)
                if entry.snapshot.ridePhase != "Not riding" {
                    Text(entry.snapshot.ridePhase)
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct RideReadyWidget: Widget {
    let kind = "RideReadyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RideReadyProvider()) { entry in
            RideReadyWidgetView(entry: entry)
                .containerBackground(Color(uiColor: .systemBackground), for: .widget)
        }
        .configurationDisplayName("Ride ready")
        .description("See whether your bike is ride ready, and how long your safety streak is.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

@main
struct RideReadyWidgetBundle: WidgetBundle {
    var body: some Widget {
        RideReadyWidget()
    }
}
